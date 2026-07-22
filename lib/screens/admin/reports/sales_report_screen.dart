import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:excel/excel.dart' hide Border;

class SalesReportScreen extends StatefulWidget {
  const SalesReportScreen({super.key});

  @override
  State<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends State<SalesReportScreen> {
  final _supabase = Supabase.instance.client;
  
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  bool _isLoading = true;
  
  List<Map<String, dynamic>> _orders = [];
  
  // Totals
  double _sumMyAmount = 0;
  double _sumDiscount = 0;
  double _sumWavedOff = 0;
  double _sumTotal = 0;

  @override
  void initState() {
    super.initState();
    _fetchReportData();
  }

  Future<void> _fetchReportData() async {
    setState(() => _isLoading = true);
    try {
      final startOfDay = DateTime(_startDate.year, _startDate.month, _startDate.day);
      final endOfDay = DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59, 999);

      final res = await _supabase
          .from('orders')
          .select()
          .eq('status', 'completed')
          .gte('created_at', startOfDay.toIso8601String())
          .lte('created_at', endOfDay.toIso8601String())
          .order('created_at');

      double tMyAmount = 0;
      double tDiscount = 0;
      double tWavedOff = 0;
      double tTotal = 0;

      List<Map<String, dynamic>> processedOrders = [];

      for (var order in res) {
        final createdAt = DateTime.parse(order['created_at']);
        final yearStr = createdAt.year.toString().substring(2);
        // Fallback to 'id' for old orders created before the SQL trigger was added
        final seq = order['yearly_seq'] ?? order['id']; 
        
        final discount = (order['discount'] as num?)?.toDouble() ?? 0.0;
        final billAmount = (order['total_amount'] as num?)?.toDouble() ?? 0.0; 
        
        final myAmount = billAmount + discount; 
        final settledAmount = (order['settled_amount'] as num?)?.toDouble() ?? billAmount;
        final wavedOff = billAmount - settledAmount; 

        String typeFormatted = 'Dine In';
        if (order['order_type'] == 'pickup') typeFormatted = 'Pick Up';
        if (order['order_type'] == 'delivery') typeFormatted = 'Delivery';

        processedOrders.add({
          'orderNo': '$yearStr/$seq',
          'date': "${createdAt.day.toString().padLeft(2, '0')}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.year.toString().substring(2)}",
          'type': typeFormatted,
          'myAmount': myAmount,
          'discount': discount,
          'wavedOff': wavedOff,
          'total': settledAmount,
        });

        tMyAmount += myAmount;
        tDiscount += discount;
        tWavedOff += wavedOff;
        tTotal += settledAmount;
      }

      setState(() {
        _orders = processedOrders;
        _sumMyAmount = tMyAmount;
        _sumDiscount = tDiscount;
        _sumWavedOff = tWavedOff;
        _sumTotal = tTotal;
      });

    } catch (e) {
      debugPrint('Error fetching sales report: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _exportToExcel() {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Sales Report'];

    sheetObject.appendRow([
      TextCellValue('Order No.'), 
      TextCellValue('Date'), 
      TextCellValue('Order Type'), 
      TextCellValue('My Amount (Rs)'), 
      TextCellValue('Discount (Rs)'),
      TextCellValue('Waved Off (Rs)'),
      TextCellValue('Total (Rs)')
    ]);
    
    for (var order in _orders) {
      sheetObject.appendRow([
        TextCellValue(order['orderNo'].toString()), 
        TextCellValue(order['date'].toString()), 
        TextCellValue(order['type'].toString()), 
        DoubleCellValue(order['myAmount']), 
        DoubleCellValue(order['discount']),
        DoubleCellValue(order['wavedOff']),
        DoubleCellValue(order['total'])
      ]);
    }
    
    // Grand Total row
    sheetObject.appendRow([
      TextCellValue('Grand Total'), 
      TextCellValue(''),            
      TextCellValue(''),            
      DoubleCellValue(_sumMyAmount), 
      DoubleCellValue(_sumDiscount),
      DoubleCellValue(_sumWavedOff),
      DoubleCellValue(_sumTotal)
    ]);

    excel.save(fileName: "sales_report_${_formatDate(_startDate)}.xlsx");
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
    bool isSameDay = _startDate.year == _endDate.year && _startDate.month == _endDate.month && _startDate.day == _endDate.day;
    String dateRangeText = isSameDay ? 'Sales Report : From ${_formatDate(_startDate)}' : 'Sales Report : From ${_formatDate(_startDate)} To ${_formatDate(_endDate)}';

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Top buttons bar
            Row(
              children: [
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: _selectDateRange,
                  icon: const Icon(Icons.access_time, size: 16),
                  label: const Text('Time Wise'),
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
                      child: Text(dateRangeText, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
                    ),
                    
                    // Table Headers
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      color: Colors.grey[200],
                      child: const Row(
                        children: [
                          Expanded(flex: 2, child: Text('Order No.', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54))),
                          Expanded(flex: 2, child: Text('Date', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54))),
                          Expanded(flex: 2, child: Text('Order Type', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54))),
                          Expanded(flex: 2, child: Text('My Amount (₹)', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54))),
                          Expanded(flex: 2, child: Text('Discount (₹)', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54))),
                          Expanded(flex: 2, child: Text('Waved Off (₹)', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54))),
                          Expanded(flex: 2, child: Text('Total (₹)', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54))),
                        ],
                      ),
                    ),
                    
                    // Total Row (Top)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      color: Colors.grey[300],
                      child: Row(
                        children: [
                          const Expanded(flex: 2, child: Text('Total', style: TextStyle(fontWeight: FontWeight.bold))),
                          const Expanded(flex: 2, child: Text('-')),
                          const Expanded(flex: 2, child: Text('-')),
                          Expanded(flex: 2, child: Text(_sumMyAmount.toStringAsFixed(2), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold))),
                          Expanded(flex: 2, child: Text(_sumDiscount.toStringAsFixed(2), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold))),
                          Expanded(flex: 2, child: Text(_sumWavedOff.toStringAsFixed(2), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold))),
                          Expanded(flex: 2, child: Text(_sumTotal.toStringAsFixed(2), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold))),
                        ],
                      ),
                    ),

                    // List Area
                    Expanded(
                      child: _isLoading 
                        ? const Center(child: CircularProgressIndicator())
                        : _orders.isEmpty
                          ? const Center(child: Text('No sales found for selected dates.'))
                          : ListView.separated(
                              itemCount: _orders.length,
                              separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade200),
                                                            itemBuilder: (context, index) {
                                final order = _orders[index];
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  child: Row(
                                    children: [
                                      Expanded(flex: 2, child: Text(order['orderNo'].toString())),
                                      Expanded(flex: 2, child: Text(order['date'].toString())),
                                      Expanded(flex: 2, child: Text(order['type'].toString())),
                                      Expanded(flex: 2, child: Text(order['myAmount'].toStringAsFixed(2), textAlign: TextAlign.right)),
                                      Expanded(flex: 2, child: Text(order['discount'].toStringAsFixed(2), textAlign: TextAlign.right)),
                                      // CHANGED: Added .abs() to remove the minus sign while keeping the color logic!
                                      Expanded(flex: 2, child: Text((order['wavedOff'] as num).abs().toStringAsFixed(2), textAlign: TextAlign.right, style: TextStyle(color: order['wavedOff'] > 0 ? Colors.red : (order['wavedOff'] < 0 ? Colors.green : Colors.black)))),
                                      Expanded(flex: 2, child: Text(order['total'].toStringAsFixed(2), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w500))),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                    
                    // Total Row (Bottom)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      color: Colors.grey[300],
                      child: Row(
                        children: [
                          const Expanded(flex: 2, child: Text('Total', style: TextStyle(fontWeight: FontWeight.bold))),
                          const Expanded(flex: 2, child: Text('')),
                          const Expanded(flex: 2, child: Text('')),
                          Expanded(flex: 2, child: Text(_sumMyAmount.toStringAsFixed(2), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold))),
                          Expanded(flex: 2, child: Text(_sumDiscount.toStringAsFixed(2), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold))),
                          Expanded(flex: 2, child: Text(_sumWavedOff.toStringAsFixed(2), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold))),
                          Expanded(flex: 2, child: Text(_sumTotal.toStringAsFixed(2), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold))),
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