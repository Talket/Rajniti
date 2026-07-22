import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CommentsMasterScreen extends StatefulWidget {
  const CommentsMasterScreen({super.key});

  @override
  State<CommentsMasterScreen> createState() => _CommentsMasterScreenState();
}

class _CommentsMasterScreenState extends State<CommentsMasterScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _comments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchComments();
  }

  Future<void> _fetchComments() async {
    setState(() => _isLoading = true);
    try {
      final res = await _supabase.from('order_comments_master').select().order('id');
      setState(() {
        _comments = List<Map<String, dynamic>>.from(res);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching comments: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addComment() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Comment'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Comment Text', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              Navigator.pop(context);
              try {
                await _supabase.from('order_comments_master').insert({'comment_text': controller.text.trim()});
                _fetchComments();
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteComment(int id) async {
    try {
      await _supabase.from('order_comments_master').delete().eq('id', id);
      _fetchComments();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Comments Master', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Container(
                width: 600,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                child: Column(
                  children: [
                    ListTile(
                      title: const Text('Standard Comments', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      trailing: ElevatedButton.icon(onPressed: _addComment, icon: const Icon(Icons.add), label: const Text('Add Comment')),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: _comments.isEmpty
                          ? const Center(child: Text('No comments added yet.'))
                          : ListView.separated(
                              itemCount: _comments.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final comment = _comments[index];
                                return ListTile(
                                  title: Text(comment['comment_text']),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _deleteComment(comment['id']),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}