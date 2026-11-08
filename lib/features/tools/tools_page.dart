import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/providers.dart';
import '../../shared/motion.dart' as motion;
import '../../shared/theme.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/premium_card.dart';
import '../../shared/widgets/premium_button.dart';
import '../brain_dump/brain_dump_page.dart';
import '../../models/quick_capture_item.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pasteboard/pasteboard.dart';
import 'tool_category_view.dart';
import 'ocr_tool.dart';
import 'storage_toolkit_tool.dart';
import 'whiteboard_page.dart';
import 'sip_calculator.dart';
import 'emi_calculator.dart';
import 'compound_interest_calculator.dart';
import 'inflation_calculator_tool.dart';
import 'portfolio_tracker_tool.dart';
import 'subscription_tracker_tool.dart';
import 'net_worth_timeline_tool.dart';
import 'gods_wish_tool.dart';
import 'not_feeling_today_tool.dart';
import 'breathing_timer_tool.dart';
import 'daily_journal_tool.dart';
import 'debt_calculator_tool.dart';

class ToolCategory {
  final String id;
  final String title;
  final String description;
  final IconData icon;

  const ToolCategory({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
  });
}

const List<ToolCategory> _categories = [
  ToolCategory(
    id: 'productivity',
    title: 'Productivity & Capture',
    description: 'Organize ideas, capture content, and track tasks offline',
    icon: Icons.edit_note_rounded,
  ),
  ToolCategory(
    id: 'personal_finance',
    title: 'Personal Finances',
    description: 'Track net worth, active portfolios, and subscriptions',
    icon: Icons.wallet_rounded,
  ),
  ToolCategory(
    id: 'calculators',
    title: 'Financial Calculators',
    description: 'Calculate EMI, compounding SIPs, and inflation impact',
    icon: Icons.calculate_rounded,
  ),
  ToolCategory(
    id: 'mindfulness',
    title: 'Mindfulness & Clarity',
    description: 'Clear your mind, breathe, and resolve dilemmas',
    icon: Icons.spa_rounded,
  ),
];

class ToolsPage extends ConsumerStatefulWidget {
  const ToolsPage({super.key});

  @override
  ConsumerState<ToolsPage> createState() => _ToolsPageState();
}

class _ToolsPageState extends ConsumerState<ToolsPage> {
  // Active tool (null = main tools page)
  String? _activeTool;

