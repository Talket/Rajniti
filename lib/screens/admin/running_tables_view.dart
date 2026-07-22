import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'dart:ui'; 
import '../../services/printer_service.dart';
import '../../widgets/add_temp_table_dialog.dart';

class RunningTablesView extends StatefulWidget {
  const RunningTablesView({super.key});

  @override
  State<RunningTablesView> createState() => _RunningTablesViewState();
}

class _RunningTablesViewState extends State<RunningTablesView> {
  final _supabase = Supabase.instance.client;
  final _printerService = PrinterService(); 

  List<Map<String, dynamic>> _allTables = [];
  List<Map<String, dynamic>> _runningOrders = [];
  bool _isLoadingTables = true;
  bool _isLoadingOrders = true;
  final Set<String> _settledOrderIds = {}; 

  StreamSubscription? _tablesSubscription;
  StreamSubscription? _ordersSubscription; 
  StreamSubscription? _printSubscription; 

  final Set<String> _handledPrintOrders = {}; 
  bool _isFirstPrintLoad = true; 

  bool _isMoveMode = false;
  Map<String, dynamic>? _moveSourceOrder;
  Map<String, dynamic>? _moveSourceTable;
  Map<String, dynamic>? _moveDestTable;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void dispose() {
    _tablesSubscription?.cancel();
    _ordersSubscription?.cancel();
    _printSubscription?.cancel(); 
    super.dispose();
  }

  void _initializeData() {
    _tablesSubscription = _supabase
        .from('tables')
        .stream(primaryKey: ['id'])
        .listen((data) {
      if (mounted) {
        setState(() {
          _allTables = List<Map<String, dynamic>>.from(data);
          _isLoadingTables = false;
        });
      }
    });
    
    _ordersSubscription = _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .listen((data) {
      if (mounted) {
         setState(() {
           final validStatuses = ['active', 'printed', 'bill_requested'];
           _runningOrders = List<Map<String, dynamic>>.from(
             data.where((o) => validStatuses.contains(o['status']))
           );
           _isLoadingOrders = false;
         });
      }
    });

    _printSubscription = _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('status', 'printed')
        .listen((data) {
      if (!mounted) return;
      
      if (_isFirstPrintLoad) {
        for (var order in data) {
          _handledPrintOrders.add(order['id'].toString());
        }
        _isFirstPrintLoad = false;
      } else {
        for (var order in data) {
          if (!_handledPrintOrders.contains(order['id'].toString())) {
             _handledPrintOrders.add(order['id'].toString());
             final tableId = order['table_id'] ?? 0;
             _printerService.printBillForTable(tableId, orderId: order['id']);
          }
        }
      }
    });
  }

  Future<void> _showAddTempTableDialog() async {
    final tableName = await showDialog<String>(
      context: context,
      builder: (context) => const AddTempTableDialog(),
    );

    if (tableName != null && tableName.isNotEmpty) {
      try {
        final existingAreas = await _supabase.from('table_areas').select('id').eq('name', 'Temporary').limit(1);
        
        int areaId;
        if (existingAreas.isNotEmpty) {
          areaId = existingAreas.first['id'];
        } else {
          final newArea = await _supabase.from('table_areas').insert({'name': 'Temporary'}).select('id').single();
          areaId = newArea['id'];
        }

        await _supabase.from('tables').insert({
          'table_number': tableName,
          'area_id': areaId, 
          'is_temporary': true,
          'status': 'vacant',
        });
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error adding temp table: $e')));
      }
    }
  }

