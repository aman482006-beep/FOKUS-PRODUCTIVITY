import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/motion.dart' as motion;
import '../../../shared/theme.dart';
import '../../../core/providers.dart';
import '../../../services/fokus_history_service.dart';
import '../../../models/task.dart';

class FocusTimerTaskSelectorPanel extends ConsumerStatefulWidget {
  final bool isBottomSheet;
  final ValueChanged<bool>? onCollapseChanged;

  const FocusTimerTaskSelectorPanel({
    super.key,
    this.isBottomSheet = false,
    this.onCollapseChanged,
  });

  @override
  ConsumerState<FocusTimerTaskSelectorPanel> createState() =>
      _FocusTimerTaskSelectorPanelState();
}

class _FocusTimerTaskSelectorPanelState
    extends ConsumerState<FocusTimerTaskSelectorPanel> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  String _searchQuery = '';
  bool _isCollapsed = false;

  void _toggleCollapsed(bool collapsed) {
    setState(() {
      _isCollapsed = collapsed;
    });
    widget.onCollapseChanged?.call(collapsed);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _quickCreateTask() {
    final title = _searchQuery.trim();
    if (title.isEmpty) return;

    // Call tasks notifier to add task
    ref.read(tasksProvider.notifier).addTask(title);

    // Find the newly added task (should be at the start of tasks list since we insert it at index 0)
    final tasks = ref.read(tasksProvider);
    final newTask = tasks.firstWhere(
      (t) => t.title.trim().toLowerCase() == title.toLowerCase(),
      orElse: () => tasks.first,
    );

    // Set as active focused task
    ref.read(focusedTaskProvider.notifier).state = newTask.id;

    // Reset input
    _searchController.clear();
    setState(() {
      _searchQuery = '';
    });
    _focusNode.unfocus();

    if (widget.isBottomSheet) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = FocusOsTheme.of(context);
    final tasks = ref.watch(tasksProvider);
    final focusedTaskId = ref.watch(focusedTaskProvider);

    // Get active tasks (not done, not archived)
    final pendingTasks = tasks.where((t) => !t.done && !t.archived).toList();

    // Get recently focused tasks using FokusHistoryService
    final recentSessions = FokusHistoryService.loadSessions();
    recentSessions.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final recentTaskIds = recentSessions
        .map((s) => s.taskId)
        .where((id) => id != null)
        .cast<String>()
        .toSet()
        .toList();

    final recentTasks = pendingTasks
        .where((t) => recentTaskIds.contains(t.id))
        .toList();

    // Filter tasks based on search query
    final query = _searchQuery.toLowerCase().trim();
    final filteredTasks = query.isEmpty
        ? pendingTasks
        : pendingTasks
            .where((t) => t.title.toLowerCase().contains(query))
            .toList();

    // Check if the current search matches any existing tasks exactly
    final exactMatch = filteredTasks.any(
        (t) => t.title.trim().toLowerCase() == query);

    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Panel Header
        Row(
          children: [
            Icon(
              Icons.assignment_outlined,
              size: 15,
              color: tokens.accent,
            ),
            const SizedBox(width: 8),
            Text(
              'What are you working on?',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: tokens.textPrimary,
                letterSpacing: 0.1,
              ),
            ),
            const Spacer(),
            if (focusedTaskId != null) ...[
              GestureDetector(
                onTap: () {
                  ref.read(focusedTaskProvider.notifier).state = null;
                  if (widget.isBottomSheet) Navigator.pop(context);
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Text(
                    'Clear',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: tokens.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            if (!widget.isBottomSheet)
              GestureDetector(
                onTap: () => _toggleCollapsed(true),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Icon(
                    Icons.keyboard_double_arrow_right_rounded,
                    size: 16,
                    color: tokens.textSecondary,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        // Search / Create Input Field
        Container(
          height: 38,
          decoration: BoxDecoration(
            color: tokens.brightness == Brightness.dark
                ? Colors.black.safeWithOpacity(0.2)
                : Colors.white.safeWithOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: tokens.borderSubtle.safeWithOpacity(0.5),
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 10),
              Icon(
                query.isNotEmpty && !exactMatch ? Icons.add_rounded : Icons.search_rounded,
                size: 15,
                color: tokens.textMuted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _focusNode,
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                  onSubmitted: (_) {
                    if (query.isNotEmpty && !exactMatch) {
                      _quickCreateTask();
                    }
                  },
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    color: tokens.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search or quick create...',
                    hintStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: tokens.textMuted,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              if (_searchQuery.isNotEmpty) ...[
                GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Icon(
                      Icons.close_rounded,
                      size: 13,
                      color: tokens.textMuted,
                    ),
                  ),
                ),
                if (!exactMatch)
                  GestureDetector(
                    onTap: _quickCreateTask,
                    child: Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: tokens.accent.safeWithOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.check_rounded,
                        size: 12,
                        color: tokens.accent,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Scrollable List of Tasks
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: ShaderMask(
              shaderCallback: (Rect rect) {
                return const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.purple, Colors.transparent, Colors.transparent, Colors.purple],
                  stops: [0.0, 0.05, 0.95, 1.0],
                ).createShader(rect);
              },
              blendMode: BlendMode.dstOut,
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: [
                  // No Task / Just Focus Option
                  _buildTaskRow(
                    title: 'Just Fokus (No Task)',
                    colorHex: '#94A3B8', // Muted slate color
                    isSelected: focusedTaskId == null,
                    focusTime: '',
                    onTap: () {
                      ref.read(focusedTaskProvider.notifier).state = null;
                      if (widget.isBottomSheet) Navigator.pop(context);
                    },
                    tokens: tokens,
                  ),
                  const SizedBox(height: 4),

                  if (query.isNotEmpty) ...[
                    // Search results
                    if (filteredTasks.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
                        child: Column(
                          children: [
                            Text(
                              'No matching tasks found',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                color: tokens.textSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: _quickCreateTask,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: tokens.accent.safeWithOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: tokens.accent.safeWithOpacity(0.2)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.add, size: 12, color: tokens.accent),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Create "$_searchQuery"',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: tokens.accent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ...filteredTasks.map(
                        (task) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: _buildTaskRow(
                            title: task.title,
                            colorHex: task.color,
                            isSelected: focusedTaskId == task.id,
                            focusTime: task.totalFocusMinutes > 0
                                ? task.formattedFocusTime
                                : '',
                            onTap: () {
                              ref.read(focusedTaskProvider.notifier).state = task.id;
                              if (widget.isBottomSheet) Navigator.pop(context);
                            },
                            tokens: tokens,
                          ),
                        ),
                      ),
                  ] else ...[
                    // Recent Tasks Section
                    if (recentTasks.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(left: 8, top: 8, bottom: 6),
                        child: Text(
                          'RECENTLY WORKED ON',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: tokens.textSecondary,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      ...recentTasks.take(4).map(
                            (task) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: _buildTaskRow(
                                title: task.title,
                                colorHex: task.color,
                                isSelected: focusedTaskId == task.id,
                                focusTime: task.totalFocusMinutes > 0
                                    ? task.formattedFocusTime
                                    : '',
                                onTap: () {
                                  ref.read(focusedTaskProvider.notifier).state = task.id;
                                  if (widget.isBottomSheet) Navigator.pop(context);
                                },
                                tokens: tokens,
                              ),
                            ),
                          ),
                    ],

                    // All Pending Tasks Section
                    if (pendingTasks.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(left: 8, top: 12, bottom: 6),
                        child: Text(
                          recentTasks.isNotEmpty ? 'OTHER TASKS' : 'TASKS',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: tokens.textSecondary,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      // Exclude already shown recent tasks to avoid duplicates
                      ...pendingTasks
                          .where((t) => !recentTasks.take(4).contains(t))
                          .map(
                            (task) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: _buildTaskRow(
                                title: task.title,
                                colorHex: task.color,
                                isSelected: focusedTaskId == task.id,
                                focusTime: task.totalFocusMinutes > 0
                                    ? task.formattedFocusTime
                                    : '',
                                onTap: () {
                                  ref.read(focusedTaskProvider.notifier).state = task.id;
                                  if (widget.isBottomSheet) Navigator.pop(context);
                                },
                                tokens: tokens,
                              ),
                            ),
                          ),
                    ] else if (recentTasks.isEmpty) ...[
                      // Empty tasks state
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 8),
                        child: Text(
                          'No pending tasks.\nType above to quick create!',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: tokens.textSecondary,
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );

    if (widget.isBottomSheet) {
      return Container(
        height: MediaQuery.of(context).size.height * 0.6,
        padding: const EdgeInsets.all(20),
        child: content,
      );
    }

    // Desktop Panel decoration (Glassmorphic & Collapsible)
    return Align(
      alignment: Alignment.topRight,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: motion.PremiumCurves.easeOutCubic,
        width: _isCollapsed ? 48.0 : 290.0,
        height: _isCollapsed ? 48.0 : 380.0,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_isCollapsed ? 14 : 16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.safeWithOpacity(0.12),
              blurRadius: _isCollapsed ? 12 : 20,
              offset: Offset(0, _isCollapsed ? 4 : 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_isCollapsed ? 14 : 16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
            child: Container(
              decoration: BoxDecoration(
                color: tokens.brightness == Brightness.dark
                    ? Colors.black.safeWithOpacity(0.4)
                    : Colors.white.safeWithOpacity(0.4),
                borderRadius: BorderRadius.circular(_isCollapsed ? 14 : 16),
                border: Border.all(
                  color: tokens.brightness == Brightness.dark
                      ? Colors.white.safeWithOpacity(0.06)
                      : Colors.black.safeWithOpacity(0.06),
                  width: 0.8,
                ),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _isCollapsed
                    ? _buildCollapsedContent(context, tokens, focusedTaskId, tasks)
                    : _buildExpandedContent(context, tokens, content),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTaskRow({
    required String title,
    required String? colorHex,
    required bool isSelected,
    required String focusTime,
    required VoidCallback onTap,
    required ThemeTokens tokens,
  }) {
    final hex = colorHex ?? '#6366F1';
    final rowColor = Color(int.parse(hex.replaceFirst('#', '0xFF')));

    return motion.PremiumHoverEffect(
      hoverScale: 1.015,
      pressScale: 0.985,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? rowColor.safeWithOpacity(0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? rowColor.safeWithOpacity(0.2)
                : Colors.transparent,
            width: 0.8,
          ),
        ),
        child: Row(
          children: [
            // Color dot
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: rowColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            // Title
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? tokens.textPrimary : tokens.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (focusTime.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                focusTime,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10.5,
                  color: isSelected ? rowColor.safeWithOpacity(0.8) : tokens.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            if (isSelected) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.check_rounded,
                size: 13,
                color: rowColor,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCollapsedContent(
    BuildContext context,
    ThemeTokens tokens,
    String? focusedTaskId,
    List<Task> tasks,
  ) {
    final activeTask = focusedTaskId != null
        ? tasks.firstWhere((t) => t.id == focusedTaskId, orElse: () => tasks.first)
        : null;
    final Color iconColor = activeTask != null
        ? Color(int.parse((activeTask.color ?? '#6366F1').replaceFirst('#', '0xFF')))
        : tokens.textSecondary;

    return Tooltip(
      message: activeTask != null
          ? 'Working on: ${activeTask.title}'
          : 'Select what you are working on',
      textStyle: GoogleFonts.plusJakartaSans(
        fontSize: 11,
        color: tokens.brightness == Brightness.light ? Colors.black : Colors.white,
      ),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: motion.PremiumHoverEffect(
        hoverScale: 1.08,
        pressScale: 0.92,
        onTap: () => _toggleCollapsed(false),
        child: Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.assignment_outlined,
                size: 20,
                color: iconColor,
              ),
              if (focusedTaskId != null)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: iconColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: iconColor.safeWithOpacity(0.4),
                          blurRadius: 4,
                          spreadRadius: 1,
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

  Widget _buildExpandedContent(
    BuildContext context,
    ThemeTokens tokens,
    Widget content,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: content,
    );
  }
}
