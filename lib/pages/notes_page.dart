import 'package:flutter/material.dart';
import '../database_service.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final DatabaseService _db = DatabaseService();
  List<Map<String, dynamic>> _notes = [];
  bool _isLoading = true;
  String? _email;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_email == null) {
      _email = ModalRoute.of(context)?.settings.arguments as String?;
      _loadNotes();
    }
  }

  Future<void> _loadNotes() async {
    if (_email == null) return;
    final notes = await _db.getNotes(_email!);
    if (mounted) setState(() {
      _notes = notes;
      _isLoading = false;
    });
  }

  void _addOrEditNote({int? index}) {
    final isEditing = index != null;
    final titleController = TextEditingController(
      text: isEditing ? _notes[index]['title'] : '',
    );
    final contentController = TextEditingController(
      text: isEditing ? _notes[index]['content'] : '',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isEditing ? "Edit Note" : "New Note",
          style: const TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: "Title",
                  hintStyle: const TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentController,
                style: const TextStyle(color: Colors.white70),
                maxLines: 6,
                decoration: InputDecoration(
                  hintText: "Write your planning notes here...",
                  hintStyle: const TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            onPressed: () async {
              final title = titleController.text.trim();
              final content = contentController.text.trim();
              if (title.isEmpty) return;

              Navigator.pop(ctx);
              setState(() => _isLoading = true);

              if (isEditing) {
                await _db.updateNote(_notes[index]['note_id'] as int, title, content);
              } else {
                await _db.addNote(_email!, title, content);
              }

              await _loadNotes(); // refresh from DB
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(isEditing ? "Update" : "Save"),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Delete Note?", style: TextStyle(color: Colors.white)),
        content: const Text("This action cannot be undone.", style: TextStyle(color: Colors.white54)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _db.deleteNote(_notes[index]['note_id'] as int);
              await _loadNotes(); // refresh from DB
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp as int);
    return "${dt.day}/${dt.month}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        title: const Text("📝 My Planning Notes"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
          : _notes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.note_alt_outlined, size: 64, color: Colors.white.withOpacity(0.15)),
                      const SizedBox(height: 16),
                      const Text("No notes yet", style: TextStyle(color: Colors.white38, fontSize: 16)),
                      const SizedBox(height: 8),
                      const Text("Tap + to add your first planning note", style: TextStyle(color: Colors.white24, fontSize: 13)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _notes.length,
                  itemBuilder: (context, index) {
                    final note = _notes[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                      ),
                      child: InkWell(
                        onTap: () => _addOrEditNote(index: index),
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      note['title'] ?? '',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                    onPressed: () => _confirmDelete(index),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                              if ((note['content'] ?? '').toString().isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  note['content'],
                                  style: const TextStyle(color: Colors.white54, fontSize: 13, height: 1.4),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              const SizedBox(height: 10),
                              Text(
                                _formatDate(note['updated_at']),
                                style: const TextStyle(color: Colors.white24, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEditNote(),
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.add),
      ),
    );
  }
}