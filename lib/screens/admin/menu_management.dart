import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MenuManagementView extends StatefulWidget {
  const MenuManagementView({super.key});

  @override
  State<MenuManagementView> createState() => _MenuManagementViewState();
}

class _MenuManagementViewState extends State<MenuManagementView> {
  final _supabase = Supabase.instance.client;
  
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _items = [];
  int? _selectedCategoryId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase.from('menu_categories').select().order('id');
      setState(() {
        _categories = List<Map<String, dynamic>>.from(response);
        
        // ADDED: Inject Favourites into the Menu Master so you can manage them!
        _categories.insert(0, {'id': -1, 'name': '⭐️ Favourites'});
        
        if (_categories.isNotEmpty && _selectedCategoryId == null) {
          _selectedCategoryId = _categories.first['id'];
          _fetchItems(_selectedCategoryId!);
        } else {
          _isLoading = false;
        }
      });
    } catch (e) {
      debugPrint('Error fetching categories: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchItems(int categoryId) async {
    setState(() => _isLoading = true);
    try {
      // ADDED: If Favourites is selected, filter by is_favourite and order by our new sort column!
      final response = categoryId == -1 
          ? await _supabase.from('menu_items').select().eq('is_favourite', true).order('favourite_sort_order', ascending: true).order('name')
          : await _supabase.from('menu_items').select().eq('category_id', categoryId).order('name');
          
      setState(() {
        _items = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching items: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteCategory(int id) async {
    if (id == -1) return; // Prevent deleting the Favourites tab
    
    final confirm = await _showConfirmDialog('Delete Category', 'This will remove the category and all items inside it if cascade is enabled. Are you sure?');
    if (!confirm) return;

    try {
      await _supabase.from('menu_categories').delete().eq('id', id);
      _selectedCategoryId = null;
      _fetchCategories();
    } catch (e) {
      debugPrint('Error deleting category: $e');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete. Ensure this category is empty or check database constraints.')));
    }
  }

  Future<void> _deleteItem(int id) async {
    final confirm = await _showConfirmDialog('Delete Item', 'Are you sure you want to remove this item?');
    if (!confirm) return;

    try {
      await _supabase.from('menu_items').delete().eq('id', id);
      _fetchItems(_selectedCategoryId!);
    } catch (e) {
      debugPrint('Error deleting item: $e');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete item.')));
    }
  }

  Future<bool> _showConfirmDialog(String title, String content) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true), 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _toggleAvailability(int itemId, bool isAvailable) async {
    try {
      await _supabase
          .from('menu_items')
          .update({'is_available': isAvailable})
          .eq('id', itemId);
      
      setState(() {
        final index = _items.indexWhere((item) => item['id'] == itemId);
        if (index != -1) {
          _items[index]['is_available'] = isAvailable;
        }
      });
    } catch (e) {
      debugPrint('Error toggling availability: $e');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update status')));
    }
  }

  Future<void> _toggleFavourite(int itemId, bool isFavourite) async {
    try {
      await _supabase
          .from('menu_items')
          .update({'is_favourite': isFavourite})
          .eq('id', itemId);
      
      setState(() {
        if (_selectedCategoryId == -1 && !isFavourite) {
          // If we are IN the Favourites tab and we un-star it, instantly remove it from the list
          _items.removeWhere((item) => item['id'] == itemId);
        } else {
          final index = _items.indexWhere((item) => item['id'] == itemId);
          if (index != -1) {
            _items[index]['is_favourite'] = isFavourite;
          }
        }
      });
    } catch (e) {
      debugPrint('Error toggling favourite: $e');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update favourite status')));
    }
  }

  void _showAddCategoryDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Category'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Category Name'), autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              Navigator.pop(context);
              await _supabase.from('menu_categories').insert({'name': controller.text.trim()});
              _fetchCategories();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddItemDialog() {
    if (_selectedCategoryId == null || _selectedCategoryId == -1) return; // Prevent adding directly to favourites
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Menu Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Item Name'), autofocus: true),
            TextField(controller: priceController, decoration: const InputDecoration(labelText: 'Price (₹)'), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final price = double.tryParse(priceController.text.trim());
              if (name.isEmpty || price == null) return;
              Navigator.pop(context);
              await _supabase.from('menu_items').insert({
                'category_id': _selectedCategoryId,
                'name': name,
                'price': price,
                'is_available': true,
              });
              _fetchItems(_selectedCategoryId!);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Helper function to build a list tile so we don't repeat code between normal and reorderable lists
    Widget buildItemTile(Map<String, dynamic> item) {
      final isAvailable = item['is_available'] ?? true;
      final isFavourite = item['is_favourite'] == true;
      
      return ListTile(
        key: ValueKey(item['id']), // REQUIRED FOR REORDERABLE DRAG & DROP
        leading: _selectedCategoryId == -1 ? const Icon(Icons.drag_handle, color: Colors.black38) : null,
        title: Text(item['name'], style: TextStyle(fontWeight: FontWeight.w500, color: isAvailable ? Colors.black : Colors.grey)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('₹${item['price']}', style: const TextStyle(fontSize: 16, color: Colors.green)),
            const SizedBox(width: 8),
            // Favourite Star Button
            IconButton(
              icon: Icon(
                isFavourite ? Icons.star : Icons.star_border,
                color: isFavourite ? Colors.orange : Colors.grey,
              ),
              onPressed: () => _toggleFavourite(item['id'], !isFavourite),
              tooltip: isFavourite ? 'Remove from Favourites' : 'Add to Favourites',
            ),
            Switch(value: isAvailable, onChanged: (val) => _toggleAvailability(item['id'], val), activeColor: Colors.green),
            IconButton(icon: const Icon(Icons.delete, size: 18, color: Colors.redAccent), onPressed: () => _deleteItem(item['id'])),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 300,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)]),
            child: Column(
              children: [
                ListTile(
                  title: const Text('Categories', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  trailing: IconButton(icon: const Icon(Icons.add, color: Colors.blue), onPressed: _showAddCategoryDialog),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final cat = _categories[index];
                      final isSelected = cat['id'] == _selectedCategoryId;
                      return ListTile(
                        title: Text(cat['name']),
                        selected: isSelected,
                        selectedTileColor: Colors.blue.withOpacity(0.1),
                        // Hide the delete button for the Favourites category
                        trailing: cat['id'] == -1 ? null : IconButton(icon: const Icon(Icons.delete, size: 18, color: Colors.redAccent), onPressed: () => _deleteCategory(cat['id'])),
                        onTap: () {
                          setState(() => _selectedCategoryId = cat['id']);
                          _fetchItems(cat['id']);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)]),
              child: Column(
                children: [
                  ListTile(
                    title: const Text('Menu Items', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    trailing: (_selectedCategoryId == null || _selectedCategoryId == -1) ? null : ElevatedButton.icon(onPressed: _showAddItemDialog, icon: const Icon(Icons.add), label: const Text('Add Item')),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: _isLoading 
                      ? const Center(child: CircularProgressIndicator()) 
                      : _selectedCategoryId == -1
                        // ADDED: The beautifully draggable list view for custom sorting!
                        ? ReorderableListView.builder(
                            itemCount: _items.length,
                            onReorder: (oldIndex, newIndex) async {
                              if (oldIndex < newIndex) newIndex -= 1;
                              setState(() {
                                final item = _items.removeAt(oldIndex);
                                _items.insert(newIndex, item);
                              });
                              
                              // Save the new sequence to Supabase instantly
                              try {
                                final futures = <Future>[];
                                for (int i = 0; i < _items.length; i++) {
                                  _items[i]['favourite_sort_order'] = i;
                                  futures.add(_supabase.from('menu_items').update({'favourite_sort_order': i}).eq('id', _items[i]['id']));
                                }
                                await Future.wait(futures);
                              } catch (e) {
                                debugPrint('Error reordering: $e');
                              }
                            },
                            itemBuilder: (context, index) => buildItemTile(_items[index]),
                          )
                        : ListView.separated(
                            itemCount: _items.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) => buildItemTile(_items[index]),
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