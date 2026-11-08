import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../shared/motion.dart' as motion;
import '../../shared/theme.dart';
import '../../shared/widgets/premium_button.dart';
import '../../shared/widgets/task_creation_modal.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/analytics_service.dart';
import '../../core/providers.dart';
import '../../core/navigation.dart';
import '../../models/task.dart';
import '../../models/habit.dart';
import '../../models/timeline_goal.dart';
import 'kanban_view.dart';

/// Tasks page — premium task management with deep focus integration.
/// Contains top tabs: Tasks and Habits (Habits Matrix tracker).
class TasksPage extends ConsumerStatefulWidget {
  const TasksPage({super.key});

  @override
  ConsumerState<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends ConsumerState<TasksPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _activeTab = 0;
  bool _showCreationModal = false;
  String _searchQuery = '';

  // Habits Tracker Matrix view settings
  String _habitView = 'This Week'; // 'This Week' | 'By Week' | 'By Month' | 'By Year'
  DateTime _selectedDate = DateTime.now();
  bool _habitColumnExpanded = false;

  // Custom resizable column widths
  Map<String, double> _habitColumnWidths = {};
  double _firstColWidth = 140.0;
  double _completedColWidth = 120.0;

  // Inline editing state
  String? _inlineEditHabitId;
  late TextEditingController _inlineEditController;
  late FocusNode _inlineEditFocusNode;

  // Drag reorder state
  String? _draggingHabitId;
  int? _dragInsertIndex;

  // Habit analytics range toggle
  String _habitAnalyticsRange = '7D';

  // Tasks view mode: list or kanban
  String _tasksViewMode = 'list';

  void _openCreationModal() => setState(() => _showCreationModal = true);
  void _closeCreationModal() => setState(() => _showCreationModal = false);

  @override
  void initState() {
    super.initState();
    final initialTab = ref.read(tasksActiveTabIndexProvider);
    _tabController = TabController(length: 3, vsync: this, initialIndex: initialTab);
    _activeTab = initialTab;
    _tabController.addListener(() {
      if (mounted) {
        setState(() => _activeTab = _tabController.index);
        ref.read(tasksActiveTabIndexProvider.notifier).state = _tabController.index;
      }
    });
    _loadColumnWidths();
    _inlineEditController = TextEditingController();
    _inlineEditFocusNode = FocusNode(onKeyEvent: (node, event) {
      if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
        _cancelInlineEdit();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    });
    _inlineEditFocusNode.addListener(() {
      if (!_inlineEditFocusNode.hasFocus && _inlineEditHabitId != null) {
        _commitInlineEdit();
      }
    });
  }

