import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/theme.dart';
import '../../models/task.dart';
import '../../core/providers.dart';
import '../../core/navigation.dart';

/// Kanban board view for tasks — drag-and-drop between columns.
///
/// Columns are derived from task state:
///  - **To Do**: pending tasks with no focus time yet
///  - **In Progress**: pending tasks that have accumulated focus time
///  - **Done**: completed tasks
class KanbanBoard extends ConsumerStatefulWidget {
  const KanbanBoard({super.key});

  @override
  ConsumerState<KanbanBoard> createState() => _KanbanBoardState();
}

class _KanbanBoardState extends ConsumerState<KanbanBoard> {
  @override
  Widget build(BuildContext context) {
    final tokens = FocusOsTheme.of(context);
    final tasks = ref.watch(tasksProvider);
    final focusedTaskId = ref.watch(focusedTaskProvider);

    final pending = tasks.where((t) => !t.done && !t.archived).toList();
    final todoTasks = pending.where((t) => t.totalFocusMinutes == 0).toList();
    final inProgressTasks = pending.where((t) => t.totalFocusMinutes > 0).toList();
    final doneTasks = tasks.where((t) => t.done && !t.archived).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final columnWidth = constraints.maxWidth > 600
            ? (constraints.maxWidth - 48) / 3
            : (constraints.maxWidth - 16) / 3;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 32),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _KanbanColumn(
                  title: 'To Do',
                  icon: Icons.inbox_outlined,
                  color: const Color(0xFF6366F1),
                  tasks: todoTasks,
                  tokens: tokens,
                  focusedTaskId: focusedTaskId,
                  columnWidth: columnWidth.clamp(220.0, 360.0),
                  onDrop: (taskId) => _moveToColumn(taskId, 'todo'),
                  onToggle: (id) => ref.read(tasksProvider.notifier).toggleTask(id),
                  onDelete: (id) => ref.read(tasksProvider.notifier).removeTask(id),
                  onFocus: (id) {
                    ref.read(focusedTaskProvider.notifier).state = id;
                    ref.read(navigationProvider.notifier).state = NavDestination.focus;
                  },
                  onArchive: (id) => ref.read(tasksProvider.notifier).archiveTask(id),
                ),
                const SizedBox(width: 16),
                _KanbanColumn(
                  title: 'In Progress',
                  icon: Icons.play_circle_outline_rounded,
                  color: const Color(0xFFF59E0B),
                  tasks: inProgressTasks,
                  tokens: tokens,
                  focusedTaskId: focusedTaskId,
                  columnWidth: columnWidth.clamp(220.0, 360.0),
                  onDrop: (taskId) => _moveToColumn(taskId, 'inProgress'),
                  onToggle: (id) => ref.read(tasksProvider.notifier).toggleTask(id),
                  onDelete: (id) => ref.read(tasksProvider.notifier).removeTask(id),
                  onFocus: (id) {
                    ref.read(focusedTaskProvider.notifier).state = id;
                    ref.read(navigationProvider.notifier).state = NavDestination.focus;
                  },
                  onArchive: (id) => ref.read(tasksProvider.notifier).archiveTask(id),
                ),
                const SizedBox(width: 16),
                _KanbanColumn(
                  title: 'Done',
                  icon: Icons.check_circle_outline_rounded,
                  color: const Color(0xFF10B981),
                  tasks: doneTasks,
                  tokens: tokens,
                  focusedTaskId: focusedTaskId,
                  columnWidth: columnWidth.clamp(220.0, 360.0),
                  onDrop: (taskId) => _moveToColumn(taskId, 'done'),
                  onToggle: (id) => ref.read(tasksProvider.notifier).toggleTask(id),
                  onDelete: (id) => ref.read(tasksProvider.notifier).removeTask(id),
                  onFocus: (id) {
                    ref.read(focusedTaskProvider.notifier).state = id;
                    ref.read(navigationProvider.notifier).state = NavDestination.focus;
                  },
                  onArchive: (id) => ref.read(tasksProvider.notifier).archiveTask(id),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _moveToColumn(String taskId, String column) {
    final tasksNotifier = ref.read(tasksProvider.notifier);
    switch (column) {
      case 'todo':
        // Move to todo: ensure not done
        tasksNotifier.toggleTask(taskId);
        break;
      case 'inProgress':
        // Move to in progress: ensure not done
        final task = ref.read(tasksProvider).firstWhere((t) => t.id == taskId);
        if (task.done) {
          tasksNotifier.toggleTask(taskId); // uncheck done
        }
        break;
      case 'done':
        // Move to done: mark as done
        final task = ref.read(tasksProvider).firstWhere((t) => t.id == taskId);
        if (!task.done) {
          tasksNotifier.toggleTask(taskId);
        }
        break;
    }
  }
}

// ──────────────────────────────────────────────
// KANBAN COLUMN
// ──────────────────────────────────────────────

class _KanbanColumn extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<Task> tasks;
  final ThemeTokens tokens;
  final String? focusedTaskId;
  final double columnWidth;
  final ValueChanged<String> onDrop;
  final ValueChanged<String> onToggle;
  final ValueChanged<String> onDelete;
  final ValueChanged<String> onFocus;
  final ValueChanged<String> onArchive;

