import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// THIS IS THE MAGIC LINE that fixes the 'Border' error:
import 'package:excel/excel.dart' hide Border; 

class ItemReportScreen extends StatefulWidget {
  const ItemReportScreen({super.key});

  @override
  State<ItemReportScreen> createState() => _ItemReportScreenState();
}

class _ItemReportScreenState extends State<ItemReportScreen> {
  final _supabase = Supabase.instance.client;
  
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  bool _isLoading = true;
  
  List<Map<String, dynamic>> _categories = [];
  double _totalQty = 0;
  double _totalAmount = 0;

  @override
  void initState() {
    super.initState();
    _fetchReportData();
  }

  Future<void> _fetchReportData() async {
    setState(() => _isLoading = true);
    try {
      // Calculate start of from-date and end of to-date
      final startOfDay = DateTime(_startDate.year, _startDate.month, _startDate.day);
      final endOfDay = DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59, 999);

      // 1. Fetch completed orders in the exact date range
      final ordersRes = await _supabase
          .from('orders')
          .select('id')
          .eq('status', 'completed')
          .gte('created_at', startOfDay.toIso8601String())
          .lte('created_at', endOfDay.toIso8601String());

      if (ordersRes.isEmpty) {
        setState(() {
          _categories = [];
          _totalQty = 0;
          _totalAmount = 0;
          _isLoading = false;
        });
        return;
      }

      final orderIds = ordersRes.map((o) => o['id']).toList();

      // 2. Fetch order items for these orders
      final itemsRes = await _supabase
          .from('order_items')
          .select('menu_item_id, quantity, historical_price')
          .inFilter('order_id', orderIds);

      // 3. Fetch menu master data
      final menuItemsRes = await _supabase.from('menu_items').select('id, name, category_id');
      final categoriesRes = await _supabase.from('menu_categories').select('id, name');

      // 4. Aggregate data securely
      Map<int, Map<String, dynamic>> categoryMap = {};
      double grandTotalQty = 0;
      double grandTotalAmount = 0;

      for (var cat in categoriesRes) {
        categoryMap[cat['id']] = {
          'id': cat['id'],
          'name': cat['name'],
          'items': <int, Map<String, dynamic>>{}, 
          'totalQty': 0.0,
          'totalAmount': 0.0,
        };
      }

      for (var orderItem in itemsRes) {
        final menuItemId = orderItem['menu_item_id'];
        final qty = (orderItem['quantity'] as num).toDouble();
        final price = (orderItem['historical_price'] as num).toDouble();
        
        final menuItemDef = menuItemsRes.firstWhere((m) => m['id'] == menuItemId, orElse: () => <String, dynamic>{});
        if (menuItemDef.isEmpty) continue;

        final categoryId = menuItemDef['category_id'];
        final itemName = menuItemDef['name'];
        final itemCode = menuItemDef['id'].toString(); 

        if (categoryMap.containsKey(categoryId)) {
           var catItems = categoryMap[categoryId]!['items'] as Map<int, Map<String, dynamic>>;
           if (catItems.containsKey(menuItemId)) {
             catItems[menuItemId]!['qty'] += qty;
             catItems[menuItemId]!['total'] += (qty * price);
           } else {
             catItems[menuItemId] = {
               'name': itemName,
               'code': itemCode,
               'qty': qty,
               'total': (qty * price),
             };
           }
           categoryMap[categoryId]!['totalQty'] += qty;
           categoryMap[categoryId]!['totalAmount'] += (qty * price);
           grandTotalQty += qty;
           grandTotalAmount += (qty * price);
        }
      }

      List<Map<String, dynamic>> finalCategories = [];
      categoryMap.forEach((_, catData) {
        if ((catData['items'] as Map).isNotEmpty) {
          catData['itemsList'] = (catData['items'] as Map).values.toList();
          finalCategories.add(catData);
        }
      });

      setState(() {
         _categories = finalCategories;
         _totalQty = grandTotalQty;
         _totalAmount = grandTotalAmount;
      });

    } catch (e) {
      debugPrint('Error fetching report: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _exportToExcel() {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Item Report'];

    // Adding Table Headers (All 'const' removed to fix the error)
    sheetObject.appendRow([
      TextCellValue('Category'), 
      TextCellValue('Item'), 
      TextCellValue('Code'), 
      TextCellValue('Qty'), 
      TextCellValue('Total')
    ]);
    
    // Iterating over the categories and items to fill the rows
    for (var cat in _categories) {
      sheetObject.appendRow([TextCellValue(cat['name'].toString())]);
      for (var item in cat['itemsList']) {
        sheetObject.appendRow([
          TextCellValue(''), 
          TextCellValue(item['name'].toString()), 
          TextCellValue(item['code'].toString()), 
          DoubleCellValue(item['qty']), 
          DoubleCellValue(item['total'])
        ]);
      }
    }
    
    // Appending Grand Total row
    sheetObject.appendRow([
      TextCellValue('Grand Total'), 
      TextCellValue(''),            
      TextCellValue(''),            
      DoubleCellValue(_totalQty), 
      DoubleCellValue(_totalAmount)
    ]);

    // THE FIX: We simply let the excel package handle the web download natively by passing a fileName!
    excel.save(fileName: "item_report_${_formatDate(_startDate)}.xlsx");
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1b1d3a),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _fetchReportData();
    }
  }

  String _formatDate(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}";
  }

  @override
  Widget build(BuildContext context) {
    // Determine the exact string to display based on whether it is 1 day or a range
    bool isSameDay = _startDate.year == _endDate.year && 
                     _startDate.month == _endDate.month && 
                     _startDate.day == _endDate.day;
                     
    String dateRangeText = isSameDay 
        ? 'Item Report : From ${_formatDate(_startDate)}'
        : 'Item Report : From ${_formatDate(_startDate)} To ${_formatDate(_endDate)}';

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Top buttons bar
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.search, size: 16),
                  label: const Text('Search'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.view_column, size: 16),
                  label: const Text('Configure Column'),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: _selectDateRange,
                  icon: const Icon(Icons.access_time, size: 16),
                  label: const Text('Time Wise'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.print, size: 16),
                  label: const Text('Print'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _exportToExcel,
                  icon: const Icon(Icons.file_download, size: 16),
                  label: const Text('Export Excel'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Data Table Area
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  // NO COLLISION HERE because we hid excel's version of Border
                  border: Border.all(color: Colors.grey.shade300), 
                ),
                child: Column(
                  children: [
                    // Date Header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFAF5F5), // Light pinkish
                        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                      ),
                      child: Text(
                        dateRangeText,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54),
                      ),
                    ),
                    
                    // Table Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      color: Colors.grey[200],
                      child: const Row(
                        children: [
                          Expanded(flex: 3, child: Text('Category', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54))),
                          Expanded(flex: 3, child: Text('Item', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54))),
                          Expanded(flex: 2, child: Text('Code', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54))),
                          Expanded(flex: 2, child: Text('Qty.', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54), textAlign: TextAlign.right)),
                          Expanded(flex: 2, child: Text('Total (₹)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54), textAlign: TextAlign.right)),
                        ],
                      ),
                    ),
                    
                    // Total Row (Top)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      color: Colors.grey[300],
                      child: Row(
                        children: [
                          const Expanded(flex: 3, child: Text('Total', style: TextStyle(fontWeight: FontWeight.bold))),
                          const Expanded(flex: 3, child: Text('-')),
                          const Expanded(flex: 2, child: Text('-')),
                          Expanded(flex: 2, child: Text(_totalQty.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                          Expanded(flex: 2, child: Text(_totalAmount.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                        ],
                      ),
                    ),

                    // List Area
                    Expanded(
                      child: _isLoading 
                        ? const Center(child: CircularProgressIndicator())
                        : _categories.isEmpty
                          ? const Center(child: Text('No completed orders found for selected dates.'))
                          : ListView.builder(
                              itemCount: _categories.length,
                              itemBuilder: (context, index) {
                                final category = _categories[index];
                                final items = category['itemsList'] as List<dynamic>;
                                return Theme(
                                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                  child: ExpansionTile(
                                    title: Row(
                                      children: [
                                        Expanded(flex: 3, child: Text(category['name'], style: const TextStyle(fontWeight: FontWeight.bold))),
                                        const Expanded(flex: 3, child: Text('')),
                                        const Expanded(flex: 2, child: Text('')),
                                        Expanded(flex: 2, child: Text(category['totalQty'].toStringAsFixed(2), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                                        Expanded(flex: 2, child: Text(category['totalAmount'].toStringAsFixed(2), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                                      ],
                                    ),
                                    backgroundColor: const Color(0xFFFAF5F5),
                                    collapsedBackgroundColor: const Color(0xFFFAF5F5),
                                    initiallyExpanded: true,
                                    children: items.map((item) {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                                        ),
                                        child: Row(
                                          children: [
                                            const Expanded(flex: 3, child: SizedBox()), // Empty space to align under 'Category'
                                            Expanded(flex: 3, child: Text(item['name'])),
                                            Expanded(flex: 2, child: Text(item['code'])),
                                            Expanded(flex: 2, child: Text(item['qty'].toStringAsFixed(2), textAlign: TextAlign.right)),
                                            Expanded(flex: 2, child: Text(item['total'].toStringAsFixed(2), textAlign: TextAlign.right)),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                );
                              },
                            ),
                    ),
                    
                    // Sub Total Row (Bottom)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      color: Colors.grey[300],
                      child: Row(
                        children: [
                          const Expanded(flex: 3, child: Text('Sub Total', style: TextStyle(fontWeight: FontWeight.bold))),
                          const Expanded(flex: 3, child: Text('')),
                          const Expanded(flex: 2, child: Text('')),
                          Expanded(flex: 2, child: Text(_totalQty.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                          Expanded(flex: 2, child: Text(_totalAmount.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}