  Future<void> _loadColumnWidths() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final first = prefs.getDouble('habit_first_col_width');
      final completed = prefs.getDouble('habit_completed_col_width');
      final widthsJson = prefs.getString('habit_column_widths');
      setState(() {
        if (first != null) _firstColWidth = first;
        if (completed != null) _completedColWidth = completed;
        if (widthsJson != null) {
          final Map<String, dynamic> decoded = Map<String, dynamic>.from(jsonDecode(widthsJson) as Map);
          _habitColumnWidths = decoded.map((key, value) => MapEntry(key, (value as num).toDouble()));
        }
      });
    } catch (_) {}
  }

  Color _parseColorSafe(String hexColor, {Color fallback = const Color(0xFF6366F1)}) {
    try {
      final cleanHex = hexColor.replaceAll('#', '');
      if (cleanHex.length == 6) {
        return Color(int.parse('0xFF$cleanHex'));
      } else if (cleanHex.length == 8) {
        return Color(int.parse('0x$cleanHex'));
      }
    } catch (_) {}
    return fallback;
  }

  Future<void> _saveColumnWidths() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('habit_first_col_width', _firstColWidth);
      await prefs.setDouble('habit_completed_col_width', _completedColWidth);
      final encoded = jsonEncode(_habitColumnWidths);
      await prefs.setString('habit_column_widths', encoded);
    } catch (_) {}
  }

  @override
  void dispose() {
    _tabController.dispose();
    _inlineEditController.dispose();
    _inlineEditFocusNode.dispose();
    super.dispose();
  }

  void _startInlineEdit(Habit habit) {
    setState(() {
      _inlineEditHabitId = habit.id;
      _inlineEditController.text = habit.name;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _inlineEditFocusNode.requestFocus();
      _inlineEditController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _inlineEditController.text.length,
      );
    });
  }

  void _commitInlineEdit() {
    final name = _inlineEditController.text.trim();
    final habitId = _inlineEditHabitId;
    if (name.isNotEmpty && habitId != null) {
      final habits = ref.read(habitsProvider);
      final habit = habits.firstWhere((h) => h.id == habitId, orElse: () => habits.first);
      if (habit.name != name) {
        ref.read(habitsProvider.notifier).updateHabit(habit.copyWith(name: name));
      }
    }
    setState(() => _inlineEditHabitId = null);
  }

  void _cancelInlineEdit() {
    setState(() => _inlineEditHabitId = null);
  }

  void _showHabitContextMenu(BuildContext context, Offset position, Habit habit, ThemeTokens tokens) async {
    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx + 1, position.dy + 1),
      color: tokens.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: tokens.borderSubtle)),
      items: [
        PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 16, color: tokens.textSecondary), const SizedBox(width: 8), Text('Edit Habit', style: TextStyle(color: tokens.textPrimary, fontSize: 13))])),
        PopupMenuItem(value: 'rename', child: Row(children: [Icon(Icons.text_fields_rounded, size: 16, color: tokens.textSecondary), const SizedBox(width: 8), Text('Rename', style: TextStyle(color: tokens.textPrimary, fontSize: 13))])),
        PopupMenuItem(value: 'hide', child: Row(children: [Icon(Icons.visibility_off_outlined, size: 16, color: tokens.textSecondary), const SizedBox(width: 8), Text('Hide Habit', style: TextStyle(color: tokens.textPrimary, fontSize: 13))])),
        const PopupMenuDivider(),
        PopupMenuItem(value: 'delete', child: Row(children: [const Icon(Icons.delete_outline, size: 16, color: Color(0xFFEF4444)), const SizedBox(width: 8), Text('Delete Habit', style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13))])),
      ],
    );
    if (result == null || !mounted) return;
    switch (result) {
      case 'edit':
        _showHabitModal(habit: habit);
        break;
      case 'rename':
        _startInlineEdit(habit);
        break;
      case 'hide':
        ref.read(habitsProvider.notifier).updateHabit(habit.copyWith(active: false));
        break;
      case 'delete':
        ref.read(habitsProvider.notifier).deleteHabit(habit.id);
        break;
    }
  }

  void _showNotesPopover(BuildContext context, String habitId, DateTime date, ThemeTokens tokens) {
    final dateStr = date.toIso8601String().substring(0, 10);
    final completions = ref.read(habitCompletionsProvider);
    final existing = completions.firstWhere(
      (c) => c.habitId == habitId && c.date == dateStr,
      orElse: () => HabitCompletion(id: '', habitId: '', date: '', completed: false, timestamp: date),
    );
    final controller = TextEditingController(text: existing.notes ?? '');

    showDialog(
      context: context,
      builder: (ctx) {
        final t = FocusOsTheme.of(ctx);
        return AlertDialog(
          backgroundColor: t.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: t.borderSubtle)),
          title: Text('Completion Note', style: TextStyle(color: t.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Add a note for ${_getFullWeekdayName(date.weekday)}, ${_getFormattedDate(date)}', style: TextStyle(fontSize: 12, color: t.textMuted)),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  autofocus: true,
                  maxLines: 3,
                  style: TextStyle(color: t.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'E.g., Ran 5km today...',
                    hintStyle: TextStyle(color: t.textMuted, fontSize: 13),
                    filled: true,
                    fillColor: t.background,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: t.borderSubtle)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: t.borderSubtle)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: t.accent)),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            if (existing.notes != null && existing.notes!.isNotEmpty)
              TextButton(
                onPressed: () {
                  ref.read(habitCompletionsProvider.notifier).updateCompletionNotes(habitId, date, null);
                  Navigator.pop(ctx);
                },
                child: Text('Clear', style: TextStyle(color: Color(0xFFEF4444), fontSize: 13)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: t.textSecondary, fontSize: 13)),
            ),
            PremiumButton(
              onTap: () {
                final text = controller.text.trim();
                ref.read(habitCompletionsProvider.notifier).updateCompletionNotes(habitId, date, text.isEmpty ? null : text);
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _prevRange() {
    setState(() {
      if (_habitView == 'This Week' || _habitView == 'By Week') {
        _selectedDate = _selectedDate.subtract(const Duration(days: 7));
        _habitView = 'By Week';
      } else if (_habitView == 'By Month') {
        _selectedDate = DateTime(_selectedDate.year, _selectedDate.month - 1, 1);
      } else {
        _selectedDate = DateTime(_selectedDate.year - 1, 1, 1);
      }
    });
  }

  void _nextRange() {
    setState(() {
      if (_habitView == 'This Week' || _habitView == 'By Week') {
        _selectedDate = _selectedDate.add(const Duration(days: 7));
        _habitView = 'By Week';
      } else if (_habitView == 'By Month') {
        _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + 1, 1);
      } else {
        _selectedDate = DateTime(_selectedDate.year + 1, 1, 1);
      }
    });
  }

  void _jumpToToday() {
    setState(() {
      _selectedDate = DateTime.now();
      if (_habitView == 'By Week') {
        _habitView = 'This Week';
      }
    });
  }

  String _getMonthName(int month) {
    const names = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return names[month - 1];
  }

  IconData _getIconData(String name) {
    switch (name) {
      case 'gym':
      case 'fitness_center':
        return Icons.fitness_center;
      case 'book':
      case 'menu_book':
        return Icons.menu_book;
      case 'water':
      case 'water_drop':
        return Icons.water_drop;
      case 'sleep':
      case 'bedtime':
        return Icons.bedtime;
      case 'food':
      case 'restaurant':
        return Icons.restaurant;
      case 'spa':
        return Icons.spa;
      case 'code':
        return Icons.code;
      case 'self_improvement':
      case 'meditate':
        return Icons.self_improvement;
      case 'check':
      default:
        return Icons.check_circle_outline;
    }
  }

  Widget _buildHabitIcon(String iconName, {double size = 14, Color? color}) {
    if (iconName.startsWith('emoji:')) {
      final emoji = iconName.substring(6);
      return Text(
        emoji,
        style: TextStyle(
          fontSize: size,
        ),
      );
    } else if (iconName.isNotEmpty && !RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(iconName)) {
      return Text(
        iconName,
        style: TextStyle(
          fontSize: size,
        ),
      );
    } else {
      return Icon(_getIconData(iconName), size: size, color: color);
    }
  }

  Widget _buildResizeHandle(ThemeTokens tokens, {required ValueChanged<double> onDrag}) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: (details) => onDrag(details.delta.dx),
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeLeftRight,
        child: Container(
          width: 8,
          height: double.infinity,
          alignment: Alignment.center,
          child: Container(
            width: 1,
            color: tokens.borderSubtle,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(tasksActiveTabIndexProvider, (previous, next) {
      if (_tabController.index != next) {
        _tabController.animateTo(next);
      }
    });

    final tokens = FocusOsTheme.of(context);
    final tasks = ref.watch(tasksProvider);
    final focusedTaskId = ref.watch(focusedTaskProvider);
    final habits = ref.watch(habitsProvider);
    final completions = ref.watch(habitCompletionsProvider);

    final query = _searchQuery.toLowerCase().trim();
    final filtered = query.isEmpty
        ? tasks
        : tasks.where((t) =>
            t.title.toLowerCase().contains(query) &&
            !t.archived).toList();
    final doneTasks = filtered.where((t) => t.done).toList();
    final pendingTasks = filtered.where((t) => !t.done && !t.archived).toList();
    final archivedTasks = query.isEmpty
        ? tasks.where((t) => t.archived).toList()
        : <Task>[];

    return motion.PremiumEnterTransition(
      duration: motion.PremiumDurations.pageTransition,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 32, right: 32, top: 32, bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header & Tab Switcher Row ──
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 700;
                    if (isNarrow) {
                      // Stack vertically on narrow screens
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title
                          Text(
                            _activeTab == 0
                                ? 'Tasks'
                                : _activeTab == 1
                                    ? 'Habit Tracker'
                                    : 'Timeline Goals',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: tokens.textPrimary,
                              letterSpacing: -0.6,
                            ),
                          ),
                          const SizedBox(height: 4),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            transitionBuilder: (child, animation) => FadeTransition(
                              opacity: animation,
                              child: child,
                            ),
                            child: _activeTab == 0
                                ? Text(
                                    '${pendingTasks.length} pending  ·  ${doneTasks.length} completed',
                                    key: const ValueKey('tasks_subtitle'),
                                    style: TextStyle(fontSize: 13, color: tokens.textMuted, fontWeight: FontWeight.w500),
                                    overflow: TextOverflow.ellipsis,
                                  )
                                : _activeTab == 1
                                    ? Text(
                                        'Track consistency and build daily routines',
                                        key: const ValueKey('habits_subtitle'),
                                        style: TextStyle(fontSize: 13, color: tokens.textMuted, fontWeight: FontWeight.w500),
                                        overflow: TextOverflow.ellipsis,
                                      )
                                    : Text(
                                        'Track countdowns and work towards major milestones',
                                        key: const ValueKey('goals_subtitle'),
                                        style: TextStyle(fontSize: 13, color: tokens.textMuted, fontWeight: FontWeight.w500),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                          ),
                          const SizedBox(height: 12),
                          // Tabs + Actions row
                          Row(
                            children: [
                              Flexible(
                                child: _PremiumSegmentedControl(
                                  controller: _tabController,
                                  tabs: const ['Tasks', 'Habits', 'Goals'],
                                  tokens: tokens,
                                ),
                              ),
                              const SizedBox(width: 12),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: _activeTab == 0
                                    ? PremiumButton(
                                        key: const ValueKey('tasks_btn_narrow'),
                                        onTap: _openCreationModal,
                                        variant: PremiumButtonVariant.gradient,
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.add, size: 14, color: Colors.white),
                                            SizedBox(width: 6),
                                            Text('New', style: TextStyle(fontSize: 12)),
                                          ],
                                        ),
                                      )
                                    : _activeTab == 1
                                        ? PremiumButton(
                                            key: const ValueKey('habits_btn_narrow'),
                                            onTap: () => _showHabitModal(),
                                            variant: PremiumButtonVariant.gradient,
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.add, size: 14, color: Colors.white),
                                                SizedBox(width: 6),
                                                Text('New', style: TextStyle(fontSize: 12)),
                                              ],
                                            ),
                                          )
                                        : PremiumButton(
                                            key: const ValueKey('goals_btn_narrow'),
                                            onTap: () => _showGoalModal(),
                                            variant: PremiumButtonVariant.gradient,
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.add, size: 14, color: Colors.white),
                                                SizedBox(width: 6),
                                                Text('New', style: TextStyle(fontSize: 12)),
                                              ],
                                            ),
                                          ),
                              ),
                            ],
                          ),
                        ],
                      );
                    }
                    // Wide layout — original three-column row
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Left Column: Title and stats/subtitle
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _activeTab == 0
                                    ? 'Tasks'
                                    : _activeTab == 1
                                        ? 'Habit Tracker'
                                        : 'Timeline Goals',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: tokens.textPrimary,
                                  letterSpacing: -0.6,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                transitionBuilder: (child, animation) => FadeTransition(
                                  opacity: animation,
                                  child: SizeTransition(
                                    sizeFactor: animation,
                                    alignment: Alignment.centerLeft,
                                    child: child,
                                  ),
                                ),
                                child: _activeTab == 0
                                    ? Text(
                                        '${pendingTasks.length} pending  ·  ${doneTasks.length} completed',
                                        key: const ValueKey('tasks_subtitle'),
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: tokens.textMuted,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      )
                                    : _activeTab == 1
                                        ? Text(
                                            'Track consistency and build daily routines',
                                            key: const ValueKey('habits_subtitle'),
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: tokens.textMuted,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          )
                                        : Text(
                                            'Track countdowns and work towards major milestones',
                                            key: const ValueKey('goals_subtitle'),
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: tokens.textMuted,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Center Column: macOS Segmented Control
                        Flexible(
                          flex: 4,
                          child: Center(
                            child: _PremiumSegmentedControl(
                              controller: _tabController,
                              tabs: const ['Tasks', 'Habits', 'Goals'],
                              tokens: tokens,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Right Column: Search bar and New buttons
                        Expanded(
                          flex: 3,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: _activeTab == 0
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      key: const ValueKey('tasks_actions'),
                                      children: [
                                        // Search
                                        Flexible(
                                          child: ConstrainedBox(
                                            constraints: const BoxConstraints(maxWidth: 200),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: tokens.surface,
                                                borderRadius: BorderRadius.circular(10),
                                                border: Border.all(color: tokens.borderSubtle),
                                              ),
                                              child: TextField(
                                                onChanged: (v) => setState(() => _searchQuery = v),
                                                style: TextStyle(color: tokens.textPrimary, fontSize: 13),
                                                decoration: InputDecoration(
                                                  hintText: 'Search tasks...',
                                                  hintStyle: TextStyle(color: tokens.textMuted, fontSize: 13),
                                                  border: InputBorder.none,
                                                  isDense: true,
                                                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                                  prefixIconConstraints: const BoxConstraints(minWidth: 18),
                                                  prefixIcon: Icon(Icons.search, size: 14, color: tokens.textMuted),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        // New task button
                                        PremiumButton(
                                          onTap: _openCreationModal,
                                          variant: PremiumButtonVariant.gradient,
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: const [
                                              Icon(Icons.add, size: 14, color: Colors.white),
                                              SizedBox(width: 6),
                                              Text('New Task', style: TextStyle(fontSize: 12)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    )
                                  : _activeTab == 1
                                      ? Row(
                                          mainAxisSize: MainAxisSize.min,
                                          key: const ValueKey('habits_actions'),
                                          children: [
                                            // Toggle Size button
                                            GestureDetector(
                                              onTap: () {
                                                setState(() {
                                                  _habitColumnExpanded = !_habitColumnExpanded;
                                                  final targetWidth = _habitColumnExpanded ? 140.0 : 50.0;
                                                  for (final h in habits) {
                                                    _habitColumnWidths[h.id] = targetWidth;
                                                  }
                                                  _saveColumnWidths();
                                                });
                                              },
                                              child: MouseRegion(
                                                cursor: SystemMouseCursors.click,
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                  decoration: BoxDecoration(
                                                    color: tokens.background,
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(color: tokens.borderSubtle),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        _habitColumnExpanded
                                                            ? Icons.unfold_less_rounded
                                                            : Icons.unfold_more_rounded,
                                                        size: 13,
                                                        color: tokens.textSecondary,
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        _habitColumnExpanded ? 'Compact' : 'Expand Names',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w500,
                                                          color: tokens.textSecondary,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            // New Habit button
                                            PremiumButton(
                                              onTap: () => _showHabitModal(),
                                              variant: PremiumButtonVariant.gradient,
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: const [
                                                  Icon(Icons.add, size: 14, color: Colors.white),
                                                  SizedBox(width: 6),
                                                  Text('New Habit', style: TextStyle(fontSize: 12)),
                                                ],
                                              ),
                                            ),
                                          ],
                                        )
                                      : Row(
                                          mainAxisSize: MainAxisSize.min,
                                          key: const ValueKey('goals_actions'),
                                          children: [
                                            PremiumButton(
                                              onTap: () => _showGoalModal(),
                                              variant: PremiumButtonVariant.gradient,
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: const [
                                                  Icon(Icons.add, size: 14, color: Colors.white),
                                                  SizedBox(width: 6),
                                                  Text('New Goal', style: TextStyle(fontSize: 12)),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),

                // ── Tab View Content ──
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildTasksTab(tokens, query, filtered, pendingTasks, doneTasks, archivedTasks, focusedTaskId),
                      _buildHabitsTab(tokens, habits, completions),
                      _buildGoalsTab(tokens, ref.watch(timelineGoalsProvider)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Task creation modal ──
          if (_showCreationModal)
            TaskCreationModal(onClose: _closeCreationModal),
        ],
      ),
    );
  }

  // ── Tasks list layout builder ──
  Widget _buildTasksTab(
    ThemeTokens tokens,
    String query,
    List<Task> filtered,
    List<Task> pendingTasks,
    List<Task> doneTasks,
    List<Task> archivedTasks,
    String? focusedTaskId,
  ) {
    return filtered.isEmpty && query.isEmpty
        ? _EmptyState(tokens: tokens, onCreateTask: _openCreationModal)
        : ListView.separated(
            physics: const BouncingScrollPhysics(parent: ClampingScrollPhysics()),
            itemCount: pendingTasks.length + doneTasks.length + (doneTasks.isNotEmpty ? 1 : 0) + (archivedTasks.isNotEmpty ? 1 + archivedTasks.length : 0),
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (context, index) {
              // Pending tasks
              if (index < pendingTasks.length) {
                return _TaskCard(
                  task: pendingTasks[index],
                  tokens: tokens,
                  isFocused: pendingTasks[index].id == focusedTaskId,
                  onToggle: () => ref.read(tasksProvider.notifier).toggleTask(pendingTasks[index].id),
                  onDelete: () => ref.read(tasksProvider.notifier).removeTask(pendingTasks[index].id),
                  onFocus: () {
                    ref.read(focusedTaskProvider.notifier).state = pendingTasks[index].id;
                    ref.read(navigationProvider.notifier).state = NavDestination.focus;
                  },
                  onArchive: () => ref.read(tasksProvider.notifier).archiveTask(pendingTasks[index].id),
                  onDuplicate: () => ref.read(tasksProvider.notifier).duplicateTask(pendingTasks[index].id),
                  onRecolor: (color) => ref.read(tasksProvider.notifier).updateTaskColor(pendingTasks[index].id, color),
                  onRename: (title) => ref.read(tasksProvider.notifier).updateTask(pendingTasks[index].id, title),
                );
              }

              final doneStart = pendingTasks.length;
              if (index == doneStart && doneTasks.isNotEmpty) {
                // Completed header
                return Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 4),
                  child: Row(
                    children: [
                      Text(
                        'Completed',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: tokens.textMuted,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Divider(color: tokens.borderSubtle)),
                      if (doneTasks.isNotEmpty)
                        GestureDetector(
                          onTap: () => ref.read(tasksProvider.notifier).clearCompleted(),
                          child: Text(
                            'Clear all',
                            style: TextStyle(fontSize: 11, color: tokens.textMuted),
                          ),
                        ),
                    ],
                  ),
                );
              }

              // Done tasks
              final doneIndex = index - doneStart - 1;
              if (doneIndex >= 0 && doneIndex < doneTasks.length) {
                return _TaskCard(
                  task: doneTasks[doneIndex],
                  tokens: tokens,
                  isFocused: false,
                  onToggle: () => ref.read(tasksProvider.notifier).toggleTask(doneTasks[doneIndex].id),
                  onDelete: () => ref.read(tasksProvider.notifier).removeTask(doneTasks[doneIndex].id),
                  onFocus: () {},
                  onArchive: () => ref.read(tasksProvider.notifier).archiveTask(doneTasks[doneIndex].id),
                  onDuplicate: () => ref.read(tasksProvider.notifier).duplicateTask(doneTasks[doneIndex].id),
                  onRecolor: (_) {},
                  onRename: (_) {},
                );
              }

              // Archived section
              final archStart = doneStart + 1 + doneTasks.length;
              if (index == archStart && archivedTasks.isNotEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 4),
                  child: Row(
                    children: [
                      Text(
                        'Archived',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: tokens.textMuted,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Divider(color: tokens.borderSubtle)),
                    ],
                  ),
                );
              }

              final archIndex = index - archStart - 1;
              if (archIndex >= 0 && archIndex < archivedTasks.length) {
                return _ArchivedTaskItem(
                  task: archivedTasks[archIndex],
                  tokens: tokens,
                );
              }

              return const SizedBox.shrink();
            },
          );
  }

  // ── Habits Tab Tracker Matrix builder ──
  Widget _buildHabitsTab(ThemeTokens tokens, List<Habit> habits, List<HabitCompletion> completions) {
    // Range selector label
    String rangeLabel = '';
    if (_habitView == 'This Week' || _habitView == 'By Week') {
      final monday = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
      final sunday = monday.add(const Duration(days: 6));
      rangeLabel = 'Week of ${monday.month}/${monday.day} - ${sunday.month}/${sunday.day}, ${monday.year}';
    } else if (_habitView == 'By Month') {
      rangeLabel = '${_getMonthName(_selectedDate.month)} ${_selectedDate.year}';
    } else {
      rangeLabel = 'Year of ${_selectedDate.year}';
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Notion-style Tabs and Controls Row
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: tokens.borderSubtle, width: 1),
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 750;
                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            _buildNotionTab('This Week', tokens),
                            _buildNotionTab('By Week', tokens),
                            _buildNotionTab('By Month', tokens),
                            _buildNotionTab('By Year', tokens),
                          ],
                        ),
                      ),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: _buildRangeNavigators(tokens, rangeLabel),
                        ),
                      ),
                    ],
                  );
                } else {
                  return Row(
                    children: [
                      _buildNotionTab('This Week', tokens),
                      _buildNotionTab('By Week', tokens),
                      _buildNotionTab('By Month', tokens),
                      _buildNotionTab('By Year', tokens),
                      const Spacer(),
                      _buildRangeNavigators(tokens, rangeLabel),
                    ],
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 16),

          // Spreadsheet tracker matrix container
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 420),
            child: _buildMatrixTable(tokens, habits, completions),
          ),
          const SizedBox(height: 24),
          _buildHabitAnalyticsSection(tokens, habits, completions),
        ],
      ),
    );
  }

  Widget _buildNotionTab(String view, ThemeTokens tokens) {
    final isSelected = _habitView == view;
    final color = isSelected ? tokens.textPrimary : tokens.textMuted;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _habitView = view;
          _selectedDate = DateTime.now();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? tokens.textPrimary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.table_chart_outlined,
              size: 14,
              color: color,
            ),
            const SizedBox(width: 6),
            Text(
              view,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRangeNavigators(ThemeTokens tokens, String rangeLabel) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _prevRange,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(Icons.chevron_left, size: 16, color: tokens.textMuted),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          rangeLabel,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: tokens.textMuted),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: _nextRange,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(Icons.chevron_right, size: 16, color: tokens.textMuted),
          ),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: _jumpToToday,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            'Today',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tokens.accent),
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildMatrixTable(ThemeTokens tokens, List<Habit> habits, List<HabitCompletion> completions) {
    final activeHabits = habits.where((h) => h.active).toList();
    if (activeHabits.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insights, size: 48, color: tokens.textMuted),
            const SizedBox(height: 12),
            Text('No active habits yet', style: TextStyle(color: tokens.textMuted, fontSize: 13)),
            const SizedBox(height: 16),
            PremiumButton(
              onTap: () => _showHabitModal(),
              child: const Text('Add Habit'),
            ),
          ],
        ),
      );
    }

    // Resolve habit column order
    ref.watch(habitOrderProvider); // Watch for ordering changes
    final orderNotifier = ref.read(habitOrderProvider.notifier);
    final orderedIds = orderNotifier.resolveOrder(activeHabits.map((h) => h.id).toList());
    final orderedHabits = <Habit>[];
    for (final id in orderedIds) {
      final h = activeHabits.firstWhere((h) => h.id == id, orElse: () => activeHabits.first);
      if (!orderedHabits.contains(h)) orderedHabits.add(h);
    }

    // Define time periods (rows)
    List<DateTime> days = [];
    List<String> yearMonths = [];
    final now = DateTime.now();
    final todayStr = now.toIso8601String().substring(0, 10);

    if (_habitView == 'This Week' || _habitView == 'By Week') {
      final monday = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
      days = List.generate(7, (i) => DateTime(monday.year, monday.month, monday.day).add(Duration(days: i)));
    } else if (_habitView == 'By Month') {
      final firstDay = DateTime(_selectedDate.year, _selectedDate.month, 1);
      final lastDay = DateTime(_selectedDate.year, _selectedDate.month + 1, 0).day;
      days = List.generate(lastDay, (i) => firstDay.add(Duration(days: i)));
    } else {
      yearMonths = List.generate(12, (i) => '${_selectedDate.year}-${(i + 1).toString().padLeft(2, '0')}');
    }

    // Calculate dynamic total table width based on current column widths
    const addColWidth = 40.0;

    // Calculate overall average for summary row
    double sumPercentages = 0;
    int countDays = 0;
    if (_habitView == 'By Year') {
      for (final ym in yearMonths) {
        final parts = ym.split('-');
        final y = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        final daysInMonth = DateTime(y, m + 1, 0).day;
        
        int monthDue = 0;
        int monthComp = 0;
        for (int d = 1; d <= daysInMonth; d++) {
          final date = DateTime(y, m, d);
          final dateStr = date.toIso8601String().substring(0, 10);
          for (final h in orderedHabits) {
            if (h.isDueOn(date)) {
              monthDue++;
              if (completions.any((c) => c.habitId == h.id && c.date == dateStr && c.completed)) {
                monthComp++;
              }
            }
          }
        }
        if (monthDue > 0) {
          sumPercentages += (monthComp / monthDue) * 100;
          countDays++;
        }
      }
    } else {
      for (final date in days) {
        final dateStr = date.toIso8601String().substring(0, 10);
        int dayDue = 0;
        int dayComp = 0;
        for (final h in orderedHabits) {
          if (h.isDueOn(date)) {
            dayDue++;
            final isDone = completions.any((c) => c.habitId == h.id && c.date == dateStr && c.completed);
            if (isDone) dayComp++;
          }
        }
        if (dayDue > 0) {
          sumPercentages += (dayComp / dayDue) * 100;
          countDays++;
        }
      }
    }
    final overallAverage = countDays == 0 ? 0.0 : sumPercentages / countDays;

    // Calculate per-habit completion rates for footer
    final Map<String, double> habitRates = {};
    final Map<String, int> habitCompCounts = {};
    final Map<String, int> habitDueCounts = {};
    for (final h in orderedHabits) {
      int due = 0;
      int comp = 0;
      if (_habitView == 'By Year') {
        for (final ym in yearMonths) {
          final parts = ym.split('-');
          final y = int.parse(parts[0]);
          final m = int.parse(parts[1]);
          final dim = DateTime(y, m + 1, 0).day;
          for (int d = 1; d <= dim; d++) {
            final dt = DateTime(y, m, d);
            if (h.isDueOn(dt)) {
              due++;
              final ds = dt.toIso8601String().substring(0, 10);
              if (completions.any((c) => c.habitId == h.id && c.date == ds && c.completed)) comp++;
            }
          }
        }
      } else {
        for (final dt in days) {
          if (h.isDueOn(dt)) {
            due++;
            final ds = dt.toIso8601String().substring(0, 10);
            if (completions.any((c) => c.habitId == h.id && c.date == ds && c.completed)) comp++;
          }
        }
      }
      habitRates[h.id] = due == 0 ? 0.0 : (comp / due) * 100;
      habitCompCounts[h.id] = comp;
      habitDueCounts[h.id] = due;
    }

    return LayoutBuilder(
      builder: (context, tableConstraints) {
        final availableWidth = tableConstraints.maxWidth;
        
        final double baseFirstColWidth = _firstColWidth;
        final double baseCompletedColWidth = _completedColWidth;
        
        double baseTotalWidth = baseFirstColWidth + baseCompletedColWidth + addColWidth + 2;
        for (final h in orderedHabits) {
          baseTotalWidth += _habitColumnWidths[h.id] ?? 140.0;
        }

        // If the table is narrower than the available width, scale columns up to fit
        final double scaleFactor = availableWidth > baseTotalWidth ? (availableWidth / baseTotalWidth) : 1.0;
        
        final firstColWidth = baseFirstColWidth * scaleFactor;
        final completedColWidth = baseCompletedColWidth * scaleFactor;
        
        final Map<String, double> scaledHabitWidths = {};
        for (final h in orderedHabits) {
          scaledHabitWidths[h.id] = (_habitColumnWidths[h.id] ?? 140.0) * scaleFactor;
        }
        
        final double finalTableWidth = availableWidth > baseTotalWidth ? availableWidth : baseTotalWidth;

        return SingleChildScrollView(
          scrollDirection: Axis.vertical,
          physics: const BouncingScrollPhysics(),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Container(
              width: finalTableWidth,
              decoration: BoxDecoration(
                color: tokens.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: tokens.borderSubtle.safeWithOpacity(0.8)),
                boxShadow: [
                  BoxShadow(
                    color: tokens.accent.safeWithOpacity(0.04),
                    blurRadius: 24,
                    spreadRadius: 0,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildTableHeader(tokens, orderedHabits, completions, scaledHabitWidths, firstColWidth, completedColWidth, scaleFactor),
                  // Streak stats row
                  _buildStreakRow(tokens, orderedHabits, scaledHabitWidths, firstColWidth, completedColWidth),
                  
                  if (_habitView == 'By Year')
                    ...yearMonths.map((ym) => _buildYearRow(tokens, ym, orderedHabits, completions, scaledHabitWidths, firstColWidth, completedColWidth))
                  else
                    ...days.map((date) => _buildDayRow(tokens, date, orderedHabits, completions, todayStr, scaledHabitWidths, firstColWidth, completedColWidth)),

                  _buildTableFooter(
                    tokens,
                    orderedHabits,
                    overallAverage,
                    habitRates,
                    habitCompCounts,
                    habitDueCounts,
                    scaledHabitWidths,
                    firstColWidth,
                    completedColWidth,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _getFullWeekdayName(int weekday) {
    const names = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return names[weekday - 1];
  }

  String _getFormattedDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}';
  }

  Widget _buildTableHeader(
    ThemeTokens tokens,
    List<Habit> habits,
    List<HabitCompletion> completions,
    Map<String, double> habitWidths,
    double firstColWidth,
    double completedColWidth,
    double scaleFactor,
  ) {
    final iconSize = ref.watch(habitEmojiSizeProvider);
    return Container(
      decoration: BoxDecoration(
        color: tokens.background.safeWithOpacity(0.3),
        border: Border(bottom: BorderSide(color: tokens.borderSubtle, width: 1)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // First Column header: Day / Month label
            SizedBox(
              width: firstColWidth,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Day',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tokens.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  _buildResizeHandle(tokens, onDrag: (dx) {
                    setState(() {
                      _firstColWidth = (_firstColWidth + dx / scaleFactor).clamp(80.0, 300.0);
                      _saveColumnWidths();
                    });
                  }),
                ],
              ),
            ),
            // Habit columns headers with inline edit, context menu, drag reorder
            ...habits.asMap().entries.map((entry) {
              final idx = entry.key;
              final h = entry.value;
              final color = Color(int.parse(h.color.replaceFirst('#', '0xFF')));
              final colWidth = habitWidths[h.id] ?? 140.0;
              final showText = colWidth >= 80.0;
              final isEditing = _inlineEditHabitId == h.id;
              final isDropTarget = _dragInsertIndex == idx && _draggingHabitId != h.id;

              return SizedBox(
                width: colWidth,
                child: Row(
                  children: [
                    Expanded(
                      child: DragTarget<String>(
                        onWillAcceptWithDetails: (details) {
                          setState(() => _dragInsertIndex = idx);
                          return true;
                        },
                        onLeave: (_) => setState(() => _dragInsertIndex = null),
                        onAcceptWithDetails: (details) {
                          final dragId = details.data;
                          if (dragId == h.id) return;
                          final ids = habits.map((h) => h.id).toList();
                          ids.remove(dragId);
                          ids.insert(idx, dragId);
                          ref.read(habitOrderProvider.notifier).setOrder(ids);
                          setState(() {
                            _draggingHabitId = null;
                            _dragInsertIndex = null;
                          });
                        },
                        builder: (context, candidateData, rejectedData) {
                          return Container(
                            decoration: BoxDecoration(
                              border: isDropTarget ? Border(left: BorderSide(color: tokens.accent, width: 2)) : null,
                            ),
                            child: Draggable<String>(
                              data: h.id,
                              onDragStarted: () => setState(() => _draggingHabitId = h.id),
                              onDragEnd: (_) => setState(() {
                                _draggingHabitId = null;
                                _dragInsertIndex = null;
                              }),
                              feedback: Material(
                                color: Colors.transparent,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: tokens.surface,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))],
                                    border: Border.all(color: color.withValues(alpha: 0.5)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _buildHabitIcon(h.icon, size: iconSize, color: color),
                                      const SizedBox(width: 6),
                                      Text(h.name, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: tokens.textPrimary)),
                                    ],
                                  ),
                                ),
                              ),
                              childWhenDragging: Opacity(
                                opacity: 0.3,
                                child: _buildHeaderCellContent(tokens, h, color, iconSize, showText, isEditing),
                              ),
                              child: GestureDetector(
                                onDoubleTap: () => _startInlineEdit(h),
                                onSecondaryTapUp: (details) => _showHabitContextMenu(context, details.globalPosition, h, tokens),
                                child: _buildHeaderCellContent(tokens, h, color, iconSize, showText, isEditing),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    _buildResizeHandle(tokens, onDrag: (dx) {
                      setState(() {
                        final newWidth = ((_habitColumnWidths[h.id] ?? 140.0) + dx / scaleFactor).clamp(40.0, 400.0);
                        _habitColumnWidths[h.id] = newWidth;
                        _saveColumnWidths();
                      });
                    }),
                  ],
                ),
              );
            }),
            // Completed Column header
            SizedBox(
              width: completedColWidth,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.donut_large_rounded, size: 12, color: tokens.textMuted),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Progress',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tokens.textMuted),
                              textAlign: TextAlign.left,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _buildResizeHandle(tokens, onDrag: (dx) {
                    setState(() {
                      _completedColWidth = (_completedColWidth + dx / scaleFactor).clamp(80.0, 300.0);
                      _saveColumnWidths();
                    });
                  }),
                ],
              ),
            ),
            // "+" Add Habit column
            SizedBox(
              width: 40,
              child: Tooltip(
                message: 'Add new habit',
                child: InkWell(
                  onTap: () => _showHabitModal(),
                  borderRadius: const BorderRadius.only(topRight: Radius.circular(7)),
                  child: Center(
                    child: Icon(Icons.add_rounded, size: 16, color: tokens.textMuted),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Header cell content — extracted for reuse (normal and dragging states)
  Widget _buildHeaderCellContent(ThemeTokens tokens, Habit h, Color color, double iconSize, bool showText, bool isEditing) {
    if (isEditing) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        child: TextField(
          controller: _inlineEditController,
          focusNode: _inlineEditFocusNode,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: tokens.textPrimary),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            filled: true,
            fillColor: tokens.background,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: tokens.accent)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: tokens.accent, width: 1.5)),
          ),
          onSubmitted: (_) => _commitInlineEdit(),
          onEditingComplete: _commitInlineEdit,
        ),
      );
    }
    final parsed = _parseHabitName(h);
    return Tooltip(
      message: '${h.name} — Streak: ${h.streak}🔥 (Best: ${h.bestStreak}🏆)\nDouble-click to rename · Right-click for options',
      child: InkWell(
        onTap: () => _showHabitModal(habit: h),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              showText
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildHabitIcon(h.icon, size: iconSize, color: color),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            parsed.title,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: tokens.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    )
                  : _buildHabitIcon(h.icon, size: iconSize, color: color),
              if (showText && parsed.subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  parsed.subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w400,
                    color: tokens.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Streak stats row — shows current streak for each habit
  Widget _buildStreakRow(
    ThemeTokens tokens,
    List<Habit> habits,
    Map<String, double> habitWidths,
    double firstColWidth,
    double completedColWidth,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: tokens.accent.safeWithOpacity(0.01),
        border: Border(bottom: BorderSide(color: tokens.borderSubtle.safeWithOpacity(0.2), width: 0.8)),
      ),
      child: Row(
        children: [
          // First col: label
          SizedBox(
            width: firstColWidth,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border(right: BorderSide(color: tokens.borderSubtle.safeWithOpacity(0.15), width: 1)),
              ),
              child: Text(
                '🔥 Streak',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: tokens.textMuted, letterSpacing: 0.3),
              ),
            ),
          ),
          // Per-habit streak
          ...habits.map((h) {
            final colWidth = habitWidths[h.id] ?? 140.0;
            final streak = h.streak;
            return SizedBox(
              width: colWidth,
              child: Container(
                height: 28,
                decoration: BoxDecoration(
                  border: Border(right: BorderSide(color: tokens.borderSubtle.safeWithOpacity(0.15), width: 1)),
                ),
                child: Center(
                  child: Text(
                    streak > 0 ? '🔥 $streak' : '—',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: streak > 0 ? const Color(0xFFEF8C2D) : tokens.textMuted,
                    ),
                  ),
                ),
              ),
            );
          }),
          // Completed col: empty
          SizedBox(
            width: completedColWidth,
            child: Container(
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: const SizedBox.shrink(),
            ),
          ),
          // Add col spacer
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildDayRow(
    ThemeTokens tokens,
    DateTime date,
    List<Habit> habits,
    List<HabitCompletion> completions,
    String todayStr,
    Map<String, double> habitWidths,
    double firstColWidth,
    double completedColWidth,
  ) {
    final dateStr = date.toIso8601String().substring(0, 10);
    final isToday = dateStr == todayStr;
    final isFuture = date.isAfter(DateTime.now()) && !isToday;

    int totalDue = 0;
    int completedCount = 0;
    for (final h in habits) {
      if (h.isDueOn(date)) {
        totalDue++;
        final isDone = completions.any((c) => c.habitId == h.id && c.date == dateStr && c.completed);
        if (isDone) completedCount++;
      }
    }
    final double rowCompletionPercent = totalDue == 0 ? 0.0 : (completedCount / totalDue) * 100;

    return _HoverableRow(
      tokens: tokens,
      isToday: isToday,
      child: (isHovered) => Container(
        decoration: BoxDecoration(
          color: isToday
              ? tokens.accent.safeWithOpacity(0.04)
              : isHovered
                  ? tokens.textMuted.safeWithOpacity(0.03)
                  : Colors.transparent,
          border: Border(
            bottom: BorderSide(color: tokens.borderSubtle.safeWithOpacity(0.2), width: 0.8),
            left: isToday ? BorderSide(color: tokens.accent, width: 4) : BorderSide.none,
          ),
        ),
        child: Row(
          children: [
            // Cell 1: Day Label
            SizedBox(
              width: isToday ? firstColWidth - 4 : firstColWidth,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                decoration: BoxDecoration(
                  border: Border(right: BorderSide(color: tokens.borderSubtle.safeWithOpacity(0.15), width: 1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _getFullWeekdayName(date.weekday),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                        color: isToday ? tokens.accent : tokens.textPrimary,
                      ),
                    ),
                    if (isToday) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: tokens.accent.safeWithOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: tokens.accent.safeWithOpacity(0.15), width: 1),
                        ),
                        child: Text(
                          'TODAY',
                          style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: tokens.accent, letterSpacing: 0.5),
                        ),
                      ),
                    ],
                    if (!isToday && _habitView == 'By Month' && firstColWidth >= 110.0) ...[
                      const SizedBox(width: 8),
                      Text(
                        _getFormattedDate(date),
                        style: TextStyle(fontSize: 10, color: tokens.textMuted),
                      ),
                    ],
                    if (isToday && _habitView == 'By Month' && firstColWidth >= 170.0) ...[
                      const SizedBox(width: 6),
                      Text(
                        _getFormattedDate(date),
                        style: TextStyle(fontSize: 10, color: tokens.textMuted),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Habit cells (checkmarks) with color-tinted backgrounds
            ...habits.map((h) {
              final colWidth = habitWidths[h.id] ?? 140.0;
              final isDue = h.isDueOn(date);
              final completion = completions.firstWhere(
                (c) => c.habitId == h.id && c.date == dateStr && c.completed,
                orElse: () => HabitCompletion(id: '', habitId: '', date: '', completed: false, timestamp: date),
              );
              final isDone = completion.id.isNotEmpty;
              final habitColor = Color(int.parse(h.color.replaceFirst('#', '0xFF')));
              final hasNote = isDone && completion.notes != null && completion.notes!.isNotEmpty;

              if (!isDue) {
                return SizedBox(
                  width: colWidth,
                  child: Container(
                    height: 36,
                    decoration: BoxDecoration(
                      border: Border(right: BorderSide(color: tokens.borderSubtle.safeWithOpacity(0.15), width: 1)),
                    ),
                    child: const Center(
                      child: Text('-', style: TextStyle(color: Colors.transparent)),
                    ),
                  ),
                );
              }

              return SizedBox(
                width: colWidth,
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: isDone ? habitColor.safeWithOpacity(0.04) : Colors.transparent,
                    border: Border(right: BorderSide(color: tokens.borderSubtle.safeWithOpacity(0.15), width: 1)),
                  ),
                  child: Center(
                    child: _HabitGridCheckbox(
                      isDone: isDone,
                      isFuture: isFuture,
                      habitColor: habitColor,
                      tokens: tokens,
                      hasNote: hasNote,
                      onTap: () => ref.read(habitCompletionsProvider.notifier).toggleCompletion(h.id, date),
                      onLongPress: isDone && !isFuture
                          ? () => _showNotesPopover(context, h.id, date, tokens)
                          : null,
                      onSecondaryTapUp: isDone && !isFuture
                          ? (details) => _showNotesPopover(context, h.id, date, tokens)
                          : null,
                    ),
                  ),
                ),
              );
            }),
            // Completed progress cell with circular progress wheel
            SizedBox(
              width: completedColWidth,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _CircularProgressWheel(
                      value: rowCompletionPercent / 100,
                      size: 16,
                      color: tokens.accent,
                      tokens: tokens,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${rowCompletionPercent.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: tokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Add col spacer
            const SizedBox(width: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildYearRow(
    ThemeTokens tokens,
    String yearMonthStr,
    List<Habit> habits,
    List<HabitCompletion> completions,
    Map<String, double> habitWidths,
    double firstColWidth,
    double completedColWidth,
  ) {
    final parts = yearMonthStr.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final daysInMonth = DateTime(year, month + 1, 0).day;

    int totalDue = 0;
    int completedCount = 0;

    for (int d = 1; d <= daysInMonth; d++) {
      final date = DateTime(year, month, d);
      final dateStr = date.toIso8601String().substring(0, 10);
      for (final h in habits) {
        if (h.isDueOn(date)) {
          totalDue++;
          if (completions.any((c) => c.habitId == h.id && c.date == dateStr && c.completed)) {
            completedCount++;
          }
        }
      }
    }
    final double monthCompletionPercent = totalDue == 0 ? 0.0 : (completedCount / totalDue) * 100;

    return _HoverableRow(
      tokens: tokens,
      isToday: false,
      child: (isHovered) => Container(
        decoration: BoxDecoration(
          color: isHovered ? tokens.textMuted.safeWithOpacity(0.03) : Colors.transparent,
          border: Border(bottom: BorderSide(color: tokens.borderSubtle.safeWithOpacity(0.2), width: 0.8)),
        ),
        child: Row(
          children: [
            // Cell 1: Month Label
            SizedBox(
              width: firstColWidth,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border(right: BorderSide(color: tokens.borderSubtle.safeWithOpacity(0.15), width: 1)),
                ),
                child: Text(
                  _getMonthName(month),
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: tokens.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            // Habit progress percentages
            ...habits.map((h) {
              final colWidth = habitWidths[h.id] ?? 140.0;
              int hDue = 0;
              int hComp = 0;
              for (int d = 1; d <= daysInMonth; d++) {
                final date = DateTime(year, month, d);
                final dateStr = date.toIso8601String().substring(0, 10);
                if (h.isDueOn(date)) {
                  hDue++;
                  if (completions.any((c) => c.habitId == h.id && c.date == dateStr && c.completed)) {
                    hComp++;
                  }
                }
              }
              final double hPercent = hDue == 0 ? 0.0 : (hComp / hDue) * 100;
              final color = Color(int.parse(h.color.replaceFirst('#', '0xFF')));

              return SizedBox(
                width: colWidth,
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: hPercent > 50 ? color.safeWithOpacity(0.04) : Colors.transparent,
                    border: Border(right: BorderSide(color: tokens.borderSubtle.safeWithOpacity(0.15), width: 1)),
                  ),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: hPercent > 0 ? color.safeWithOpacity(0.1) : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: hPercent > 0 ? Border.all(color: color.safeWithOpacity(0.2), width: 0.8) : null,
                      ),
                      child: Text(
                        '${hPercent.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: hPercent > 0 ? color : tokens.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
            // Completed progress cell with gradient progress bar
            SizedBox(
              width: completedColWidth,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${monthCompletionPercent.toStringAsFixed(0)}%',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tokens.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    _buildGradientProgressBar(monthCompletionPercent, tokens),
                  ],
                ),
              ),
            ),
            // Add col spacer
            const SizedBox(width: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildTableFooter(
    ThemeTokens tokens,
    List<Habit> habits,
    double average,
    Map<String, double> habitRates,
    Map<String, int> habitCompCounts,
    Map<String, int> habitDueCounts,
    Map<String, double> habitWidths,
    double firstColWidth,
    double completedColWidth,
  ) {
    final String rateLabel = _habitView == 'By Month'
        ? 'Monthly Rate'
        : _habitView == 'By Year'
            ? 'Yearly Rate'
            : 'Weekly Rate';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: tokens.background.safeWithOpacity(0.1),
        border: Border(top: BorderSide(color: tokens.borderSubtle.safeWithOpacity(0.6), width: 1)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: firstColWidth,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                border: Border(right: BorderSide(color: tokens.borderSubtle.safeWithOpacity(0.15), width: 1)),
              ),
              child: Text(
                rateLabel,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: tokens.textSecondary),
              ),
            ),
          ),
          ...habits.map((h) {
            final colWidth = habitWidths[h.id] ?? 140.0;
            final rate = habitRates[h.id] ?? 0.0;
            final comp = habitCompCounts[h.id] ?? 0;
            final due = habitDueCounts[h.id] ?? 0;
            final color = Color(int.parse(h.color.replaceFirst('#', '0xFF')));
            return SizedBox(
              width: colWidth,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  border: Border(right: BorderSide(color: tokens.borderSubtle.safeWithOpacity(0.15), width: 1)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${rate.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: rate > 0 ? color : tokens.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$comp/$due days',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w400,
                        color: tokens.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          SizedBox(
            width: completedColWidth,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'AVG ${average.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: tokens.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _CircularProgressWheel(
                    value: average / 100,
                    size: 16,
                    color: tokens.accent,
                    tokens: tokens,
                  ),
                ],
              ),
            ),
          ),
          // Add col spacer
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildGradientProgressBar(double percentage, ThemeTokens tokens) {
    final double fraction = (percentage / 100).clamp(0.0, 1.0);
    
    final List<Color> colors;
    if (percentage >= 100) {
      colors = [const Color(0xFF10B981), const Color(0xFF059669)];
    } else if (percentage >= 50) {
      colors = [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)];
    } else if (percentage > 0) {
      colors = [const Color(0xFF6B7280), const Color(0xFF4B5563)];
    } else {
      colors = [Colors.transparent, Colors.transparent];
    }

    return Container(
      height: 6,
      width: double.infinity,
      decoration: BoxDecoration(
        color: tokens.borderSubtle.safeWithOpacity(0.15),
        borderRadius: BorderRadius.circular(3),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: fraction,
        child: fraction > 0
            ? Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: colors,
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: percentage >= 50
                      ? [
                          BoxShadow(
                            color: colors[0].safeWithOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          )
                        ]
                      : [],
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildHabitProgressBar(double percentage, Color color, ThemeTokens tokens) {
    final double fraction = (percentage / 100).clamp(0.0, 1.0);
    return Container(
      height: 5,
      width: double.infinity,
      decoration: BoxDecoration(
        color: tokens.borderSubtle.safeWithOpacity(0.15),
        borderRadius: BorderRadius.circular(2.5),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: fraction,
        child: fraction > 0
            ? Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.safeWithOpacity(0.7)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(2.5),
                  boxShadow: [
                    BoxShadow(
                      color: color.safeWithOpacity(0.25),
                      blurRadius: 3,
                    )
                  ],
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  // ── Habit Analytics Section ──
  Widget _buildHabitAnalyticsSection(ThemeTokens tokens, List<Habit> habits, List<HabitCompletion> completions) {
    final analytics = ref.watch(analyticsProvider);
    final activeHabits = habits.where((h) => h.active).toList();
    if (activeHabits.isEmpty) return const SizedBox.shrink();
    
    final todayPct = analytics.habitCompletionTodayPercent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Analytics header
        Row(
          children: [
            Icon(Icons.analytics_rounded, size: 16, color: tokens.textPrimary),
            const SizedBox(width: 8),
            Text(
              'Habit Analytics',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: tokens.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Your consistency at a glance',
              style: TextStyle(fontSize: 12, color: tokens.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Stat cards row
        _buildHabitStatCards(tokens, todayPct, activeHabits, completions, analytics),

        const SizedBox(height: 20),

        // Trend chart section
        _buildHabitTrendChart(tokens, analytics),
      ],
    );
  }

  Widget _buildHabitStatCards(
    ThemeTokens tokens,
    double todayPercent,
    List<Habit> activeHabits,
    List<HabitCompletion> completions,
    AnalyticsState analytics,
  ) {
    // Current max streak
    
    final cards = <_StatCardData>[
      _StatCardData(
        icon: Icons.today_rounded,
        label: 'Today',
        value: '${todayPercent.toStringAsFixed(0)}%',
        color: const Color(0xFF6366F1),
        subtitle: '${activeHabits.length} habits due',
      ),
      _StatCardData(
        icon: Icons.local_fire_department_rounded,
        label: 'Best Streak',
        value: '${analytics.bestHabitStreak}',
        color: const Color(0xFFEF8C2D),
        subtitle: 'days',
        suffix: '🔥',
      ),
      _StatCardData(
        icon: Icons.calendar_view_week_rounded,
        label: 'This Week',
        value: '${analytics.thisWeekHabitPercent.toStringAsFixed(0)}%',
        color: const Color(0xFF2383E2),
        subtitle: 'consistency',
      ),
      _StatCardData(
        icon: Icons.date_range_rounded,
        label: 'This Month',
        value: '${analytics.thisMonthHabitPercent.toStringAsFixed(0)}%',
        color: const Color(0xFF0F7B5F),
        subtitle: 'consistency',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final useCompact = constraints.maxWidth < 700;
        if (useCompact) {
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: cards.map((c) => SizedBox(
              width: (constraints.maxWidth - 12) / 2,
              child: _buildStatCard(tokens, c),
            )).toList(),
          );
        }
        return Row(
          children: cards.map((c) => Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: cards.last == c ? 0 : 12),
              child: _buildStatCard(tokens, c),
            ),
          )).toList(),
        );
      },
    );
  }

  Widget _buildStatCard(ThemeTokens tokens, _StatCardData data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: data.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(data.icon, size: 16, color: data.color),
              ),
              const Spacer(),
              if (data.suffix != null)
                Text(data.suffix!, style: const TextStyle(fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            data.value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: tokens.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            data.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: tokens.textSecondary,
            ),
          ),
          if (data.subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              data.subtitle!,
              style: TextStyle(
                fontSize: 10,
                color: tokens.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHabitTrendChart(ThemeTokens tokens, AnalyticsState analytics) {
    List<double> trendData;
    List<String> labels;
    String chartLabel;
    Color lineColor;

    switch (_habitAnalyticsRange) {
      case '30D':
        trendData = analytics.habitTrend30D;
        labels = analytics.habitTrendDates30D
            .map((d) => '${d.month}/${d.day}')
            .toList();
        chartLabel = 'Last 30 Days';
        lineColor = const Color(0xFF2383E2);
        break;
      case '90D':
        trendData = analytics.habitTrend90D;
        labels = analytics.habitTrendDates90D
            .map((d) => '${d.month}/${d.day}')
            .toList();
        chartLabel = 'Last 90 Days';
        lineColor = const Color(0xFF0F7B5F);
        break;
      default: // 7D
        trendData = analytics.habitTrend7D;
        const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        labels = analytics.habitTrendDates7D
            .map((d) => weekdays[d.weekday - 1])
            .toList();
        chartLabel = 'Last 7 Days';
        lineColor = const Color(0xFF6366F1);
        break;
    }

    // Build spots from data
    final spots = <FlSpot>[];
    for (int i = 0; i < trendData.length; i++) {
      spots.add(FlSpot(i.toDouble(), trendData[i]));
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with title and range toggle
          Row(
            children: [
              Icon(Icons.trending_up_rounded, size: 16, color: tokens.textPrimary),
              const SizedBox(width: 8),
              Text(
                'Completion Rate',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                chartLabel,
                style: TextStyle(fontSize: 11, color: tokens.textMuted),
              ),
              const Spacer(),
              // Range toggle buttons
              ...['7D', '30D', '90D'].map((range) {
                final isSelected = _habitAnalyticsRange == range;
                return GestureDetector(
                  onTap: () => setState(() => _habitAnalyticsRange = range),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    margin: const EdgeInsets.only(left: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? lineColor.withValues(alpha: 0.15) : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isSelected ? lineColor.withValues(alpha: 0.4) : tokens.borderSubtle,
                      ),
                    ),
                    child: Text(
                      range,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? lineColor : tokens.textMuted,
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 20),

          // Chart
          SizedBox(
            height: 200,
            child: spots.isEmpty
                ? Center(
                    child: Text(
                      'Not enough data yet',
                      style: TextStyle(color: tokens.textMuted, fontSize: 13),
                    ),
                  )
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 25,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: tokens.borderSubtle.safeWithOpacity(0.3),
                            strokeWidth: 1,
                          );
                        },
                      ),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 22,
                            interval: _habitAnalyticsRange == '7D' ? 1 : (_habitAnalyticsRange == '30D' ? 5 : 15),
                            getTitlesWidget: (value, meta) {
                              final idx = value.toInt();
                              if (idx < 0 || idx >= labels.length) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  labels[idx],
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: tokens.textMuted,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 36,
                            interval: 25,
                            getTitlesWidget: (value, meta) {
                              if (value == meta.min || value == meta.max) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Text(
                                  '${value.toInt()}%',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: tokens.textMuted,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      minX: 0,
                      maxX: (trendData.length - 1).toDouble(),
                      minY: 0,
                      maxY: 100,
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          curveSmoothness: 0.3,
                          color: lineColor,
                          barWidth: 2.5,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: trendData.length <= 30,
                            getDotPainter: (spot, percent, barData, index) {
                              return FlDotCirclePainter(
                                radius: 3,
                                color: lineColor,
                                strokeWidth: 2,
                                strokeColor: tokens.surface,
                              );
                            },
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            color: lineColor.withValues(alpha: 0.08),
                          ),
                        ),
                      ],
                      lineTouchData: LineTouchData(
                        enabled: true,
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipItems: (touchedSpots) {
                            return touchedSpots.map((spot) {
                              final idx = spot.spotIndex;
                              final label = idx < labels.length ? labels[idx] : '';
                              return LineTooltipItem(
                                '$label\n${spot.y.toStringAsFixed(0)}%',
                                const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              );
                            }).toList();
                          },
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _showHabitModal({Habit? habit}) {
    showDialog(
      context: context,
      builder: (context) => _HabitModalDialog(
        habit: habit,
        tokens: FocusOsTheme.of(context),
        onSave: (name, icon, color, frequency, customWeekdays, reminderTime) {
          if (habit == null) {
            ref.read(habitsProvider.notifier).addHabit(
              name,
              icon,
              color,
              frequency,
              customWeekdays: customWeekdays,
              reminderTime: reminderTime,
            );
          } else {
            ref.read(habitsProvider.notifier).updateHabit(
              habit.copyWith(
                name: name,
                icon: icon,
                color: color,
                frequency: frequency,
                customWeekdays: customWeekdays,
                reminderTime: reminderTime,
              ),
            );
          }
        },
        onDelete: habit == null
            ? null
            : () {
                ref.read(habitsProvider.notifier).deleteHabit(habit.id);
              },
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Goals Tab Implementation
  // ──────────────────────────────────────────────

  Widget _buildIntimidatingCountdownCard(ThemeTokens tokens, List<TimelineGoal> goals) {
    final pinnedGoalId = ref.watch(pinnedGoalIdProvider);
    final activeGoals = goals.where((g) => !g.isCompleted).toList();

    TimelineGoal? pinnedGoal;
    if (pinnedGoalId != null) {
      final matches = goals.where((g) => g.id == pinnedGoalId);
      if (matches.isNotEmpty) {
        pinnedGoal = matches.first;
      }
    }

    // Fallbacks to ensure a primary goal is always shown if there is at least one goal
    if (pinnedGoal == null && activeGoals.isNotEmpty) {
      pinnedGoal = activeGoals.first;
    }
    if (pinnedGoal == null && goals.isNotEmpty) {
      pinnedGoal = goals.first;
    }

    if (pinnedGoal == null) {
      return const SizedBox.shrink();
    }

    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    final targetMidnight = DateTime(pinnedGoal.targetDate.year, pinnedGoal.targetDate.month, pinnedGoal.targetDate.day);
    final daysLeft = targetMidnight.difference(todayMidnight).inDays;

    final goalColor = _parseColorSafe(pinnedGoal.color);

    final createdMidnight = DateTime(pinnedGoal.createdAt.year, pinnedGoal.createdAt.month, pinnedGoal.createdAt.day);
    final totalDays = targetMidnight.difference(createdMidnight).inDays;
    
    double progress = 0.0;
    if (pinnedGoal.isCompleted) {
      progress = 1.0;
    } else if (totalDays > 0) {
      final elapsed = todayMidnight.difference(createdMidnight).inDays;
      progress = (elapsed / totalDays).clamp(0.0, 1.0);
    } else {
      progress = todayMidnight.isAfter(targetMidnight) ? 1.0 : 0.0;
    }

    final popupItems = <PopupMenuEntry<String>>[
      ...activeGoals.map((g) => PopupMenuItem<String>(
            value: g.id,
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _parseColorSafe(g.color),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(g.title, style: TextStyle(color: tokens.textPrimary, fontSize: 13))),
                if (g.id == pinnedGoal!.id)
                  Icon(Icons.check_circle_rounded, size: 16, color: tokens.accent),
              ],
            ),
          )),
      if (pinnedGoalId != null) ...[
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'clear',
          child: Row(
            children: const [
              Icon(Icons.clear_all_rounded, size: 16, color: Colors.redAccent),
              SizedBox(width: 8),
              Text('Clear Pinned Ticker', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
            ],
          ),
        ),
      ]
    ];

    final daysStr = daysLeft.clamp(0, 9999).toString();
    final digits = daysStr.split('');
    final isDark = tokens.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.08 : 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: goalColor, width: 6),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Row (Dot + UpperCase Title, SWITCH button)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: goalColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        pinnedGoal.title.toUpperCase(),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: tokens.textPrimary,
                          letterSpacing: 0.8,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    PopupMenuButton<String>(
                      itemBuilder: (_) => popupItems,
                      onSelected: (val) {
                        if (val == 'clear') {
                          ref.read(pinnedGoalIdProvider.notifier).setPinnedGoalId(null);
                        } else {
                          ref.read(pinnedGoalIdProvider.notifier).setPinnedGoalId(val);
                        }
                      },
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: tokens.surfaceAlt,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: tokens.borderSubtle),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'SWITCH',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: tokens.textSecondary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.arrow_drop_down, size: 14, color: tokens.textSecondary),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Content Box (Light Blue Background, illustration on right)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? [
                              tokens.surfaceAlt.withOpacity(0.4),
                              tokens.surfaceAlt.withOpacity(0.2),
                            ]
                          : [
                              const Color(0xFFF3F7FA),
                              const Color(0xFFEDF2F7),
                            ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? tokens.borderSubtle : const Color(0xFFE2E8F0),
                    ),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final showSideIllustration = constraints.maxWidth > 580;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Hourglass Row
                                    Row(
                                      children: [
                                        Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: isDark ? tokens.surface : Colors.white,
                                            border: Border.all(
                                              color: goalColor.withOpacity(0.15),
                                              width: 1.5,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.02),
                                                blurRadius: 6,
                                              ),
                                            ],
                                          ),
                                          child: Center(
                                            child: Icon(
                                              Icons.hourglass_bottom_rounded,
                                              color: goalColor,
                                              size: 22,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                "You've got this!",
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.w800,
                                                  color: tokens.textPrimary,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                "Consistent effort today builds success tomorrow.",
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: tokens.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 20),

                                    // Countdown digits
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        ...digits.map((digit) {
                                          return Container(
                                            margin: const EdgeInsets.only(right: 6),
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                            decoration: BoxDecoration(
                                              color: isDark ? tokens.surface : Colors.white,
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(
                                                color: isDark ? tokens.borderSubtle : const Color(0xFFE2E8F0),
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(isDark ? 0.1 : 0.03),
                                                  blurRadius: 6,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Text(
                                              digit,
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 44,
                                                fontWeight: FontWeight.w800,
                                                color: tokens.textPrimary,
                                                height: 1.1,
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                        const SizedBox(width: 8),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              "days",
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: tokens.textSecondary,
                                              ),
                                            ),
                                            Text(
                                              "left",
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: tokens.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (showSideIllustration) ...[
                                const SizedBox(width: 16),
                                SizedBox(
                                  width: 260,
                                  height: 135,
                                  child: CustomPaint(
                                    painter: _MountainPainter(
                                      themeColor: goalColor,
                                      isDark: isDark,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),

                          const SizedBox(height: 20),

                          // Progress bar
                          _buildProgressBar(progress, goalColor, tokens, pinnedGoal!.targetDate),
                        ],
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Sprout footer
              Padding(
                padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F2D24) : const Color(0xFFEDF7F4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF1B4E3E).withOpacity(0.5)
                          : const Color(0xFFDCF2EB),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark ? const Color(0xFF164E3E) : const Color(0xFFDCF2EB),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.eco_rounded,
                            color: Color(0xFF10B981),
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Small steps every day lead to big achievements. Keep going!",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFFA7F3D0) : const Color(0xFF2C5E43),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () => _showViewPlanDialog(pinnedGoal!),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isDark ? const Color(0xFFA7F3D0).withOpacity(0.4) : const Color(0xFF3B82F6).withOpacity(0.4),
                              ),
                            ),
                            child: Text(
                              "View Plan →",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isDark ? const Color(0xFFA7F3D0) : const Color(0xFF3B82F6),
                              ),
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
      ),
    );
  }

  Widget _buildProgressBar(double progress, Color color, ThemeTokens tokens, DateTime targetDate) {
    final pct = (progress * 100).toStringAsFixed(0);
    final formattedTarget = _getFormattedDate(targetDate);
    final isDark = tokens.brightness == Brightness.dark;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          alignment: Alignment.centerLeft,
          children: [
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: isDark ? tokens.borderSubtle : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final activeWidth = constraints.maxWidth * progress;
                return Container(
                  width: activeWidth,
                  height: 6,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              },
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final leftOffset = (constraints.maxWidth * progress) - 4;
                return Positioned(
                  left: leftOffset.clamp(0.0, constraints.maxWidth - 8),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.4),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$pct% complete',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: tokens.textMuted,
              ),
            ),
            Text(
              'Target: $formattedTarget',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: tokens.textMuted,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showViewPlanDialog(TimelineGoal goal) {
    final tokens = FocusOsTheme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: tokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: tokens.borderSubtle),
        ),
        title: Text(
          'Goal Plan: ${goal.title}',
          style: GoogleFonts.plusJakartaSans(color: tokens.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: Text(
          (goal.notes != null && goal.notes!.trim().isNotEmpty)
              ? goal.notes!
              : 'No plan notes defined for this goal yet.',
          style: TextStyle(color: tokens.textSecondary, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close', style: TextStyle(color: tokens.accent)),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalsTab(ThemeTokens tokens, List<TimelineGoal> goals) {
    if (goals.isEmpty) {
      return _GoalsEmptyState(
        tokens: tokens,
        onCreateGoal: () => _showGoalModal(),
      );
    }
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cardWidth = width > 768 ? 360.0 : double.infinity;
        
        return ListView(
          physics: const BouncingScrollPhysics(parent: ClampingScrollPhysics()),
          padding: const EdgeInsets.only(top: 8, bottom: 32),
          children: [
            _buildIntimidatingCountdownCard(tokens, goals),
            const SizedBox(height: 24),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: goals.map((goal) {
                return SizedBox(
                  width: cardWidth == double.infinity ? null : cardWidth,
                  child: _buildGoalCard(tokens, goal),
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGoalCard(ThemeTokens tokens, TimelineGoal goal) {
    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    final targetMidnight = DateTime(goal.targetDate.year, goal.targetDate.month, goal.targetDate.day);
    final createdMidnight = DateTime(goal.createdAt.year, goal.createdAt.month, goal.createdAt.day);

    final daysLeft = targetMidnight.difference(todayMidnight).inDays;
    final totalDays = targetMidnight.difference(createdMidnight).inDays;
    
    double progress = 0.0;
    if (goal.isCompleted) {
      progress = 1.0;
    } else if (totalDays > 0) {
      final elapsed = todayMidnight.difference(createdMidnight).inDays;
      progress = (elapsed / totalDays).clamp(0.0, 1.0);
    } else {
      progress = todayMidnight.isAfter(targetMidnight) ? 1.0 : 0.0;
    }

    final goalColor = _parseColorSafe(goal.color);
    final isDark = tokens.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.08 : 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row (Checkbox Circle, Title, Options Menu)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () {
                    ref.read(timelineGoalsProvider.notifier).toggleGoalCompletion(goal.id);
                  },
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: goal.isCompleted ? const Color(0xFF10B981) : tokens.textMuted,
                          width: 2,
                        ),
                        color: goal.isCompleted ? const Color(0xFF10B981).withOpacity(0.1) : Colors.transparent,
                      ),
                      child: goal.isCompleted
                          ? const Center(
                              child: Icon(
                                Icons.check,
                                size: 12,
                                color: Color(0xFF10B981),
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: goal.isCompleted ? tokens.textMuted : tokens.textPrimary,
                          decoration: goal.isCompleted ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_outlined, size: 12, color: tokens.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            'Target: ${_getFormattedDate(goal.targetDate)}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: tokens.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTapDown: (details) {
                    _showGoalContextMenu(context, details.globalPosition, goal);
                  },
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Icon(
                      Icons.more_vert,
                      size: 18,
                      color: tokens.textMuted,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),

            // Inner Progress Card
            Container(
              decoration: BoxDecoration(
                color: isDark
                    ? tokens.surfaceAlt.withOpacity(0.3)
                    : const Color(0xFFF1F6FB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? tokens.borderSubtle : const Color(0xFFE2E8F0),
                ),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Progress Column
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "PROGRESS",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: tokens.textMuted,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "${(progress * 100).toStringAsFixed(0)}%",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: goalColor,
                            ),
                          ),
                        ],
                      ),
                      // Days Left Column
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            "DAYS LEFT",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: tokens.textMuted,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                daysLeft.clamp(0, 9999).toString(),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: tokens.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                "days",
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: tokens.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Progress Bar Track
                  Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      Container(
                        height: 5,
                        decoration: BoxDecoration(
                          color: isDark ? tokens.borderSubtle : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(2.5),
                        ),
                      ),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          return Container(
                            width: constraints.maxWidth * progress,
                            height: 5,
                            decoration: BoxDecoration(
                              color: goalColor,
                              borderRadius: BorderRadius.circular(2.5),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Motivation text
            Text(
              "Let's make today count. 💪",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: tokens.textSecondary,
              ),
            ),

            const SizedBox(height: 12),

            // Interactive Inline Notes
            _InlineGoalNoteField(
              goal: goal,
              tokens: tokens,
              onSave: (newNote) {
                ref.read(timelineGoalsProvider.notifier).updateGoal(
                  goal.copyWith(notes: newNote),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showGoalContextMenu(BuildContext context, Offset position, TimelineGoal goal) async {
    final tokens = FocusOsTheme.of(context);
    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx + 1, position.dy + 1),
      color: tokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: tokens.borderSubtle),
      ),
      items: [
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 16, color: tokens.textSecondary),
              const SizedBox(width: 8),
              Text('Edit Goal', style: TextStyle(color: tokens.textPrimary, fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'toggle',
          child: Row(
            children: [
              Icon(
                goal.isCompleted ? Icons.radio_button_off : Icons.check_circle_outline,
                size: 16,
                color: tokens.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                goal.isCompleted ? 'Mark Active' : 'Mark Completed',
                style: TextStyle(color: tokens.textPrimary, fontSize: 13),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: const [
              Icon(Icons.delete_outline, size: 16, color: Color(0xFFEF4444)),
              SizedBox(width: 8),
              Text('Delete Goal', style: TextStyle(color: Color(0xFFEF4444), fontSize: 13)),
            ],
          ),
        ),
      ],
    );
    
    if (result == null || !mounted) return;
    
    switch (result) {
      case 'edit':
        _showGoalModal(goal: goal);
        break;
      case 'toggle':
        ref.read(timelineGoalsProvider.notifier).toggleGoalCompletion(goal.id);
        break;
      case 'delete':
        ref.read(timelineGoalsProvider.notifier).deleteGoal(goal.id);
        break;
    }
  }

  void _showGoalModal({TimelineGoal? goal}) {
    final tokens = FocusOsTheme.of(context);
    showDialog(
      context: context,
      builder: (context) => _GoalModalDialog(
        goal: goal,
        tokens: tokens,
        onSave: (title, targetDate, notes, color) {
          if (goal == null) {
            ref.read(timelineGoalsProvider.notifier).addGoal(
              title,
              targetDate,
              notes: notes,
              color: color,
            );
          } else {
            ref.read(timelineGoalsProvider.notifier).updateGoal(
              goal.copyWith(
                title: title,
                targetDate: targetDate,
                notes: notes,
                color: color,
              ),
            );
          }
        },
      ),
    );
  }
}

class _GoalsEmptyState extends StatelessWidget {
  final ThemeTokens tokens;
  final VoidCallback onCreateGoal;

  const _GoalsEmptyState({required this.tokens, required this.onCreateGoal});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: tokens.borderSubtle),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: tokens.brightness == Brightness.light ? 0.02 : 0.1),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: tokens.borderSubtle,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.track_changes_rounded,
                  size: 28, color: tokens.textMuted),
            ),
            const SizedBox(height: 12),
            Text('No countdown goals yet',
                style: TextStyle(fontSize: 15, color: tokens.textMuted, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Set your first target date goal to visualize your timeline',
                style: TextStyle(fontSize: 12, color: tokens.textMuted)),
            const SizedBox(height: 20),
            PremiumButton(
              onTap: onCreateGoal,
              variant: PremiumButtonVariant.primary,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.add, size: 14, color: Colors.white),
                  SizedBox(width: 6),
                  Text('Set Timeline Goal'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalModalDialog extends StatefulWidget {
  final TimelineGoal? goal;
  final ThemeTokens tokens;
  final Function(String title, DateTime targetDate, String? notes, String color) onSave;

  const _GoalModalDialog({
    this.goal,
    required this.tokens,
    required this.onSave,
  });

  @override
  State<_GoalModalDialog> createState() => _GoalModalDialogState();
}

class _GoalModalDialogState extends State<_GoalModalDialog> {
  late TextEditingController _titleController;
  late TextEditingController _notesController;
  late DateTime _selectedDate;
  late String _selectedColor;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.goal?.title ?? '');
    _notesController = TextEditingController(text: widget.goal?.notes ?? '');
    _selectedDate = widget.goal?.targetDate ?? DateTime.now().add(const Duration(days: 30));
    _selectedColor = widget.goal?.color ?? '#6366F1';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    final isEdit = widget.goal != null;

    return AlertDialog(
      backgroundColor: tokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: tokens.borderSubtle),
      ),
      title: Text(
        isEdit ? 'Edit Goal' : 'New Goal',
        style: TextStyle(color: tokens.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 340,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Goal Title',
                style: TextStyle(color: tokens.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _titleController,
                autofocus: !isEdit,
                style: TextStyle(color: tokens.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'E.g. Final Semester Exams',
                  hintStyle: TextStyle(color: tokens.textMuted, fontSize: 13),
                  filled: true,
                  fillColor: tokens.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: tokens.borderSubtle),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: tokens.borderSubtle),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: tokens.accent),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Target Date',
                style: TextStyle(color: tokens.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 30)),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: tokens.brightness == Brightness.light
                              ? ColorScheme.light(
                                  primary: tokens.accent,
                                  onPrimary: Colors.white,
                                  surface: tokens.surface,
                                  onSurface: tokens.textPrimary,
                                )
                              : ColorScheme.dark(
                                  primary: tokens.accent,
                                  onPrimary: Colors.white,
                                  surface: tokens.surface,
                                  onSurface: tokens.textPrimary,
                                ),
                          dialogTheme: DialogThemeData(backgroundColor: tokens.background),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null) {
                    setState(() => _selectedDate = picked);
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: tokens.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: tokens.borderSubtle),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_outlined, size: 14, color: tokens.textMuted),
                      const SizedBox(width: 8),
                      Text(
                        '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                        style: TextStyle(fontSize: 13, color: tokens.textPrimary),
                      ),
                      const Spacer(),
                      Icon(Icons.arrow_drop_down, size: 18, color: tokens.textMuted),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Notes / Syllabus / Milestones',
                style: TextStyle(color: tokens.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _notesController,
                maxLines: 3,
                style: TextStyle(color: tokens.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Add details, revision plans, resources...',
                  hintStyle: TextStyle(color: tokens.textMuted, fontSize: 12),
                  filled: true,
                  fillColor: tokens.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: tokens.borderSubtle),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: tokens.borderSubtle),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: tokens.accent),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Color Theme',
                style: TextStyle(color: tokens.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: taskColors.map((hex) {
                  final isSelected = _selectedColor == hex;
                  final color = Color(int.parse(hex.replaceFirst('#', '0xFF')));
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = hex),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
                        boxShadow: isSelected ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 4)] : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: tokens.textSecondary, fontSize: 13)),
        ),
        PremiumButton(
          onTap: () {
            final title = _titleController.text.trim();
            if (title.isEmpty) return;
            widget.onSave(title, _selectedDate, _notesController.text.trim(), _selectedColor);
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _HabitModalDialog extends StatefulWidget {
  final Habit? habit;
  final ThemeTokens tokens;
  final Function(String name, String icon, String color, String frequency, List<int>? customWeekdays, String? reminderTime) onSave;
  final VoidCallback? onDelete;

  const _HabitModalDialog({
    this.habit,
    required this.tokens,
    required this.onSave,
    this.onDelete,
  });

  @override
  State<_HabitModalDialog> createState() => _HabitModalDialogState();
}

class _HabitModalDialogState extends State<_HabitModalDialog> {
  late TextEditingController _nameController;
  late TextEditingController _emojiController;
  late String _selectedIcon;
  late String _selectedColor;
  late String _selectedFrequency;
  late List<int> _customWeekdays;
  TimeOfDay? _reminderTime;

  final List<String> _icons = [
    'gym',
    'book',
    'water',
    'sleep',
    'food',
    'spa',
    'code',
    'meditate',
    'check',
  ];

  final List<String> _popularEmojis = [
    '💧', '🏃', '📚', '🧘', '🏋️', '😴', '💻', '🎨',
    '🍎', '💊', '🚴', '✍️', '🎸', '🧹', '🪴', '🚶',
    '🍳', '☕', '🦷', '🎯', '⏱️', '📅', '💼', '🧠'
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.habit?.name ?? '');
    _selectedIcon = widget.habit?.icon ?? 'check';
    _selectedColor = widget.habit?.color ?? '#6366F1';
    _selectedFrequency = widget.habit?.frequency ?? 'daily';
    _customWeekdays = List<int>.from(widget.habit?.customWeekdays ?? [1, 2, 3, 4, 5]);

    _emojiController = TextEditingController(
      text: _selectedIcon.startsWith('emoji:')
          ? _selectedIcon.substring(6)
          : (_selectedIcon.isNotEmpty && !RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(_selectedIcon) ? _selectedIcon : '')
    );

    if (widget.habit?.reminderTime != null) {
      final parts = widget.habit!.reminderTime!.split(':');
      if (parts.length == 2) {
        _reminderTime = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 8,
          minute: int.tryParse(parts[1]) ?? 0,
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emojiController.dispose();
    super.dispose();
  }

  IconData _getIconData(String name) {
    switch (name) {
      case 'gym':
        return Icons.fitness_center;
      case 'book':
        return Icons.menu_book;
      case 'water':
        return Icons.water_drop;
      case 'sleep':
        return Icons.bedtime;
      case 'food':
        return Icons.restaurant;
      case 'spa':
        return Icons.spa;
      case 'code':
        return Icons.code;
      case 'meditate':
        return Icons.self_improvement;
      case 'check':
      default:
        return Icons.check_circle_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    final isEdit = widget.habit != null;

    return AlertDialog(
      backgroundColor: tokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: tokens.borderSubtle),
      ),
      title: Text(
        isEdit ? 'Edit Habit' : 'New Habit',
        style: TextStyle(color: tokens.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name input
            Text(
              'Habit Name',
              style: TextStyle(color: tokens.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                // Selected Icon/Emoji Preview
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Color(int.parse(_selectedColor.replaceFirst('#', '0xFF'))).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Color(int.parse(_selectedColor.replaceFirst('#', '0xFF'))).withValues(alpha: 0.25),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: _selectedIcon.startsWith('emoji:')
                        ? Text(
                            _selectedIcon.substring(6),
                            style: const TextStyle(fontSize: 18),
                          )
                        : (_selectedIcon.isNotEmpty &&
                                !RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(_selectedIcon)
                            ? Text(_selectedIcon, style: const TextStyle(fontSize: 18))
                            : Icon(
                                _getIconData(_selectedIcon),
                                size: 18,
                                color: Color(int.parse(_selectedColor.replaceFirst('#', '0xFF'))),
                              )),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    autofocus: !isEdit,
                    style: TextStyle(color: tokens.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'E.g. Drink Water',
                      hintStyle: TextStyle(color: tokens.textMuted, fontSize: 13),
                      filled: true,
                      fillColor: tokens.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: tokens.borderSubtle),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: tokens.borderSubtle),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Icon selection
            Text(
              'Select Emoji / Icon',
              style: TextStyle(color: tokens.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            // Emoji Selection Grid
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _popularEmojis.map((emoji) {
                final isSelected = _selectedIcon == 'emoji:$emoji';
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedIcon = 'emoji:$emoji';
                      _emojiController.text = emoji;
                    });
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected ? Color(int.parse(_selectedColor.replaceFirst('#', '0xFF'))).withValues(alpha: 0.15) : tokens.background,
                      border: Border.all(
                        color: isSelected ? Color(int.parse(_selectedColor.replaceFirst('#', '0xFF'))) : tokens.borderSubtle,
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            // Material Icon Selection (as fallback)
            Text(
              'Or Core Icons',
              style: TextStyle(color: tokens.textSecondary, fontSize: 11, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _icons.map((iconName) {
                final isSelected = _selectedIcon == iconName;
                final iconColor = isSelected ? Color(int.parse(_selectedColor.replaceFirst('#', '0xFF'))) : tokens.textSecondary;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedIcon = iconName;
                      _emojiController.clear();
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isSelected ? Color(int.parse(_selectedColor.replaceFirst('#', '0xFF'))).withValues(alpha: 0.15) : tokens.background,
                      border: Border.all(
                        color: isSelected ? Color(int.parse(_selectedColor.replaceFirst('#', '0xFF'))) : tokens.borderSubtle,
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      _getIconData(iconName),
                      size: 16,
                      color: iconColor,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            // Custom Emoji Text Field
            Row(
              children: [
                Text(
                  'Or Custom Character: ',
                  style: TextStyle(color: tokens.textSecondary, fontSize: 11, fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 32,
                    decoration: BoxDecoration(
                      color: tokens.background,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: tokens.borderSubtle),
                    ),
                    child: TextField(
                      controller: _emojiController,
                      maxLength: 4,
                      style: TextStyle(color: tokens.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Type any emoji/text',
                        hintStyle: TextStyle(color: tokens.textMuted, fontSize: 11),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        counterText: '',
                        border: InputBorder.none,
                      ),
                      onChanged: (val) {
                        final valTrimmed = val.trim();
                        if (valTrimmed.isNotEmpty) {
                          setState(() {
                            _selectedIcon = 'emoji:$valTrimmed';
                          });
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Color selection
            Text(
              'Color Theme',
              style: TextStyle(color: tokens.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: taskColors.map((hex) {
                final isSelected = _selectedColor == hex;
                final color = Color(int.parse(hex.replaceFirst('#', '0xFF')));
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = hex),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
                      boxShadow: isSelected ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 4)] : null,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Frequency selection
            Text(
              'Frequency',
              style: TextStyle(color: tokens.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: tokens.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: tokens.borderSubtle),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedFrequency,
                  dropdownColor: tokens.surface,
                  style: TextStyle(color: tokens.textPrimary, fontSize: 13),
                  items: const [
                    DropdownMenuItem(value: 'daily', child: Text('Every Day')),
                    DropdownMenuItem(value: 'weekdays', child: Text('Weekdays (Mon-Fri)')),
                    DropdownMenuItem(value: 'weekends', child: Text('Weekends (Sat-Sun)')),
                    DropdownMenuItem(value: 'custom', child: Text('Custom Days')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedFrequency = val);
                    }
                  },
                ),
              ),
            ),

            if (_selectedFrequency == 'custom') ...[
              const SizedBox(height: 12),
              Text(
                'Select Days',
                style: TextStyle(color: tokens.textSecondary, fontSize: 11, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(7, (i) {
                  final dayNum = i + 1;
                  const dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                  final isSelected = _customWeekdays.contains(dayNum);
                  final color = isSelected ? Color(int.parse(_selectedColor.replaceFirst('#', '0xFF'))) : tokens.textMuted;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          if (_customWeekdays.length > 1) {
                            _customWeekdays.remove(dayNum);
                          }
                        } else {
                          _customWeekdays.add(dayNum);
                        }
                      });
                    },
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isSelected ? color.withValues(alpha: 0.15) : tokens.background,
                        border: Border.all(color: isSelected ? color : tokens.borderSubtle),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        dayLabels[i],
                        style: TextStyle(
                          color: isSelected ? color : tokens.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
            const SizedBox(height: 16),

            // Reminder time
            Text(
              'Daily Reminder',
              style: TextStyle(color: tokens.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                GestureDetector(
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: _reminderTime ?? const TimeOfDay(hour: 8, minute: 0),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: ColorScheme.dark(
                              primary: Color(int.parse(_selectedColor.replaceFirst('#', '0xFF'))),
                              surface: tokens.surface,
                              onSurface: tokens.textPrimary,
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (time != null) {
                      setState(() => _reminderTime = time);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: tokens.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: tokens.borderSubtle),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.alarm, size: 16, color: Color(int.parse(_selectedColor.replaceFirst('#', '0xFF')))),
                        const SizedBox(width: 8),
                        Text(
                          _reminderTime != null
                              ? '${_reminderTime!.hour.toString().padLeft(2, '0')}:${_reminderTime!.minute.toString().padLeft(2, '0')}'
                              : 'None Set',
                          style: TextStyle(color: tokens.textPrimary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_reminderTime != null) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() => _reminderTime = null),
                    child: Icon(Icons.close, size: 16, color: tokens.textMuted),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
      actions: [
        if (isEdit && widget.onDelete != null)
          TextButton(
            onPressed: () {
              widget.onDelete!();
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Color(0xFFEF4444), fontSize: 13)),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: tokens.textSecondary, fontSize: 13)),
        ),
        PremiumButton(
          onTap: () {
            final name = _nameController.text.trim();
            if (name.isEmpty) return;

            String? reminderStr;
            if (_reminderTime != null) {
              reminderStr = '${_reminderTime!.hour.toString().padLeft(2, '0')}:${_reminderTime!.minute.toString().padLeft(2, '0')}';
            }

            widget.onSave(
              name,
              _selectedIcon,
              _selectedColor,
              _selectedFrequency,
              _selectedFrequency == 'custom' ? _customWeekdays : null,
              reminderStr,
            );
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────
// Empty State
// ──────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final ThemeTokens tokens;
  final VoidCallback onCreateTask;

  const _EmptyState({required this.tokens, required this.onCreateTask});

  @override
  Widget build(BuildContext context) {
    return motion.PremiumEnterTransition(
      duration: motion.PremiumDurations.panelSlide,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: tokens.borderSubtle,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.check_circle_outline,
                  size: 28, color: tokens.textMuted),
            ),
            const SizedBox(height: 12),
            Text('No tasks yet',
                style: TextStyle(fontSize: 15, color: tokens.textMuted)),
            const SizedBox(height: 4),
            Text('Add your first task to get started',
                style: TextStyle(fontSize: 12, color: tokens.textMuted)),
            const SizedBox(height: 20),
            PremiumButton(
              onTap: onCreateTask,
              variant: PremiumButtonVariant.primary,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: 14, color: Colors.white),
                  const SizedBox(width: 6),
                  Text('Create Task'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Premium Task Card — enhanced with progress bar, always-visible actions,
// rich stats display, and refined visual hierarchy.
// ──────────────────────────────────────────────

class _TaskCard extends StatefulWidget {
  final Task task;
  final ThemeTokens tokens;
  final bool isFocused;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onFocus;
  final VoidCallback onArchive;
  final VoidCallback onDuplicate;
  final ValueChanged<String> onRecolor;
  final ValueChanged<String> onRename;

  const _TaskCard({
    required this.task,
    required this.tokens,
    required this.isFocused,
    required this.onToggle,
    required this.onDelete,
    required this.onFocus,
    required this.onArchive,
    required this.onDuplicate,
    required this.onRecolor,
    required this.onRename,
  });

  @override
  State<_TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<_TaskCard> {
  bool _hovered = false;
  bool _editing = false;
  late TextEditingController _editController;

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController(text: widget.task.title);
  }

  @override
  void didUpdateWidget(_TaskCard old) {
    super.didUpdateWidget(old);
    if (old.task.id != widget.task.id) {
      _editController.text = widget.task.title;
    }
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  void _showContextMenu(BuildContext context, Offset position) {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx, position.dy, position.dx + 1, position.dy + 1,
      ),
      color: widget.tokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      items: [
        if (!widget.task.done)
          PopupMenuItem(
            value: 'fokus',
            child: _ContextMenuItem(
              icon: Icons.play_circle_outline,
              label: 'Start fokus session',
              tokens: widget.tokens,
            ),
          ),
        PopupMenuItem(
          value: 'rename',
          child: _ContextMenuItem(
            icon: Icons.edit_outlined,
            label: 'Rename',
            tokens: widget.tokens,
          ),
        ),
        PopupMenuItem(
          value: 'recolor',
          child: _ContextMenuItem(
            icon: Icons.palette_outlined,
            label: 'Change color',
            tokens: widget.tokens,
          ),
        ),
        PopupMenuItem(
          value: 'duplicate',
          child: _ContextMenuItem(
            icon: Icons.copy_outlined,
            label: 'Duplicate',
            tokens: widget.tokens,
          ),
        ),
        PopupMenuItem(
          value: 'archive',
          child: _ContextMenuItem(
            icon: Icons.archive_outlined,
            label: 'Archive',
            tokens: widget.tokens,
          ),
        ),
        PopupMenuDivider(height: 1),
        PopupMenuItem(
          value: 'delete',
          child: _ContextMenuItem(
            icon: Icons.delete_outline,
            label: 'Delete',
            tokens: widget.tokens,
            isDestructive: true,
          ),
        ),
      ],
    ).then((value) {
      if (value == null) return;
      switch (value) {
        case 'fokus':
          widget.onFocus();
        case 'rename':
          setState(() => _editing = true);
        case 'recolor':
          _showColorPicker();
        case 'duplicate':
          widget.onDuplicate();
        case 'archive':
          widget.onArchive();
        case 'delete':
          widget.onDelete();
      }
    });
  }

  void _showColorPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: widget.tokens.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Choose color',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: widget.tokens.textPrimary)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: taskColors.map((hex) {
                final color = int.parse(hex.replaceFirst('#', '0xFF'));
                final isSelected = widget.task.color == hex;
                return GestureDetector(
                  onTap: () {
                    widget.onRecolor(hex);
                    Navigator.pop(ctx);
                  },
                  child: AnimatedContainer(
                    duration: motion.PremiumDurations.panelSlide,
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Color(color),
                      borderRadius:
                          BorderRadius.circular(isSelected ? 10 : 8),
                      border: isSelected
                          ? Border.all(
                              color: Colors.white.safeWithOpacity(0.5),
                              width: 2)
                          : null,
                    ),
                    child: isSelected
                        ? const Center(
                            child: Icon(Icons.check,
                                size: 18, color: Colors.white))
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _finishRename() {
    final text = _editController.text.trim();
    if (text.isNotEmpty && text != widget.task.title) {
      widget.onRename(text);
    } else {
      _editController.text = widget.task.title;
    }
    setState(() => _editing = false);
  }

  Color get _taskColor => Color(widget.task.colorValue);

  @override
  Widget build(BuildContext context) {
    final isDone = widget.task.done;
    final hasFocusTime = widget.task.totalFocusMinutes > 0;
    final progress = widget.task.fokusProgress;

    return MouseRegion(
      cursor: SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onSecondaryTapDown: (details) =>
            _showContextMenu(context, details.globalPosition),
        child: AnimatedContainer(
          duration: motion.PremiumDurations.hoverLong,
          curve: motion.PremiumCurves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDone
                ? widget.tokens.surface
                : widget.isFocused
                    ? _taskColor.safeWithOpacity(0.06)
                    : _hovered
                        ? widget.tokens.textPrimary.safeWithOpacity(0.03)
                        : widget.tokens.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.isFocused
                  ? _taskColor.safeWithOpacity(0.4)
                  : _hovered && !isDone
                      ? widget.tokens.borderMedium
                      : widget.tokens.borderSubtle,
            ),
            boxShadow: widget.isFocused
                ? [
                    BoxShadow(
                      color: _taskColor.safeWithOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : _hovered && !isDone
                    ? [
                        BoxShadow(
                          color: widget.tokens.accent.safeWithOpacity(0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Main row ──
              Row(
                children: [
                  // ── Color accent bar ──
                  AnimatedContainer(
                    duration: motion.PremiumDurations.panelSlide,
                    width: 4,
                    height: hasFocusTime ? 44 : 32,
                    decoration: BoxDecoration(
                      color: _taskColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // ── Animated checkbox ──
                  motion.PremiumHoverEffect(
                    hoverScale: 1.15,
                    pressScale: 0.88,
                    onTap: widget.onToggle,
                    child: AnimatedContainer(
                      duration: motion.PremiumDurations.panelSlide,
                      curve: motion.PremiumCurves.springyOut,
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: isDone ? _taskColor : Colors.transparent,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: isDone ? _taskColor : widget.tokens.borderMedium,
                          width: isDone ? 1 : 1.5,
                        ),
                      ),
                      child: isDone
                          ? motion.PremiumEnterTransition(
                              duration: motion.PremiumDurations.microFeedbackLong,
                              child: const Icon(Icons.check,
                                  size: 14, color: Colors.white),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),

                  // ── Title + stats column ──
                  Expanded(
                    child: _editing
                        ? SizedBox(
                            height: 32,
                            child: TextField(
                              controller: _editController,
                              autofocus: true,
                              style: TextStyle(
                                fontSize: 14,
                                color: widget.tokens.textPrimary,
                              ),
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: BorderSide(
                                      color: widget.tokens.borderMedium),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 6),
                                isDense: true,
                              ),
                              onSubmitted: (_) => _finishRename(),
                              onTapOutside: (_) => _finishRename(),
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      widget.task.title,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: isDone
                                            ? widget.tokens.textMuted
                                            : widget.tokens.textPrimary,
                                        decoration: isDone
                                            ? TextDecoration.lineThrough
                                            : null,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (hasFocusTime && !isDone) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      '—  ${widget.task.formattedFocusTime}',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: _taskColor.safeWithOpacity(0.85),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (hasFocusTime &&
                                  !isDone &&
                                  (widget.task.completedSessions > 0 ||
                                      widget.task.interruptedSessions > 0))
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Row(
                                    children: [
                                      if (widget.task.completedSessions >
                                          0)
                                        Text(
                                          '${widget.task.completedSessions} session${widget.task.completedSessions == 1 ? '' : 's'}',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: widget.tokens.textMuted,
                                          ),
                                        ),
                                      if (widget.task.interruptedSessions >
                                          0) ...[
                                        const SizedBox(width: 6),
                                        Text(
                                          '(${widget.task.interruptedSessions} interrupted)',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: widget.tokens.textMuted,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                            ],
                          ),
                  ),

                  // ── Quick start focus button (always visible for pending) ──
                  if (!isDone && !_editing)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Tooltip(
                        message: 'Start Fokus',
                        child: motion.PremiumHoverEffect(
                          hoverScale: 1.12,
                          pressScale: 0.9,
                          onTap: widget.onFocus,
                          child: AnimatedContainer(
                            duration: motion.PremiumDurations.hover,
                            curve: motion.PremiumCurves.easeOutCubic,
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: _hovered
                                  ? _taskColor.safeWithOpacity(0.15)
                                  : _taskColor.safeWithOpacity(0.08),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Icon(Icons.play_arrow_rounded,
                                size: 16, color: _taskColor),
                          ),
                        ),
                      ),
                    ),

                  // ── Hover actions ──
                  if (!_editing)
                    AnimatedOpacity(
                      opacity: _hovered ? 1.0 : 0.0,
                      duration: motion.PremiumDurations.panelFade,
                      curve: motion.PremiumCurves.easeOutCubic,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Archive
                          motion.PremiumHoverEffect(
                            hoverScale: 1.1,
                            pressScale: 0.92,
                            onTap: widget.onArchive,
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: widget.tokens.borderSubtle,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(Icons.archive_outlined,
                                  size: 12, color: widget.tokens.textMuted),
                            ),
                          ),
                          const SizedBox(width: 4),
                          // Delete
                          motion.PremiumHoverEffect(
                            hoverScale: 1.1,
                            pressScale: 0.92,
                            onTap: widget.onDelete,
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: widget.tokens.borderSubtle,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(Icons.close,
                                  size: 12, color: widget.tokens.textMuted),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              // ── Focus progress bar ──
              if (hasFocusTime && !isDone && !_editing)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 16, right: 4),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: AnimatedContainer(
                      duration: motion.PremiumDurations.panelSlide,
                      height: 2,
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: widget.tokens.borderSubtle,
                        valueColor: AlwaysStoppedAnimation(_taskColor),
                        minHeight: 2,
                      ),
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

// ──────────────────────────────────────────────
// Archived Task Item (collapsed)
// ──────────────────────────────────────────────

class _ArchivedTaskItem extends StatelessWidget {
  final Task task;
  final ThemeTokens tokens;

  const _ArchivedTaskItem({required this.task, required this.tokens});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Color(task.colorValue),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              task.title,
              style: TextStyle(
                fontSize: 13,
                color: tokens.textMuted,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          Text(
            task.formattedFocusTime,
            style: TextStyle(fontSize: 11, color: tokens.textMuted),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Context Menu Item
// ──────────────────────────────────────────────

class _ContextMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final ThemeTokens tokens;
  final bool isDestructive;

  const _ContextMenuItem({
    required this.icon,
    required this.label,
    required this.tokens,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: isDestructive
              ? const Color(0xFFEF4444)
              : tokens.textSecondary,
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isDestructive
                ? const Color(0xFFEF4444)
                : tokens.textPrimary,
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────
// macOS-Style Segmented Control
// ──────────────────────────────────────────────

class _PremiumSegmentedControl extends StatelessWidget {
  final TabController controller;
  final List<String> tabs;
  final ThemeTokens tokens;

  const _PremiumSegmentedControl({
    required this.controller,
    required this.tabs,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final double value = controller.animation?.value ?? controller.index.toDouble();

        return Container(
          height: 34,
          width: 280,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: tokens.brightness == Brightness.light
                ? const Color(0xFFE5E7EB) // Light gray track background
                : tokens.surfaceAlt.safeWithOpacity(0.5), // Tinted dark track background
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: tokens.brightness == Brightness.light
                  ? const Color(0x0E000000)
                  : tokens.borderSubtle,
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double totalWidth = constraints.maxWidth;
              final double tabWidth = totalWidth / tabs.length;
              final double leftPosition = value * tabWidth;

              return Stack(
                children: [
                  // Animated sliding card
                  Positioned(
                    left: leftPosition,
                    top: 0,
                    bottom: 0,
                    width: tabWidth,
                    child: Container(
                      decoration: BoxDecoration(
                        color: tokens.brightness == Brightness.light
                            ? Colors.white
                            : tokens.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: tokens.brightness == Brightness.light
                              ? const Color(0x15000000)
                              : tokens.borderMedium.safeWithOpacity(0.15),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: tokens.brightness == Brightness.light ? 0.06 : 0.2,
                            ),
                            blurRadius: 4,
                            offset: const Offset(0, 1.5),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Tab Buttons
                  Row(
                    children: List.generate(tabs.length, (index) {
                      final isSelected = controller.index == index;

                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            controller.animateTo(index);
                          },
                          behavior: HitTestBehavior.opaque,
                          child: Center(
                            child: Text(
                              tabs[index],
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                color: isSelected
                                    ? tokens.textPrimary
                                    : tokens.textMuted,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

// ──────────────────────────────────────────────
// Custom Elegant Countdown Widgets
// ──────────────────────────────────────────────

class FuseProgressBar extends StatelessWidget {
  final double progress;
  final Color glowColor;
  final Animation<double> pulseAnimation;

  const FuseProgressBar({
    Key? key,
    required this.progress,
    required this.glowColor,
    required this.pulseAnimation,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final progressWidth = totalWidth * progress;

        return Stack(
          alignment: Alignment.centerLeft,
          children: [
            // Background line (unfilled)
            Container(
              height: 6,
              width: totalWidth,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            // Progress fill (with breathing glow)
            AnimatedBuilder(
              animation: pulseAnimation,
              builder: (context, child) {
                return Container(
                  height: 6,
                  width: progressWidth,
                  decoration: BoxDecoration(
                    color: glowColor,
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: [
                      BoxShadow(
                        color: glowColor.withValues(alpha: pulseAnimation.value * 0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class TimeBombTickingPanel extends StatefulWidget {
  final int daysLeft;
  final String title;
  final double progress;
  final Color themeColor;
  final ThemeTokens tokens;
  final String statusLabel;
  final String statusSubtitle;
  final bool isCompleted;
  final Widget switchButton;

  const TimeBombTickingPanel({
    Key? key,
    required this.daysLeft,
    required this.title,
    required this.progress,
    required this.themeColor,
    required this.tokens,
    required this.statusLabel,
    required this.statusSubtitle,
    required this.isCompleted,
    required this.switchButton,
  }) : super(key: key);

  @override
  _TimeBombTickingPanelState createState() => _TimeBombTickingPanelState();
}

class _TimeBombTickingPanelState extends State<TimeBombTickingPanel> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200), // Breathing pulse
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getAdjustedThemeColor(Color color, bool isDark) {
    if (isDark) return color;
    // In light mode, increase contrast for status colors on white background
    if (color.toARGB32() == 0xFFF59E0B) { // Amber
      return const Color(0xFFD97706); // Darker amber
    }
    return color;
  }

  @override
  Widget build(BuildContext context) {
    final daysStr = widget.daysLeft.clamp(0, 9999).toString().padLeft(3, '0');
    final isDark = widget.tokens.brightness == Brightness.dark;
    final activeThemeColor = _getAdjustedThemeColor(widget.themeColor, isDark);

    String statusCopy;
    if (widget.isCompleted) {
      statusCopy = "Goal achieved successfully. Timeline completed.";
    } else if (widget.daysLeft < 0) {
      statusCopy = "Timeline has expired. Action required to reschedule.";
    } else if (widget.daysLeft == 0) {
      statusCopy = "Today is the deadline. Complete now!";
    } else {
      statusCopy = "Only ${widget.daysLeft} days remaining. Stay fokused.";
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final containerWidth = constraints.maxWidth;
        final isMobile = containerWidth < 620;

        return Container(
          decoration: BoxDecoration(
            color: widget.tokens.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: widget.tokens.borderSubtle, width: 1.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.03),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: activeThemeColor, width: 6.0),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Row (Goal Title & Switch Button)
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: activeThemeColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: activeThemeColor.withValues(alpha: 0.4),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.title.toUpperCase(),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: widget.tokens.textPrimary,
                              letterSpacing: 1.0,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        widget.switchButton,
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Giant Elegant Countdown Viewport
                    _buildLCDDisplay(daysStr, containerWidth, isMobile, isDark, activeThemeColor),

                    const SizedBox(height: 22),

                    // Bottom Info Section
                    isMobile
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildStatusSection(statusCopy, activeThemeColor),
                              const SizedBox(height: 20),
                              _buildProgressBreakdown(isDark, activeThemeColor),
                            ],
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 6,
                                child: _buildStatusSection(statusCopy, activeThemeColor),
                              ),
                              const SizedBox(width: 32),
                              Expanded(
                                flex: 5,
                                child: _buildProgressBreakdown(isDark, activeThemeColor),
                              ),
                            ],
                          ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLCDDisplay(String daysStr, double containerWidth, bool isMobile, bool isDark, Color activeThemeColor) {
    final displayStr = widget.isCompleted ? 'COMPLETED' : daysStr;
    final double digitsFontSize = (containerWidth * (widget.isCompleted ? 0.12 : 0.24)).clamp(48.0, 140.0);

    return Container(
      width: double.infinity,
      height: isMobile ? 160 : 220,
      decoration: BoxDecoration(
        color: widget.tokens.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.tokens.borderSubtle,
          width: 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              widget.isCompleted ? 'PRIMARY TARGET SECURED' : 'TIME REMAINING',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: activeThemeColor,
                letterSpacing: 4.0,
              ),
            ),
            const SizedBox(height: 10),
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Opacity(
                  opacity: widget.isCompleted ? 1.0 : _pulseAnimation.value,
                  child: Text(
                    displayStr,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: digitsFontSize,
                      fontWeight: FontWeight.w900,
                      color: activeThemeColor,
                      letterSpacing: widget.isCompleted ? 1.0 : 4.0,
                      height: 1.0,
                    ),
                  ),
                );
              },
            ),
            if (!widget.isCompleted) ...[
              const SizedBox(height: 10),
              Text(
                widget.daysLeft == 1 ? 'DAY' : 'DAYS',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: widget.tokens.textSecondary.withValues(alpha: 0.7),
                  letterSpacing: 3.0,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSection(String statusCopy, Color activeThemeColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: activeThemeColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: activeThemeColor.withValues(alpha: 0.15),
                  width: 1.0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.isCompleted ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                    size: 12,
                    color: activeThemeColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.statusLabel.toUpperCase(),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: activeThemeColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          statusCopy,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: widget.tokens.textSecondary,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBreakdown(bool isDark, Color activeThemeColor) {
    final elapsedPercent = (widget.progress * 100).toStringAsFixed(0);
    final remainingPercent = (100 - (widget.progress * 100)).toStringAsFixed(0);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.isCompleted 
                  ? 'COMPLETED' 
                  : '$elapsedPercent% TIME ELAPSED',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: widget.isCompleted ? const Color(0xFF10B981) : activeThemeColor,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              widget.isCompleted ? 'SAFE' : '$remainingPercent% TIME LEFT',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: widget.tokens.textSecondary.withValues(alpha: 0.65),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        FuseProgressBar(
          progress: widget.progress,
          glowColor: activeThemeColor,
          pulseAnimation: _pulseAnimation,
        ),
        const SizedBox(height: 10),
        Text(
          widget.isCompleted 
              ? 'Milestone completed.' 
              : 'Complete your tasks before the deadline.',
          style: TextStyle(
            fontSize: 11,
            color: widget.tokens.textMuted,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}

class TimeBombMiniPanel extends StatefulWidget {
  final int daysLeft;
  final double progress;
  final Color themeColor;
  final String statusLabel;
  final String statusSubtitle;
  final bool isCompleted;

  const TimeBombMiniPanel({
    Key? key,
    required this.daysLeft,
    required this.progress,
    required this.themeColor,
    required this.statusLabel,
    required this.statusSubtitle,
    required this.isCompleted,
  }) : super(key: key);

  @override
  _TimeBombMiniPanelState createState() => _TimeBombMiniPanelState();
}

class _TimeBombMiniPanelState extends State<TimeBombMiniPanel> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = FocusOsTheme.of(context);
    final daysStr = widget.daysLeft.clamp(0, 9999).toString();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.statusLabel.toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: widget.themeColor,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                widget.isCompleted ? 'COMPLETED' : 'DAYS LEFT',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: tokens.textMuted,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: widget.isCompleted ? 1.0 : _pulseAnimation.value,
                    child: Text(
                      widget.isCompleted ? 'GOAL MET' : daysStr,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: widget.isCompleted ? 24 : 32,
                        fontWeight: FontWeight.w900,
                        color: widget.themeColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  );
                },
              ),
              if (!widget.isCompleted) ...[
                const SizedBox(width: 4),
                Text(
                  widget.daysLeft == 1 ? 'DAY' : 'DAYS',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: tokens.textSecondary,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          FuseProgressBar(
            progress: widget.progress,
            glowColor: widget.themeColor,
            pulseAnimation: _pulseAnimation,
          ),
        ],
      ),
    );
  }
}

class _HoverableRow extends StatefulWidget {
  final ThemeTokens tokens;
  final bool isToday;
  final Widget Function(bool isHovered) child;

  const _HoverableRow({
    required this.tokens,
    required this.isToday,
    required this.child,
  });

  @override
  State<_HoverableRow> createState() => _HoverableRowState();
}

class _HoverableRowState extends State<_HoverableRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: widget.child(_isHovered),
    );
  }
}

class _StatCardData {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final String? subtitle;
  final String? suffix;

  const _StatCardData({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.subtitle,
    this.suffix,
  });
}

class _HabitGridCheckbox extends StatefulWidget {
  final bool isDone;
  final bool isFuture;
  final Color habitColor;
  final ThemeTokens tokens;
  final VoidCallback onTap;
  final bool hasNote;
  final VoidCallback? onLongPress;
  final GestureTapUpCallback? onSecondaryTapUp;

  const _HabitGridCheckbox({
    required this.isDone,
    required this.isFuture,
    required this.habitColor,
    required this.tokens,
    required this.onTap,
    this.hasNote = false,
    this.onLongPress,
    this.onSecondaryTapUp,
  });

  @override
  State<_HabitGridCheckbox> createState() => _HabitGridCheckboxState();
}

class _HabitGridCheckboxState extends State<_HabitGridCheckbox> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final habitColor = widget.habitColor;
    
    return MouseRegion(
      cursor: widget.isFuture ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.isFuture ? null : widget.onTap,
        onLongPress: widget.isFuture ? null : widget.onLongPress,
        onSecondaryTapUp: widget.isFuture ? null : widget.onSecondaryTapUp,
        child: AnimatedScale(
          scale: _isHovered && !widget.isFuture ? 1.12 : 1.0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.isDone
                      ? habitColor
                      : _isHovered && !widget.isFuture
                          ? habitColor.safeWithOpacity(0.08)
                          : Colors.transparent,
                  border: Border.all(
                    color: widget.isDone
                        ? habitColor
                        : _isHovered && !widget.isFuture
                            ? habitColor.safeWithOpacity(0.6)
                            : widget.tokens.borderMedium.safeWithOpacity(0.6),
                    width: widget.isDone ? 1.5 : 1.2,
                  ),
                  boxShadow: widget.isDone
                      ? [
                          BoxShadow(
                            color: habitColor.safeWithOpacity(0.4),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ]
                      : _isHovered && !widget.isFuture
                          ? [
                              BoxShadow(
                                color: habitColor.safeWithOpacity(0.15),
                                blurRadius: 4,
                                spreadRadius: 0,
                              ),
                            ]
                          : [],
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                  child: widget.isDone
                      ? const Icon(
                          Icons.check_rounded,
                          size: 13,
                          color: Colors.white,
                          key: ValueKey('checked'),
                        )
                      : const SizedBox(key: ValueKey('unchecked')),
                ),
              ),
              if (widget.hasNote)
                Positioned(
                  top: -3,
                  right: -3,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: widget.isDone ? Colors.white : habitColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: widget.isDone ? habitColor : widget.tokens.surface,
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: habitColor.safeWithOpacity(0.4),
                          blurRadius: 2,
                        )
                      ]
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

class _CircularProgressWheel extends StatelessWidget {
  final double value; // 0.0 to 1.0
  final double size;
  final Color? color;
  final ThemeTokens tokens;

  const _CircularProgressWheel({
    required this.value,
    this.size = 16,
    this.color,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    final progressColor = color ?? tokens.accent;
    final backgroundColor = tokens.borderSubtle.safeWithOpacity(0.3);

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CircularProgressPainter(
          value: value,
          color: progressColor,
          backgroundColor: backgroundColor,
        ),
      ),
    );
  }
}

class _CircularProgressPainter extends CustomPainter {
  final double value;
  final Color color;
  final Color backgroundColor;

  _CircularProgressPainter({
    required this.value,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 3) / 2; // leave margin for stroke
    final strokeWidth = 2.5;

    // Draw background circle
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, bgPaint);

    // Draw progress arc
    if (value > 0) {
      final progressPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -3.1415926535 / 2, // start at top (-90 degrees)
        value * 2 * 3.1415926535,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CircularProgressPainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.color != color ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}

class _HabitNameInfo {
  final String title;
  final String subtitle;
  _HabitNameInfo({required this.title, required this.subtitle});
}

_HabitNameInfo _parseHabitName(Habit h) {
  final match = RegExp(r'^(.*?)\s*\(([^)]+)\)\s*$').firstMatch(h.name);
  if (match != null) {
    return _HabitNameInfo(
      title: match.group(1)!.trim(),
      subtitle: match.group(2)!.trim(),
    );
  } else {
    // fallback based on target count and frequency
    String sub = '';
    if (h.targetCount > 1) {
      sub = '${h.targetCount} times';
    } else {
      if (h.frequency == 'daily') {
        sub = 'daily';
      } else if (h.frequency == 'weekdays') {
        sub = 'weekdays';
      } else if (h.frequency == 'weekends') {
        sub = 'weekends';
      } else {
        sub = 'custom';
      }
    }
    return _HabitNameInfo(title: h.name, subtitle: sub);
  }
}


class _InlineGoalNoteField extends StatefulWidget {
  final TimelineGoal goal;
  final ThemeTokens tokens;
  final void Function(String) onSave;

  const _InlineGoalNoteField({
    super.key,
    required this.goal,
    required this.tokens,
    required this.onSave,
  });

  @override
  State<_InlineGoalNoteField> createState() => _InlineGoalNoteFieldState();
}

class _InlineGoalNoteFieldState extends State<_InlineGoalNoteField> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.goal.notes ?? '');
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        _saveNote();
      }
    });
  }

  @override
  void didUpdateWidget(covariant _InlineGoalNoteField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.goal.notes != widget.goal.notes && !_focusNode.hasFocus) {
      _controller.text = widget.goal.notes ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _saveNote() {
    final text = _controller.text.trim();
    if (text != (widget.goal.notes ?? '')) {
      widget.onSave(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: widget.tokens.brightness == Brightness.light ? Colors.white : widget.tokens.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: widget.tokens.borderSubtle),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Icon(
            Icons.subject_rounded,
            size: 16,
            color: widget.tokens.textMuted,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              onSubmitted: (_) => _saveNote(),
              style: TextStyle(
                color: widget.tokens.textPrimary,
                fontSize: 12,
              ),
              decoration: InputDecoration(
                hintText: 'Add a note or plan...',
                hintStyle: TextStyle(
                  color: widget.tokens.textMuted,
                  fontSize: 12,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MountainPainter extends CustomPainter {
  final Color themeColor;
  final bool isDark;

  _MountainPainter({required this.themeColor, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Sun (top right)
    final sunCenter = Offset(size.width * 0.82, size.height * 0.22);
    final sunRadius = size.height * 0.18;
    final sunPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFDBA74).withValues(alpha: isDark ? 0.6 : 0.8), // Orange-300
          const Color(0xFFFEF08A).withValues(alpha: 0.0), // Yellow-200 fade out
        ],
      ).createShader(Rect.fromCircle(center: sunCenter, radius: sunRadius * 1.5));
    canvas.drawCircle(sunCenter, sunRadius * 1.5, sunPaint);

    final innerSunPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFFFDE047), // Yellow-300
          const Color(0xFFF97316), // Orange-500
        ],
      ).createShader(Rect.fromCircle(center: sunCenter, radius: sunRadius));
    canvas.drawCircle(sunCenter, sunRadius, innerSunPaint);

    // 2. Mountains (layered from back to front)
    // Mountain 1 (Back Right peak)
    final path1 = Path();
    path1.moveTo(size.width * 0.3, size.height);
    path1.lineTo(size.width * 0.78, size.height * 0.28);
    path1.lineTo(size.width * 1.1, size.height);
    path1.close();
    
    final mountain1Paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDark
            ? [
                themeColor.withValues(alpha: 0.25),
                themeColor.withValues(alpha: 0.05),
              ]
            : [
                themeColor.withValues(alpha: 0.15),
                themeColor.withValues(alpha: 0.02),
              ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(path1, mountain1Paint);

    // Mountain 2 (Middle Left/Center peak)
    final path2 = Path();
    path2.moveTo(-size.width * 0.1, size.height);
    path2.lineTo(size.width * 0.45, size.height * 0.45);
    path2.lineTo(size.width * 0.85, size.height);
    path2.close();

    final mountain2Paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDark
            ? [
                themeColor.withValues(alpha: 0.35),
                themeColor.withValues(alpha: 0.1),
              ]
            : [
                themeColor.withValues(alpha: 0.22),
                themeColor.withValues(alpha: 0.04),
              ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(path2, mountain2Paint);

    // Mountain 3 (Foreground Right/Far Right peak)
    final path3 = Path();
    path3.moveTo(size.width * 0.5, size.height);
    path3.lineTo(size.width * 0.9, size.height * 0.55);
    path3.lineTo(size.width * 1.2, size.height);
    path3.close();

    final mountain3Paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDark
            ? [
                themeColor.withValues(alpha: 0.45),
                themeColor.withValues(alpha: 0.15),
              ]
            : [
                themeColor.withValues(alpha: 0.3),
                themeColor.withValues(alpha: 0.06),
              ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(path3, mountain3Paint);

    // Winding Path up to the peak (Mountain 1 Peak: size.width * 0.78, size.height * 0.28)
    final windingPath = Path();
    windingPath.moveTo(size.width * 0.45, size.height);
    
    // Smooth Bezier Curve for path winding up
    windingPath.cubicTo(
      size.width * 0.55, size.height * 0.85,
      size.width * 0.75, size.height * 0.8,
      size.width * 0.68, size.height * 0.68,
    );
    windingPath.cubicTo(
      size.width * 0.62, size.height * 0.6,
      size.width * 0.8, size.height * 0.5,
      size.width * 0.74, size.height * 0.4,
    );
    windingPath.lineTo(size.width * 0.78, size.height * 0.28);

    final pathStrokePaint = Paint()
      ..color = isDark ? Colors.white.withValues(alpha: 0.45) : Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(windingPath, pathStrokePaint);

    final pathCorePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(windingPath, pathCorePaint);

    // Flag at Peak (size.width * 0.78, size.height * 0.28)
    final peak = Offset(size.width * 0.78, size.height * 0.28);
    final flagHeight = size.height * 0.16;
    final flagWidth = size.width * 0.08;

    // Flag Pole
    final polePaint = Paint()
      ..color = themeColor
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(peak, peak - Offset(0, flagHeight), polePaint);

    // Flag fabric (triangle/banner)
    final flagPath = Path();
    flagPath.moveTo(peak.dx, peak.dy - flagHeight);
    flagPath.lineTo(peak.dx + flagWidth, peak.dy - flagHeight + flagHeight * 0.25);
    flagPath.lineTo(peak.dx, peak.dy - flagHeight + flagHeight * 0.5);
    flagPath.close();

    final flagPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          themeColor,
          themeColor.withValues(alpha: 0.8),
        ],
      ).createShader(Rect.fromLTWH(peak.dx, peak.dy - flagHeight, flagWidth, flagHeight * 0.5));
    canvas.drawPath(flagPath, flagPaint);

    // Flag pin dot
    final dotPaint = Paint()..color = themeColor;
    canvas.drawCircle(peak - Offset(0, flagHeight), 2.5, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _MountainPainter oldDelegate) {
    return oldDelegate.themeColor != themeColor || oldDelegate.isDark != isDark;
  }
}



