import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:excel/excel.dart' hide Border;
import '../../../services/printer_service.dart';

class OrderSummaryScreen extends StatefulWidget {
  const OrderSummaryScreen({super.key});

  @override
  State<OrderSummaryScreen> createState() => _OrderSummaryScreenState();
}

class _OrderSummaryScreenState extends State<OrderSummaryScreen> {
  final _supabase = Supabase.instance.client;
  final _printerService = PrinterService();
  
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  bool _isLoading = true;
  
  List<Map<String, dynamic>> _orders = [];

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
          .select('*, tables(table_number)')
          .gte('created_at', startOfDay.toIso8601String())
          .lte('created_at', endOfDay.toIso8601String())
          .order('created_at', ascending: false);

      List<Map<String, dynamic>> processedOrders = [];

      for (var order in res) {
        final createdAt = DateTime.parse(order['created_at']);
        final yearStr = createdAt.year.toString().substring(2);
        final seq = order['yearly_seq'] ?? order['id']; 
        
        final discount = (order['discount'] as num?)?.toDouble() ?? 0.0;
        final billAmount = (order['total_amount'] as num?)?.toDouble() ?? 0.0; 
        final myAmount = billAmount + discount; 
        final settledAmount = (order['settled_amount'] as num?)?.toDouble() ?? billAmount;
        
        String tableName = order['tables'] != null ? order['tables']['table_number'].toString() : '';
        String typeFormatted = order['order_type'] == 'pickup' 
            ? 'Pick Up\n(Pick Up)' 
            : 'Dine In ($tableName)\n($tableName)';

        processedOrders.add({
          'id': order['id'],
          'tableId': order['table_id'] ?? 0, 
          'orderNo': '$yearStr/$seq',
          'type': typeFormatted,
          'customerName': order['customer_name'] ?? '-',
          'myAmount': myAmount,
          'discount': discount,
          'grandTotal': settledAmount,
          'created': "${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')} ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}:${createdAt.second.toString().padLeft(2, '0')}",
          'status': order['status'], 
        });
      }