  const _KanbanColumn({
    required this.title,
    required this.icon,
    required this.color,
    required this.tasks,
    required this.tokens,
    required this.focusedTaskId,
    required this.columnWidth,
    required this.onDrop,
    required this.onToggle,
    required this.onDelete,
    required this.onFocus,
    required this.onArchive,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: columnWidth,
      child: DragTarget<String>(
        onWillAcceptWithDetails: (details) => true,
        onAcceptWithDetails: (details) {
          onDrop(details.data);
        },
        builder: (context, candidateData, rejectedData) {
          final isHovering = candidateData.isNotEmpty;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: isHovering
                  ? color.withValues(alpha: 0.04)
                  : tokens.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isHovering
                    ? color.withValues(alpha: 0.3)
                    : tokens.borderSubtle,
                width: isHovering ? 1.5 : 1,
              ),
              boxShadow: isHovering
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Column Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: tokens.borderSubtle.withValues(alpha: 0.5),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.4),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: tokens.textPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${tasks.length}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Task Cards
                Expanded(
                  child: tasks.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  icon,
                                  size: 28,
                                  color: tokens.textMuted.withValues(alpha: 0.3),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'No tasks',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: tokens.textMuted.withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          physics: const BouncingScrollPhysics(),
                          itemCount: tasks.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final task = tasks[index];
                            return _KanbanTaskCard(
                              task: task,
                              tokens: tokens,
                              isFocused: task.id == focusedTaskId,
                              onToggle: () => onToggle(task.id),
                              onDelete: () => onDelete(task.id),
                              onFocus: () => onFocus(task.id),
                              onArchive: () => onArchive(task.id),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ──────────────────────────────────────────────
// KANBAN TASK CARD
// ──────────────────────────────────────────────

class _KanbanTaskCard extends StatelessWidget {
  final Task task;
  final ThemeTokens tokens;
  final bool isFocused;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onFocus;
  final VoidCallback onArchive;

  const _KanbanTaskCard({
    required this.task,
    required this.tokens,
    required this.isFocused,
    required this.onToggle,
    required this.onDelete,
    required this.onFocus,
    required this.onArchive,
  });

  Color get _taskColor {
    final hex = task.color ?? '#6366F1';
    return Color(int.parse(hex.replaceFirst('#', '0xFF')));
  }

  Color get _priorityColor {
    switch (task.priority) {
      case 'high':
        return const Color(0xFFEF4444);
      case 'medium':
        return const Color(0xFFF59E0B);
      case 'low':
        return const Color(0xFF22C55E);
      default:
        return const Color(0xFF6B7280);
    }
  }

  String get _priorityLabel {
    switch (task.priority) {
      case 'high':
        return 'High';
      case 'medium':
        return 'Med';
      case 'low':
        return 'Low';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Draggable<String>(
      data: task.id,
      feedback: Material(
        color: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _taskColor.withValues(alpha: 0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: _buildCardContent(showActions: false),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _buildCardBody(),
      ),
      child: _buildCardBody(),
    );
  }

  Widget _buildCardBody() {
    return MouseRegion(
      cursor: SystemMouseCursors.grab,
      child: GestureDetector(
        onTap: onFocus,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isFocused
                  ? _taskColor.withValues(alpha: 0.5)
                  : tokens.borderSubtle,
              width: isFocused ? 1.5 : 1,
            ),
            boxShadow: isFocused
                ? [
                    BoxShadow(
                      color: _taskColor.withValues(alpha: 0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: _buildCardContent(showActions: true),
        ),
      ),
    );
  }

  Widget _buildCardContent({required bool showActions}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Color bar + Priority badge
        Row(
          children: [
            // Color indicator bar
            Container(
              width: 24,
              height: 3,
              decoration: BoxDecoration(
                color: _taskColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Spacer(),
            // Priority badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _priorityColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _priorityLabel,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: _priorityColor,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Task title
        Text(
          task.title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: task.done
                ? tokens.textMuted
                : tokens.textPrimary,
            decoration: task.done ? TextDecoration.lineThrough : null,
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),

        // Notes preview
        if (task.notes != null && task.notes!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            task.notes!,
            style: TextStyle(
              fontSize: 11,
              color: tokens.textMuted,
              height: 1.4,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],

        const SizedBox(height: 10),

        // Bottom row: Focus time + Due date + Actions
        Row(
          children: [
            // Focus time indicator
            if (task.totalFocusMinutes > 0) ...[
              Icon(
                Icons.timer_outlined,
                size: 11,
                color: tokens.textMuted,
              ),
              const SizedBox(width: 3),
              Text(
                task.formattedFocusTime,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: tokens.textMuted,
                ),
              ),
              const SizedBox(width: 8),
            ],

            // Due date
            if (task.dueDate != null) ...[
              Icon(
                Icons.event_outlined,
                size: 11,
                color: _isOverdue
                    ? const Color(0xFFEF4444)
                    : tokens.textMuted,
              ),
              const SizedBox(width: 3),
              Text(
                _formatDueDate(task.dueDate!),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: _isOverdue
                      ? const Color(0xFFEF4444)
                      : tokens.textMuted,
                ),
              ),
            ],

            const Spacer(),

            // Action buttons
            if (showActions) ...[
              _ActionIconButton(
                icon: task.done
                    ? Icons.replay_rounded
                    : Icons.check_circle_outline_rounded,
                color: task.done ? tokens.textMuted : const Color(0xFF10B981),
                tooltip: task.done ? 'Mark pending' : 'Mark done',
                onTap: onToggle,
              ),
              const SizedBox(width: 4),
              _ActionIconButton(
                icon: Icons.center_focus_strong_rounded,
                color: tokens.accent,
                tooltip: 'Fokus on this task',
                onTap: onFocus,
              ),
            ],
          ],
        ),
      ],
    );
  }

  bool get _isOverdue {
    if (task.dueDate == null) return false;
    return task.dueDate!.isBefore(DateTime.now()) && !task.done;
  }

  String _formatDueDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = target.difference(today).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff == -1) return 'Yesterday';
    if (diff > 1 && diff <= 7) return '${diff}d left';
    if (diff < -1 && diff >= -7) return '${-diff}d ago';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}';
  }
}

// ──────────────────────────────────────────────
// ACTION ICON BUTTON
// ──────────────────────────────────────────────

class _ActionIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionIconButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 13, color: color),
          ),
        ),
      ),
    );
  }
}
