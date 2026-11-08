import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/shortcuts.dart';
import '../../../shared/motion.dart' as motion;
import '../../../shared/theme.dart';
import '../../../core/providers.dart';
import '../../../core/navigation.dart';
import '../../../services/fokus_history_service.dart';
import '../../../models/task.dart';

/// Left panel — Today's Tasks, Focus Streak, Session Stats, Quick Actions.
class LeftPanel extends ConsumerWidget {
  const LeftPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = FocusOsTheme.of(context);
    final tasks = ref.watch(tasksProvider);
    final pendingTasks = tasks.where((t) => !t.done && !t.archived).toList();
    final streak = FokusHistoryService.getDailyStreak();
    final todayMinutes = FokusHistoryService.todayMinutes();
    final todaySessions = FokusHistoryService.todaySessions();
    final totalSessions = FokusHistoryService.totalSessionsCount();

    return Container(
      width: 300,
      margin: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            _PanelSection(
              title: 'Today\'s Tasks',
              icon: Icons.check_circle_outline,
              child: Column(
                children: [
                  if (pendingTasks.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'No tasks yet — add one to get started',
                        style: TextStyle(
                          fontSize: 12,
                          color: tokens.textMuted,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    )
                  else
                    ...pendingTasks.take(6).map(
                          (task) => _TaskCard(
                            task: task,
                            onToggle: () => ref
                                .read(tasksProvider.notifier)
                                .toggleTask(task.id),
                            onSelect: () {
                              ref.read(focusedTaskProvider.notifier).state =
                                  task.id;
                            },
                            isFocused: ref.watch(focusedTaskProvider) == task.id,
                          ),
                        ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => ref
                        .read(navigationProvider.notifier)
                        .state = NavDestination.tasks,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: tokens.borderSubtle.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        pendingTasks.isEmpty
                            ? 'Create a new task →'
                            : 'View all tasks →',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: tokens.textMuted,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _PanelSection(
              title: 'Fokus Streak',
              icon: Icons.local_fire_department,
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFF59E0B),
                          const Color(0xFFEF4444),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        '$streak',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$streak day${streak == 1 ? '' : 's'}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: tokens.textPrimary,
                          ),
                        ),
                        Text(
                          'Current streak',
                          style: TextStyle(
                            fontSize: 12,
                            color: tokens.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _PanelSection(
              title: 'Session Stats',
              icon: Icons.bar_chart_rounded,
              child: Column(
                children: [
                  _StatBar(
                    label: 'Today\'s focus',
                    value:
                        '${todayMinutes ~/ 60}h ${todayMinutes % 60}m',
                    progress: (todayMinutes / 240.0).clamp(0.0, 1.0),
                    color: tokens.accent,
                    tokens: tokens,
                  ),
                  const SizedBox(height: 8),
                  _StatBar(
                    label: 'Sessions today',
                    value: '$todaySessions',
                    progress: (todaySessions / 8.0).clamp(0.0, 1.0),
                    color: tokens.accentSecondary,
                    tokens: tokens,
                  ),
                  const SizedBox(height: 8),
                  _StatBar(
                    label: 'All-time sessions',
                    value: '$totalSessions',
                    progress: (totalSessions / 100.0).clamp(0.0, 1.0),
                    color: tokens.textSecondary,
                    tokens: tokens,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _PanelSection(
              title: 'Quick Actions',
              icon: Icons.flash_on,
              child: Column(
                children: [
                  _QuickActionButton(
                    icon: Icons.edit_outlined,
                    label: 'Quick capture',
                    shortcut: '${FocusOsShortcut.modifierLabel}Q',
                    onTap: () => ref
                        .read(quickCaptureOpenProvider.notifier)
                        .state = true,
                    tokens: tokens,
                  ),
                  const SizedBox(height: 6),
                  _QuickActionButton(
                    icon: Icons.do_not_disturb_alt,
                    label: 'Toggle fokus mode',
                    shortcut: '${FocusOsShortcut.modifierLabel}D',
                    onTap: () {
                      final fokusMode = ref.read(fokusModeProvider);
                      ref.read(fokusModeProvider.notifier).state = !fokusMode;
                    },
                    tokens: tokens,
                  ),
                  const SizedBox(height: 6),
                  _QuickActionButton(
                    icon: Icons.palette_outlined,
                    label: 'Change theme',
                    shortcut: null,
                    onTap: () => ref
                        .read(navigationProvider.notifier)
                        .state = NavDestination.settings,
                    tokens: tokens,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Panel Section
// ──────────────────────────────────────────────

class _PanelSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _PanelSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = FocusOsTheme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: tokens.borderSubtle.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: tokens.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, size: 14, color: tokens.accent),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: tokens.textSecondary,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Task Card
// ──────────────────────────────────────────────

class _TaskCard extends ConsumerStatefulWidget {
  final Task task;
  final VoidCallback onToggle;
  final VoidCallback onSelect;
  final bool isFocused;

  const _TaskCard({
    required this.task,
    required this.onToggle,
    required this.onSelect,
    required this.isFocused,
  });

  @override
  ConsumerState<_TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends ConsumerState<_TaskCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = FocusOsTheme.of(context);
    final taskColor = Color(widget.task.colorValue);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onSelect,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isFocused
                ? taskColor.withValues(alpha: 0.08)
                : _hovered
                    ? tokens.textPrimary.withValues(alpha: 0.03)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.isFocused
                  ? taskColor.withValues(alpha: 0.25)
                  : _hovered
                      ? tokens.borderMedium.withValues(alpha: 0.3)
                      : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              // Checkbox
              GestureDetector(
                onTap: widget.onToggle,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: widget.task.done
                        ? taskColor
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: widget.task.done
                          ? taskColor
                          : tokens.borderMedium,
                      width: 1.5,
                    ),
                  ),
                  child: widget.task.done
                      ? const Icon(Icons.check,
                          size: 12, color: Colors.white)
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              // Color dot
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: taskColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              // Title
              Expanded(
                child: Text(
                  widget.task.title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        widget.isFocused ? FontWeight.w500 : FontWeight.w400,
                    color: widget.task.done
                        ? tokens.textMuted
                        : tokens.textPrimary,
                    decoration: widget.task.done
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              // Focus time badge
              if (widget.task.totalFocusMinutes > 0)
                Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: taskColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    widget.task.formattedFocusTime,
                    style: TextStyle(
                      fontSize: 9,
                      color: taskColor,
                      fontWeight: FontWeight.w500,
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
// Stat Bar
// ──────────────────────────────────────────────

class _StatBar extends StatelessWidget {
  final String label;
  final String value;
  final double progress;
  final Color color;
  final ThemeTokens tokens;

  const _StatBar({
    required this.label,
    required this.value,
    required this.progress,
    required this.color,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: tokens.textSecondary,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: tokens.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 3,
            backgroundColor: tokens.borderSubtle,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────
// Quick Action Button
// ──────────────────────────────────────────────

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? shortcut;
  final VoidCallback onTap;
  final ThemeTokens tokens;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.shortcut,
    required this.onTap,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return motion.HoverBuilder(
      onTap: onTap,
      hoverScale: 1.01,
      pressScale: 0.98,
      builder: (context, hovered, pressed) {
        return AnimatedContainer(
          duration: motion.PremiumDurations.hover,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: hovered
                ? tokens.textPrimary.withValues(alpha: 0.04)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 14,
                color: hovered ? tokens.textPrimary : tokens.textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: hovered ? tokens.textPrimary : tokens.textSecondary,
                  ),
                ),
              ),
              if (shortcut != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.borderSubtle,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    shortcut!,
                    style: TextStyle(
                      fontSize: 9,
                      color: tokens.textMuted,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
