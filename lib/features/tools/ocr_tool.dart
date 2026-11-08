import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';

import '../../shared/theme.dart';
import '../../shared/motion.dart' as motion;
import '../../shared/widgets/premium_button.dart';
import '../../services/ocr_service.dart';

class QuickOcrPage extends StatefulWidget {
  final VoidCallback onBack;

  const QuickOcrPage({super.key, required this.onBack});

  @override
  State<QuickOcrPage> createState() => _QuickOcrPageState();
}

class _OcrSample {
  final String name;
  final String description;
  final String imagePlaceholder;
  final String extractedText;

  _OcrSample({
    required this.name,
    required this.description,
    required this.imagePlaceholder,
    required this.extractedText,
  });
}

class _QuickOcrPageState extends State<QuickOcrPage> {
  bool _isScanning = false;
  bool _isDragging = false;
  double _scanProgress = 0.0;
  String _extractedText = '';
  String? _selectedFilePath;
  _OcrSample? _selectedSample;

  final List<_OcrSample> _samples = [
    _OcrSample(
      name: 'Meeting Whiteboard',
      description: 'Handwritten brainstorming layout',
      imagePlaceholder: '💡 Brainstorm: Fokus features\n1. Minimal design & glassmorphism\n2. Local-first storage (no sync APIs)\n3. Custom timers & analytics dashboard\n4. CFA Financial calculators (TVM, NPV, IRR)',
      extractedText: 'Brainstorm: Fokus features\n1. Minimal design & glassmorphism\n2. Local-first storage (no sync APIs)\n3. Custom timers & analytics dashboard\n4. CFA Financial calculators (TVM, NPV, IRR)',
    ),
    _OcrSample(
      name: 'Book Page (Productivity)',
      description: 'Standard textbook paragraph printed text',
      imagePlaceholder: 'Chapter 4: The Deep Work Hypothesis\nDeep work is the ability to focus without distraction on a cognitively demanding task. It is a skill that allows you to quickly master complicated information and produce better results in less time. Deep work will make you better at what you do and provide the sense of true fulfillment that comes from craftsmanship.',
      extractedText: 'Chapter 4: The Deep Work Hypothesis\nDeep work is the ability to focus without distraction on a cognitively demanding task. It is a skill that allows you to quickly master complicated information and produce better results in less time. Deep work will make you better at what you do and provide the sense of true fulfillment that comes from craftsmanship.',
    ),
    _OcrSample(
      name: 'Sticky Note Receipt',
      description: 'Receipt numbers & quick ideas',
      imagePlaceholder: 'Focus Labs Inc.\n---------------------------\nID: 948302-XC\nTotal: USD 120.45\nStatus: Paid (Offline)\n---------------------------',
      extractedText: 'Focus Labs Inc.\n---------------------------\nID: 948302-XC\nTotal: USD 120.45\nStatus: Paid (Offline)\n---------------------------',
    ),
  ];

  // Runs OCR on a real local file (image or document)
  void _runOcrFromFile(String filePath) async {
    setState(() {
      _isScanning = true;
      _scanProgress = 0.0;
      _extractedText = '';
      _selectedFilePath = filePath;
      _selectedSample = null;
    });

    // Simulate progress bar movement for modern feel
    for (double i = 0.1; i <= 0.4; i += 0.1) {
      await Future.delayed(const Duration(milliseconds: 60));
      if (!mounted) return;
      setState(() {
        _scanProgress = i;
      });
    }

    try {
      final text = await OcrService.processFile(filePath);
      
      // Update progress closer to complete
      if (mounted) {
        setState(() {
          _scanProgress = 0.8;
        });
      }
      await Future.delayed(const Duration(milliseconds: 100));

      if (mounted) {
        setState(() {
          _isScanning = false;
          _scanProgress = 1.0;
          _extractedText = text;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _scanProgress = 1.0;
          _extractedText = 'OCR process encountered an error:\n$e';
        });
      }
    }
  }

