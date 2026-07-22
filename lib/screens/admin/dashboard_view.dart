import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  final _supabase = Supabase.instance.client;
  
  bool _isLoading = true;
  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now();

  // KPI Data
  int _runningTables = 0;
  int _dineInCount = 0;
  double _totalRevenue = 0.0;
  
  // HTML Template placeholders for features not yet built
  final int _deliveryCount = 0;
  final int _takeAwayCount = 0;
  final int _totalStaff = 0; // Requires Employee Master

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Fetch Running (Occupied) Tables
      final tablesRes = await _supabase.from('tables').select('id').eq('status', 'occupied');
      
      // 2. Fetch Dine-In Orders for the selected date range
      final startStr = DateTime(_fromDate.year, _fromDate.month, _fromDate.day).toIso8601String();
      final endStr = DateTime(_toDate.year, _toDate.month, _toDate.day, 23, 59, 59).toIso8601String();

      final ordersRes = await _supabase
          .from('orders')
          .select('total_amount')
          .gte('created_at', startStr)
          .lte('created_at', endStr)
          .eq('status', 'completed');

      double revenue = 0;
      for (var order in ordersRes) {
        revenue += (order['total_amount'] as num).toDouble();
      }

      if (mounted) {
        setState(() {
          _runningTables = tablesRes.length;
          _dineInCount = ordersRes.length;
          _totalRevenue = revenue;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching dashboard: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate(BuildContext context, bool isFrom) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _fromDate : _toDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) _fromDate = picked;
        else _toDate = picked;
      });
      _fetchData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ==========================================
                // DATE FILTER BAR (Matched to HTML)
                // ==========================================
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text('Total Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                      _DateSelector(
                        label: DateFormat('yyyy-MM-dd').format(_fromDate),
                        onTap: () => _selectDate(context, true),
                      ),
                      const SizedBox(width: 16),
                      _DateSelector(
                        label: DateFormat('yyyy-MM-dd').format(_toDate),
                        onTap: () => _selectDate(context, false),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: _fetchData,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          padding: const EdgeInsets.all(16),
                        ),
                        child: const Icon(Icons.search, color: Colors.white),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ==========================================
                // KPI CARDS ROW (Matched to HTML)
                // ==========================================
                GridView.count(
                  crossAxisCount: 5,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 2.2,
                  children: [
                    _KpiCard(title: 'Total Running Table', value: _runningTables.toString(), icon: Icons.access_time, color: Colors.grey),
                    _KpiCard(title: 'Total Dine In Count', value: _dineInCount.toString(), icon: Icons.fastfood, color: Colors.blue),
                    _KpiCard(title: 'Total Delivery Count', value: _deliveryCount.toString(), icon: Icons.delivery_dining, color: Colors.green),
                    _KpiCard(title: 'Total Take Away Count', value: _takeAwayCount.toString(), icon: Icons.shopping_bag, color: Colors.orange),
                    _KpiCard(title: 'Total Staff', value: _totalStaff.toString(), icon: Icons.people, color: Colors.cyan),
                  ],
                ),
                const SizedBox(height: 24),

                // ==========================================
                // CHARTS ROW (Matched to HTML)
                // ==========================================
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // CHART 1: Payment Break Down (Single metric as requested)
                    Expanded(
                      child: Container(
                        height: 400,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
                        child: Column(
                          children: [
                            const Text('Payment Break Down', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 32),
                            Expanded(
                              child: _totalRevenue == 0 
                                ? const Center(child: Text('No data for selected dates.'))
                                : PieChart(
                                    PieChartData(
                                      sectionsSpace: 0,
                                      centerSpaceRadius: 70,
                                      sections: [
                                        PieChartSectionData(
                                          color: Colors.blue,
                                          value: _totalRevenue,
                                          title: '₹${_totalRevenue.toStringAsFixed(0)}',
                                          radius: 50,
                                          titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                                        ),
                                      ],
                                    ),
                                  ),
                            ),
                            const SizedBox(height: 16),
                            const Text('Total Payments Received', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    
                    // CHART 2: Top Selling Products
                    Expanded(
                      child: Container(
                        height: 400,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
                        child: Column(
                          children: [
                            const Text('Top Selling Products (Weekly Comparison)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 32),
                            Expanded(
                              child: LineChart(
                                LineChartData(
                                  gridData: FlGridData(show: true, drawVerticalLine: false),
                                  titlesData: FlTitlesData(
                                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30)),
                                  ),
                                  borderData: FlBorderData(show: true, border: const Border(bottom: BorderSide(color: Colors.grey), left: BorderSide(color: Colors.grey))),
                                  lineBarsData: [
                                    // Last Week (Mock structure matching HTML)
                                    LineChartBarData(
                                      spots: const [FlSpot(0, 3), FlSpot(1, 1), FlSpot(2, 4), FlSpot(3, 2)],
                                      isCurved: true, color: Colors.red, barWidth: 3, isStrokeCapRound: true, dotData: FlDotData(show: false),
                                    ),
                                    // This Week (Mock structure matching HTML)
                                    LineChartBarData(
                                      spots: const [FlSpot(0, 1), FlSpot(1, 3), FlSpot(2, 2), FlSpot(3, 5)],
                                      isCurved: true, color: Colors.green, barWidth: 3, isStrokeCapRound: true, dotData: FlDotData(show: false),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _LegendItem(color: Colors.red, text: 'Last Week'),
                                const SizedBox(width: 16),
                                _LegendItem(color: Colors.green, text: 'This Week'),
                              ],
                            )
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
    );
  }
}

class _DateSelector extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _DateSelector({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(4)),
        child: Text(label),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  const _KpiCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)]),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(border: Border.all(color: color.withOpacity(0.5)), borderRadius: BorderRadius.circular(4)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String text;
  const _LegendItem({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
      ],
    );
  }
}