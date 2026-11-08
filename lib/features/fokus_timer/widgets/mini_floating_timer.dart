import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:window_manager/window_manager.dart';
import 'fokus_timer_display.dart';
import 'premium_background.dart';
import '../../../core/providers.dart';
import '../../../shared/theme.dart';
import '../../../shared/motion.dart' as motion;
import '../../../models/task.dart';
import '../../../services/timer_sound_service.dart';

class MiniFloatingTimerWidget extends ConsumerWidget {
  const MiniFloatingTimerWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timerState = ref.watch(timerProvider);
    final tokens = FocusOsTheme.of(context);
    final focusedTaskId = ref.watch(focusedTaskProvider);
    final tasks = ref.watch(tasksProvider);

    Task? activeFocusedTask;
    if (focusedTaskId != null) {
      final found = tasks.where((t) => t.id == focusedTaskId);
      if (found.isNotEmpty) activeFocusedTask = found.first;
    }

    final isRunning = timerState.running;
    final isAlarmPlaying = ref.watch(timerSoundProvider).isAlarmPlaying;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: tokens.borderSubtle,
        ),
      ),
      child: Stack(
        children: [
          // Theme/scene background matching the main page
          const PremiumBackground(),

          // Drag region to move the window!
          Positioned.fill(
            child: DragToMoveArea(
              child: const SizedBox.expand(),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 12),
                // Title / Task Name
                if (activeFocusedTask != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      activeFocusedTask.title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: tokens.accent,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                else
                  Text(
                    'FOKUS',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: tokens.textMuted,
                      letterSpacing: 2.0,
                    ),
                  ),
                const Spacer(),
                // Timer Clock Display (enforce a fixed width/height of 200px)
                const SizedBox(
                  width: 200,
                  height: 200,
                  child: FocusTimerDisplay(
                    showCompletion: false,
                    onTap: null,
                    hideLabel: true,
                  ),
                ),
                const Spacer(),
                // Control buttons row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Reset Button
                    _MiniControlBtn(
                      icon: Icons.replay_rounded,
                      tooltip: 'Reset',
                      onTap: () {
                        ref.read(timerProvider.notifier).reset();
                      },
                    ),
                    const SizedBox(width: 16),
                    // Play/Pause/Stop Alarm button
                    _MiniControlBtn(
                      icon: isAlarmPlaying
                          ? Icons.stop_rounded
                          : (isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded),
                      tooltip: isAlarmPlaying
                          ? 'Stop Alarm'
                          : (isRunning ? 'Pause' : 'Start'),
                      highlighted: true,
                      onTap: () {
                        if (isAlarmPlaying) {
                          ref.read(timerSoundProvider.notifier).stopAlarm();
                          return;
                        }
                        final notifier = ref.read(timerProvider.notifier);
                        if (isRunning) {
                          notifier.pause();
                        } else {
                          notifier.start();
                        }
                      },
                    ),
                    const SizedBox(width: 16),
                    // Exit Mini Mode button (Restores regular window size)
                    _MiniControlBtn(
                      icon: Icons.open_in_full_rounded,
                      tooltip: 'Exit mini mode',
                      onTap: () {
                        ref.read(miniModeProvider.notifier).toggle();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniControlBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool highlighted;

  const _MiniControlBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = FocusOsTheme.of(context);
    return Tooltip(
      message: tooltip,
      child: motion.PremiumHoverEffect(
        hoverScale: 1.1,
        pressScale: 0.9,
        onTap: onTap,
        child: Container(
          width: highlighted ? 42 : 34,
          height: highlighted ? 42 : 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: highlighted
                ? tokens.accent
                : tokens.surface.withValues(alpha: 0.5),
            border: Border.all(
              color: highlighted
                  ? Colors.transparent
                  : tokens.borderSubtle.withValues(alpha: 0.3),
            ),
            boxShadow: highlighted
                ? [
                    BoxShadow(
                      color: tokens.accent.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [],
          ),
          child: Icon(
            icon,
            size: highlighted ? 22 : 18,
            color: highlighted ? Colors.white : tokens.textPrimary,
          ),
        ),
      ),
    );
  }
}