  /// All tool definitions across the app.
  static const List<ToolItem> _allTools = [
    ToolItem(
      id: 'quick_capture',
      title: 'Quick Capture',
      description: 'Capture tasks, links, screenshots, and quick ideas instantly.',
      icon: Icons.bolt_rounded,
      color: Color(0xFFEAB308), // Amber/Yellow
      pageBuilder: _buildQuickCapture,
      category: 'productivity',
    ),
    ToolItem(
      id: 'brain_dump',
      title: 'Brain Dump',
      description: 'Unload thoughts, clear mental clutter, and reflect freely.',
      icon: Icons.psychology_rounded,
      color: Color(0xFF8B5CF6), // Purple/Indigo
      pageBuilder: _buildBrainDump,
      category: 'productivity',
    ),
    ToolItem(
      id: 'whiteboard',
      title: 'Whiteboard',
      description: 'Sketch diagrams, draw shapes, take notes — like Excalidraw, offline.',
      icon: Icons.draw_rounded,
      color: Color(0xFF1971C2), // Excalidraw Blue
      pageBuilder: _buildWhiteboard,
      category: 'productivity',
    ),
    ToolItem(
      id: 'quick_ocr',
      title: 'Quick OCR',
      description: 'Extract text instantly from screenshots, images, PDFs, and notes.',
      icon: Icons.text_fields_rounded,
      color: Color(0xFFEAB308), // Amber/Yellow
      pageBuilder: _buildQuickOcr,
      category: 'productivity',
    ),
    ToolItem(
      id: 'storage_toolkit',
      title: 'Storage Toolkit',
      description: 'Analyze storage, clean temporary files, find duplicates, and organize downloads locally.',
      icon: Icons.storage_rounded,
      color: Color(0xFF6366F1), // Indigo
      pageBuilder: _buildStorageToolkit,
      category: 'productivity',
    ),
    ToolItem(
      id: 'sip_calculator',
      title: 'SIP Calculator',
      description: 'Calculate growth of monthly mutual fund investments with compounding returns.',
      icon: Icons.trending_up_rounded,
      color: Color(0xFF3B82F6), // Blue
      pageBuilder: _buildSipCalculator,
      category: 'calculators',
    ),
    ToolItem(
      id: 'emi_calculator',
      title: 'EMI Calculator',
      description: 'Calculate loan monthly repayments, interest, and total payable amount.',
      icon: Icons.account_balance_rounded,
      color: Color(0xFF8B5CF6), // Purple
      pageBuilder: _buildEmiCalculator,
      category: 'calculators',
    ),
    ToolItem(
      id: 'compound_interest_calculator',
      title: 'Compound Interest Calculator',
      description: 'Calculate initial principal growth with compound interest and recurring contributions.',
      icon: Icons.monetization_on_rounded,
      color: Color(0xFFF59E0B), // Amber
      pageBuilder: _buildCompoundInterestCalculator,
      category: 'calculators',
    ),
    ToolItem(
      id: 'inflation_calculator',
      title: 'Inflation Calculator',
      description: 'See how inflation erodes your purchasing power over time.',
      icon: Icons.local_fire_department_rounded,
      color: Color(0xFFEF4444), // Red
      pageBuilder: _buildInflationCalculator,
      category: 'calculators',
    ),
    ToolItem(
      id: 'debt_calculator',
      title: 'Debt Calculator',
      description: 'Analyze payoff times, step-up accelerated payoffs, and project long-term interest savings.',
      icon: Icons.money_off_rounded,
      color: Color(0xFFEF4444), // Red
      pageBuilder: _buildDebtCalculator,
      category: 'calculators',
    ),
    ToolItem(
      id: 'portfolio_tracker',
      title: 'Portfolio Tracker',
      description: 'Track your investments, cash positions, and asset allocation dynamically.',
      icon: Icons.donut_large_rounded,
      color: Color(0xFF10B981), // Emerald Green
      pageBuilder: _buildPortfolioTracker,
      category: 'personal_finance',
    ),
    ToolItem(
      id: 'subscription_tracker',
      title: 'Subscription Tracker',
      description: 'Track recurring expenses and upcoming renewals.',
      icon: Icons.subscriptions_rounded,
      color: Color(0xFFEC4899), // Pink
      pageBuilder: _buildSubscriptionTracker,
      category: 'personal_finance',
    ),
    ToolItem(
      id: 'net_worth_timeline',
      title: 'Net Worth Timeline',
      description: 'Track your assets, liabilities, and net worth over time.',
      icon: Icons.timeline_rounded,
      color: Color(0xFF14B8A6), // Teal
      pageBuilder: _buildNetWorthTimeline,
      category: 'personal_finance',
    ),
    ToolItem(
      id: 'gods_wish',
      title: "God's Wish",
      description: "Stuck in a dilemma? Input your options and let divine randomness make the decision.",
      icon: Icons.auto_awesome_rounded,
      color: Color(0xFF8B5CF6), // Deep Purple
      pageBuilder: _buildGodsWish,
      category: 'mindfulness',
    ),
    ToolItem(
      id: 'not_feeling_today',
      title: "Not Feeling Today?",
      description: "Need a spark of motivation? Explore 100 high-power quotes in clean minimalist themes.",
      icon: Icons.emoji_objects_rounded,
      color: Color(0xFFF59E0B), // Warm Amber/Gold
      pageBuilder: _buildNotFeelingToday,
      category: 'mindfulness',
    ),
    ToolItem(
      id: 'breathing_timer',
      title: 'Breathing Timer',
      description: 'Guided breathing exercises with animated visual guidance for calm and fokus.',
      icon: Icons.air_rounded,
      color: Color(0xFF6366F1), // Indigo
      pageBuilder: _buildBreathingTimer,
      category: 'mindfulness',
    ),
    ToolItem(
      id: 'daily_journal',
      title: 'Daily Journal',
      description: 'Reflect on your day, track your mood, log gratitude, and keep memories.',
      icon: Icons.edit_note_rounded,
      color: Color(0xFF14B8A6), // Teal
      pageBuilder: _buildDailyJournal,
      category: 'productivity',
    ),
  ];

  // ── Static page builders ──

  static Widget _buildQuickCapture(VoidCallback onBack) {
    return _QuickCaptureView(onBack: onBack);
  }

  static Widget _buildBrainDump(VoidCallback onBack) {
    return BrainDumpWorkspace(onBack: onBack);
  }

  static Widget _buildWhiteboard(VoidCallback onBack) {
    return WhiteboardPage(onBack: onBack);
  }

  static Widget _buildQuickOcr(VoidCallback onBack) {
    return QuickOcrPage(onBack: onBack);
  }

  static Widget _buildStorageToolkit(VoidCallback onBack) {
    return StorageToolkitPage(onBack: onBack);
  }

  static Widget _buildSipCalculator(VoidCallback onBack) {
    return SipCalculatorPage(onBack: onBack);
  }