  Future<void> _executeMove(Map<String, dynamic> sourceOrder, Map<String, dynamic> sourceTable, Map<String, dynamic> destTable) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Confirm Move'),
        content: Text('Are you sure you want to move the order from Table ${sourceTable['table_number']} to Table ${destTable['table_number']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), 
            child: const Text('CANCEL', style: TextStyle(color: Colors.grey))
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('YES, MOVE', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final orderId = sourceOrder['id'];
      final oldTableId = sourceTable['id'];
      final newTableId = destTable['id'];

      await _supabase.from('orders').update({
        'table_id': newTableId,
      }).eq('id', orderId);

      await _supabase.from('tables').update({'status': 'occupied'}).eq('id', newTableId);

      final remainingOrders = await _supabase.from('orders')
          .select('id')
          .eq('table_id', oldTableId)
          .inFilter('status', const ['active', 'printed', 'bill_requested'])
          .limit(1);
          
      if (remainingOrders.isEmpty) {
         await _supabase.from('tables').update({'status': 'vacant'}).eq('id', oldTableId);
      }

      if (mounted) {
        setState(() {
          _isMoveMode = false;
          _moveSourceOrder = null;
          _moveSourceTable = null;
          _moveDestTable = null; 
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Table Moved Successfully!'), backgroundColor: Colors.green));
      }

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error moving: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _showSettleDialog(Map<String, dynamic> order, String displayTitle, {bool isTemp = false, bool isPickup = false}) async {
    final TextEditingController amountController = TextEditingController(text: order['total_amount'].toString());
    bool isSubmitting = false;
    String? errorMessage; 

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(isPickup ? 'Settle Pickup: $displayTitle' : 'Settle Table $displayTitle'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: Colors.red[100], borderRadius: BorderRadius.circular(8)),
                  child: Text(errorMessage!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                ),
              const Text('Enter the final amount collected:'),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Final Amount (₹)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.currency_rupee)
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              onPressed: isSubmitting ? null : () async {
                setDialogState(() { isSubmitting = true; errorMessage = null; });
                try {
                  final parsedAmount = num.tryParse(amountController.text);
                  if (parsedAmount == null) throw 'Please enter a valid number.';

                  await _supabase.from('orders').update({
                    'status': 'completed',
                    'settled_amount': parsedAmount
                  }).eq('id', order['id']);
                  
                  if (!isPickup) {
                    final activeCheck = await _supabase.from('orders')
                        .select('id')
                        .eq('table_id', order['table_id'])
                        .eq('status', 'active')
                        .maybeSingle();

                    if (activeCheck == null) {
                      if (isTemp) {
                        await _supabase.from('tables').delete().eq('id', order['table_id']);
                        final remainingTemp = await _supabase.from('tables').select('id').eq('is_temporary', true);
                        if (remainingTemp.isEmpty) {
                          await _supabase.from('table_areas').delete().eq('name', 'Temporary');
                        }
                      } else {
                        await _supabase.from('tables').update({'status': 'vacant'}).eq('id', order['table_id']);
                      }
                    }
                  }
                  
                  if (mounted) {
                    setState(() {
                      _settledOrderIds.add(order['id'].toString());
                      _runningOrders.removeWhere((item) => item['id'] == order['id']);
                    });
                  }
                  if (context.mounted) Navigator.pop(context); 
                } catch (e) {
                  setDialogState(() { isSubmitting = false; errorMessage = e.toString(); });
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              child: isSubmitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('SETTLE BILL'),
            )
          ],
        ),
      ),
    );
  }

  int _extractNumber(String tableStr) {
    final match = RegExp(r'\d+').firstMatch(tableStr);
    return match != null ? int.parse(match.group(0)!) : 0;
  }

  String _calculateTime(String? createdAt) {
    if (createdAt == null) return '0 Min';
    final created = DateTime.parse(createdAt);
    final diff = DateTime.now().difference(created);
    return '${diff.inMinutes} Min';
  }

