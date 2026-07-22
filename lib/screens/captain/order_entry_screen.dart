import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../../state/cart_provider.dart';

class OrderEntryScreen extends StatefulWidget {
  final int tableId;
  final bool isAppendMode; 

  const OrderEntryScreen({
    super.key, 
    required this.tableId,
    this.isAppendMode = true, 
  });

  @override
  State<OrderEntryScreen> createState() => _OrderEntryScreenState();
}

class _OrderEntryScreenState extends State<OrderEntryScreen> {
  final _supabase = Supabase.instance.client;
  
  String _tableNumber = 'Loading...';
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _allItems = [];
  int? _selectedCategoryId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMenuAndTable();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CartProvider>().loadExistingOrder(widget.tableId, appendMode: widget.isAppendMode);
    });
  }

  Future<void> _fetchMenuAndTable() async {
    try {
      if (widget.tableId != 0) {
        final tableRes = await _supabase.from('tables').select('table_number').eq('id', widget.tableId).single();
        _tableNumber = tableRes['table_number'];
      } else {
        _tableNumber = "Pickup";
      }

      final catRes = await _supabase.from('menu_categories').select().order('id');
      _categories = List<Map<String, dynamic>>.from(catRes);

      // ADDED: Inject the Favourites tab back into the top bar
      _categories.insert(0, {'id': -1, 'name': '⭐️ Favourites'});

      final itemRes = await _supabase
          .from('menu_items')
          .select()
          .eq('is_available', true) 
          // Custom Sort Order added here!
          .order('favourite_sort_order', ascending: true)
          .order('name');
      
      _allItems = List<Map<String, dynamic>>.from(itemRes);

      if (_categories.isNotEmpty) _selectedCategoryId = _categories.first['id'];
    } catch (e) {
      debugPrint('Error fetching menu: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    
    if (_isLoading || cart.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // CRITICAL FIX: Handle logic when "Favourites" (-1) is selected
    final displayedItems = _allItems.where((i) {
      if (_selectedCategoryId == -1) return i['is_favourite'] == true;
      return i['category_id'] == _selectedCategoryId;
    }).toList();
    
    // UPDATED MATH: Calculates Gross Total first, then subtracts discount for the final display
    final cartTotal = cart.calculateTotal(_allItems);
    final grossTotal = widget.isAppendMode ? cart.existingTotal + cartTotal : cartTotal;
    final grandTotal = grossTotal - cart.discount;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back), 
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/captain');
            }
          }
        ),
        title: Text(
          widget.tableId == 0 
            ? 'Pickup Order' 
            : 'Table $_tableNumber ${widget.isAppendMode ? '(New KOT)' : '(Full Bill)'}', 
          style: const TextStyle(fontWeight: FontWeight.bold)
        ),
        backgroundColor: const Color(0xFF1b1d3a),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            height: 60,
            color: Colors.white,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = cat['id'] == _selectedCategoryId;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategoryId = cat['id']),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: isSelected ? Colors.blueAccent : Colors.transparent, width: 3))),
                    child: Center(child: Text(cat['name'], style: TextStyle(fontSize: 16, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? Colors.blueAccent : Colors.black54))),
                  ),
                );
              },
            ),
          ),
          
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: displayedItems.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = displayedItems[index];
                final itemId = item['id'];
                final qty = cart.items[itemId] ?? 0;
                
                return Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item['name'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              Text('₹${item['price']}', style: const TextStyle(fontSize: 16, color: Colors.green, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            children: [
                              if (qty > 0) ...[
                                IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.red), onPressed: () => cart.updateQuantity(itemId, -1)),
                                Text('$qty', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              ],
                              IconButton(icon: const Icon(Icons.add_circle, color: Colors.blueAccent, size: 28), onPressed: () => cart.updateQuantity(itemId, 1)),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      
      bottomNavigationBar: (cart.isEmpty && !cart.hasExistingOrder) ? null : SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))]),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.isAppendMode && cart.existingTotal > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Previous Bill', style: TextStyle(fontSize: 14, color: Colors.grey)),
                      Text('₹${cart.existingTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, color: Colors.grey)),
                    ],
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Amount', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  Text('₹${grandTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87)),
                ],
              ),
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton(
                    onPressed: cart.isSubmitting ? null : () async {
                      final error = await cart.sendKOT(widget.tableId, _allItems);
                      if (error == null && mounted) {
                        if (context.canPop()) { context.pop(); } else { context.go('/captain'); }
                      } else if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('DB ERROR: $error', style: const TextStyle(fontWeight: FontWeight.bold)),
                          backgroundColor: Colors.red,
                        ));
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey, 
                      foregroundColor: Colors.white, 
                      padding: const EdgeInsets.symmetric(vertical: 12)
                    ),
                    child: cart.isSubmitting 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                        : const Text('Send KOT', style: TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: cart.items.isEmpty && !cart.hasExistingOrder ? null : () async {
                      final error = await cart.printBill(widget.tableId, _allItems);
                      if (error != null) {
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Bill sent to Admin PC!'), backgroundColor: Colors.green)
                          );
                          context.pop();
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Save & Print', style: TextStyle(fontSize: 16)),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}