  // Browse files from filesystem
  Future<void> _browseFiles() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp', 'bmp', 'pdf', 'txt', 'md'],
      );
      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        _runOcrFromFile(path);
      }
    } catch (e) {
      _showError('Failed to select file: $e');
    }
  }

  // Paste image from clipboard
  Future<void> _pasteScreenshot() async {
    try {
      final bytes = await Pasteboard.image;
      if (bytes != null) {
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/ocr_clipboard_${DateTime.now().millisecondsSinceEpoch}.png');
        await tempFile.writeAsBytes(bytes);
        _runOcrFromFile(tempFile.path);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Image pasted from clipboard successfully!'),
            backgroundColor: FocusOsTheme.of(context).accent,
            duration: const Duration(seconds: 1),
          ),
        );
      } else {
        _showError('No image found in clipboard. Copy or take a screenshot of an image first.');
      }
    } catch (e) {
      _showError('Failed to read image from clipboard: $e');
    }
  }

  // Run a local sample file simulation
  void _runSample(_OcrSample sample) async {
    setState(() {
      _selectedSample = sample;
      _isScanning = true;
      _scanProgress = 0.0;
      _extractedText = '';
      _selectedFilePath = null;
    });

    for (double i = 0.2; i <= 0.8; i += 0.2) {
      await Future.delayed(const Duration(milliseconds: 80));
      if (!mounted) return;
      setState(() {
        _scanProgress = i;
      });
    }

    if (mounted) {
      setState(() {
        _isScanning = false;
        _scanProgress = 1.0;
        _extractedText = sample.extractedText;
      });
    }
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _extractedText));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Text copied to clipboard'),
        backgroundColor: FocusOsTheme.of(context).surfaceAlt,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = FocusOsTheme.of(context);

    // Get display name for file path
    String getDisplayFileName() {
      if (_selectedFilePath == null) return '';
      final file = File(_selectedFilePath!);
      return file.path.split(Platform.pathSeparator).last;
    }

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
                      'Quick OCR & Document Reader',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: tokens.textPrimary),
                    ),
                    Text(
                      'Extract text locally from images, documents, PDFs, or clipboard.',
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
                  // Left panel: Dropzone, clipboard paste, and samples
                  Expanded(
                    flex: 1,
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Dropzone Area with drag-and-drop listening
                          DropTarget(
                            onDragEntered: (detail) {
                              setState(() => _isDragging = true);
                            },
                            onDragExited: (detail) {
                              setState(() => _isDragging = false);
                            },
                            onDragDone: (detail) {
                              setState(() => _isDragging = false);
                              if (detail.files.isNotEmpty) {
                                _runOcrFromFile(detail.files.first.path);
                              }
                            },
                            child: GestureDetector(
                              onTap: _browseFiles,
                              child: Container(
                                height: 180,
                                decoration: BoxDecoration(
                                  color: _isDragging 
                                      ? tokens.accent.withValues(alpha: 0.15) 
                                      : tokens.surfaceAlt.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: _isDragging ? tokens.accent : tokens.borderMedium,
                                    style: BorderStyle.solid,
                                    width: 1.5,
                                  ),
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        _isDragging ? Icons.file_download_outlined : Icons.upload_file_rounded,
                                        size: 36,
                                        color: tokens.accent,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        _selectedFilePath != null
                                            ? 'Loaded: ${getDisplayFileName()}'
                                            : _isDragging
                                                ? 'Drop here!'
                                                : 'Drag & Drop files or Click to Browse',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: tokens.textPrimary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _selectedFilePath != null
                                            ? 'Click to choose a different document'
                                            : 'Supports PNG, JPG, PDF, TXT, MD',
                                        style: TextStyle(fontSize: 10, color: tokens.textMuted),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Paste from screenshot button
                          Row(
                            children: [
                              Expanded(
                                child: PremiumButton(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Icon(Icons.assignment_rounded, color: Colors.white, size: 14),
                                      SizedBox(width: 8),
                                      Text('Paste Image from Clipboard', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  onTap: _pasteScreenshot,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Sample selector
                          Text('Or Select a Local Sample:', style: TextStyle(fontSize: 12, color: tokens.textSecondary, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 10),
                          ..._samples.map((sample) {
                            final active = _selectedSample == sample;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: GestureDetector(
                                onTap: () => _runSample(sample),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: active ? tokens.accent.withValues(alpha: 0.12) : tokens.surface,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: active ? tokens.accent : tokens.borderSubtle),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.image_search_rounded, size: 16, color: active ? tokens.accent : tokens.textSecondary),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(sample.name, style: TextStyle(fontSize: 11, color: tokens.textPrimary, fontWeight: FontWeight.bold)),
                                            Text(sample.description, style: TextStyle(fontSize: 9, color: tokens.textMuted)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 24),

                  // Right panel: Scan progress & OCR Results
                  Expanded(
                    flex: 1,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: tokens.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: tokens.borderSubtle),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.text_fields_rounded, size: 16, color: tokens.accent),
                              const SizedBox(width: 8),
                              Text('Extracted Text', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: tokens.textPrimary)),
                              const Spacer(),
                              if (_extractedText.isNotEmpty && !_isScanning)
                                GestureDetector(
                                  onTap: _copyToClipboard,
                                  child: Icon(Icons.copy_rounded, size: 16, color: tokens.textSecondary),
                                ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Expanded(
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: tokens.background,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: _isScanning
                                  ? Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const CircularProgressIndicator(strokeWidth: 2),
                                          const SizedBox(height: 14),
                                          Text('Reading document local-first...', style: TextStyle(fontSize: 11, color: tokens.textSecondary)),
                                          const SizedBox(height: 4),
                                          Text('${(_scanProgress * 100).toInt()}% processed', style: TextStyle(fontSize: 10, color: tokens.textMuted)),
                                        ],
                                      ),
                                    )
                                  : _extractedText.isEmpty
                                      ? Center(
                                          child: Text('Provide an image or document to extract text', style: TextStyle(fontSize: 11, color: tokens.textMuted)),
                                        )
                                      : SingleChildScrollView(
                                          physics: const BouncingScrollPhysics(),
                                          child: Text(
                                            _extractedText,
                                            style: TextStyle(fontSize: 12, color: tokens.textPrimary, height: 1.5, fontFamily: 'monospace'),
                                          ),
                                        ),
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
