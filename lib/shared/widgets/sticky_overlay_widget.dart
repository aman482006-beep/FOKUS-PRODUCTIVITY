import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart' as wm;
import '../../core/providers.dart';
import '../theme.dart';

class StickyOverlayWidget extends ConsumerStatefulWidget {
  const StickyOverlayWidget({super.key});

  @override
  ConsumerState<StickyOverlayWidget> createState() => _StickyOverlayWidgetState();
}

class _StickyOverlayWidgetState extends ConsumerState<StickyOverlayWidget> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String? _editingNoteId;

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _saveNote() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    if (_editingNoteId != null) {
      ref.read(stickyNotesProvider.notifier).updateText(_editingNoteId!, text);
      setState(() {
        _editingNoteId = null;
      });
      _textController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Note updated!'),
          duration: Duration(seconds: 1),
          backgroundColor: Color(0xFF1971C2),
        ),
      );
    } else {
      ref.read(stickyNotesProvider.notifier).addNoteWithText(text);
      _textController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Note saved to Fokus!'),
          duration: Duration(seconds: 1),
          backgroundColor: Color(0xFF1971C2),
        ),
      );
    }

    // Automatically collapse back to bubble to stay out of the way
    ref.read(stickyOverlayProvider.notifier).enterBubble();
  }

  void _cancelEdit() {
    setState(() {
      _editingNoteId = null;
      _textController.clear();
    });
  }

  String _formatTimeShort(DateTime dt) {
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
    final state = ref.watch(stickyOverlayProvider);
    final notes = ref.watch(stickyNotesProvider);

    if (state == StickyOverlayState.bubble) {
      return _buildBubble(tokens);
    } else if (state == StickyOverlayState.expanded) {
      return _buildExpanded(tokens, notes);
    }

    return const SizedBox.shrink();
  }

  // ── 1. Mini Bubble Mode UI ──
  Widget _buildBubble(ThemeTokens tokens) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: GestureDetector(
          onPanStart: (_) {
            if (!kIsWeb) wm.WindowManager.instance.startDragging();
          },
          onTap: () {
            ref.read(stickyOverlayProvider.notifier).enterExpanded();
            // Auto focus text field on expand
            Future.delayed(const Duration(milliseconds: 100), () {
              _focusNode.requestFocus();
            });
          },
          child: Tooltip(
            message: 'Fokus Notes - Click to expand, Drag to move',
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [tokens.accent, tokens.accentSecondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: tokens.accent.withValues(alpha: 0.4),
                    blurRadius: 10,
                    spreadRadius: 1,
                    offset: const Offset(0, 3),
                  ),
                ],
                border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
              ),
              child: const Center(
                child: Icon(
                  Icons.edit_note_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── 2. Expanded Note Pad UI ──
  Widget _buildExpanded(ThemeTokens tokens, List<StickyNoteData> notes) {
    // Show all recent notes (with scrolling)
    final recentNotes = notes.reversed.toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        margin: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: tokens.surface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: tokens.borderMedium),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 16,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header / Drag bar
            GestureDetector(
              onPanStart: (_) {
                if (!kIsWeb) wm.WindowManager.instance.startDragging();
              },
              onDoubleTap: () {
                ref.read(stickyOverlayProvider.notifier).enterBubble();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: tokens.borderSubtle)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.edit_note_rounded, size: 18, color: tokens.accent),
                    const SizedBox(width: 8),
                    Text(
                      'Fokus Notepad',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: tokens.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    // Collapse to bubble
                    IconButton(
                      icon: Icon(Icons.close_fullscreen_rounded, size: 14, color: tokens.textSecondary),
                      onPressed: () {
                        ref.read(stickyOverlayProvider.notifier).enterBubble();
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      splashRadius: 16,
                      tooltip: 'Collapse to bubble',
                    ),
                    const SizedBox(width: 10),
                    // Restore main app
                    IconButton(
                      icon: Icon(Icons.open_in_full_rounded, size: 14, color: tokens.textSecondary),
                      onPressed: () {
                        ref.read(stickyOverlayProvider.notifier).exit();
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      splashRadius: 16,
                      tooltip: 'Restore main app',
                    ),
                  ],
                ),
              ),
            ),

            // Note input area
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Text Field
                    Expanded(
                      flex: 5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: tokens.background.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: tokens.borderSubtle),
                        ),
                        child: KeyboardListener(
                          focusNode: FocusNode(),
                          onKeyEvent: (KeyEvent event) {
                            if (event is KeyDownEvent &&
                                event.logicalKey == LogicalKeyboardKey.enter &&
                                (HardwareKeyboard.instance.isLogicalKeyPressed(LogicalKeyboardKey.controlLeft) ||
                                 HardwareKeyboard.instance.isLogicalKeyPressed(LogicalKeyboardKey.controlRight))) {
                              _saveNote();
                            }
                          },
                          child: TextField(
                            controller: _textController,
                            focusNode: _focusNode,
                            maxLines: null,
                            style: TextStyle(fontSize: 12, color: tokens.textPrimary, height: 1.4),
                            decoration: InputDecoration(
                              hintText: 'Note down ideas, links, code snippet...',
                              hintStyle: TextStyle(fontSize: 11, color: tokens.textMuted),
                              border: InputBorder.none,
                            ),
                            keyboardType: TextInputType.multiline,
                            textInputAction: TextInputAction.newline,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Actions Bar (Save & Info)
                    Row(
                      children: [
                        if (_editingNoteId != null) ...[
                          Text(
                            'Editing Note',
                            style: TextStyle(fontSize: 9.5, color: tokens.accent, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: _cancelEdit,
                            child: Icon(Icons.cancel_outlined, size: 12, color: tokens.textMuted),
                          ),
                        ] else ...[
                          Text(
                            'Ctrl+Enter to save',
                            style: TextStyle(fontSize: 9, color: tokens.textMuted),
                          ),
                        ],
                        const Spacer(),
                        ElevatedButton(
                          onPressed: _saveNote,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: tokens.accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            minimumSize: Size.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _editingNoteId != null ? Icons.check_rounded : Icons.send_rounded,
                                size: 10,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _editingNoteId != null ? 'Update' : 'Save',
                                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Recent Notes List
                    if (recentNotes.isNotEmpty) ...[
                      Text(
                        'Recent Notes',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: tokens.textSecondary),
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        flex: 4,
                        child: ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          itemCount: recentNotes.length,
                          itemBuilder: (context, index) {
                            final note = recentNotes[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: note.color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: note.color.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  // Color bar indicator
                                  Container(
                                    width: 3,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      color: note.color,
                                      borderRadius: BorderRadius.circular(1.5),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          note.text.trim().isEmpty ? '(Empty Note)' : note.text,
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            color: tokens.textPrimary,
                                            fontWeight: _editingNoteId == note.id ? FontWeight.bold : FontWeight.normal,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          _formatTimeShort(note.timestamp),
                                          style: TextStyle(fontSize: 8, color: tokens.textMuted),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Copy button
                                  GestureDetector(
                                    onTap: () {
                                      Clipboard.setData(ClipboardData(text: note.text));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Copied note!'),
                                          duration: Duration(seconds: 1),
                                        ),
                                      );
                                    },
                                    child: Icon(Icons.content_copy_rounded, size: 12, color: tokens.textMuted),
                                  ),
                                  const SizedBox(width: 8),
                                  // Edit button
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _editingNoteId = note.id;
                                        _textController.text = note.text;
                                      });
                                      _focusNode.requestFocus();
                                    },
                                    child: Icon(Icons.edit_outlined, size: 12, color: tokens.textMuted),
                                  ),
                                  const SizedBox(width: 8),
                                  // Delete button
                                  GestureDetector(
                                    onTap: () {
                                      if (_editingNoteId == note.id) {
                                        _cancelEdit();
                                      }
                                      ref.read(stickyNotesProvider.notifier).deleteNote(note.id);
                                    },
                                    child: Icon(Icons.delete_outline_rounded, size: 12, color: Colors.redAccent.withValues(alpha: 0.8)),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ] else ...[
                      const Spacer(),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
