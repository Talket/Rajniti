import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TableManagementView extends StatefulWidget {
  const TableManagementView({super.key});

  @override
  State<TableManagementView> createState() => _TableManagementViewState();
}

class _TableManagementViewState extends State<TableManagementView> {
  final _supabase = Supabase.instance.client;
  
  List<Map<String, dynamic>> _areas = [];
  List<Map<String, dynamic>> _tables = [];
  int? _selectedAreaId;
  String? _selectedAreaName;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAreas();
  }

  Future<void> _fetchAreas() async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase.from('table_areas').select().order('name');
      setState(() {
        _areas = List<Map<String, dynamic>>.from(response);
        if (_areas.isNotEmpty && _selectedAreaId == null) {
          _selectedAreaId = _areas.first['id'];
          _selectedAreaName = _areas.first['name'];
          _fetchTables(_selectedAreaId!);
        } else {
          _isLoading = false;
        }
      });
    } catch (e) {
      debugPrint('Error fetching areas: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchTables(int areaId) async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase
          .from('tables')
          .select()
          .eq('area_id', areaId)
          .order('table_number');
      setState(() {
        _tables = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching tables: $e');
      setState(() => _isLoading = false);
    }
  }

  void _showAddAreaDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Floor Area'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Area Name (e.g., A, R, Balcony)'),
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              Navigator.pop(context);
              try {
                await _supabase.from('table_areas').insert({'name': controller.text.trim()});
                _fetchAreas();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Error: Area name must be unique.')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteArea(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Area?'),
        content: const Text('This will delete the area AND all tables inside it. Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _supabase.from('table_areas').delete().eq('id', id);
      if (_selectedAreaId == id) {
        setState(() {
          _selectedAreaId = null;
          _selectedAreaName = null;
          _tables = [];
        });
      }
      _fetchAreas();
    }
  }

  void _showAddTableDialog() {
    if (_selectedAreaId == null) return;
    
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Table to $_selectedAreaName'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Table Identifier',
            hintText: 'e.g., ${_selectedAreaName}1',
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final number = controller.text.trim().toUpperCase();
              if (number.isEmpty) return;
              Navigator.pop(context);
              
              try {
                await _supabase.from('tables').insert({
                  'area_id': _selectedAreaId,
                  'table_number': number,
                });
                _fetchTables(_selectedAreaId!);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Error: Table number must be unique globally.')),
                  );
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTable(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Table?'),
        content: const Text('This will remove the table from the floor plan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _supabase.from('tables').delete().eq('id', id);
      _fetchTables(_selectedAreaId!);
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'vacant': return Colors.green;
      case 'occupied': return Colors.redAccent;
      case 'bill_requested': return Colors.orange;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Panel: Areas
          Container(
            width: 250,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
            ),
            child: Column(
              children: [
                ListTile(
                  title: const Text('Floor Areas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  trailing: IconButton(
                    icon: const Icon(Icons.add, color: Colors.blue),
                    onPressed: _showAddAreaDialog,
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: _areas.isEmpty && !_isLoading
                      ? const Center(child: Text('No areas added.'))
                      : ListView.builder(
                          itemCount: _areas.length,
                          itemBuilder: (context, index) {
                            final area = _areas[index];
                            final isSelected = area['id'] == _selectedAreaId;
                            return ListTile(
                              title: Text(area['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                              selected: isSelected,
                              selectedTileColor: Colors.blueGrey.withOpacity(0.1),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, size: 18, color: Colors.redAccent),
                                onPressed: () => _deleteArea(area['id']),
                              ),
                              onTap: () {
                                setState(() {
                                  _selectedAreaId = area['id'];
                                  _selectedAreaName = area['name'];
                                });
                                _fetchTables(area['id']);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          
          // Right Panel: Table Grid
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _selectedAreaName != null ? 'Tables in $_selectedAreaName' : 'Tables',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
                      ),
                      if (_selectedAreaId != null)
                        ElevatedButton.icon(
                          onPressed: _showAddTableDialog,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Table'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, foregroundColor: Colors.white),
                        ),
                    ],
                  ),
                  const Divider(height: 32),
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _tables.isEmpty
                            ? Center(child: Text(_selectedAreaId == null ? 'Select an area to view tables' : 'No tables in $_selectedAreaName.'))
                            : GridView.builder(
                                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 180,
                                  mainAxisSpacing: 16,
                                  crossAxisSpacing: 16,
                                  childAspectRatio: 1.1,
                                ),
                                itemCount: _tables.length,
                                itemBuilder: (context, index) {
                                  final table = _tables[index];
                                  final statusColor = _getStatusColor(table['status']);
                                  return Card(
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(color: statusColor.withOpacity(0.5), width: 2),
                                    ),
                                    child: Stack(
                                      children: [
                                        Center(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.table_restaurant, size: 40, color: statusColor),
                                              const SizedBox(height: 8),
                                              Text(table['table_number'], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                        ),
                                        Positioned(
                                          top: 0,
                                          right: 0,
                                          child: IconButton(
                                            icon: const Icon(Icons.close, color: Colors.black26, size: 18),
                                            onPressed: () => _deleteTable(table['id']),
                                          ),
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
    );
  }
}