  static Widget _buildEmiCalculator(VoidCallback onBack) {
    return EmiCalculatorPage(onBack: onBack);
  }

  static Widget _buildCompoundInterestCalculator(VoidCallback onBack) {
    return CompoundInterestCalculatorPage(onBack: onBack);
  }

  static Widget _buildInflationCalculator(VoidCallback onBack) {
    return InflationCalculatorPage(onBack: onBack);
  }



  static Widget _buildPortfolioTracker(VoidCallback onBack) {
    return PortfolioTrackerPage(onBack: onBack);
  }

  static Widget _buildSubscriptionTracker(VoidCallback onBack) {
    return SubscriptionTrackerPage(onBack: onBack);
  }

  static Widget _buildNetWorthTimeline(VoidCallback onBack) {
    return NetWorthTimelinePage(onBack: onBack);
  }

  static Widget _buildGodsWish(VoidCallback onBack) {
    return GodsWishPage(onBack: onBack);
  }

  static Widget _buildNotFeelingToday(VoidCallback onBack) {
    return NotFeelingTodayPage(onBack: onBack);
  }

  static Widget _buildBreathingTimer(VoidCallback onBack) {
    return BreathingTimerPage(onBack: onBack);
  }

  static Widget _buildDailyJournal(VoidCallback onBack) {
    return DailyJournalPage(onBack: onBack);
  }

  static Widget _buildDebtCalculator(VoidCallback onBack) {
    return DebtCalculatorPage(onBack: onBack);
  }