  Widget _buildSubHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.black12), top: BorderSide(color: Colors.black12))
      ),
      child: Row(
        children: [
          const Text('Table View', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh), 
            onPressed: () => _initializeData(),
            tooltip: 'Refresh',
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _isMoveMode = !_isMoveMode;
                _moveSourceOrder = null;
                _moveSourceTable = null;
                _moveDestTable = null;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _isMoveMode ? Colors.blue : Colors.grey[200], 
              foregroundColor: _isMoveMode ? Colors.white : Colors.black87, 
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: _isMoveMode ? 2 : 0,
            ),
            child: Text(_isMoveMode ? 'Cancel Move' : 'Move Table'),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _showAddTempTableDialog,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700], foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('Add Temp Table'),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => context.push('/admin/running/order/0'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[900], foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('Pick Up'),
          ),
        ],
      ),
    );
  }

  Widget _buildMoveBanner() {
    if (!_isMoveMode) return const SizedBox.shrink();
    
    String bannerText = '';
    if (_moveSourceOrder == null) {
      bannerText = 'MOVE MODE: Step 1 - Select a RUNNING table to move.';
    } else if (_moveDestTable == null) {
      bannerText = 'MOVE MODE: Step 2 - Select a BLANK table to move ${_moveSourceTable!['table_number']} to.';
    } else {
      bannerText = 'MOVE MODE: Step 3 - Click DONE to move ${_moveSourceTable!['table_number']} to ${_moveDestTable!['table_number']}.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.blue.shade50,
      child: Row(
        children: [
          const Icon(Icons.swap_horiz, color: Colors.blue, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              bannerText,
              style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          if (_moveDestTable != null) ...[
            ElevatedButton(
              onPressed: () => _executeMove(_moveSourceOrder!, _moveSourceTable!, _moveDestTable!),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              child: const Text('DONE'),
            ),
            const SizedBox(width: 8),
          ],
          ElevatedButton(
            onPressed: () {
              setState(() {
                _isMoveMode = false;
                _moveSourceOrder = null;
                _moveSourceTable = null;
                _moveDestTable = null;
              });
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.red),
            child: const Text('CANCEL'),
          )
        ],
      ),
    );
  }

  Widget _cardActionButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4), 
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black87, width: 1.0),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 16, color: Colors.black87), 
      ),
    );
  }

  Widget _buildTableCard(BuildContext context, Map<String, dynamic> table, Map<String, dynamic>? order) {
    final hasOrder = order != null;
    final isPrinted = hasOrder && order['status'] == 'printed';
    
    final bgColor = hasOrder 
        ? (isPrinted ? const Color(0xFFB9F6CA) : const Color(0xFFFFF59D)) 
        : const Color(0xFFF3F3F3); 
        
    final timeString = hasOrder ? _calculateTime(order['created_at']) : '';
    
    final isSelectedSource = _isMoveMode && _moveSourceOrder != null && hasOrder && _moveSourceOrder!['id'] == order['id'];
    final isSelectedDest = _isMoveMode && _moveDestTable != null && !hasOrder && _moveDestTable!['id'] == table['id'];

    return SizedBox(
      width: 78, 
      height: 98, 
      child: Stack(
        children: [
          Positioned(
            top: 0, left: 0, right: 0, height: 78, 
            child: GestureDetector(
              onTap: () {
                if (_isMoveMode) {
                  if (_moveSourceOrder == null) {
                    if (hasOrder) {
                      setState(() {
                        _moveSourceOrder = order;
                        _moveSourceTable = table;
                      });
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a Running Table first.')));
                    }
                  } else {
                    if (!hasOrder) {
                      setState(() {
                        _moveDestTable = table; 
                      });
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Destination must be a Blank Table.')));
                    }
                  }
                  return; 
                }

                String url = '/admin/running/order/${table['id']}?append=true';
                if (hasOrder) url += '&orderId=${order['id']}';
                context.push(url);
              },
              child: CustomPaint(
                painter: DashedRectPainter(
                  color: isSelectedSource ? Colors.blue : (isSelectedDest ? Colors.green : Colors.black38)
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(8),
                    border: isSelectedSource 
                        ? Border.all(color: Colors.blue, width: 3) 
                        : isSelectedDest 
                            ? Border.all(color: Colors.green, width: 3) 
                            : null,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (hasOrder) Text(timeString, style: const TextStyle(fontSize: 11, color: Colors.black87)),
                        if (hasOrder) const SizedBox(height: 2),
                        Text(table['table_number'].toString(), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
                        if (hasOrder) const SizedBox(height: 2),
                        if (hasOrder) Text('₹${(order['total_amount'] as num).toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          if (hasOrder && !_isMoveMode) 
            Positioned(
              bottom: 4, 
              left: 4, 
              child: Row(
                children: [
                  if (!isPrinted) ...[
                    _cardActionButton(Icons.print_outlined, () async {
                      await _supabase.from('orders').update({'status': 'printed'}).eq('id', order['id']);
                      await _supabase.from('tables').update({'status': 'vacant'}).eq('id', table['id']);
                      await PrinterService().printBillForTable(table['id'], orderId: order['id']);
                    }),
                    const SizedBox(width: 4),
                    _cardActionButton(Icons.visibility_outlined, () {
                      context.push('/admin/running/order/${table['id']}?append=false&orderId=${order['id']}');
                    }),
                  ],
                  if (isPrinted) ...[
                    _cardActionButton(Icons.check_circle_outline, () => _showSettleDialog(order, table['table_number'].toString(), isTemp: table['is_temporary'] == true)),
                    const SizedBox(width: 4),
                    _cardActionButton(Icons.visibility_outlined, () {
                      context.push('/admin/running/order/${table['id']}?append=false&orderId=${order['id']}');
                    }),
                  ]
                ],
              ),
            )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, List<Map<String, dynamic>>> sectionMap = {};
    for (var table in _allTables) {
      String sectionName = 'M'; 
      if (table['is_temporary'] == true) {
        sectionName = 'Temporary';
      } else {
        if (table.containsKey('floor_area') && table['floor_area'] != null && table['floor_area'].toString().trim().isNotEmpty) {
          sectionName = table['floor_area'].toString().trim();
        } else if (table.containsKey('section') && table['section'] != null && table['section'].toString().trim().isNotEmpty) {
          sectionName = table['section'].toString().trim();
        } else {
          String tNum = table['table_number'].toString().trim();
          if (tNum.isNotEmpty && RegExp(r'^[A-Za-z]').hasMatch(tNum)) {
            sectionName = tNum[0].toUpperCase(); 
          }
        }
      }
      sectionMap.putIfAbsent(sectionName, () => []).add(table);
    }

    final sortedSections = sectionMap.keys.toList()..sort();
    final pickupOrders = _runningOrders.where((o) => o['table_id'] == null || o['table_id'] == 0 || o['order_type'] == 'pickup').toList();

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildSubHeader(),
          _buildMoveBanner(), 
          Expanded(
            child: _isLoadingTables || _isLoadingOrders
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Container(
                  width: double.infinity, // Forces Left Alignment
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (pickupOrders.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                child: Text('Pickup Orders', style: TextStyle(fontSize: 16, color: Colors.orange, fontWeight: FontWeight.bold)),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Wrap(
                                  spacing: 10,
                                  runSpacing: 14, // SLIGHTLY INCREASED VERTICAL GAP
                                  children: pickupOrders.map((order) {
                                    final isPrinted = order['status'] == 'printed';
                                    final bgColor = isPrinted ? const Color(0xFFB9F6CA) : Colors.orange[200]!;
                                    final timeString = _calculateTime(order['created_at']);
                                    final customerName = order['customer_name']?.toString().isNotEmpty == true ? order['customer_name'].toString() : 'Guest';

                                    return SizedBox(
                                      width: 78, 
                                      height: 98, 
                                      child: Stack(
                                        children: [
                                          Positioned(
                                            top: 0, left: 0, right: 0, height: 78,
                                            child: GestureDetector(
                                              onTap: () {
                                                if (_isMoveMode) return; 
                                                _showSettleDialog(order, customerName, isPickup: true);
                                              },
                                              child: CustomPaint(
                                                painter: DashedRectPainter(color: Colors.black38),
                                                child: Container(
                                                  decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
                                                  child: Center(
                                                    child: Column(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        Text(timeString, style: const TextStyle(fontSize: 11, color: Colors.black87)),
                                                        const SizedBox(height: 1),
                                                        Text(customerName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black), maxLines: 1, overflow: TextOverflow.ellipsis),
                                                        const SizedBox(height: 1),
                                                        Text('₹${(order['total_amount'] as num).toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black)),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          if (!_isMoveMode)
                                            Positioned(
                                              bottom: 4, left: 4,
                                              child: Row(
                                                children: [
                                                  if (!isPrinted) ...[
                                                    _cardActionButton(Icons.print_outlined, () async {
                                                      await _supabase.from('orders').update({'status': 'printed'}).eq('id', order['id']);
                                                      await PrinterService().printBillForTable(0, orderId: order['id']); 
                                                    }),
                                                    const SizedBox(width: 4),
                                                  ],
                                                  _cardActionButton(Icons.check_circle_outline, () => _showSettleDialog(order, customerName, isPickup: true)),
                                                ],
                                              ),
                                            )
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              )
                            ],
                          ),
                        ),
                        
                      ...sortedSections.map((sectionName) {
                        final tablesInSection = sectionMap[sectionName]!;
                        tablesInSection.sort((a, b) => _extractNumber(a['table_number'].toString()).compareTo(_extractNumber(b['table_number'].toString())));

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16.0), // SLIGHTLY INCREASED GAP BETWEEN FLOORS
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0), 
                                child: Text(sectionName, style: const TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.bold)),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Wrap(
                                  spacing: 10, // Horizontal gap
                                  runSpacing: 14, // SLIGHTLY INCREASED VERTICAL GAP between rows in the same floor
                                  children: tablesInSection.expand((table) {
                                    final tableOrders = _runningOrders.where((item) => item['table_id'] == table['id']).toList();
                                    if (tableOrders.isEmpty) {
                                        return [_buildTableCard(context, table, null)];
                                    } else {
                                        return tableOrders.map((order) => _buildTableCard(context, table, order)).toList();
                                    }
                                  }).toList(),
                                ),
                              )
                            ],
                          ),
                        );
                      }), 
                    ],
                  ),
                ), 
              ), 
          ), 
        ],
      ),
    ); 
  }
}

class DashedRectPainter extends CustomPainter {
  final Color color;
  DashedRectPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height), 
      const Radius.circular(8)
    );
    
    Path path = Path()..addRRect(rrect);
    Path dashedPath = Path();
    
    const dashWidth = 4.0;
    const dashSpace = 4.0;
    
    for (PathMetric measurePath in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < measurePath.length) {
        dashedPath.addPath(
          measurePath.extractPath(distance, distance + dashWidth),
          Offset.zero,
        );
        distance += dashWidth + dashSpace;
      }
    }
    
    canvas.drawPath(dashedPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}