import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../shared/theme.dart';
import '../../shared/motion.dart' as motion;
import '../../shared/widgets/premium_button.dart';

// Provider for global sticky notes visibility
final showStickyNotesProvider = StateProvider<bool>((ref) => true);

class StickyNotesPage extends ConsumerStatefulWidget {
  final VoidCallback onBack;

  const StickyNotesPage({super.key, required this.onBack});

  @override
  ConsumerState<StickyNotesPage> createState() => _StickyNotesPageState();
}

class _StickyNotesPageState extends ConsumerState<StickyNotesPage> {
  @override
  Widget build(BuildContext context) {
    final tokens = FocusOsTheme.of(context);
    final notes = ref.watch(stickyNotesProvider);
    final showNotes = ref.watch(showStickyNotesProvider);

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
                      'Floating Sticky Notes',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: tokens.textPrimary),
                    ),
                    Text(
                      'Create floating draggable notes visible anywhere in Fokus.',
                      style: TextStyle(fontSize: 12, color: tokens.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left panel: Settings & Controls
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: tokens.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: tokens.borderSubtle),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Workspace Control', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: tokens.textPrimary)),
                              const SizedBox(height: 14),

                              // Visibility toggle
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Show Sticky Notes', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: tokens.textPrimary)),
                                      Text('Display floating notes on screen', style: TextStyle(fontSize: 9.5, color: tokens.textMuted)),
                                    ],
                                  ),
                                  Switch(
                                    value: showNotes,
                                    onChanged: (val) {
                                      ref.read(showStickyNotesProvider.notifier).state = val;
                                    },
                                    activeThumbColor: tokens.accent,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),

                              // Mini Bubble Mode control
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Floating Desktop Bubble', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: tokens.textPrimary)),
                                      Text('Shrink app into a floating desktop bubble', style: TextStyle(fontSize: 9.5, color: tokens.textMuted)),
                                    ],
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.picture_in_picture_alt_rounded, color: tokens.accent),
                                    onPressed: () {
                                      ref.read(stickyOverlayProvider.notifier).enterBubble();
                                    },
                                    tooltip: 'Shrink to Desktop Bubble',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),

                              // Add Note Button
                              Row(
                                children: [
                                  Expanded(
                                    child: PremiumButton(
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: const [
                                          Icon(Icons.note_add_rounded, color: Colors.white, size: 14),
                                          SizedBox(width: 8),
                                          Text('Spawn New Sticky Note', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                      onTap: () {
                                        // Spawn at a default position (e.g. 200, 200)
                                        ref.read(stickyNotesProvider.notifier).addNote(250.0, 180.0);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: const Text('New sticky note spawned! Drag it anywhere.'),
                                            backgroundColor: FocusOsTheme.of(context).surfaceAlt,
                                            duration: const Duration(seconds: 1),
                                          ),
                                        );
                                      },
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

                  // Right panel: Notes management list
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Active Notes (${notes.length})', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: tokens.textPrimary)),
                          const SizedBox(height: 12),
                          Expanded(
                            child: notes.isEmpty
                                ? Center(
                                    child: Text('No active sticky notes.', style: TextStyle(fontSize: 11, color: tokens.textMuted)),
                                  )
                                : ListView.builder(
                                    physics: const BouncingScrollPhysics(),
                                    itemCount: notes.length,
                                    itemBuilder: (context, index) {
                                      final note = notes[index];
                                      return StickyNoteListItem(note: note);
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

class StickyNoteListItem extends ConsumerStatefulWidget {
  final StickyNoteData note;
  const StickyNoteListItem({super.key, required this.note});

  @override
  ConsumerState<StickyNoteListItem> createState() => _StickyNoteListItemState();
}

class _StickyNoteListItemState extends ConsumerState<StickyNoteListItem> {
  bool _isEditing = false;
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.note.text);
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant StickyNoteListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.note.text != widget.note.text && !_isEditing) {
      _controller.text = widget.note.text;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _save() {
    final text = _controller.text;
    ref.read(stickyNotesProvider.notifier).updateText(widget.note.id, text);
    setState(() {
      _isEditing = false;
    });
  }

  void _cancel() {
    setState(() {
      _controller.text = widget.note.text;
      _isEditing = false;
    });
  }

  String _formatDateTime(DateTime dt) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final month = months[dt.month - 1];
    final day = dt.day;
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$day $month, $hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = FocusOsTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: tokens.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: tokens.borderSubtle),
        ),
        child: Row(
          crossAxisAlignment: _isEditing ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 2),
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: widget.note.color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _isEditing
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          style: TextStyle(fontSize: 12, color: tokens.textPrimary),
                          maxLines: null,
                          keyboardType: TextInputType.multiline,
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                            border: OutlineInputBorder(
                              borderSide: BorderSide(color: tokens.borderMedium),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: tokens.accent),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          onSubmitted: (_) => _save(),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.note.text.trim().isEmpty ? '(Empty Note)' : widget.note.text,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: widget.note.text.trim().isEmpty ? tokens.textMuted : tokens.textPrimary,
                            fontStyle: widget.note.text.trim().isEmpty ? FontStyle.italic : FontStyle.normal,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              'Position: (${widget.note.x.toInt()}, ${widget.note.y.toInt()})',
                              style: TextStyle(fontSize: 8.5, color: tokens.textMuted),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 3,
                              height: 3,
                              decoration: BoxDecoration(
                                color: tokens.textMuted.withValues(alpha: 0.4),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Saved: ${_formatDateTime(widget.note.timestamp)}',
                              style: TextStyle(fontSize: 8.5, color: tokens.textMuted),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
            const SizedBox(width: 10),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: _isEditing
                  ? [
                      IconButton(
                        icon: const Icon(Icons.check_rounded, size: 14, color: Colors.greenAccent),
                        onPressed: _save,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        splashRadius: 14,
                        tooltip: 'Save',
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.close_rounded, size: 14, color: tokens.textMuted),
                        onPressed: _cancel,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        splashRadius: 14,
                        tooltip: 'Cancel',
                      ),
                    ]
                  : [
                      IconButton(
                        icon: Icon(Icons.content_copy_rounded, size: 13, color: tokens.textMuted),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: widget.note.text));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Copied note to clipboard!'),
                              backgroundColor: tokens.surfaceAlt,
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        splashRadius: 14,
                        tooltip: 'Copy Note',
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.edit_outlined, size: 13, color: tokens.textMuted),
                        onPressed: () {
                          setState(() {
                            _isEditing = true;
                          });
                          _focusNode.requestFocus();
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        splashRadius: 14,
                        tooltip: 'Edit Note',
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 13, color: Colors.redAccent),
                        onPressed: () {
                          ref.read(stickyNotesProvider.notifier).deleteNote(widget.note.id);
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        splashRadius: 14,
                        tooltip: 'Delete Note',
                      ),
                    ],
            ),
          ],
        ),
      ),
    );
  }
}
