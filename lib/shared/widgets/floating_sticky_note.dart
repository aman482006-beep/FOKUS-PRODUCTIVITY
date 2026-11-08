import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';

class FloatingStickyNote extends ConsumerStatefulWidget {
  final StickyNoteData note;

  const FloatingStickyNote({super.key, required this.note});

  @override
  ConsumerState<FloatingStickyNote> createState() => _FloatingStickyNoteState();
}

class _FloatingStickyNoteState extends ConsumerState<FloatingStickyNote> {
  late TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.note.text);
  }

  @override
  void didUpdateWidget(covariant FloatingStickyNote oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.note.text != widget.note.text && _textController.text != widget.note.text) {
      _textController.text = widget.note.text;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final note = widget.note;

    // Clamp coordinates to screen boundaries
    double x = note.x.clamp(0.0, size.width - 60);
    double y = note.y.clamp(0.0, size.height - 60);

    // Pale color mapping for styling the header & text fields
    final headerColor = note.color.withValues(alpha: 0.85);

    // Color choices
    const colors = [
      Color(0xFFFFF9C4), // Yellow
      Color(0xFFF8BBD0), // Pink
      Color(0xFFB3E5FC), // Blue
      Color(0xFFC8E6C9), // Green
      Color(0xFFE1BEE7), // Purple
    ];

    return Positioned(
      left: x,
      top: y,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: note.width,
          height: note.height,
          decoration: BoxDecoration(
            color: note.color,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
            border: Border.all(color: Colors.black.withValues(alpha: 0.06), width: 1),
          ),
          child: Column(
            children: [
              // Header bar for dragging
              GestureDetector(
                onPanUpdate: (details) {
                  ref.read(stickyNotesProvider.notifier).updatePosition(
                        note.id,
                        note.x + details.delta.dx,
                        note.y + details.delta.dy,
                      );
                },
                child: Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: headerColor,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  child: Row(
                    children: [
                      // Close button
                      GestureDetector(
                        onTap: () {
                          ref.read(stickyNotesProvider.notifier).deleteNote(note.id);
                        },
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFF5F56),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Icon(Icons.close, size: 7, color: Colors.black54),
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Color dots picker
                      Row(
                        children: colors.map((c) {
                          final active = c.toARGB32() == note.color.toARGB32();
                          return GestureDetector(
                            onTap: () {
                              ref.read(stickyNotesProvider.notifier).updateColor(note.id, c);
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 2.5),
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: active ? Colors.black54 : Colors.black12,
                                  width: active ? 1 : 0.5,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),

              // Note Text Editor Area
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
                  child: TextField(
                    controller: _textController,
                    maxLines: null,
                    expands: true,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 12,
                      fontFamily: 'sans-serif',
                      height: 1.4,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Write a quick note...',
                      hintStyle: TextStyle(color: Colors.black38, fontSize: 12),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (text) {
                      ref.read(stickyNotesProvider.notifier).updateText(note.id, text);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
