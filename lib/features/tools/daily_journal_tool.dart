import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../../shared/theme.dart';
import '../../shared/motion.dart' as motion;
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/premium_card.dart';
import '../../shared/widgets/premium_button.dart';

// ──────────────────────────────────────────────
// Journal Entry Model
// ──────────────────────────────────────────────

class JournalEntry {
  final String id;
  final DateTime date;
  final String mood; // 'radiant', 'happy', 'peaceful', 'neutral', 'tired', 'stressed'
  final String title;
  final String body;
  final List<String> gratitude; // up to 3 items
  final String highlight;
  final String challenge;
  final List<String> tags;
  final DateTime createdAt;

  JournalEntry({
    required this.id,
    required this.date,
    required this.mood,
    required this.title,
    required this.body,
    required this.gratitude,
    required this.highlight,
    required this.challenge,
    required this.tags,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'mood': mood,
        'title': title,
        'body': body,
        'gratitude': gratitude,
        'highlight': highlight,
        'challenge': challenge,
        'tags': tags,
        'createdAt': createdAt.toIso8601String(),
      };

  factory JournalEntry.fromJson(Map<String, dynamic> json) => JournalEntry(
        id: json['id'] as String,
        date: DateTime.parse(json['date'] as String),
        mood: json['mood'] as String,
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        gratitude: (json['gratitude'] as List?)?.map((e) => e as String).toList() ?? [],
        highlight: json['highlight'] as String? ?? '',
        challenge: json['challenge'] as String? ?? '',
        tags: (json['tags'] as List?)?.map((e) => e as String).toList() ?? [],
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

// ──────────────────────────────────────────────
// Mood Definition
// ──────────────────────────────────────────────

class MoodOption {
  final String id;
  final String label;
  final String emoji;
  final Color color;

  const MoodOption({
    required this.id,
    required this.label,
    required this.emoji,
    required this.color,
  });
}

const List<MoodOption> _moodOptions = [
  MoodOption(id: 'radiant', label: 'Radiant', emoji: '🌟', color: Color(0xFFF59E0B)), // Amber
  MoodOption(id: 'happy', label: 'Happy', emoji: '😊', color: Color(0xFF10B981)), // Emerald
  MoodOption(id: 'peaceful', label: 'Peaceful', emoji: '🧘', color: Color(0xFF14B8A6)), // Teal
  MoodOption(id: 'neutral', label: 'Neutral', emoji: '😐', color: Color(0xFF6B7280)), // Grey
  MoodOption(id: 'tired', label: 'Tired', emoji: '😴', color: Color(0xFF6366F1)), // Indigo
  MoodOption(id: 'stressed', label: 'Stressed', emoji: '🤯', color: Color(0xFFEF4444)), // Red
];

// ──────────────────────────────────────────────
// Daily Journal Page
// ──────────────────────────────────────────────

class DailyJournalPage extends StatefulWidget {
  final VoidCallback onBack;

  const DailyJournalPage({super.key, required this.onBack});

  @override
  State<DailyJournalPage> createState() => _DailyJournalPageState();
}

class _DailyJournalPageState extends State<DailyJournalPage> {
  final List<JournalEntry> _entries = [];
  List<JournalEntry> _filteredEntries = [];

  // Active States
  JournalEntry? _selectedEntry;
  bool _isEditing = false;
  bool _isCreatingNew = false;

  // Search & Filtering
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _filterMood;
  String? _selectedTag;

  // Form Controllers & State
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _highlightController = TextEditingController();
  final _challengeController = TextEditingController();
  final _tagsController = TextEditingController();
  final _gratitudeController1 = TextEditingController();
  final _gratitudeController2 = TextEditingController();
  final _gratitudeController3 = TextEditingController();
  
  DateTime _selectedDate = DateTime.now();
  String _selectedMood = 'happy';

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _titleController.dispose();
    _bodyController.dispose();
    _highlightController.dispose();
    _challengeController.dispose();
    _tagsController.dispose();
    _gratitudeController1.dispose();
    _gratitudeController2.dispose();
    _gratitudeController3.dispose();
    super.dispose();
  }

  // ── Database Operations ──

  Future<void> _loadEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('daily_journal_entries');
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw) as List;
        setState(() {
          _entries.clear();
          _entries.addAll(decoded.map((e) => JournalEntry.fromJson(Map<String, dynamic>.from(e))));
          // Sort entries by date descending
          _entries.sort((a, b) => b.date.compareTo(a.date));
          _filterEntries();

          // Auto-select the latest entry if nothing is selected yet
          if (_entries.isNotEmpty && _selectedEntry == null && !_isEditing) {
            _selectedEntry = _entries.first;
          }
        });
      } catch (e) {
        debugPrint('Error loading journal entries: $e');
      }
    }
  }

  Future<void> _saveEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_entries.map((e) => e.toJson()).toList());
    await prefs.setString('daily_journal_entries', encoded);
  }

  void _filterEntries() {
    setState(() {
      _filteredEntries = _entries.where((entry) {
        // Search text matching (title, body, tags, gratitude)
        final query = _searchQuery.toLowerCase().trim();
        bool matchesQuery = true;
        if (query.isNotEmpty) {
          final titleMatch = entry.title.toLowerCase().contains(query);
          final bodyMatch = entry.body.toLowerCase().contains(query);
          final highlightMatch = entry.highlight.toLowerCase().contains(query);
          final challengeMatch = entry.challenge.toLowerCase().contains(query);
          final tagsMatch = entry.tags.any((t) => t.toLowerCase().contains(query));
          final gratitudeMatch = entry.gratitude.any((g) => g.toLowerCase().contains(query));
          
          matchesQuery = titleMatch || bodyMatch || highlightMatch || challengeMatch || tagsMatch || gratitudeMatch;
        }

        // Mood filtering
        bool matchesMood = true;
        if (_filterMood != null) {
          matchesMood = entry.mood == _filterMood;
        }

        // Tag filtering
        bool matchesTag = true;
        if (_selectedTag != null) {
          matchesTag = entry.tags.any((t) => t.toLowerCase() == _selectedTag!.toLowerCase());
        }

        return matchesQuery && matchesMood && matchesTag;
      }).toList();
    });
  }

  // ── Form Actions ──

  void _startNewEntry() {
    setState(() {
      _isEditing = true;
      _isCreatingNew = true;
      _selectedEntry = null;

      // Reset Form fields
      _titleController.clear();
      _bodyController.clear();
      _highlightController.clear();
      _challengeController.clear();
      _tagsController.clear();
      _gratitudeController1.clear();
      _gratitudeController2.clear();
      _gratitudeController3.clear();
      _selectedDate = DateTime.now();
      _selectedMood = 'happy';
    });
  }

  void _startEditing(JournalEntry entry) {
    setState(() {
      _isEditing = true;
      _isCreatingNew = false;
      _selectedEntry = entry;

      // Populate Form fields
      _titleController.text = entry.title;
      _bodyController.text = entry.body;
      _highlightController.text = entry.highlight;
      _challengeController.text = entry.challenge;
      _tagsController.text = entry.tags.join(', ');
      
      _gratitudeController1.text = entry.gratitude.isNotEmpty ? entry.gratitude[0] : '';
      _gratitudeController2.text = entry.gratitude.length > 1 ? entry.gratitude[1] : '';
      _gratitudeController3.text = entry.gratitude.length > 2 ? entry.gratitude[2] : '';
      
      _selectedDate = entry.date;
      _selectedMood = entry.mood;
    });
  }

  void _cancelEditing() {
    setState(() {
      _isEditing = false;
      _isCreatingNew = false;
      if (_selectedEntry == null && _entries.isNotEmpty) {
        _selectedEntry = _entries.first;
      }
    });
  }

  void _saveEntry() {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    final highlight = _highlightController.text.trim();
    final challenge = _challengeController.text.trim();
    
    final gratitude = <String>[];
    if (_gratitudeController1.text.trim().isNotEmpty) gratitude.add(_gratitudeController1.text.trim());
    if (_gratitudeController2.text.trim().isNotEmpty) gratitude.add(_gratitudeController2.text.trim());
    if (_gratitudeController3.text.trim().isNotEmpty) gratitude.add(_gratitudeController3.text.trim());

    final tags = _tagsController.text
        .split(',')
        .map((t) => t.trim().replaceAll('#', ''))
        .where((t) => t.isNotEmpty)
        .toList();

    // Require either a title, body, highlight, or gratitude to save
    if (title.isEmpty && body.isEmpty && highlight.isEmpty && gratitude.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please write a title, notes, gratitude, or highlight to save.'),
          backgroundColor: FocusOsTheme.of(context).borderMedium,
        ),
      );
      return;
    }

    if (_isCreatingNew) {
      final newEntry = JournalEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        date: _selectedDate,
        mood: _selectedMood,
        title: title.isEmpty ? 'Journal Entry' : title,
        body: body,
        gratitude: gratitude,
        highlight: highlight,
        challenge: challenge,
        tags: tags,
        createdAt: DateTime.now(),
      );

      setState(() {
        _entries.add(newEntry);
        _entries.sort((a, b) => b.date.compareTo(a.date));
        _selectedEntry = newEntry;
        _isEditing = false;
        _isCreatingNew = false;
        _filterEntries();
      });
    } else if (_selectedEntry != null) {
      final updatedEntry = JournalEntry(
        id: _selectedEntry!.id,
        date: _selectedDate,
        mood: _selectedMood,
        title: title.isEmpty ? 'Journal Entry' : title,
        body: body,
        gratitude: gratitude,
        highlight: highlight,
        challenge: challenge,
        tags: tags,
        createdAt: _selectedEntry!.createdAt,
      );

      setState(() {
        final index = _entries.indexWhere((e) => e.id == _selectedEntry!.id);
        if (index != -1) {
          _entries[index] = updatedEntry;
        }
        _entries.sort((a, b) => b.date.compareTo(a.date));
        _selectedEntry = updatedEntry;
        _isEditing = false;
        _filterEntries();
      });
    }

    _saveEntries();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Journal entry saved successfully!'),
        backgroundColor: FocusOsTheme.of(context).accent,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _deleteEntry(JournalEntry entry) {
    showDialog(
      context: context,
      builder: (ctx) {
        final tokens = FocusOsTheme.of(ctx);
        return AlertDialog(
          backgroundColor: tokens.surface,
          title: Text('Delete Journal Entry', style: TextStyle(color: tokens.textPrimary)),
          content: Text(
            'Are you sure you want to delete this entry? This action cannot be undone.',
            style: TextStyle(color: tokens.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancel', style: TextStyle(color: tokens.textMuted)),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                setState(() {
                  _entries.removeWhere((e) => e.id == entry.id);
                  if (_selectedEntry?.id == entry.id) {
                    _selectedEntry = _entries.isNotEmpty ? _entries.first : null;
                  }
                  _filterEntries();
                });
                _saveEntries();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Entry deleted.'),
                    backgroundColor: tokens.borderMedium,
                  ),
                );
              },
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  // ── Share / Export ──

  void _exportEntryToMarkdown(JournalEntry entry) {
    final buffer = StringBuffer();
    final formattedDate = _formatFullDate(entry.date);
    final moodOpt = _moodOptions.firstWhere((m) => m.id == entry.mood,
        orElse: () => _moodOptions[3]);

    buffer.writeln('# ${entry.title}');
    buffer.writeln('**Date**: $formattedDate');
    buffer.writeln('**Mood**: ${moodOpt.emoji} ${moodOpt.label}');
    buffer.writeln();

    if (entry.gratitude.isNotEmpty) {
      buffer.writeln('### 3 Things I\'m Grateful For Today');
      for (final item in entry.gratitude) {
        buffer.writeln('- $item');
      }
      buffer.writeln();
    }

    if (entry.highlight.isNotEmpty) {
      buffer.writeln('### Highlight of the Day');
      buffer.writeln('> ${entry.highlight}');
      buffer.writeln();
    }

    if (entry.challenge.isNotEmpty) {
      buffer.writeln('### Challenge & Learning');
      buffer.writeln('> ${entry.challenge}');
      buffer.writeln();
    }

    if (entry.body.isNotEmpty) {
      buffer.writeln('### Reflection & Notes');
      buffer.writeln(entry.body);
      buffer.writeln();
    }

    if (entry.tags.isNotEmpty) {
      buffer.writeln('**Tags**: ${entry.tags.map((t) => '#$t').join(', ')}');
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Entry copied as Markdown to clipboard!'),
        backgroundColor: FocusOsTheme.of(context).accent,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _exportEntries(List<JournalEntry> entriesToExport, String format) async {
    if (entriesToExport.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No entries selected for export.'),
          backgroundColor: Colors.amber.shade700,
        ),
      );
      return;
    }

    if (format == 'pdf') {
      try {
        final document = PdfDocument();

        for (var i = 0; i < entriesToExport.length; i++) {
          final entry = entriesToExport[i];
          final page = document.pages.add();
          _drawSingleEntryOnPdf(document, page, entry);
        }

        // Add page numbers and footer
        _addPageNumbers(document);

        final bytes = Uint8List.fromList(await document.save());
        document.dispose();

        final result = await FilePicker.saveFile(
          dialogTitle: 'Save Journal Archive as PDF',
          fileName: 'journal_archive.pdf',
          type: FileType.custom,
          allowedExtensions: ['pdf'],
          bytes: bytes,
        );

        if (result == null) return;
        
        if (!kIsWeb) {
          await File(result).writeAsBytes(bytes);
        }

        if (mounted) {
          final displayPath = kIsWeb ? result : result.split(Platform.isWindows ? "\\" : "/").last;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Saved PDF to $displayPath'),
              backgroundColor: FocusOsTheme.of(context).accent,
            ),
          );
        }
      } catch (e) {
        debugPrint('Error generating PDF: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to save PDF: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } else {
      final buffer = StringBuffer();
      for (var i = 0; i < entriesToExport.length; i++) {
        final entry = entriesToExport[i];
        final formattedDate = _formatFullDate(entry.date);
        final moodOpt = _moodOptions.firstWhere((m) => m.id == entry.mood,
            orElse: () => _moodOptions[3]);

        buffer.writeln('==================================================');
        buffer.writeln('TITLE: ${entry.title}');
        buffer.writeln('DATE: $formattedDate');
        buffer.writeln('MOOD: ${moodOpt.emoji} ${moodOpt.label}');
        if (entry.tags.isNotEmpty) buffer.writeln('TAGS: ${entry.tags.join(', ')}');
        buffer.writeln('--------------------------------------------------');

        if (entry.gratitude.isNotEmpty) {
          buffer.writeln('GRATITUDE:');
          for (var j = 0; j < entry.gratitude.length; j++) {
            buffer.writeln('${j + 1}. ${entry.gratitude[j]}');
          }
        }

        if (entry.highlight.isNotEmpty) {
          buffer.writeln('HIGHLIGHT: ${entry.highlight}');
        }

        if (entry.challenge.isNotEmpty) {
          buffer.writeln('CHALLENGE: ${entry.challenge}');
        }

        if (entry.body.isNotEmpty) {
          buffer.writeln('REFLECTION:');
          buffer.writeln(entry.body);
        }
        buffer.writeln();
      }

      Clipboard.setData(ClipboardData(text: buffer.toString()));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Markdown text copied to clipboard!'),
          backgroundColor: FocusOsTheme.of(context).accent,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _exportEntryToPdf(JournalEntry entry) async {
    try {
      final document = PdfDocument();
      final page = document.pages.add();
      _drawSingleEntryOnPdf(document, page, entry);

      // Add page numbers and footer
      _addPageNumbers(document);

      final bytes = Uint8List.fromList(await document.save());
      document.dispose();

      // Clean file name
      final cleanTitle = entry.title.replaceAll(RegExp(r'[^\w\s\-]'), '').replaceAll(' ', '_').toLowerCase();
      final formattedDate = '${entry.date.year}-${entry.date.month.toString().padLeft(2, '0')}-${entry.date.day.toString().padLeft(2, '0')}';
      final fileName = 'journal_${formattedDate}_$cleanTitle.pdf';

      final result = await FilePicker.saveFile(
        dialogTitle: 'Save Journal Entry as PDF',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        bytes: bytes,
      );

      if (result == null) return;
      
      if (!kIsWeb) {
        await File(result).writeAsBytes(bytes);
      }

      if (mounted) {
        final displayPath = kIsWeb ? result : result.split(Platform.isWindows ? "\\" : "/").last;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved PDF to $displayPath'),
            backgroundColor: FocusOsTheme.of(context).accent,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error generating PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save PDF: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showExportDialog(ThemeTokens tokens) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: tokens.surface,
          elevation: 24,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _ExportDialog(
                  tokens: tokens,
                  filteredEntries: _filteredEntries,
                  allEntries: _entries,
                  onExport: (entries, format) {
                    _exportEntries(entries, format);
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _drawSingleEntryOnPdf(PdfDocument document, PdfPage initialPage, JournalEntry entry) {
    PdfPage page = initialPage;
    final pageSize = page.getClientSize();
    double currentY = 100.0;

    // Helper to ensure enough space on the current page, otherwise add a new page.
    void ensureSpace(double requiredHeight) {
      final remaining = pageSize.height - currentY - 50;
      if (remaining < requiredHeight) {
        page = document.pages.add();
        currentY = 50; // Reset to top margin
      }
    }

    // 1. Draw top accent bar (Teal)
    page.graphics.drawRectangle(
      bounds: const Rect.fromLTWH(0, 0, 600, 15),
      brush: PdfSolidBrush(PdfColor(20, 184, 166)),
    );

    // 2. Draw Top branding/header
    page.graphics.drawString(
      'DAILY JOURNAL',
      PdfStandardFont(PdfFontFamily.helvetica, 18, style: PdfFontStyle.bold),
      brush: PdfSolidBrush(PdfColor(15, 23, 42)), // Slate 900
      bounds: const Rect.fromLTWH(50, 40, 300, 25),
    );

    page.graphics.drawString(
      'Fokus Forge Reflection Log',
      PdfStandardFont(PdfFontFamily.helvetica, 8, style: PdfFontStyle.italic),
      brush: PdfSolidBrush(PdfColor(100, 116, 139)), // Slate 500
      bounds: const Rect.fromLTWH(50, 65, 300, 15),
    );

    // Divider line
    page.graphics.drawLine(
      PdfPen(PdfColor(226, 232, 240), width: 1), // Slate 200
      const Offset(50, 85),
      Offset(pageSize.width - 50, 85),
    );

    // 3. Entry title & date/mood info
    final titleElement = PdfTextElement(
      text: _sanitizeForHelvetica(entry.title),
      font: PdfStandardFont(PdfFontFamily.helvetica, 14, style: PdfFontStyle.bold),
      brush: PdfSolidBrush(PdfColor(15, 23, 42)), // Slate 900
    );

    final titleResult = titleElement.draw(
      page: page,
      bounds: Rect.fromLTWH(50, 100, pageSize.width - 100, 25),
    )!;
    page = titleResult.page;
    currentY = titleResult.bounds.bottom + 6;

    // Date (left) and Mood (right)
    final formattedDate = _formatFullDate(entry.date);
    final moodOpt = _moodOptions.firstWhere((m) => m.id == entry.mood,
        orElse: () => _moodOptions[3]);

    page.graphics.drawString(
      _sanitizeForHelvetica(formattedDate),
      PdfStandardFont(PdfFontFamily.helvetica, 10),
      brush: PdfSolidBrush(PdfColor(100, 116, 139)), // Slate 500
      bounds: Rect.fromLTWH(50, currentY, 300, 15),
    );

    // Draw Mood Pill background
    final moodLabel = moodOpt.label; // Emojis removed to prevent PDF font crash
    final moodFont = PdfStandardFont(PdfFontFamily.helvetica, 9, style: PdfFontStyle.bold);
    final moodTextWidth = moodFont.measureString(moodLabel).width;
    
    final pillX = pageSize.width - 50 - moodTextWidth - 16;
    page.graphics.drawRectangle(
      bounds: Rect.fromLTWH(pillX, currentY - 2, moodTextWidth + 16, 17),
      brush: PdfSolidBrush(PdfColor(241, 245, 249)), // Slate 100
      pen: PdfPen(PdfColor(226, 232, 240), width: 1),
    );

    page.graphics.drawString(
      _sanitizeForHelvetica(moodLabel),
      moodFont,
      brush: PdfSolidBrush(PdfColor(71, 85, 105)), // Slate 600
      bounds: Rect.fromLTWH(pillX + 8, currentY + 1, moodTextWidth + 8, 15),
    );

    currentY += 28;

    // Small divider
    page.graphics.drawLine(
      PdfPen(PdfColor(241, 245, 249), width: 1),
      Offset(50, currentY),
      Offset(pageSize.width - 50, currentY),
    );

    currentY += 15;

    // 4. Gratitude Practice
    if (entry.gratitude.isNotEmpty) {
      ensureSpace(35);
      final headingElement = PdfTextElement(
        text: '3 THINGS I\'M GRATEFUL FOR TODAY',
        font: PdfStandardFont(PdfFontFamily.helvetica, 8, style: PdfFontStyle.bold),
        brush: PdfSolidBrush(PdfColor(20, 184, 166)), // Teal
      );
      final hr = headingElement.draw(
        page: page,
        bounds: Rect.fromLTWH(50, currentY, pageSize.width - 100, 15),
      )!;
      page = hr.page;
      currentY = hr.bounds.bottom + 6;

      for (var i = 0; i < entry.gratitude.length; i++) {
        ensureSpace(20);
        final itemText = '${i + 1}.   ${entry.gratitude[i]}';
        final textElement = PdfTextElement(
          text: _sanitizeForHelvetica(itemText),
          font: PdfStandardFont(PdfFontFamily.helvetica, 11),
          brush: PdfSolidBrush(PdfColor(51, 65, 85)), // Slate 700
        );
        final tr = textElement.draw(
          page: page,
          bounds: Rect.fromLTWH(50, currentY, pageSize.width - 100, pageSize.height - currentY - 50),
          format: PdfLayoutFormat(layoutType: PdfLayoutType.paginate),
        )!;
        page = tr.page;
        currentY = tr.bounds.bottom + 6;
      }
      currentY += 12;
    }

    // 5. Highlight of the Day (Blockquote style)
    if (entry.highlight.isNotEmpty) {
      ensureSpace(45);
      final headingElement = PdfTextElement(
        text: 'HIGHLIGHT OF THE DAY',
        font: PdfStandardFont(PdfFontFamily.helvetica, 8, style: PdfFontStyle.bold),
        brush: PdfSolidBrush(PdfColor(20, 184, 166)), // Teal
      );
      final hr = headingElement.draw(
        page: page,
        bounds: Rect.fromLTWH(50, currentY, pageSize.width - 100, 15),
      )!;
      page = hr.page;
      currentY = hr.bounds.bottom + 6;

      ensureSpace(30);
      final barPen = PdfPen(PdfColor(20, 184, 166), width: 3);
      final textElement = PdfTextElement(
        text: _sanitizeForHelvetica(entry.highlight),
        font: PdfStandardFont(PdfFontFamily.helvetica, 11, style: PdfFontStyle.italic),
        brush: PdfSolidBrush(PdfColor(51, 65, 85)),
      );
      final tr = textElement.draw(
        page: page,
        bounds: Rect.fromLTWH(62, currentY, pageSize.width - 120, pageSize.height - currentY - 50),
        format: PdfLayoutFormat(layoutType: PdfLayoutType.paginate),
      )!;

      // Draw vertical border along blockquote
      if (tr.page == page) {
        tr.page.graphics.drawLine(
          barPen,
          Offset(53, currentY),
          Offset(53, tr.bounds.bottom),
        );
      } else {
        page.graphics.drawLine(
          barPen,
          Offset(53, currentY),
          Offset(53, pageSize.height - 50),
        );
        tr.page.graphics.drawLine(
          barPen,
          Offset(53, 50),
          Offset(53, tr.bounds.bottom),
        );
      }

      page = tr.page;
      currentY = tr.bounds.bottom + 20;
    }

    // 6. Challenge & Learning
    if (entry.challenge.isNotEmpty) {
      ensureSpace(45);
      final headingElement = PdfTextElement(
        text: 'CHALLENGE & LEARNING',
        font: PdfStandardFont(PdfFontFamily.helvetica, 8, style: PdfFontStyle.bold),
        brush: PdfSolidBrush(PdfColor(139, 92, 246)), // Purple
      );
      final hr = headingElement.draw(
        page: page,
        bounds: Rect.fromLTWH(50, currentY, pageSize.width - 100, 15),
      )!;
      page = hr.page;
      currentY = hr.bounds.bottom + 6;

      ensureSpace(30);
      final barPen = PdfPen(PdfColor(139, 92, 246), width: 3);
      final textElement = PdfTextElement(
        text: _sanitizeForHelvetica(entry.challenge),
        font: PdfStandardFont(PdfFontFamily.helvetica, 11),
        brush: PdfSolidBrush(PdfColor(51, 65, 85)),
      );
      final tr = textElement.draw(
        page: page,
        bounds: Rect.fromLTWH(62, currentY, pageSize.width - 120, pageSize.height - currentY - 50),
        format: PdfLayoutFormat(layoutType: PdfLayoutType.paginate),
      )!;

      if (tr.page == page) {
        tr.page.graphics.drawLine(
          barPen,
          Offset(53, currentY),
          Offset(53, tr.bounds.bottom),
        );
      } else {
        page.graphics.drawLine(
          barPen,
          Offset(53, currentY),
          Offset(53, pageSize.height - 50),
        );
        tr.page.graphics.drawLine(
          barPen,
          Offset(53, 50),
          Offset(53, tr.bounds.bottom),
        );
      }

      page = tr.page;
      currentY = tr.bounds.bottom + 20;
    }

    // 7. Reflection Notes
    if (entry.body.isNotEmpty) {
      ensureSpace(45);
      final headingElement = PdfTextElement(
        text: 'REFLECTION & NOTES',
        font: PdfStandardFont(PdfFontFamily.helvetica, 8, style: PdfFontStyle.bold),
        brush: PdfSolidBrush(PdfColor(20, 184, 166)), // Teal
      );
      final hr = headingElement.draw(
        page: page,
        bounds: Rect.fromLTWH(50, currentY, pageSize.width - 100, 15),
      )!;
      page = hr.page;
      currentY = hr.bounds.bottom + 6;

      ensureSpace(40);
      final textElement = PdfTextElement(
        text: _sanitizeForHelvetica(entry.body),
        font: PdfStandardFont(PdfFontFamily.helvetica, 11),
        brush: PdfSolidBrush(PdfColor(15, 23, 42)), // Slate 900
        format: PdfStringFormat(lineSpacing: 3),
      );
      final tr = textElement.draw(
        page: page,
        bounds: Rect.fromLTWH(50, currentY, pageSize.width - 100, pageSize.height - currentY - 50),
        format: PdfLayoutFormat(layoutType: PdfLayoutType.paginate),
      )!;

      page = tr.page;
      currentY = tr.bounds.bottom + 20;
    }

    // 8. Tags
    if (entry.tags.isNotEmpty) {
      ensureSpace(30);
      final tagsText = entry.tags.map((t) => '#$t').join('   ');
      final textElement = PdfTextElement(
        text: _sanitizeForHelvetica(tagsText),
        font: PdfStandardFont(PdfFontFamily.helvetica, 9, style: PdfFontStyle.italic),
        brush: PdfSolidBrush(PdfColor(100, 116, 139)), // Slate 500
      );
      final tr = textElement.draw(
        page: page,
        bounds: Rect.fromLTWH(50, currentY, pageSize.width - 100, pageSize.height - currentY - 50),
        format: PdfLayoutFormat(layoutType: PdfLayoutType.paginate),
      )!;
      page = tr.page;
    }
  }

  void _addPageNumbers(PdfDocument document) {
    for (int i = 0; i < document.pages.count; i++) {
      final page = document.pages[i];
      final pageSize = page.getClientSize();

      // Divider
      page.graphics.drawLine(
        PdfPen(PdfColor(241, 245, 249), width: 0.75),
        Offset(50, pageSize.height - 35),
        Offset(pageSize.width - 50, pageSize.height - 35),
      );

      // Page numbers (right)
      page.graphics.drawString(
        'Page ${i + 1} of ${document.pages.count}',
        PdfStandardFont(PdfFontFamily.helvetica, 8),
        brush: PdfSolidBrush(PdfColor(148, 163, 184)), // Slate 400
        bounds: Rect.fromLTWH(pageSize.width - 150, pageSize.height - 28, 100, 15),
        format: PdfStringFormat(alignment: PdfTextAlignment.right),
      );

      // Brand tag (left)
      page.graphics.drawString(
        'Created with Fokus Forge Daily Journal',
        PdfStandardFont(PdfFontFamily.helvetica, 8),
        brush: PdfSolidBrush(PdfColor(148, 163, 184)),
        bounds: Rect.fromLTWH(50, pageSize.height - 28, 250, 15),
      );
    }
  }

  // ── Helpers ──

  String _formatFullDate(DateTime dt) {
    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return '${weekdays[dt.weekday - 1]}, ${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  String _formatShortDate(DateTime dt) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  String _sanitizeForHelvetica(String text) {
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      final char = text[i];
      final code = char.codeUnitAt(0);
      if (code == 10 || code == 13 || code == 9) {
        buffer.write(char);
      } else if (code >= 32 && code <= 126) {
        buffer.write(char);
      } else if (code >= 160 && code <= 255) {
        buffer.write(char);
      } else {
        if (char == '’' || char == '‘') {
          buffer.write("'");
        } else if (char == '”' || char == '“') {
          buffer.write('"');
        } else if (char == '–' || char == '—') {
          buffer.write('-');
        } else if (char == '…') {
          buffer.write('...');
        }
      }
    }
    return buffer.toString();
  }

  // ── Build Method ──

  @override
  Widget build(BuildContext context) {
    final tokens = FocusOsTheme.of(context);
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 900;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: motion.PremiumEnterTransition(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Toolbar / Header ──
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
                      'Daily Journal',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: tokens.textPrimary,
                      ),
                    ),
                    Text(
                      'Reflect on your day, log your mood, practice gratitude, and capture memories.',
                      style: TextStyle(fontSize: 12, color: tokens.textSecondary),
                    ),
                  ],
                ),
                const Spacer(),
                if (_entries.isNotEmpty) ...[
                  GestureDetector(
                    onTap: () => _showExportDialog(tokens),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: tokens.surfaceAlt,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: tokens.borderSubtle),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.ios_share_rounded, size: 14, color: tokens.textPrimary),
                          const SizedBox(width: 6),
                          Text('Export Journals', style: TextStyle(color: tokens.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                PremiumButton(
                  variant: PremiumButtonVariant.primary,
                  icon: Icons.add_rounded,
                  label: 'Write Entry',
                  onPressed: _startNewEntry,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Main Content Area ──
            Expanded(
              child: isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Panel: Entry List
                        SizedBox(
                          width: 360,
                          child: _buildListPanel(tokens),
                        ),
                        const SizedBox(width: 24),
                        // Right Panel: Detail / Form View
                        Expanded(
                          child: _buildDetailOrFormPanel(tokens),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        // If editing or selected entry exists, show detailed view
                        if (_isEditing || _selectedEntry != null)
                          Expanded(
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    TextButton.icon(
                                      onPressed: () {
                                        setState(() {
                                          _isEditing = false;
                                          _selectedEntry = null;
                                        });
                                      },
                                      icon: Icon(Icons.keyboard_arrow_left_rounded, color: tokens.accent),
                                      label: Text('Back to List', style: TextStyle(color: tokens.accent)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: _buildDetailOrFormPanel(tokens),
                                ),
                              ],
                            ),
                          )
                        else
                          Expanded(
                            child: _buildListPanel(tokens),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Left/Main List Panel Widget ──

  Widget _buildListPanel(ThemeTokens tokens) {
    // Unique list of all tags present in entries
    final allTags = _entries.expand((e) => e.tags).map((t) => t.toLowerCase()).toSet().toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Box
          TextField(
            controller: _searchController,
            style: TextStyle(color: tokens.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search entries, tags, gratitude...',
              hintStyle: TextStyle(color: tokens.textMuted, fontSize: 13),
              prefixIcon: Icon(Icons.search_rounded, size: 18, color: tokens.textMuted),
              filled: true,
              fillColor: tokens.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              isDense: true,
              suffixIcon: _searchQuery.isNotEmpty
                  ? GestureDetector(
                      onTap: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                          _filterEntries();
                        });
                      },
                      child: Icon(Icons.clear_rounded, size: 16, color: tokens.textMuted),
                    )
                  : null,
            ),
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
                _filterEntries();
              });
            },
          ),
          const SizedBox(height: 12),

          // Mood filter buttons row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _filterMood = null;
                      _filterEntries();
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: _filterMood == null ? tokens.accent.withValues(alpha: 0.15) : tokens.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _filterMood == null ? tokens.accent.withValues(alpha: 0.3) : tokens.borderSubtle,
                      ),
                    ),
                    child: Text(
                      'All Moods',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: _filterMood == null ? FontWeight.bold : FontWeight.normal,
                        color: _filterMood == null ? tokens.textPrimary : tokens.textSecondary,
                      ),
                    ),
                  ),
                ),
                ..._moodOptions.map((mood) {
                  final isSelected = _filterMood == mood.id;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _filterMood = isSelected ? null : mood.id;
                        _filterEntries();
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? mood.color.withValues(alpha: 0.15) : tokens.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? mood.color.withValues(alpha: 0.4) : tokens.borderSubtle,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(mood.emoji, style: const TextStyle(fontSize: 12)),
                          const SizedBox(width: 4),
                          Text(
                            mood.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? tokens.textPrimary : tokens.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),

          // Tag Filter chips row (if any exist)
          if (allTags.isNotEmpty) ...[
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedTag = null;
                        _filterEntries();
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: _selectedTag == null ? tokens.accent.withValues(alpha: 0.1) : tokens.background,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _selectedTag == null ? tokens.accent.withValues(alpha: 0.2) : tokens.borderSubtle,
                        ),
                      ),
                      child: Text(
                        '#all-tags',
                        style: TextStyle(
                          fontSize: 10,
                          color: _selectedTag == null ? tokens.textPrimary : tokens.textMuted,
                        ),
                      ),
                    ),
                  ),
                  ...allTags.map((tag) {
                    final isSelected = _selectedTag?.toLowerCase() == tag;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedTag = isSelected ? null : tag;
                          _filterEntries();
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? tokens.accent.withValues(alpha: 0.1) : tokens.background,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isSelected ? tokens.accent.withValues(alpha: 0.3) : tokens.borderSubtle,
                          ),
                        ),
                        child: Text(
                          '#$tag',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            color: isSelected ? tokens.textPrimary : tokens.textMuted,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Entries List
          Expanded(
            child: _filteredEntries.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notes_rounded, size: 28, color: tokens.textMuted),
                        const SizedBox(height: 8),
                        Text(
                          'No entries found',
                          style: TextStyle(fontSize: 12, color: tokens.textSecondary),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: _filteredEntries.length,
                    itemBuilder: (context, index) {
                      final entry = _filteredEntries[index];
                      final isSelected = _selectedEntry?.id == entry.id;
                      final moodOpt = _moodOptions.firstWhere((m) => m.id == entry.mood,
                          orElse: () => _moodOptions[3]);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: PremiumCard(
                          padding: const EdgeInsets.all(12),
                          isActive: isSelected,
                          onTap: () {
                            setState(() {
                              _selectedEntry = entry;
                              _isEditing = false;
                            });
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    moodOpt.emoji,
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      entry.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: tokens.textPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              if (entry.body.isNotEmpty) ...[
                                Text(
                                  entry.body,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 11, color: tokens.textSecondary, height: 1.3),
                                ),
                                const SizedBox(height: 6),
                              ],
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatShortDate(entry.date),
                                    style: TextStyle(fontSize: 9, color: tokens.textMuted),
                                  ),
                                  if (entry.tags.isNotEmpty)
                                    Expanded(
                                      child: Align(
                                        alignment: Alignment.centerRight,
                                        child: SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: entry.tags.map((t) {
                                              return Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                margin: const EdgeInsets.only(left: 3),
                                                decoration: BoxDecoration(
                                                  color: tokens.background,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  '#$t',
                                                  style: TextStyle(fontSize: 8, color: tokens.textMuted),
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
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
    );
  }

  // ── Right/Detail or Form Panel Widget ──

  Widget _buildDetailOrFormPanel(ThemeTokens tokens) {
    if (_isEditing) {
      return _buildFormPanel(tokens);
    }

    if (_selectedEntry == null) {
      return Container(
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: tokens.borderSubtle),
        ),
        child: EmptyState(
          icon: Icons.edit_note_rounded,
          title: 'Start Journaling',
          subtitle: 'Create a sanctuary for your thoughts. Capture reflections, log moods, and remember what you are grateful for.',
          actionLabel: 'Write First Entry',
          onAction: _startNewEntry,
        ),
      );
    }

    final entry = _selectedEntry!;
    final moodOpt = _moodOptions.firstWhere((m) => m.id == entry.mood, orElse: () => _moodOptions[3]);

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row (Mood badge, date, actions)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Mood Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: moodOpt.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: moodOpt.color.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Text(moodOpt.emoji, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(
                      moodOpt.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: tokens.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Action Buttons
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'pdf') {
                    _exportEntryToPdf(entry);
                  } else {
                    _exportEntryToMarkdown(entry);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'pdf',
                    child: Row(
                      children: [
                        Icon(Icons.picture_as_pdf_rounded, size: 16, color: tokens.textPrimary),
                        const SizedBox(width: 8),
                        Text('Save as PDF', style: TextStyle(color: tokens.textPrimary, fontSize: 13)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'markdown',
                    child: Row(
                      children: [
                        Icon(Icons.copy_rounded, size: 16, color: tokens.textPrimary),
                        const SizedBox(width: 8),
                        Text('Copy Markdown', style: TextStyle(color: tokens.textPrimary, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Icon(Icons.share_rounded, size: 18, color: tokens.textSecondary),
                ),
              ),
              IconButton(
                tooltip: 'Edit Entry',
                icon: Icon(Icons.edit_outlined, size: 18, color: tokens.textSecondary),
                onPressed: () => _startEditing(entry),
              ),
              IconButton(
                tooltip: 'Delete Entry',
                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                onPressed: () => _deleteEntry(entry),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Date & Title
          Text(
            _formatFullDate(entry.date),
            style: TextStyle(fontSize: 12, color: tokens.textMuted, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            entry.title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: tokens.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 20),

          // Detailed Content in a scrollable view
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Gratitude Section
                  if (entry.gratitude.isNotEmpty) ...[
                    Text(
                      '3 Things I\'m Grateful For Today',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: tokens.accent, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 10),
                    Column(
                      children: entry.gratitude.map((item) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 2.0, right: 10.0),
                                child: Icon(Icons.favorite_rounded, size: 12, color: moodOpt.color),
                              ),
                              Expanded(
                                child: Text(
                                  item,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: tokens.textPrimary,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Highlight of the day
                  if (entry.highlight.isNotEmpty) ...[
                    Text(
                      'Highlight of the Day',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: tokens.accent, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: tokens.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: tokens.borderSubtle),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.star_rounded, size: 16, color: Colors.amber.shade600),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              entry.highlight,
                              style: TextStyle(
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                                color: tokens.textPrimary,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Challenge & Reflection
                  if (entry.challenge.isNotEmpty) ...[
                    Text(
                      'Challenge & Learning',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: tokens.accent, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: tokens.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: tokens.borderSubtle),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.psychology_rounded, size: 16, color: Color(0xFF8B5CF6)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              entry.challenge,
                              style: TextStyle(
                                fontSize: 13,
                                color: tokens.textPrimary,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Reflection / Notes / Freeform Text
                  if (entry.body.isNotEmpty) ...[
                    Text(
                      'Reflection & Notes',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: tokens.accent, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      entry.body,
                      style: TextStyle(
                        fontSize: 14,
                        color: tokens.textPrimary,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Tags Row
                  if (entry.tags.isNotEmpty) ...[
                    const Divider(height: 1),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: entry.tags.map((tag) {
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedTag = tag;
                              _filterEntries();
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: tokens.background,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: tokens.borderSubtle),
                            ),
                            child: Text(
                              '#$tag',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: tokens.textSecondary,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Edit/New Entry Form Panel Widget ──

  Widget _buildFormPanel(ThemeTokens tokens) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Form Title / Date row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isCreatingNew ? 'New Entry' : 'Edit Entry',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: tokens.textPrimary,
                ),
              ),
              // Date picker button
              GestureDetector(
                onTap: () async {
                  final chosen = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    builder: (ctx, child) {
                      return Theme(
                        data: Theme.of(ctx).copyWith(
                          colorScheme: ColorScheme.dark(
                            primary: tokens.accent,
                            onPrimary: Colors.white,
                            surface: tokens.surface,
                            onSurface: tokens.textPrimary,
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (chosen != null) {
                    setState(() {
                      _selectedDate = chosen;
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: tokens.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: tokens.borderSubtle),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 12, color: tokens.accent),
                      const SizedBox(width: 8),
                      Text(
                        _formatShortDate(_selectedDate),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: tokens.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // Scrollable inputs
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Mood Selector Label
                  Text(
                    'How are you feeling today?',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: tokens.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  // Mood Row selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: _moodOptions.map((mood) {
                      final isSelected = _selectedMood == mood.id;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedMood = mood.id;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected ? mood.color.withValues(alpha: 0.15) : Colors.transparent,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? mood.color.withValues(alpha: 0.4) : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Tooltip(
                            message: mood.label,
                            child: Text(
                              mood.emoji,
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Gratitude section
                  Text(
                    '3 Things You are Grateful For Today',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: tokens.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  _buildGratitudeField(1, _gratitudeController1, tokens),
                  const SizedBox(height: 8),
                  _buildGratitudeField(2, _gratitudeController2, tokens),
                  const SizedBox(height: 8),
                  _buildGratitudeField(3, _gratitudeController3, tokens),
                  const SizedBox(height: 20),

                  // Highlight of the day
                  Text(
                    'Highlight of the Day',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: tokens.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _highlightController,
                    hint: 'What is the absolute best thing that happened today?',
                    tokens: tokens,
                    icon: Icons.star_rounded,
                  ),
                  const SizedBox(height: 20),

                  // Challenge & learning
                  Text(
                    'Challenge faced & learnings',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: tokens.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _challengeController,
                    hint: 'Did you hit any roadblocks today? What did you learn?',
                    tokens: tokens,
                    icon: Icons.psychology_rounded,
                  ),
                  const SizedBox(height: 20),

                  // Journal Title
                  Text(
                    'Title (Optional)',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: tokens.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _titleController,
                    hint: 'Give this day a title...',
                    tokens: tokens,
                  ),
                  const SizedBox(height: 20),

                  // Freeform reflection / Body
                  Text(
                    'Reflection & Journal Notes',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: tokens.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _bodyController,
                    maxLines: null,
                    minLines: 8,
                    style: TextStyle(color: tokens.textPrimary, fontSize: 13, height: 1.5),
                    decoration: InputDecoration(
                      hintText: 'Unload your mind here. Write about your thoughts, feelings, plans, or whatever is on your mind...',
                      hintStyle: TextStyle(color: tokens.textMuted, fontSize: 13),
                      filled: true,
                      fillColor: tokens.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Tags
                  Text(
                    'Tags',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: tokens.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _tagsController,
                    hint: 'e.g. work, family, self-care, learning (comma separated)',
                    tokens: tokens,
                    icon: Icons.label_outline_rounded,
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // Save / Cancel Row
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              PremiumButton(
                variant: PremiumButtonVariant.ghost,
                label: 'Cancel',
                onPressed: _cancelEditing,
              ),
              const SizedBox(width: 12),
              PremiumButton(
                variant: PremiumButtonVariant.primary,
                label: _isCreatingNew ? 'Save Journal' : 'Update Journal',
                icon: Icons.check_rounded,
                onPressed: _saveEntry,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Form Input Helpers ──

  Widget _buildGratitudeField(int index, TextEditingController controller, ThemeTokens tokens) {
    return TextField(
      controller: controller,
      style: TextStyle(color: tokens.textPrimary, fontSize: 13),
      decoration: InputDecoration(
        hintText: 'Something you are grateful for ($index)...',
        hintStyle: TextStyle(color: tokens.textMuted, fontSize: 13),
        prefixIcon: Container(
          width: 32,
          alignment: Alignment.center,
          child: Text(
            '$index.',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: tokens.accent.withValues(alpha: 0.7),
            ),
          ),
        ),
        filled: true,
        fillColor: tokens.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        isDense: true,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required ThemeTokens tokens,
    IconData? icon,
  }) {
    return TextField(
      controller: controller,
      style: TextStyle(color: tokens.textPrimary, fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: tokens.textMuted, fontSize: 13),
        prefixIcon: icon != null ? Icon(icon, size: 16, color: tokens.textMuted) : null,
        filled: true,
        fillColor: tokens.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        isDense: true,
      ),
    );
  }
}

class _ExportDialog extends StatefulWidget {
  final ThemeTokens tokens;
  final List<JournalEntry> filteredEntries;
  final List<JournalEntry> allEntries;
  final Function(List<JournalEntry> entries, String format) onExport;

  const _ExportDialog({
    required this.tokens,
    required this.filteredEntries,
    required this.allEntries,
    required this.onExport,
  });

  @override
  State<_ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<_ExportDialog> {
  bool _customSelection = false;
  DateTimeRange? _dateRange;
  final Set<String> _selectedMoods = {};
  String _exportFormat = 'pdf'; // 'pdf' or 'markdown'

  String _formatShortDate(DateTime dt) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  String _formatDateRange(DateTimeRange? range) {
    if (range == null) return 'All Time';
    return '${_formatShortDate(range.start)} – ${_formatShortDate(range.end)}';
  }

  Widget _buildSelectorCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
    required ThemeTokens tokens,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? tokens.accent.withValues(alpha: 0.08) : tokens.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? tokens.accent : tokens.borderSubtle,
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: selected ? tokens.accent : tokens.textSecondary,
              size: 20,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: tokens.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                color: tokens.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatChip({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
    required ThemeTokens tokens,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? tokens.accent.withValues(alpha: 0.08) : tokens.surfaceAlt,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? tokens.accent : tokens.borderSubtle,
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: selected ? tokens.accent : tokens.textSecondary,
              size: 14,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: tokens.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    
    // Calculate matching entries
    final List<JournalEntry> matchingEntries;
    if (!_customSelection) {
      matchingEntries = widget.filteredEntries;
    } else {
      matchingEntries = widget.allEntries.where((entry) {
        if (_dateRange != null) {
          final entryDate = DateTime(entry.date.year, entry.date.month, entry.date.day);
          final startDate = DateTime(_dateRange!.start.year, _dateRange!.start.month, _dateRange!.start.day);
          final endDate = DateTime(_dateRange!.end.year, _dateRange!.end.month, _dateRange!.end.day);
          if (entryDate.isBefore(startDate) || entryDate.isAfter(endDate)) {
            return false;
          }
        }
        if (_selectedMoods.isNotEmpty && !_selectedMoods.contains(entry.mood)) {
          return false;
        }
        return true;
      }).toList();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Row(
          children: [
            Icon(Icons.ios_share_rounded, color: tokens.accent, size: 20),
            const SizedBox(width: 8),
            Text(
              'Export Journals',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: tokens.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Segmented selector
        Row(
          children: [
            Expanded(
              child: _buildSelectorCard(
                title: 'Filtered UI List',
                subtitle: '${widget.filteredEntries.length} entries',
                icon: Icons.filter_list_rounded,
                selected: !_customSelection,
                onTap: () => setState(() => _customSelection = false),
                tokens: tokens,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSelectorCard(
                title: 'Custom Select',
                subtitle: 'Choose range & moods',
                icon: Icons.tune_rounded,
                selected: _customSelection,
                onTap: () => setState(() => _customSelection = true),
                tokens: tokens,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Custom config controls
        if (_customSelection) ...[
          // Date Range picker Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Date Range',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: tokens.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDateRange(_dateRange),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () async {
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    initialDateRange: _dateRange,
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: ColorScheme.dark(
                            primary: tokens.accent,
                            onPrimary: Colors.white,
                            surface: tokens.surface,
                            onSurface: tokens.textPrimary,
                          ),
                          dialogTheme: DialogThemeData(
                            backgroundColor: tokens.surface,
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null) {
                    setState(() {
                      _dateRange = picked;
                    });
                  }
                },
                icon: const Icon(Icons.calendar_today_rounded, size: 14),
                label: const Text('Change', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: tokens.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Mood multi-selector
          Text(
            'Filter by Moods',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: tokens.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _moodOptions.map((mood) {
              final isSelected = _selectedMoods.contains(mood.id);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedMoods.remove(mood.id);
                    } else {
                      _selectedMoods.add(mood.id);
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? mood.color.withValues(alpha: 0.18) 
                        : tokens.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected 
                          ? mood.color.withValues(alpha: 0.5) 
                          : tokens.borderSubtle,
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(mood.emoji, style: const TextStyle(fontSize: 13)),
                      const SizedBox(width: 4),
                      Text(
                        mood.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? tokens.textPrimary : tokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
        ],

        // Export Format
        Text(
          'Export Format',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: tokens.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildFormatChip(
                label: 'PDF Document (.pdf)',
                icon: Icons.picture_as_pdf_rounded,
                selected: _exportFormat == 'pdf',
                onTap: () => setState(() => _exportFormat = 'pdf'),
                tokens: tokens,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildFormatChip(
                label: 'Markdown Text (.md)',
                icon: Icons.copy_rounded,
                selected: _exportFormat == 'markdown',
                onTap: () => setState(() => _exportFormat = 'markdown'),
                tokens: tokens,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Action buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: tokens.textSecondary,
              ),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: matchingEntries.isEmpty
                  ? null
                  : () {
                      Navigator.of(context).pop();
                      widget.onExport(matchingEntries, _exportFormat);
                    },
              icon: Icon(
                _exportFormat == 'pdf' ? Icons.picture_as_pdf_rounded : Icons.copy_rounded,
                size: 14,
              ),
              label: Text('Export (${matchingEntries.length})'),
              style: ElevatedButton.styleFrom(
                backgroundColor: tokens.accent,
                foregroundColor: Colors.white,
                disabledBackgroundColor: tokens.borderSubtle,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
