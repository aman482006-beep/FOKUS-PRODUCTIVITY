import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../shared/theme.dart';
import '../../shared/motion.dart' as motion;

class TimestampNote {
  final String id;
  final String content;
  final DateTime timestamp;

  TimestampNote({
    required this.id,
    required this.content,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
      };

  factory TimestampNote.fromJson(Map<String, dynamic> json) => TimestampNote(
        id: json['id'] as String,
        content: json['content'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}

class TimestampNotesPage extends StatefulWidget {
  final VoidCallback onBack;

  const TimestampNotesPage({super.key, required this.onBack});

  @override
  State<TimestampNotesPage> createState() => _TimestampNotesPageState();
}

class _TimestampNotesPageState extends State<TimestampNotesPage> {
  final List<TimestampNote> _notes = [];
  List<TimestampNote> _filteredNotes = [];
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _noteFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadNotes();
    _noteFocusNode.requestFocus();
  }

  @override
  void dispose() {
    _noteController.dispose();
    _searchController.dispose();
    _noteFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('timestamp_notes');
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw) as List;
        setState(() {
          _notes.clear();
          _notes.addAll(decoded.map((e) => TimestampNote.fromJson(Map<String, dynamic>.from(e))));
          _filterNotes();
        });
      } catch (e) {
        debugPrint('Error loading notes: $e');
      }
    }
  }

  Future<void> _saveNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_notes.map((e) => e.toJson()).toList());
    await prefs.setString('timestamp_notes', encoded);
  }

  void _addNote() {
    final text = _noteController.text.trim();
    if (text.isEmpty) return;

    final newNote = TimestampNote(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: text,
      timestamp: DateTime.now(),
    );

    setState(() {
      _notes.insert(0, newNote);
      _noteController.clear();
      _filterNotes();
    });

    _saveNotes();
    _noteFocusNode.requestFocus();
  }

  void _deleteNote(String id) {
    setState(() {
      _notes.removeWhere((n) => n.id == id);
      _filterNotes();
    });
    _saveNotes();
  }

  void _filterNotes() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredNotes = List.from(_notes);
      } else {
        _filteredNotes = _notes.where((n) => n.content.toLowerCase().contains(query)).toList();
      }
    });
  }

  String _formatDateTime(DateTime dt) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final minuteStr = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]}, $hour:$minuteStr $period';
  }

  void _copyNote(String content) {
    Clipboard.setData(ClipboardData(text: content));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Note copied to clipboard'),
        backgroundColor: FocusOsTheme.of(context).surfaceAlt,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _exportNotes() {
    if (_notes.isEmpty) return;
    final buffer = StringBuffer();
    for (final note in _notes) {
      buffer.writeln('[${_formatDateTime(note.timestamp)}] ${note.content}');
      buffer.writeln('--------------------------------------------------');
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('All notes exported to clipboard!'),
        backgroundColor: FocusOsTheme.of(context).surfaceAlt,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = FocusOsTheme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: motion.PremiumEnterTransition(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                GestureDetector(
                  onTap: widget.onBack,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: tokens.borderSubtle.withValues(alpha: 0.5),
                    ),
                    child: Icon(Icons.arrow_back, size: 16, color: tokens.textPrimary),
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Timestamp Notes',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: tokens.textPrimary),
                    ),
                    Text(
                      'Keyboard-first append-only quick note capturing with automated timestamps.',
                      style: TextStyle(fontSize: 12, color: tokens.textSecondary),
                    ),
                  ],
                ),
                const Spacer(),
                if (_notes.isNotEmpty)
                  GestureDetector(
                    onTap: _exportNotes,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: tokens.borderSubtle.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.share_outlined, size: 12, color: tokens.textPrimary),
                          const SizedBox(width: 6),
                          Text('Export All', style: TextStyle(fontSize: 10, color: tokens.textPrimary, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),

            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Side: Fast Input Field
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: tokens.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: tokens.borderSubtle),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Capture Idea', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tokens.textSecondary)),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _noteController,
                                focusNode: _noteFocusNode,
                                maxLines: 4,
                                style: TextStyle(color: tokens.textPrimary, fontSize: 13, height: 1.4),
                                decoration: InputDecoration(
                                  hintText: 'Type a reminder, business idea, meeting note or draft task...',
                                  hintStyle: TextStyle(color: tokens.textMuted, fontSize: 13),
                                  filled: true,
                                  fillColor: tokens.background,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.all(12),
                                ),
                                onSubmitted: (_) => _addNote(),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Press Enter to save instantly', style: TextStyle(fontSize: 9, color: tokens.textMuted)),
                                  GestureDetector(
                                    onTap: _addNote,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                      decoration: BoxDecoration(
                                        color: tokens.accent,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text('Add Note', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 24),

                  // Right Side: Notes Search & Feed
                  Expanded(
                    flex: 6,
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: tokens.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: tokens.borderSubtle),
                      ),
                      child: Column(
                        children: [
                          // Search Box
                          Container(
                            height: 38,
                            child: TextField(
                              controller: _searchController,
                              style: TextStyle(color: tokens.textPrimary, fontSize: 12),
                              decoration: InputDecoration(
                                hintText: 'Search timestamped notes...',
                                hintStyle: TextStyle(color: tokens.textMuted, fontSize: 12),
                                prefixIcon: Icon(Icons.search, size: 14, color: tokens.textMuted),
                                filled: true,
                                fillColor: tokens.background,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                              ),
                              onChanged: (_) => _filterNotes(),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Notes List
                          Expanded(
                            child: _filteredNotes.isEmpty
                                ? Center(
                                    child: Text(
                                      _notes.isEmpty ? 'No notes captured yet.' : 'No notes match your query.',
                                      style: TextStyle(fontSize: 11, color: tokens.textMuted),
                                    ),
                                  )
                                : ListView.builder(
                                    physics: const BouncingScrollPhysics(),
                                    itemCount: _filteredNotes.length,
                                    itemBuilder: (context, index) {
                                      final note = _filteredNotes[index];
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 12),
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: tokens.background,
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: tokens.borderSubtle),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(
                                                    _formatDateTime(note.timestamp),
                                                    style: TextStyle(fontSize: 9, color: tokens.textMuted, fontWeight: FontWeight.w600, fontFamily: 'monospace'),
                                                  ),
                                                  Row(
                                                    children: [
                                                      GestureDetector(
                                                        onTap: () => _copyNote(note.content),
                                                        child: Icon(Icons.copy_rounded, size: 12, color: tokens.textMuted),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      GestureDetector(
                                                        onTap: () => _deleteNote(note.id),
                                                        child: const Icon(Icons.delete_outline, size: 12, color: Colors.redAccent),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                note.content,
                                                style: TextStyle(fontSize: 11.5, color: tokens.textPrimary, height: 1.4),
                                              ),
                                            ],
                                          ),
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
          ],
        ),
      ),
    );
  }
}
