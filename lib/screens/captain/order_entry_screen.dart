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

      // CHANGED: Fetch ordered by our new sort_order column
      final catRes = await _supabase.from('menu_categories').select().order('sort_order', ascending: true).order('id');
      _categories = List<Map<String, dynamic>>.from(catRes);

      _categories.insert(0, {'id': -1, 'name': '⭐️ Favourites'});

      final itemRes = await _supabase
          .from('menu_items')
          .select()
          .eq('is_available', true) 
          .order('favourite_sort_order', ascending: true)
          .order('name');
      
      _allItems = List<Map<String, dynamic>>.from(itemRes);

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

    if (_categories.isEmpty) {
      return const Scaffold(body: Center(child: Text("No categories found")));
    }

    final cartTotal = cart.calculateTotal(_allItems);
    final grossTotal = widget.isAppendMode ? cart.existingTotal + cartTotal : cartTotal;
    final grandTotal = grossTotal - cart.discount;

    return DefaultTabController(
      length: _categories.length,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F8), 
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
            style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)
          ),
          backgroundColor: const Color(0xFF1b1d3a),
          foregroundColor: Colors.white,
          elevation: 2,
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            dividerColor: Colors.transparent, 
            indicator: BoxDecoration(
              color: Colors.white, 
              borderRadius: BorderRadius.circular(30),
            ),
            indicatorPadding: const EdgeInsets.only(top: 8, bottom: 8),
            labelColor: const Color(0xFF1b1d3a), 
            unselectedLabelColor: Colors.white70, 
            tabs: _categories.map((cat) => Tab(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(cat['name'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            )).toList(),
          ),
        ),
        
        body: TabBarView(
          physics: const BouncingScrollPhysics(), 
          children: _categories.map((cat) {
            
            final displayedItems = _allItems.where((i) {
              if (cat['id'] == -1) return i['is_favourite'] == true;
              return i['category_id'] == cat['id'];
            }).toList();

            if (displayedItems.isEmpty) {
              return const Center(child: Text('No items in this category', style: TextStyle(color: Colors.grey, fontSize: 16)));
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 12),
              physics: const BouncingScrollPhysics(),
              itemCount: displayedItems.length,
              itemBuilder: (context, index) {
                final item = displayedItems[index];
                final itemId = item['id'];
                final qty = cart.items[itemId] ?? 0;
                final isSelected = qty > 0;
                
                return Card(
                  elevation: isSelected ? 4 : 1,
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shadowColor: isSelected ? Colors.blueAccent.withOpacity(0.3) : Colors.black12,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: isSelected ? const BorderSide(color: Colors.blueAccent, width: 2) : BorderSide(color: Colors.grey.shade200),
                  ),
                  child: InkWell(
                    onTap: () => cart.updateQuantity(itemId, 1),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['name'], 
                                  style: TextStyle(
                                    fontSize: 18, 
                                    fontWeight: FontWeight.bold, 
                                    color: isSelected ? Colors.blueAccent.shade700 : Colors.black87
                                  )
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '₹${item['price']}', 
                                  style: const TextStyle(fontSize: 16, color: Colors.green, fontWeight: FontWeight.w700)
                                ),
                              ],
                            ),
                          ),
                          
                          if (isSelected)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 30),
                                  onPressed: () => cart.updateQuantity(itemId, -1),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.blueAccent,
                                    borderRadius: BorderRadius.circular(12)
                                  ),
                                  child: Text('$qty', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                                ),
                              ],
                            )
                          else
                            const Icon(Icons.add_circle_outline, color: Colors.black26, size: 30),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          }).toList(),
        ),
        
        bottomNavigationBar: (cart.isEmpty && !cart.hasExistingOrder) ? null : SafeArea(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white, 
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))]
            ),
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
                        backgroundColor: Colors.blueAccent.shade700, 
                        foregroundColor: Colors.white, 
                        padding: const EdgeInsets.symmetric(vertical: 16), 
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                      ),
                      child: cart.isSubmitting 
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)) 
                          : const Text('SEND KOT', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}