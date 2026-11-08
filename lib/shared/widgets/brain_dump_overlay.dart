import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/providers.dart';
import '../theme.dart';
import '../shortcuts.dart';

// ──────────────────────────────────────────────
// Brain Dump Entry Model
// ──────────────────────────────────────────────

class BrainDumpEntry {
  final String id;
  final String text;
  final DateTime timestamp;
  final bool reviewed;

  const BrainDumpEntry({
    required this.id,
    required this.text,
    required this.timestamp,
    this.reviewed = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'timestamp': timestamp.toIso8601String(),
        'reviewed': reviewed,
      };

  factory BrainDumpEntry.fromJson(Map<String, dynamic> json) => BrainDumpEntry(
        id: json['id'] as String? ?? DateTime.now().toIso8601String(),
        text: json['text'] as String? ?? '',
        timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
        reviewed: json['reviewed'] as bool? ?? false,
      );

  BrainDumpEntry copyWith({bool? reviewed}) => BrainDumpEntry(
        id: id,
        text: text,
        timestamp: timestamp,
        reviewed: reviewed ?? this.reviewed,
      );
}

// ──────────────────────────────────────────────
// Brain Dump Service
// ──────────────────────────────────────────────

class BrainDumpService {
  BrainDumpService._();

  static const _storageKey = 'brain_dump_entries';

  static Future<List<BrainDumpEntry>> loadEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey) ?? '[]';
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => BrainDumpEntry.fromJson(Map<String, dynamic>.from(e as Map))).toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveEntry(BrainDumpEntry entry) async {
    final entries = await loadEntries();
    entries.insert(0, entry);
    await _persist(entries);
  }

  static Future<void> markReviewed(String id) async {
    final entries = await loadEntries();
    final idx = entries.indexWhere((e) => e.id == id);
    if (idx >= 0) {
      entries[idx] = entries[idx].copyWith(reviewed: true);
      await _persist(entries);
    }
  }

  static Future<void> deleteEntry(String id) async {
    final entries = await loadEntries();
    entries.removeWhere((e) => e.id == id);
    await _persist(entries);
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  static Future<void> _persist(List<BrainDumpEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(entries.map((e) => e.toJson()).toList()));
  }
}

// ──────────────────────────────────────────────
// Brain Dump Overlay Widget
// ──────────────────────────────────────────────

/// Full-screen modal overlay for capturing distractions.
/// Triggered via Ctrl+B keyboard shortcut.
class BrainDumpOverlay extends ConsumerStatefulWidget {
  final VoidCallback onClose;

  const BrainDumpOverlay({super.key, required this.onClose});

  @override
  ConsumerState<BrainDumpOverlay> createState() => _BrainDumpOverlayState();
}

class _BrainDumpOverlayState extends ConsumerState<BrainDumpOverlay>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _animController.forward();
    _controller.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _focusNode.canRequestFocus) {
        _focusNode.requestFocus();
      }
    });
  }

  void _onTextChanged() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _saveAndClose() async {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      await BrainDumpService.saveEntry(
        BrainDumpEntry(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text: text,
          timestamp: DateTime.now(),
        ),
      );
      ref.read(brainDumpEntriesProvider.notifier).refresh();
    }
    await _animController.reverse();
    widget.onClose();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _justClose() async {
    await _animController.reverse();
    widget.onClose();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = FocusOsTheme.of(context);

    return FadeTransition(
      opacity: _fadeAnim,
      child: GestureDetector(
        onTap: _justClose,
        child: Container(
          color: Colors.black.withValues(alpha: 0.6),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: GestureDetector(
                onTap: () {},
                child: Container(
                  constraints: const BoxConstraints(
                    maxWidth: 480,
                    maxHeight: 400,
                  ),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: tokens.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: tokens.borderSubtle),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 40,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    // ── Header ──
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: tokens.accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.psychology_outlined, size: 20, color: tokens.accent),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Brain Dump',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: tokens.textPrimary,
                                ),
                              ),
                              Text(
                                'Capture your thoughts, get back to fokus',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: tokens.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: _justClose,
                          icon: Icon(Icons.close, size: 20, color: tokens.textMuted),
                          splashRadius: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // ── Text input ──
                    TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      autofocus: true,
                      maxLines: 5,
                      minLines: 3,
                      style: TextStyle(color: tokens.textPrimary, fontSize: 15),
                      decoration: InputDecoration(
                        hintText:
                            'What\'s on your mind? e.g., "Remember to email Sarah about the project..."',
                        hintStyle: TextStyle(color: tokens.textMuted, fontSize: 14),
                        filled: true,
                        fillColor: tokens.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: tokens.borderMedium),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: tokens.borderSubtle),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: tokens.accent, width: 2),
                        ),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                      onSubmitted: (_) => _saveAndClose(),
                    ),
                    const SizedBox(height: 20),
                    // ── Action Buttons ──
                    Row(
                      children: [
                        Icon(Icons.keyboard, size: 14, color: tokens.textMuted),
                        const SizedBox(width: 6),
                        Text(
                          '${FocusOsShortcut.modifierLabel}+B · Enter to save · Esc to close',
                          style: TextStyle(fontSize: 11, color: tokens.textMuted),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: _justClose,
                          child: Text(
                            'Cancel',
                            style: TextStyle(color: tokens.textSecondary),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _hasText ? _saveAndClose : null,
                          icon: const Icon(Icons.save_rounded, size: 18),
                          label: const Text('Save Entry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: tokens.accent,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: tokens.surfaceAlt,
                            disabledForegroundColor: tokens.textMuted,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  ),
);
  }
}