  @override
  Widget build(BuildContext context) {
    // If a tool is active, show its page directly
    if (_activeTool != null) {
      for (final tool in _allTools) {
        if (tool.id == _activeTool) {
          return tool.pageBuilder(() => setState(() => _activeTool = null));
        }
      }
    }

    final tokens = FocusOsTheme.of(context);

    return motion.PremiumEnterTransition(
      duration: motion.PremiumDurations.pageTransition,
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tools',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Boost your productivity with specialized workflow tools',
                  style: TextStyle(fontSize: 13, color: tokens.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // ── Categorized Tool Grid ──
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _categories.map((category) {
                      final categoryTools = _allTools.where((t) => t.category == category.id).toList();
                      if (categoryTools.isEmpty) return const SizedBox.shrink();

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 40.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Category Header
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Icon(
                                  category.icon,
                                  size: 18,
                                  color: tokens.accent,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  category.title,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: tokens.textPrimary,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Container(
                                    height: 1,
                                    color: tokens.borderSubtle,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              category.description,
                              style: TextStyle(
                                fontSize: 11,
                                color: tokens.textMuted,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Cards Wrap Grid
                            Wrap(
                              spacing: 20,
                              runSpacing: 20,
                              children: categoryTools.map((tool) {
                                return _ToolCard(
                                  tool: tool,
                                  onTap: () {
                                    setState(() => _activeTool = tool.id);
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Quick Capture View Component
// ──────────────────────────────────────────────

class _QuickCaptureView extends ConsumerStatefulWidget {
  final VoidCallback onBack;

  const _QuickCaptureView({required this.onBack});

  @override
  ConsumerState<_QuickCaptureView> createState() => _QuickCaptureViewState();
}

class _QuickCaptureViewState extends ConsumerState<_QuickCaptureView> {
  final _inputController = TextEditingController();
  final _searchController = TextEditingController();
  final _inputFocusNode = FocusNode();
  String _searchQuery = '';
  String _filterTab = 'all'; // 'all', 'pending', 'actioned'
  List<String> _attachedImages = [];

  @override
  void dispose() {
    _inputController.dispose();
    _searchController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'png', 'jpeg', 'gif', 'webp'],
        allowMultiple: true,
      );
      if (result != null) {
        final paths = result.files
            .where((f) => f.path != null)
            .map((f) => f.path!)
            .toList();
        if (paths.isNotEmpty) {
          setState(() => _attachedImages.addAll(paths));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick images: $e'),
            backgroundColor: FocusOsTheme.of(context).surfaceAlt,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _pasteFromClipboard() async {
    try {
      // 1. Check if there is an image in clipboard
      final imageBytes = await Pasteboard.image;
      if (imageBytes != null) {
        final tempDir = await getTemporaryDirectory();
        final filePath = '${tempDir.path}/captured_image_${DateTime.now().millisecondsSinceEpoch}.png';
        final file = File(filePath);
        await file.writeAsBytes(imageBytes);
        
        setState(() {
          _attachedImages.add(filePath);
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Attached image from clipboard!'),
              backgroundColor: FocusOsTheme.of(context).surfaceAlt,
              duration: const Duration(seconds: 1),
            ),
          );
        }
        _inputFocusNode.requestFocus();
        return;
      }
      
      // 1.5 Check if there are files in clipboard
      final files = await Pasteboard.files();
      if (files.isNotEmpty) {
        final imageExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp'];
        bool foundAny = false;
        for (final path in files) {
          final lower = path.toLowerCase();
          if (imageExtensions.any((ext) => lower.endsWith(ext))) {
            _attachedImages.add(path);
            foundAny = true;
          }
        }
        
        if (foundAny) {
          setState(() {});
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Attached image file(s) from clipboard!'),
                backgroundColor: FocusOsTheme.of(context).surfaceAlt,
                duration: const Duration(seconds: 1),
              ),
            );
          }
          _inputFocusNode.requestFocus();
          return;
        }
      }
      
      // 2. Check for text
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      if (clipboardData != null && clipboardData.text != null) {
        final pastedText = clipboardData.text!;
        if (pastedText.isEmpty) return;
        
        // Check if file path to image
        if (pastedText.trim().endsWith('.png') ||
            pastedText.trim().endsWith('.jpg') ||
            pastedText.trim().endsWith('.jpeg') ||
            pastedText.trim().endsWith('.gif') ||
            pastedText.trim().endsWith('.webp')) {
          final file = File(pastedText.trim());
          if (await file.exists()) {
            setState(() {
              _attachedImages.add(pastedText.trim());
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Attached image from clipboard path!'),
                  backgroundColor: FocusOsTheme.of(context).surfaceAlt,
                  duration: const Duration(seconds: 1),
                ),
              );
            }
            _inputFocusNode.requestFocus();
            return;
          }
        }
        
        // Paste into TextField
        final val = _inputController.value;
        final currentText = val.text;
        final start = val.selection.start;
        final end = val.selection.end;
        
        if (start >= 0 && end >= 0) {
          final newText = currentText.replaceRange(start, end, pastedText);
          _inputController.value = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: start + pastedText.length),
          );
        } else {
          if (currentText.isEmpty) {
            _inputController.text = pastedText;
          } else {
            _inputController.text = '$currentText\n$pastedText';
          }
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Pasted text from clipboard!'),
              backgroundColor: FocusOsTheme.of(context).surfaceAlt,
              duration: const Duration(seconds: 1),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Clipboard paste error: $e');
    } finally {
      _inputFocusNode.requestFocus();
    }
  }

  void _addCapture() {
    final text = _inputController.text.trim();
    if (text.isEmpty && _attachedImages.isEmpty) return;

    ref.read(quickCaptureProvider.notifier).addEntry(
      text.isNotEmpty ? text : (_attachedImages.isNotEmpty ? 'Captured ${_attachedImages.length} image(s)' : ''),
      mediaPaths: _attachedImages.isNotEmpty ? _attachedImages : null,
    );

    _inputController.clear();
    setState(() {
      _attachedImages.clear();
    });
    _inputFocusNode.requestFocus();
  }

  void _copyToClipboard(String note) {
    Clipboard.setData(ClipboardData(text: note));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.greenAccent, size: 16),
            const SizedBox(width: 8),
            const Text('Copied to clipboard!'),
          ],
        ),
        backgroundColor: FocusOsTheme.of(context).surfaceAlt,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _convertToTask(QuickCaptureItem item) {
    ref.read(tasksProvider.notifier).addTask(item.text);
    ref.read(quickCaptureProvider.notifier).removeEntry(item.id);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.task_alt_rounded, color: Colors.greenAccent, size: 16),
            const SizedBox(width: 8),
            const Text('Converted and added to Tasks!'),
          ],
        ),
        backgroundColor: FocusOsTheme.of(context).surfaceAlt,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = FocusOsTheme.of(context);
    final items = ref.watch(quickCaptureProvider);

    // Filter list based on search and selected tab
    final filteredItems = items.where((item) {
      final matchesSearch = item.text.toLowerCase().contains(_searchQuery.toLowerCase());
      if (!matchesSearch) return false;

      if (_filterTab == 'pending') return !item.isActioned;
      if (_filterTab == 'actioned') return item.isActioned;
      return true;
    }).toList();

    return motion.PremiumEnterTransition(
      duration: motion.PremiumDurations.pageTransition,
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back_ios_new_rounded,
                      size: 18, color: tokens.textPrimary),
                  onPressed: widget.onBack,
                  splashRadius: 20,
                  tooltip: 'Back to Tools',
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Quick Capture',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                                color: tokens.textPrimary,
                                letterSpacing: -0.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (items.isNotEmpty) ...[
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: tokens.accent.safeWithOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: tokens.accent.safeWithOpacity(0.2),
                                ),
                              ),
                              child: Text(
                                '${items.where((i) => !i.isActioned).length} pending',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: tokens.accent),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Capture tasks, links, screenshots, and quick ideas instantly',
                        style: TextStyle(fontSize: 13, color: tokens.textMuted),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Layout Split ──
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 600;
                  if (isNarrow) {
                    // Stack vertically on narrow screens
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Input section (compact)
                        Container(
                          height: 160,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: tokens.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: tokens.borderSubtle),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'New Capture',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: tokens.textSecondary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: tokens.background,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: tokens.borderSubtle),
                                  ),
                                  padding: const EdgeInsets.all(8),
                                  child: TextField(
                                    controller: _inputController,
                                    focusNode: _inputFocusNode,
                                    maxLines: null,
                                    keyboardType: TextInputType.multiline,
                                    style: TextStyle(
                                        color: tokens.textPrimary, fontSize: 13, height: 1.4),
                                    decoration: InputDecoration(
                                      hintText: 'Type an idea, task, or paste a link...',
                                      hintStyle: TextStyle(
                                          color: tokens.textMuted, fontSize: 13),
                                      border: InputBorder.none,
                                    ),
                                    onSubmitted: (_) => _addCapture(),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.add_photo_alternate_rounded,
                                        color: tokens.textSecondary, size: 18),
                                    onPressed: _pickImages,
                                    tooltip: 'Attach Images',
                                    splashRadius: 16,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: Icon(Icons.content_paste_rounded,
                                        color: tokens.textSecondary, size: 18),
                                    onPressed: _pasteFromClipboard,
                                    tooltip: 'Paste (Ctrl+V)',
                                    splashRadius: 16,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                  const Spacer(),
                                  PremiumButton(
                                    onTap: _addCapture,
                                    variant: PremiumButtonVariant.gradient,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                    child: const Text(
                                      'Capture',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Inbox below
                        Expanded(
                          child: Column(
                            children: [
                              // Tabs only (no search on narrow)
                              Row(
                                children: [
                                  Flexible(
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: tokens.surface,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: tokens.borderSubtle),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _TabButton(
                                            label: 'All',
                                            active: _filterTab == 'all',
                                            onTap: () => setState(() => _filterTab = 'all'),
                                            tokens: tokens,
                                          ),
                                          _TabButton(
                                            label: 'Pending',
                                            active: _filterTab == 'pending',
                                            onTap: () => setState(() => _filterTab = 'pending'),
                                            tokens: tokens,
                                          ),
                                          _TabButton(
                                            label: 'Actioned',
                                            active: _filterTab == 'actioned',
                                            onTap: () => setState(() => _filterTab = 'actioned'),
                                            tokens: tokens,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Expanded(
                                child: _buildInboxContent(tokens, filteredItems, items.isEmpty),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }
                  // Wide layout
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Left Panel (Fast Input Capture) ──
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 320, minWidth: 200),
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
                              Text(
                                'New Capture',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: tokens.textSecondary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 12),
                              
                              // Text Area input
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: tokens.background,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: tokens.borderSubtle),
                                  ),
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    children: [
                                      Expanded(
                                        child: CallbackShortcuts(
                                          bindings: <ShortcutActivator, VoidCallback>{
                                            const SingleActivator(LogicalKeyboardKey.keyV, control: true): _pasteFromClipboard,
                                            const SingleActivator(LogicalKeyboardKey.keyV, meta: true): _pasteFromClipboard,
                                          },
                                          child: TextField(
                                            controller: _inputController,
                                            focusNode: _inputFocusNode,
                                            maxLines: null,
                                            keyboardType: TextInputType.multiline,
                                            style: TextStyle(
                                                color: tokens.textPrimary, fontSize: 13, height: 1.4),
                                            decoration: InputDecoration(
                                              hintText: 'Type an idea, task, or paste a link...',
                                              hintStyle: TextStyle(
                                                  color: tokens.textMuted, fontSize: 13),
                                              border: InputBorder.none,
                                            ),
                                            onSubmitted: (_) => _addCapture(),
                                          ),
                                        ),
                                      ),

                                      // Attached images preview
                                      if (_attachedImages.isNotEmpty) ...[
                                        const SizedBox(height: 12),
                                        SizedBox(
                                          height: 56,
                                          child: ListView.separated(
                                            scrollDirection: Axis.horizontal,
                                            itemCount: _attachedImages.length,
                                            separatorBuilder: (_, __) => const SizedBox(width: 6),
                                            itemBuilder: (context, index) {
                                              return Stack(
                                                children: [
                                                  ClipRRect(
                                                    borderRadius: BorderRadius.circular(6),
                                                    child: Image.file(
                                                      File(_attachedImages[index]),
                                                      width: 56,
                                                      height: 56,
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (_, __, ___) => Container(
                                                        width: 56,
                                                        height: 56,
                                                        color: tokens.borderSubtle,
                                                        child: Icon(Icons.broken_image, size: 20, color: tokens.textMuted),
                                                      ),
                                                    ),
                                                  ),
                                                  Positioned(
                                                    top: 2,
                                                    right: 2,
                                                    child: GestureDetector(
                                                      onTap: () => setState(() => _attachedImages.removeAt(index)),
                                                      child: Container(
                                                        padding: const EdgeInsets.all(2),
                                                        decoration: const BoxDecoration(
                                                          color: Colors.black54,
                                                          shape: BoxShape.circle,
                                                        ),
                                                        child: const Icon(Icons.close, size: 10, color: Colors.white),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Action Buttons
                              Row(
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.add_photo_alternate_rounded,
                                        color: tokens.textSecondary),
                                    onPressed: _pickImages,
                                    tooltip: 'Attach Images / Screenshots',
                                    splashRadius: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: Icon(Icons.content_paste_rounded,
                                        color: tokens.textSecondary),
                                    onPressed: _pasteFromClipboard,
                                    tooltip: 'Paste Link or Image (Ctrl+V)',
                                    splashRadius: 20,
                                  ),
                                  const Spacer(),
                                  PremiumButton(
                                    onTap: _addCapture,
                                    variant: PremiumButtonVariant.gradient,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 11),
                                    child: const Text(
                                      'Capture Item',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(width: 24),

                      // ── Right Panel (Capture Inbox) ──
                      Expanded(
                        child: Column(
                          children: [
                            // Search & Tabs Controls
                            Row(
                              children: [
                                // Tabs
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: tokens.surface,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: tokens.borderSubtle),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _TabButton(
                                          label: 'All',
                                          active: _filterTab == 'all',
                                          onTap: () => setState(() => _filterTab = 'all'),
                                          tokens: tokens,
                                        ),
                                        _TabButton(
                                          label: 'Pending',
                                          active: _filterTab == 'pending',
                                          onTap: () => setState(() => _filterTab = 'pending'),
                                          tokens: tokens,
                                        ),
                                        _TabButton(
                                          label: 'Actioned',
                                          active: _filterTab == 'actioned',
                                          onTap: () => setState(() => _filterTab = 'actioned'),
                                          tokens: tokens,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const Spacer(),

                                // Search bar
                                Flexible(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 260),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: tokens.surface,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: tokens.borderSubtle),
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 10),
                                      child: Row(
                                        children: [
                                          Icon(Icons.search_rounded,
                                              color: tokens.textMuted, size: 16),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: TextField(
                                              controller: _searchController,
                                              style: TextStyle(
                                                  color: tokens.textPrimary, fontSize: 12),
                                              decoration: InputDecoration(
                                                hintText: 'Search inbox...',
                                                hintStyle: TextStyle(
                                                    color: tokens.textMuted, fontSize: 12),
                                                border: InputBorder.none,
                                                isDense: true,
                                                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                              ),
                                              onChanged: (val) {
                                                setState(() {
                                                  _searchQuery = val;
                                                });
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // List Grid of Inbox Cards
                            Expanded(
                              child: _buildInboxContent(tokens, filteredItems, items.isEmpty),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInboxContent(ThemeTokens tokens, List<QuickCaptureItem> filteredItems, bool totalEmpty) {
    if (totalEmpty) {
      return EmptyState(
        icon: Icons.bolt_rounded,
        title: 'Your Capture Inbox is empty',
        subtitle: 'Capture tasks, links, screenshots, and ideas instantly using the input panel on the left.',
      );
    }

    if (filteredItems.isEmpty) {
      return EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No items match your criteria',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth < 500 ? 1 : (constraints.maxWidth < 800 ? 2 : 3);
        return GridView.builder(
          physics: const BouncingScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.5,
          ),
          itemCount: filteredItems.length,
          itemBuilder: (context, index) {
            final item = filteredItems[index];
            return _QuickCaptureCard(
              key: ValueKey(item.id),
              item: item,
              onCopy: () => _copyToClipboard(item.text),
              onDelete: () {
                ref.read(quickCaptureProvider.notifier).removeEntry(item.id);
              },
              onToggleAction: () {
                ref.read(quickCaptureProvider.notifier).toggleActioned(item.id);
              },
              onConvertToTask: () => _convertToTask(item),
              onUpdateText: (newVal) {
                ref.read(quickCaptureProvider.notifier).updateEntry(item.id, newVal);
              },
            );
          },
        );
      },
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final ThemeTokens tokens;

  const _TabButton({
    required this.label,
    required this.active,
    required this.onTap,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? tokens.background : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            color: active ? tokens.textPrimary : tokens.textMuted,
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Quick Capture Card Component
// ──────────────────────────────────────────────

class _QuickCaptureCard extends ConsumerStatefulWidget {
  final QuickCaptureItem item;
  final VoidCallback onCopy;
  final VoidCallback onDelete;
  final VoidCallback onToggleAction;
  final VoidCallback onConvertToTask;
  final ValueChanged<String> onUpdateText;

  const _QuickCaptureCard({
    super.key,
    required this.item,
    required this.onCopy,
    required this.onDelete,
    required this.onToggleAction,
    required this.onConvertToTask,
    required this.onUpdateText,
  });

  @override
  ConsumerState<_QuickCaptureCard> createState() => _QuickCaptureCardState();
}

class _QuickCaptureCardState extends ConsumerState<_QuickCaptureCard> {
  bool _isEditing = false;
  late TextEditingController _editController;
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController(text: widget.item.text);
  }

  @override
  void didUpdateWidget(covariant _QuickCaptureCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.item.text != oldWidget.item.text && !_isEditing) {
      _editController.text = widget.item.text;
    }
  }

  @override
  void dispose() {
    _editController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startEditing() {
    setState(() {
      _isEditing = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  void _saveChanges() {
    final text = _editController.text.trim();
    if (text.isNotEmpty) {
      widget.onUpdateText(text);
    } else {
      _editController.text = widget.item.text;
    }
    setState(() {
      _isEditing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = FocusOsTheme.of(context);
    final isActioned = widget.item.isActioned;

    return PremiumCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      hoverElevation: 6.0,
      hoverYOffset: -2.0,
      hoverScale: 1.002,
      child: Opacity(
        opacity: isActioned ? 0.6 : 1.0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image Previews (multiple)
            if (widget.item.mediaPaths.isNotEmpty) ...[
              SizedBox(
                height: 60,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.item.mediaPaths.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (context, index) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.file(
                        File(widget.item.mediaPaths[index]),
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 60,
                          height: 60,
                          color: tokens.borderSubtle,
                          child: Icon(Icons.broken_image_rounded, color: tokens.textMuted, size: 20),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Content
            Expanded(
              child: _isEditing
                  ? TextField(
                      controller: _editController,
                      focusNode: _focusNode,
                      maxLines: null,
                      style: TextStyle(
                        fontSize: 12,
                        color: tokens.textPrimary,
                        height: 1.35,
                      ),
                      cursorColor: tokens.accent,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                    )
                  : GestureDetector(
                      onDoubleTap: _startEditing,
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Link badges (multiple)
                            if (widget.item.linkUrls.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Wrap(
                                  spacing: 4,
                                  runSpacing: 4,
                                  children: widget.item.linkUrls.map((url) => _LinkBadge(
                                    url: url,
                                    tokens: tokens,
                                  )).toList(),
                                ),
                              ),
                            ],
                            Text(
                              widget.item.text,
                              style: TextStyle(
                                fontSize: 12,
                                color: tokens.textPrimary,
                                height: 1.35,
                                decoration: isActioned ? TextDecoration.lineThrough : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 6),

            // Actions Row
            Row(
              children: [
                // Quick checkbox for marking actioned
                GestureDetector(
                  onTap: widget.onToggleAction,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      border: Border.all(color: tokens.textMuted, width: 1.5),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    alignment: Alignment.center,
                    child: isActioned
                        ? Icon(Icons.check, size: 10, color: tokens.accent)
                        : null,
                  ),
                ),
                const Spacer(),
                if (_isEditing) ...[
                  IconButton(
                    icon: Icon(Icons.check_rounded, size: 14, color: tokens.accent),
                    onPressed: _saveChanges,
                    splashRadius: 16,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Save',
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 14, color: tokens.textMuted),
                    onPressed: () {
                      setState(() {
                        _isEditing = false;
                        _editController.text = widget.item.text;
                      });
                    },
                    splashRadius: 16,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Cancel',
                  ),
                ] else ...[
                  // Convert to Task
                  IconButton(
                    icon: Icon(Icons.task_alt_rounded, size: 13, color: tokens.textMuted),
                    onPressed: widget.onConvertToTask,
                    splashRadius: 16,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Convert to Task',
                  ),
                  const SizedBox(width: 10),
                  // Edit
                  IconButton(
                    icon: Icon(Icons.edit_outlined, size: 13, color: tokens.textMuted),
                    onPressed: _startEditing,
                    splashRadius: 16,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Edit text',
                  ),
                  const SizedBox(width: 10),
                  // Copy
                  IconButton(
                    icon: Icon(Icons.copy_rounded, size: 13, color: tokens.textMuted),
                    onPressed: widget.onCopy,
                    splashRadius: 16,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Copy text',
                  ),
                  const SizedBox(width: 10),
                  // Delete
                  IconButton(
                    icon: Icon(Icons.delete_outline_rounded, size: 13, color: tokens.textMuted),
                    onPressed: widget.onDelete,
                    splashRadius: 16,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Delete item',
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Link Badge — clickable link chip that opens in browser
// ──────────────────────────────────────────────

class _LinkBadge extends StatelessWidget {
  final String url;
  final ThemeTokens tokens;

  const _LinkBadge({
    required this.url,
    required this.tokens,
  });

  String _hostname(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host.replaceFirst('www.', '');
    } catch (_) {
      return url.length > 20 ? '${url.substring(0, 20)}…' : url;
    }
  }

  Future<void> _openUrl(String url, BuildContext ctx) async {
    try {
      if (Platform.isWindows) {
        await Process.run('start', ['""', url], runInShell: true);
      } else if (Platform.isMacOS) {
        await Process.run('open', [url]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [url]);
      } else {
        throw UnsupportedError('Platform not supported for opening URLs');
      }
    } catch (e) {
      await Clipboard.setData(ClipboardData(text: url));
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text('URL copied to clipboard (could not open browser: $e)'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openUrl(url, context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: tokens.accent.safeWithOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: tokens.accent.safeWithOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.link_rounded, size: 10, color: tokens.accent),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                _hostname(url),
                style: TextStyle(
                  fontSize: 10,
                  color: tokens.accent,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Premium Tool Card — redesigned with round corners, glow, and gradient accents
// ──────────────────────────────────────────────

class _ToolCard extends StatefulWidget {
  final ToolItem tool;
  final VoidCallback onTap;

  const _ToolCard({
    required this.tool,
    required this.onTap,
  });

  @override
  State<_ToolCard> createState() => _ToolCardState();
}

class _ToolCardState extends State<_ToolCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = FocusOsTheme.of(context);
    final tool = widget.tool;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: motion.PremiumDurations.hoverLong,
          curve: motion.PremiumCurves.easeOutCubic,
          width: 280,
          height: 180,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _hovered
                  ? tool.color.withValues(alpha: 0.4)
                  : tokens.borderSubtle,
              width: _hovered ? 1.5 : 1.0,
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: tool.color.withValues(alpha: 0.18),
                      blurRadius: 28,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          transform: Matrix4.translationValues(
            0,
            _hovered ? -4.0 : 0,
            0,
          ),
          transformAlignment: Alignment.center,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top row: Icon + Arrow ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Glass-morphism icon container
                  AnimatedContainer(
                    duration: motion.PremiumDurations.hover,
                    curve: motion.PremiumCurves.easeOutCubic,
                    width: _hovered ? 46 : 42,
                    height: _hovered ? 46 : 42,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          tool.color.withValues(alpha: 0.22),
                          tool.color.withValues(alpha: 0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: tool.color.withValues(alpha: _hovered ? 0.35 : 0.15),
                        width: 1.0,
                      ),
                    ),
                    child: Icon(
                      tool.icon,
                      size: _hovered ? 22 : 20,
                      color: tool.color,
                    ),
                  ),
                  // Animated arrow
                  AnimatedOpacity(
                    duration: motion.PremiumDurations.hover,
                    opacity: _hovered ? 1.0 : 0.4,
                    child: AnimatedSlide(
                      duration: motion.PremiumDurations.hover,
                      curve: motion.PremiumCurves.easeOutCubic,
                      offset: _hovered ? const Offset(0.2, 0) : Offset.zero,
                      child: TweenAnimationBuilder<Color?>(
                        tween: ColorTween(
                          begin: _hovered ? tool.color : tokens.textMuted,
                          end: _hovered ? tool.color : tokens.textMuted,
                        ),
                        duration: motion.PremiumDurations.hover,
                        curve: motion.PremiumCurves.easeOutCubic,
                        builder: (context, color, _) => Icon(
                          Icons.arrow_forward_rounded,
                          size: 16,
                          color: color,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // ── Title ──
              Text(
                tool.title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: tokens.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              // ── Description ──
              Text(
                tool.description,
                style: TextStyle(
                  fontSize: 11,
                  color: tokens.textMuted,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              // ── Bottom accent bar ──
              AnimatedContainer(
                duration: motion.PremiumDurations.hover,
                curve: motion.PremiumCurves.easeOutCubic,
                height: 3,
                width: _hovered ? 60 : 32,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      tool.color,
                      tool.color.withValues(alpha: 0.4),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
