import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CartProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  
  final Map<int, int> _items = {};
  dynamic _currentOrderId; 
  bool _isSubmitting = false;
  bool _isLoading = false;
  
  String? customerName; 
  double _discount = 0; 
  List<String> _selectedComments = []; // ADDED: List of selected comments

  bool _isAppendMode = false;
  double _existingTotal = 0; 

  Map<int, int> get items => _items;
  bool get isSubmitting => _isSubmitting;
  bool get isLoading => _isLoading;
  bool get isEmpty => _items.isEmpty;
 bool get hasExistingOrder => _currentOrderId != null;
  bool get isAppendMode => _isAppendMode;
  double get existingTotal => _existingTotal;
  double get discount => _discount; 
  List<String> get selectedComments => _selectedComments; // ADDED: Getter

  void setCustomerName(String name) {
    customerName = name;
    notifyListeners();
  }

  void setDiscount(double amount) {
    _discount = amount;
    notifyListeners();
  }

  // ADDED: Toggle comments in and out of the list
  void toggleComment(String comment) {
    if (_selectedComments.contains(comment)) {
      _selectedComments.remove(comment);
    } else {
      _selectedComments.add(comment);
    }
    notifyListeners();
  }

  Future<void> loadExistingOrder(int tableId, {bool appendMode = false, dynamic specificOrderId}) async {
    _isLoading = true;
    _items.clear();
    _currentOrderId = null;
    customerName = null;
    _discount = 0; 
    _selectedComments = []; // Reset comments
    _isAppendMode = appendMode;
    _existingTotal = 0;
    notifyListeners();

    try {
      Map<String, dynamic>? targetOrder;

      // 1. If Admin clicked a specific order card, load that exact order
      if (specificOrderId != null) {
        targetOrder = await _supabase.from('orders').select().eq('id', specificOrderId).maybeSingle();
      } else {
        // 2. If Captain taps a table, intelligently pick the active one and IGNORE settling bills
        final ordersRes = await _supabase
            .from('orders')
            .select()
            .eq('table_id', tableId)
            .inFilter('status', const ['active', 'printed'])
            .order('status', ascending: true); 

        if (ordersRes.isNotEmpty) {
          final activeOrder = ordersRes.where((o) => o['status'] == 'active').firstOrNull;
          final printedOrder = ordersRes.where((o) => o['status'] == 'printed').firstOrNull;

          if (activeOrder != null) {
            targetOrder = activeOrder;
          } else if (printedOrder != null && !appendMode) {
            targetOrder = printedOrder;
          }
        }
      }

      if (targetOrder != null) {
        _currentOrderId = targetOrder['id'];
        customerName = targetOrder['customer_name']; 
        _discount = (targetOrder['discount'] as num?)?.toDouble() ?? 0;
        _existingTotal = (targetOrder['total_amount'] as num?)?.toDouble() ?? 0.0;
        
        // ADDED: Load existing comments if they exist
        final dbComments = targetOrder['comments']?.toString() ?? '';
        if (dbComments.isNotEmpty) {
          _selectedComments = dbComments.split(' | ').where((s) => s.isNotEmpty).toList();
        }
        
        if (!appendMode) {
          final itemsRes = await _supabase
              .from('order_items')
              .select('menu_item_id, quantity')
              .eq('order_id', _currentOrderId);

          // THE FIX IS HERE: We now ADD duplicate items together instead of overwriting them!
          for (var item in itemsRes) {
            final itemId = item['menu_item_id'];
            final qty = (item['quantity'] as num).toInt();
            
            if (_items.containsKey(itemId)) {
              _items[itemId] = _items[itemId]! + qty;
            } else {
              _items[itemId] = qty;
            }
          }
        } else {
          // If we are appending, we need the Gross Total from last time
          _existingTotal = _existingTotal + _discount;
        }
      }
    } catch (e) {
      debugPrint('Error loading active order: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void updateQuantity(int itemId, int delta) {
    final currentQty = _items[itemId] ?? 0;
    final newQty = currentQty + delta;
    if (newQty <= 0) {
      _items.remove(itemId);
    } else {
      _items[itemId] = newQty;
    }
    notifyListeners();
  }

  void removeItem(int itemId) {
    _items.remove(itemId);
    notifyListeners();
  }

 void clearCart() {
    _items.clear();
    _currentOrderId = null;
    customerName = null;
    _discount = 0; 
    _selectedComments = []; // Reset
    _isAppendMode = false;
    _existingTotal = 0;
    notifyListeners();
  }

  double calculateTotal(List<Map<String, dynamic>> allMenuData) {
    double total = 0;
    _items.forEach((itemId, qty) {
      final item = allMenuData.firstWhere((i) => i['id'] == itemId, orElse: () => <String, dynamic>{});
      if (item.isNotEmpty) total += (item['price'] as num).toDouble() * qty;
    });
    return total;
  }

  Future<String?> _processOrder(int tableId, List<Map<String, dynamic>> allMenuData, {required bool isPrinting}) async {
    if (_items.isEmpty && _currentOrderId == null) return 'Cart is empty';
    _isSubmitting = true;
    notifyListeners();

    try {
      final newItemsTotal = calculateTotal(allMenuData);
      final grossTotal = _isAppendMode ? (_existingTotal + newItemsTotal) : newItemsTotal;
      final finalTotalAmount = grossTotal - _discount; 
      
      dynamic orderId;
      final targetOrderStatus = isPrinting ? 'printed' : 'active';
      // CHANGED: Instantly set table to vacant when printed, freeing it up for the Captain!
      final targetTableStatus = isPrinting ? 'vacant' : 'occupied'; 

      // ADD THIS LINE HERE: Combine selected comments into a single string
      final commentsString = _selectedComments.isEmpty ? null : _selectedComments.join(' | ');

      if (_currentOrderId == null) {
        final orderRes = await _supabase.from('orders').insert({
          'table_id': tableId == 0 ? null : tableId, 
          'captain_id': _supabase.auth.currentUser!.id,
          'order_type': tableId == 0 ? 'pickup' : 'dine_in',
          'status': targetOrderStatus,
          'total_amount': finalTotalAmount,
          'customer_name': customerName, 
          'discount': _discount, 
          'comments': commentsString, // Save to DB
        }).select('id').single();
        orderId = orderRes['id'];
      } else {
       orderId = _currentOrderId;
        
        await _supabase.from('orders').update({
          'total_amount': finalTotalAmount,
          'status': targetOrderStatus,
          'customer_name': customerName, 
          'discount': _discount, 
          'comments': commentsString, // Update in DB
        }).eq('id', orderId);
        
        // This consolidates all KOTs into one clean receipt when the admin saves!
        if (!_isAppendMode) {
          await _supabase.from('order_items').delete().eq('order_id', orderId);
        }
      }

      if (tableId != 0) {
        await _supabase.from('tables').update({'status': targetTableStatus}).eq('id', tableId);
      }
      
      if (_items.isNotEmpty) {
        final itemsToInsert = _items.entries.map((e) {
          final item = allMenuData.firstWhere((i) => i['id'] == e.key, orElse: () => <String, dynamic>{});
          return {
            'order_id': orderId, 
            'menu_item_id': item['id'] ?? e.key, 
            'quantity': e.value, 
            'historical_price': item['price'] ?? 0
          };
        }).toList();
        await _supabase.from('order_items').insert(itemsToInsert);
      } else if (!isPrinting && !_isAppendMode) {
         await _supabase.from('orders').delete().eq('id', orderId);
         if (tableId != 0) {
           await _supabase.from('tables').update({'status': 'vacant'}).eq('id', tableId);
         }
      }
      
      clearCart();
      return null; 
    } catch (e) {
      debugPrint('Order Processing Failed: $e');
      return e.toString(); 
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<String?> sendKOT(int tableId, List<Map<String, dynamic>> allMenuData) async {
    return await _processOrder(tableId, allMenuData, isPrinting: false);
  }

  Future<String?> printBill(int tableId, List<Map<String, dynamic>> allMenuData) async {
    return await _processOrder(tableId, allMenuData, isPrinting: true);
  }
}