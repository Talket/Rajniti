import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ActiveOrderScreen extends StatefulWidget {
  final int tableId;
  const ActiveOrderScreen({super.key, required this.tableId});

  @override
  State<ActiveOrderScreen> createState() => _ActiveOrderScreenState();
}

class _ActiveOrderScreenState extends State<ActiveOrderScreen> {
  final _supabase = Supabase.instance.client;
  
  bool _isLoading = true;
  String _tableNumber = '';
  Map<String, dynamic>? _activeOrder;
  List<Map<String, dynamic>> _orderItems = [];

  @override
  void initState() {
    super.initState();
    _fetchActiveOrder();
  }

  Future<void> _fetchActiveOrder() async {
    setState(() => _isLoading = true);
    try {
      // 1. Get Table Number
      final tableRes = await _supabase.from('tables').select('table_number').eq('id', widget.tableId).single();
      _tableNumber = tableRes['table_number'];

      // 2. Get the active order for this table
      final orderRes = await _supabase
          .from('orders')
          .select()
          .eq('table_id', widget.tableId)
          .eq('status', 'active')
          .maybeSingle();

      if (orderRes != null) {
        _activeOrder = orderRes;
        
        // 3. Get the items for this order linked with item names
        // Supabase allows joining tables if foreign keys are set up
        final itemsRes = await _supabase
            .from('order_items')
            .select('quantity, historical_price, menu_items(name)')
            .eq('order_id', _activeOrder!['id']);
            
        _orderItems = List<Map<String, dynamic>>.from(itemsRes);
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error fetching active order: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _requestBill() async {
    if (_activeOrder == null) return;
    try {
      // Update the table status to trigger the Admin dashboard listener
      await _supabase.from('tables').update({'status': 'bill_requested'}).eq('id', widget.tableId);
      if (mounted) context.go('/captain');
    } catch (e) {
      debugPrint('Error requesting bill: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_activeOrder == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Table $_tableNumber')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Database Error: Table is occupied but has no active order.'),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: () => context.go('/captain'), child: const Text('Go Back'))
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/captain')),
        title: Text('Table $_tableNumber - Active Order', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1b1d3a),
        foregroundColor: Colors.white,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _orderItems.length,
        separatorBuilder: (_, __) => const Divider(),
        itemBuilder: (context, index) {
          final item = _orderItems[index];
          final name = item['menu_items']['name'];
          final qty = item['quantity'];
          final price = item['historical_price'];
          
          return ListTile(
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            subtitle: Text('₹$price x $qty', style: const TextStyle(color: Colors.grey)),
            trailing: Text('₹${(price * qty).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Subtotal', style: TextStyle(color: Colors.grey)),
                  Text('₹${_activeOrder!['total_amount']}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _requestBill,
                icon: const Icon(Icons.receipt),
                label: const Text('REQUEST BILL', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}