      setState(() {
        _orders = processedOrders;
      });

    } catch (e) {
      debugPrint('Error fetching order summary: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // CRITICAL FIX: Change from int to dynamic to support UUID strings
  Future<void> _cancelOrder(dynamic orderId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order?'),
        content: const Text('This will mark the order as cancelled and set the Grand Total to 0. Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('NO')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true), 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('CANCEL ORDER', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _supabase.from('orders').update({
          'status': 'cancelled',
          'settled_amount': 0
        }).eq('id', orderId);
        
        _fetchReportData(); 
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error cancelling: $e')));
      }
    }
  }

  // CRITICAL FIX: Change from int to dynamic to support UUID strings
  Future<void> _editGrandTotal(dynamic orderId, double currentTotal) async {
    final TextEditingController amountController = TextEditingController(text: currentTotal.toStringAsFixed(0));
    
    final newAmount = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Settlement Amount'),
        content: TextField(
          controller: amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'New Grand Total (₹)',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(amountController.text);
              if (val != null) Navigator.pop(context, val);
            }, 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('SAVE', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (newAmount != null) {
      try {
        await _supabase.from('orders').update({
          'settled_amount': newAmount,
          'status': 'completed' 
        }).eq('id', orderId);
        
        _fetchReportData();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating amount: $e')));
      }
    }
  }

  void _exportToExcel() {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Order Summary'];

    sheetObject.appendRow([
      TextCellValue('Order No.'), 
      TextCellValue('Order Type'), 
      TextCellValue('Customer Name'), 
      TextCellValue('My Amount (Rs)'), 
      TextCellValue('Discount (Rs)'),
      TextCellValue('Grand Total (Rs)'),
      TextCellValue('Created Date'),
      TextCellValue('Status'),
    ]);
    
    for (var order in _orders) {
      sheetObject.appendRow([
        TextCellValue(order['orderNo'].toString()), 
        TextCellValue(order['type'].toString().replaceAll('\n', ' ')), 
        TextCellValue(order['customerName'].toString()), 
        DoubleCellValue(order['myAmount']), 
        DoubleCellValue(order['discount']),
        DoubleCellValue(order['grandTotal']),
        TextCellValue(order['created'].toString()),
        TextCellValue(order['status'].toString().toUpperCase()),
      ]);
    }

    excel.save(fileName: "order_summary_${_formatDate(_startDate)}.xlsx");
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
    String dateRangeText = isSameDay ? 'Order Summary : From ${_formatDate(_startDate)}' : 'Order Summary : From ${_formatDate(_startDate)} To ${_formatDate(_endDate)}';

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
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
            
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300), 
                ),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFAF5F5),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                      ),
                      child: Text(dateRangeText, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
                    ),
                    
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      color: Colors.grey[200],
                      child: const Row(
                        children: [
                          Expanded(flex: 2, child: Text('Order No.', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54))),
                          Expanded(flex: 3, child: Text('Order Type', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54))),
                          Expanded(flex: 3, child: Text('Customer Name', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54))),
                          Expanded(flex: 2, child: Text('My Amount (₹)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54))),
                          Expanded(flex: 2, child: Text('Discount (₹)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54))),
                          Expanded(flex: 3, child: Text('Grand Total (₹)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54))),
                          Expanded(flex: 3, child: Text('Created', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54))),
                          Expanded(flex: 3, child: Text('', textAlign: TextAlign.center)), 
                        ],
                      ),
                    ),

                    Expanded(
                      child: _isLoading 
                        ? const Center(child: CircularProgressIndicator())
                        : _orders.isEmpty
                          ? const Center(child: Text('No orders found for selected dates.'))
                          : ListView.separated(
                              itemCount: _orders.length,
                              separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.white),
                              itemBuilder: (context, index) {
                                final order = _orders[index];
                                final isCancelled = order['status'] == 'cancelled';
                                final rowColor = isCancelled ? Colors.red.shade300 : const Color(0xFF74E091); 
                                
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  color: rowColor,
                                  child: Row(
                                    children: [
                                      Expanded(flex: 2, child: _cellText(order['orderNo'].toString(), isCancelled)),
                                      Expanded(flex: 3, child: _cellText(order['type'].toString(), isCancelled)),
                                      Expanded(flex: 3, child: _cellText(order['customerName'].toString(), isCancelled)),
                                      Expanded(flex: 2, child: _cellText(order['myAmount'].toStringAsFixed(2), isCancelled)),
                                      Expanded(flex: 2, child: _cellText(order['discount'].toStringAsFixed(2), isCancelled)),
                                      
                                      // 6. EDITABLE Grand Total Pill
                                      Expanded(
                                        flex: 3, 
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          // CRITICAL FIX: Use opaque GestureDetector to ensure tap goes through colored row
                                          child: GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onTap: isCancelled ? null : () => _editGrandTotal(order['id'], order['grandTotal']),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(16),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    order['grandTotal'].toStringAsFixed(2), 
                                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)
                                                  ),
                                                  if (!isCancelled) ...[
                                                    const SizedBox(width: 4),
                                                    const Icon(Icons.edit_square, size: 14, color: Colors.blueAccent),
                                                  ]
                                                ],
                                              ),
                                            ),
                                          ),
                                        )
                                      ),
                                      
                                      Expanded(flex: 3, child: _cellText(order['created'].toString(), isCancelled)),
                                      
                                      // 8. Action Buttons
                                      Expanded(
                                        flex: 3, 
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            // View Bill (Eye)
                                            _actionBtn(Icons.visibility, () {
                                              context.push('/admin/running/order/${order['tableId']}?append=false&orderId=${order['id']}');
                                            }),
                                            // Print Bill (Printer)
                                            _actionBtn(Icons.print, () async {
                                              try {
                                                await _printerService.reprintHistoricalBill(order['id']);
                                                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sent to Printer!')));
                                              } catch (e) {
                                                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                                              }
                                            }),
                                            // Cancel Order (Cross)
                                            _actionBtn(Icons.close, isCancelled ? null : () => _cancelOrder(order['id'])),
                                          ],
                                        )
                                      ),
                                    ],
                                  ),
                                );
                              },
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

  Widget _cellText(String text, bool isCancelled) {
    return Text(
      text,
      style: TextStyle(
        color: isCancelled ? Colors.white : Colors.black87,
        fontWeight: isCancelled ? FontWeight.bold : FontWeight.normal,
        fontSize: 13
      ),
    );
  }

  // CRITICAL FIX: Use opaque GestureDetector to ensure tap goes through colored row
  Widget _actionBtn(IconData icon, VoidCallback? onTap) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.grey.shade300)
          ),
          child: Icon(icon, size: 16, color: onTap == null ? Colors.grey : Colors.black87),
        ),
      ),
    );
  }
}