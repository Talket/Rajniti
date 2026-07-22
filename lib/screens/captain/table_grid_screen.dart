import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';
import '../../widgets/add_temp_table_dialog.dart';

class TableGridScreen extends StatefulWidget {
  const TableGridScreen({super.key});

  @override
  State<TableGridScreen> createState() => _TableGridScreenState();
}

class _TableGridScreenState extends State<TableGridScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _allAreas = [];
  List<Map<String, dynamic>> _allTables = [];
  List<Map<String, dynamic>> _runningOrders = []; // ADDED: To store active orders
  
  int? _selectedAreaId;
  bool _isLoading = true;
  
  StreamSubscription<List<Map<String, dynamic>>>? _areasSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _tablesSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _ordersSubscription; // ADDED

  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _areaKeys = {}; 
  Timer? _timeUpdater; // ADDED: To tick the clock every minute

  @override
  void initState() {
    super.initState();
    _listenToAreas();
    _listenToTables();
    _listenToOrders(); // ADDED
    
    // ADDED: Updates the UI every 1 minute so the running time ticks automatically
    _timeUpdater = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _areasSubscription?.cancel();
    _tablesSubscription?.cancel();
    _ordersSubscription?.cancel();
    _scrollController.dispose();
    _timeUpdater?.cancel();
    super.dispose();
  }

  void _listenToAreas() {
    _areasSubscription = _supabase.from('table_areas').stream(primaryKey: ['id']).order('name').listen((data) {
      if (mounted) {
        setState(() {
          _allAreas = List<Map<String, dynamic>>.from(data);
          if (_allAreas.isNotEmpty) {
            if (_selectedAreaId == null || !_allAreas.any((a) => a['id'] == _selectedAreaId)) {
              _selectedAreaId = _allAreas.first['id'];
            }
          } else {
            _selectedAreaId = null;
          }
          _isLoading = false;
        });
      }
    }, onError: (e) {
      debugPrint('Error streaming areas: $e');
      if (mounted) setState(() => _isLoading = false);
    });
  }

  void _listenToTables() {
    _tablesSubscription = _supabase.from('tables').stream(primaryKey: ['id']).order('table_number').listen((data) {
      if (mounted) {
        setState(() {
          _allTables = List<Map<String, dynamic>>.from(data);
        });
      }
    });
  }

  // ADDED: Stream to track the exact bills and times for running tables
  void _listenToOrders() {
    _ordersSubscription = _supabase.from('orders').stream(primaryKey: ['id']).listen((data) {
      if (mounted) {
         setState(() {
           final validStatuses = ['active', 'printed', 'bill_requested'];
           _runningOrders = List<Map<String, dynamic>>.from(
             data.where((o) => validStatuses.contains(o['status']))
           );
         });
      }
    });
  }

  void _refreshData() {
    setState(() => _isLoading = true);
    _areasSubscription?.cancel();
    _tablesSubscription?.cancel();
    _ordersSubscription?.cancel();
    _listenToAreas();
    _listenToTables();
    _listenToOrders();
  }

  int _extractNumber(String tableStr) {
    final match = RegExp(r'\d+').firstMatch(tableStr);
    return match != null ? int.parse(match.group(0)!) : 0;
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'vacant': return Colors.green;
      case 'occupied': return Colors.redAccent;
      case 'bill_requested': return Colors.orange;
      default: return Colors.grey;
    }
  }

  // ADDED: Calculates minutes since KOT was placed
  String _calculateTime(String? createdAt) {
    if (createdAt == null) return '0 Min';
    final created = DateTime.parse(createdAt);
    final diff = DateTime.now().difference(created);
    return '${diff.inMinutes} Min';
  }

  void _scrollToArea(int areaId) {
    setState(() => _selectedAreaId = areaId);
    
    final key = _areaKeys[areaId];
    if (key != null && key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        alignment: 0.0, 
      );
    }
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
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Table $tableName created successfully!'), backgroundColor: Colors.green),
          );
          _refreshData(); 
        }

      } catch (e) {
        if (mounted) {
          String errorMessage = 'Error: $e';
          if (errorMessage.contains('duplicate key') || errorMessage.contains('tables_table_number_key')) {
             errorMessage = 'Table "$tableName" already exists! Please pick a different name (e.g. $tableName 2).';
          }
          
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(errorMessage, style: const TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ));
        }
      }
    }
  }

  Future<void> _showOrderDetails(Map<String, dynamic> order, String tableNumber) async {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Table $tableNumber - Bill Items', style: const TextStyle(fontWeight: FontWeight.bold)),
          content: FutureBuilder<List<Map<String, dynamic>>>(
            future: _supabase
                .from('order_items')
                .select('quantity, historical_price, menu_items(name)')
                .eq('order_id', order['id']),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 100,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}');
              }
              
              final items = snapshot.data ?? [];
              if (items.isEmpty) {
                return const Text('No items found in this order.');
              }

              return SizedBox(
                width: double.maxFinite,
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 16),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final name = item['menu_items'] != null ? item['menu_items']['name'] : 'Unknown Item';
                    final qty = (item['quantity'] as num).toInt();
                    final price = (item['historical_price'] as num).toDouble();
                    final total = qty * price;
                    
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text('$name  x$qty', style: const TextStyle(fontSize: 16))),
                        Text('₹${total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    );
                  },
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CLOSE', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    bool hasTempTables = _allTables.any((t) => t['is_temporary'] == true);
    
    List<Map<String, dynamic>> displayAreas = _allAreas.where((area) {
       if (area['name'] == 'Temporary' && !hasTempTables) return false;
       return true;
    }).toList();

    displayAreas.sort((a, b) {
      if (a['name'] == 'Temporary') return 1;
      if (b['name'] == 'Temporary') return -1;
      return a['name'].toString().compareTo(b['name'].toString());
    });

    for (var area in displayAreas) {
      if (!_areaKeys.containsKey(area['id'])) {
        _areaKeys[area['id']] = GlobalKey();
      }
    }

    if (displayAreas.isNotEmpty && (_selectedAreaId == null || !displayAreas.any((a) => a['id'] == _selectedAreaId))) {
      _selectedAreaId = displayAreas.first['id'];
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Rajniti Dosa', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1b1d3a),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _refreshData,
            tooltip: 'Refresh Data',
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () async {
              await AuthService().logout();
              if (context.mounted) context.go('/login');
            },
          )
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTempTableDialog,
        backgroundColor: Colors.blueGrey,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('', style: TextStyle(color: Colors.white)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  height: 60,
                  color: Colors.white,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: displayAreas.length,
                    itemBuilder: (context, index) {
                      final area = displayAreas[index];
                      final isSelected = area['id'] == _selectedAreaId;
                      return GestureDetector(
                        onTap: () => _scrollToArea(area['id']), 
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: isSelected ? Colors.blueAccent : Colors.transparent, width: 3),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              area['name'],
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? Colors.blueAccent : Colors.black54,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                
                Expanded(
                  child: displayAreas.isEmpty
                      ? const Center(child: Text('No areas configured.'))
                      : SingleChildScrollView(
                          controller: _scrollController,
                          scrollDirection: Axis.horizontal, 
                          padding: const EdgeInsets.all(24),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: displayAreas.map((area) {
                              final areaId = area['id'];
                              final tablesInArea = _allTables.where((t) => t['area_id'] == areaId).toList();
                              
                              tablesInArea.sort((a, b) => _extractNumber(a['table_number'].toString())
                                  .compareTo(_extractNumber(b['table_number'].toString())));

                              return Padding(
                                key: _areaKeys[areaId], 
                                padding: const EdgeInsets.only(right: 48), 
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      area['name'],
                                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                                    ),
                                    const SizedBox(height: 16),
                                    Expanded(
                                      child: tablesInArea.isEmpty
                                          ? const Text('No tables in this area', style: TextStyle(color: Colors.grey))
                                          : Wrap(
                                              direction: Axis.vertical, 
                                              spacing: 16, 
                                              runSpacing: 16, 
                                              children: tablesInArea.map((table) {
                                                final statusColor = _getStatusColor(table['status']);
                                                
                                                // Fetch active order for this table if it exists
                                                final tableOrders = _runningOrders.where((o) => o['table_id'] == table['id']).toList();
                                                final activeOrder = tableOrders.isNotEmpty ? tableOrders.first : null;

                                                return SizedBox(
                                                  width: 150, 
                                                  height: 150,
                                                  child: InkWell(
                                                    onTap: () {
                                                      if (table['status'] == 'vacant' || table['status'] == 'occupied') {
                                                        context.go('/captain/order/${table['id']}');
                                                      } else if (table['status'] == 'bill_requested') {
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          const SnackBar(content: Text('Waiting for admin to print bill...')),
                                                        );
                                                      }
                                                    },
                                                    onLongPress: () {
                                                      if (activeOrder != null) {
                                                        _showOrderDetails(activeOrder, table['table_number'].toString());
                                                      } else {
                                                        // ADDED: Helpful feedback if the table is empty!
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          const SnackBar(
                                                            content: Text('No items ordered yet! Tap to place an order first.', style: TextStyle(fontWeight: FontWeight.bold)),
                                                            backgroundColor: Colors.orange,
                                                          ),
                                                        );
                                                      }
                                                    },
                                                    borderRadius: BorderRadius.circular(16),
                                                    child: Card(
                                                      elevation: 4,
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(16), 
                                                        side: BorderSide(color: statusColor.withOpacity(0.5), width: 3)
                                                    ),
                                                    child: Column(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        // CHANGED: Show Time if running, else Table Icon
                                                        if (activeOrder != null)
                                                          Text(
                                                            _calculateTime(activeOrder['created_at']),
                                                            style: TextStyle(fontSize: 20, color: statusColor, fontWeight: FontWeight.bold),
                                                          )
                                                        else
                                                          Icon(Icons.table_restaurant, size: 48, color: statusColor),
                                                        
                                                        const SizedBox(height: 12),
                                                        Text(
                                                          table['table_number'],
                                                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                                                        ),
                                                        const SizedBox(height: 8),
                                                        
                                                        // CHANGED: Show Amount if running, else Status Text
                                                        if (activeOrder != null)
                                                          Text(
                                                            '₹ ${(activeOrder['total_amount'] as num).toStringAsFixed(2)}',
                                                            style: TextStyle(fontSize: 16, color: statusColor, fontWeight: FontWeight.bold),
                                                          )
                                                        else
                                                          Text(
                                                            table['status'].toString().toUpperCase().replaceAll('_', ' '),
                                                            style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.bold),
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}