import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../state/cart_provider.dart';

class AdminOrderEntryScreen extends StatefulWidget {
  final int tableId;
  final bool isAppendMode;
  final dynamic orderId; // CRITICAL FIX: Changed from int? to dynamic to support UUID

  const AdminOrderEntryScreen({
    super.key, 
    required this.tableId, 
    this.isAppendMode = true,
    this.orderId,
  });

  @override
  State<AdminOrderEntryScreen> createState() => _AdminOrderEntryScreenState();
}

class _AdminOrderEntryScreenState extends State<AdminOrderEntryScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _allItems = [];
  List<Map<String, dynamic>> _masterComments = []; 
  
  bool _isLoading = true;
  String _tableName = '...';
  int? _selectedCategoryId;
  
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      if (widget.tableId != 0) {
        final tableRes = await _supabase.from('tables').select('table_number').eq('id', widget.tableId).maybeSingle();
        if (tableRes != null) _tableName = tableRes['table_number'];
      } else {
        _tableName = "Pickup";
      }

      final catRes = await _supabase.from('menu_categories').select().order('id');
      
      // CHANGED: Fetch items ordered by favourite_sort_order first!
      final itemsRes = await _supabase.from('menu_items').select().order('favourite_sort_order', ascending: true).order('name');
      final commentsRes = await _supabase.from('order_comments_master').select().order('id'); 
      
      if (mounted) {
        setState(() {
          _categories = List<Map<String, dynamic>>.from(catRes);
          
          // ADDED: Inject the Favourites tab back into the sidebar
          _categories.insert(0, {'id': -1, 'name': '⭐️ Favourites'});
          
          _allItems = List<Map<String, dynamic>>.from(itemsRes);
          _masterComments = List<Map<String, dynamic>>.from(commentsRes); 
          if (_categories.isNotEmpty) {
            _selectedCategoryId = _categories.first['id'];
          }
          _isLoading = false;
        });

        // Initialize cart provider and load existing name if any
        final provider = context.read<CartProvider>();
        await provider.loadExistingOrder(widget.tableId, appendMode: widget.isAppendMode, specificOrderId: widget.orderId);
        if (provider.customerName != null) {
          _nameController.text = provider.customerName!;
        }
      }
    } catch (e) {
      debugPrint('Error loading menu: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleAction(String action) async {
    final provider = context.read<CartProvider>();
    if (provider.items.isEmpty && !provider.hasExistingOrder) return;
    
    // Save customer name before processing
    provider.setCustomerName(_nameController.text.trim());

    String? error;
    if (action == 'KOT') {
      error = await provider.sendKOT(widget.tableId, _allItems);
    } else if (action == 'PRINT') {
      error = await provider.printBill(widget.tableId, _allItems);
    } else {
      error = await provider.sendKOT(widget.tableId, _allItems);
    }

    if (error != null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    } else {
      if (mounted) {
        if (action == 'PRINT') {
           final isCaptain = GoRouterState.of(context).uri.toString().contains('captain');
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(
               content: Text(isCaptain ? 'Bill sent to Admin PC!' : 'Generating Print...'),
               backgroundColor: isCaptain ? Colors.green : Colors.blue[800],
             )
           );
        }
        context.pop();
      }
    }
  }

  Future<void> _showCommentsDialog(CartProvider provider) async {
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Select Comments'),
              content: SizedBox(
                width: 300,
                height: 400,
                child: _masterComments.isEmpty 
                  ? const Center(child: Text('No comments in master list.'))
                  : ListView.builder(
                      itemCount: _masterComments.length,
                      itemBuilder: (context, index) {
                        final commentStr = _masterComments[index]['comment_text'] as String;
                        final isSelected = provider.selectedComments.contains(commentStr);
                        
                        return CheckboxListTile(
                          title: Text(commentStr),
                          value: isSelected,
                          onChanged: (bool? value) {
                            provider.toggleComment(commentStr);
                            setDialogState(() {}); // Rebuild dialog
                          },
                        );
                      },
                    ),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800], foregroundColor: Colors.white),
                  child: const Text('Done'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  Future<void> _showDiscountDialog(CartProvider provider) async {
    final TextEditingController discountController = TextEditingController(
      text: provider.discount > 0 ? provider.discount.toStringAsFixed(0) : ''
    );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apply Discount'),
        content: TextField(
          controller: discountController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Discount Amount (₹)',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.currency_rupee),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(discountController.text) ?? 0;
              provider.setDiscount(amount);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800], foregroundColor: Colors.white),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final cartProvider = context.watch<CartProvider>();
    final newItemsTotal = cartProvider.calculateTotal(_allItems);
    
    // CALCULATE SUBTOTAL BEFORE DISCOUNT
     final subTotal = cartProvider.isAppendMode && cartProvider.hasExistingOrder
        ? cartProvider.existingTotal + newItemsTotal 
        : newItemsTotal;
        
    // CALCULATE FINAL GRAND TOTAL
    final grandTotal = subTotal - cartProvider.discount;
    
    // CRITICAL FIX: Handle logic when "Favourites" (-1) is selected
    final displayItems = _allItems.where((item) {
      if (item['is_available'] != true) return false;
      if (_selectedCategoryId == -1) return item['is_favourite'] == true;
      return item['category_id'] == _selectedCategoryId;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5), // Light background
      appBar: AppBar(
        title: Text(
          widget.tableId == 0 
            ? 'Pickup Order' 
            : 'Table: $_tableName ${widget.isAppendMode ? '(New KOT)' : '(Full Bill)'}', 
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          IconButton(icon: const Icon(Icons.close), onPressed: () => context.pop()),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. LEFT SIDEBAR: Categories
          Container(
            width: 220,
            color: Colors.white,
            child: ListView.separated(
              itemCount: _categories.length,
              separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.black12),
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = category['id'] == _selectedCategoryId;
                return Material(
                  color: isSelected ? const Color(0xFFFFF0F0) : Colors.transparent, // Light red tint for selected
                  child: InkWell(
                    onTap: () => setState(() => _selectedCategoryId = category['id']),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            color: isSelected ? Colors.red : Colors.transparent,
                            width: 4,
                          ),
                        ),
                      ),
                      child: Text(
                        category['name'],
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Colors.red.shade800 : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          // 2. MIDDLE AREA: Menu Items Grid
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              child: displayItems.isEmpty 
                ? const Center(child: Text('No available items in this category'))
                : GridView.builder(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 200,
                      childAspectRatio: 2.2, // Rectangular buttons
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: displayItems.length,
                    itemBuilder: (context, index) {
                      final item = displayItems[index];
                      return InkWell(
                        onTap: () => cartProvider.updateQuantity(item['id'], 1),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0,1))],
                            border: const Border(left: BorderSide(color: Colors.green, width: 4)),
                          ),
                          padding: const EdgeInsets.all(12),
                          alignment: Alignment.centerLeft,
                          child: Text(
                            item['name'],
                            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      );
                    },
                  ),
            ),
          ),
          
          // 3. RIGHT SIDEBAR: Cart / Order Details
          Container(
            width: 400, // Fixed width for Cart
            color: Colors.white,
            child: Column(
              children: [
                // Top Header (Table Indicator & Name Input)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black12))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.table_restaurant, size: 20, color: Colors.black54),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(border: Border.all(color: Colors.black26), borderRadius: BorderRadius.circular(4)),
                            child: Text(
                              _tableName, 
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // The Comments Button
                          InkWell(
                            onTap: () => _showCommentsDialog(cartProvider),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: cartProvider.selectedComments.isNotEmpty ? Colors.blue.shade50 : Colors.transparent,
                                border: Border.all(color: Colors.blue.shade300), 
                                borderRadius: BorderRadius.circular(16)
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.comment, size: 14, color: Colors.blue.shade700),
                                  const SizedBox(width: 6),
                                  Text(
                                    cartProvider.selectedComments.isEmpty 
                                      ? 'Add Comment' 
                                      : '${cartProvider.selectedComments.length} Selected', 
                                    style: TextStyle(color: Colors.blue.shade700, fontSize: 12, fontWeight: FontWeight.bold)
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Text('Please Enter Name of Person', style: TextStyle(fontSize: 12, color: Colors.black54)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 35,
                              child: TextField(
                                controller: _nameController,
                                decoration: const InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Cart Headers
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black12))),
                  child: const Row(
                    children: [
                      Expanded(flex: 4, child: Text('ITEMS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54))),
                      Expanded(flex: 3, child: Text('QTY.', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54))),
                      Expanded(flex: 2, child: Text('PRICE', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54))),
                    ],
                  ),
                ),
                
                // Cart Items List
                Expanded(
                  child: cartProvider.items.isEmpty
                      ? const Center(child: Text('No items added', style: TextStyle(color: Colors.grey)))
                      : ListView.separated(
                          itemCount: cartProvider.items.length,
                          separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.black12),
                          itemBuilder: (context, index) {
                            final itemId = cartProvider.items.keys.elementAt(index);
                            final qty = cartProvider.items.values.elementAt(index);
                            final itemData = _allItems.firstWhere((i) => i['id'] == itemId, orElse: () => <String, dynamic>{});
                            if (itemData.isEmpty) return const SizedBox.shrink();
                            
                            final price = (itemData['price'] as num).toDouble();
                            final itemTotal = price * qty;
                            
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              child: Row(
                                children: [
                                  // Delete Button
                                  InkWell(
                                    onTap: () => cartProvider.removeItem(itemId),
                                    child: const Icon(Icons.cancel, color: Colors.red, size: 20),
                                  ),
                                  const SizedBox(width: 8),
                                  
                                  // Item Name
                                  Expanded(
                                    flex: 4,
                                    child: Text(
                                      itemData['name'],
                                      style: const TextStyle(fontWeight: FontWeight.w500, decoration: TextDecoration.underline),
                                    ),
                                  ),
                                  
                                  // Qty Control
                                  Expanded(
                                    flex: 3,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        InkWell(
                                          onTap: () => cartProvider.updateQuantity(itemId, -1),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(border: Border.all(color: Colors.black26), borderRadius: BorderRadius.circular(4)),
                                            child: const Text('-', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 8),
                                          child: Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold)),
                                        ),
                                        InkWell(
                                          onTap: () => cartProvider.updateQuantity(itemId, 1),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(border: Border.all(color: Colors.black26), borderRadius: BorderRadius.circular(4)),
                                            child: const Text('+', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  // Price
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(itemTotal.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                        Text(price.toStringAsFixed(2), style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
                
                // Total Area
                 Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.black12)), color: Color(0xFFF9F9F9)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (cartProvider.isAppendMode && cartProvider.existingTotal > 0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text('Previous Bill: ₹${cartProvider.existingTotal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w500)),
                        ),
                        
                      if (cartProvider.discount > 0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text('Subtotal: ₹${subTotal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 14, color: Colors.black54)),
                        ),
                        
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            InkWell(
                              onTap: () => _showDiscountDialog(cartProvider),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  border: Border.all(color: Colors.blue.shade200),
                                  borderRadius: BorderRadius.circular(4)
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.discount, size: 14, color: Colors.blue),
                                    SizedBox(width: 4),
                                    Text('Discount', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12)),
                                  ],
                                ),
                              ),
                            ),
                            if (cartProvider.discount > 0) ...[
                              const SizedBox(width: 8),
                              Text('- ₹${cartProvider.discount.toStringAsFixed(0)}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                              IconButton(
                                icon: const Icon(Icons.cancel, size: 16, color: Colors.red),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => cartProvider.setDiscount(0),
                              )
                            ]
                          ],
                        ),
                      ),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const Text('Total ₹', style: TextStyle(fontSize: 16)),
                          Text(grandTotal.toStringAsFixed(0), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Action Buttons
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      _buildActionButton('Save & Print', const Color(0xFFD32F2F), () => _handleAction('PRINT'), cartProvider),
                      _buildActionButton('Save & EBill', const Color(0xFFD32F2F), () => _handleAction('KOT'), cartProvider), // Maps to Save for now
                      _buildActionButton('KOT', const Color(0xFF546E7A), () => _handleAction('KOT'), cartProvider),
                      _buildActionButton('KOT & Print', const Color(0xFF546E7A), () => _handleAction('PRINT'), cartProvider),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, Color color, VoidCallback onTap, CartProvider provider) {
    final isDisabled = provider.items.isEmpty && !provider.hasExistingOrder;
    return ElevatedButton(
      onPressed: isDisabled || provider.isSubmitting ? null : onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      child: provider.isSubmitting 
        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
        : Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}