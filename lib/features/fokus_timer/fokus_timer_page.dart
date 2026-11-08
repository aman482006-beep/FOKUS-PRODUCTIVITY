import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:window_manager/window_manager.dart' as wm;
import 'package:google_fonts/google_fonts.dart';

import '../../shared/motion.dart' as motion;
import '../../shared/theme.dart';
import '../../core/providers.dart';
import '../../core/navigation.dart';
import '../../models/task.dart';
import '../../services/fokus_history_service.dart';
import '../../services/timer_sound_service.dart';

import 'widgets/premium_background.dart';
import 'widgets/fokus_timer_display.dart';
import 'widgets/fokus_timer_presets.dart';
import 'widgets/ambient_sound_mini_player.dart';
import 'widgets/task_selector_panel.dart';


/// Focus Timer Page — premium, centered, immersive focus experience.
class FokusTimerPage extends ConsumerStatefulWidget {
  const FokusTimerPage({super.key});

  @override
  ConsumerState<FokusTimerPage> createState() => _FokusTimerPageState();
}

class _FokusTimerPageState extends ConsumerState<FokusTimerPage>
    with SingleTickerProviderStateMixin {
  bool _showCompletion = false;
  bool _taskSelectorCollapsed = false;
  late AnimationController _entryController;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;
  final _breakDurationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(
      parent: _entryController,
      curve: const Cubic(0.16, 1.0, 0.3, 1.0),
    );
    _scaleAnim = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Cubic(0.34, 1.56, 0.64, 1.0),
      ),
    );
    _entryController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final timerState = ref.read(timerProvider);
        if (timerState.totalSeconds == 0) {
          ref.read(timerProvider.notifier).setDuration(1500);
        }
      }
    });
  }

  @override
  void dispose() {
    _entryController.dispose();
    _breakDurationController.dispose();
    super.dispose();
  }

  void _completeSession() {
    final timerState = ref.read(timerProvider);
    final elapsed = timerState.elapsed;
    final minutes = elapsed ~/ 60;
    final focusedTaskId = ref.read(focusedTaskProvider);

    final isCountdown = timerState.isCountdown;
    final isDeepWork = ref.read(deepWorkModeProvider);
    final sessionType = isDeepWork
        ? 'Deep Work'
        : (!isCountdown
            ? 'Flow'
            : (timerState.totalSeconds == 1500 ? 'Pomodoro' : 'Custom Timer'));

    // Compute detailed tracking fields
    final plannedMin = (timerState.plannedSeconds ?? timerState.totalSeconds) ~/ 60;
    final actualSec = timerState.elapsed;
    final startTimeStr = timerState.sessionStartTime?.toIso8601String() ?? DateTime.now().toIso8601String();
    final endTimeStr = DateTime.now().toIso8601String();

    ref.read(fokusHistoryProvider.notifier).logSession(
      minutes,
      taskId: focusedTaskId,
      isInterrupted: false,
      sessionType: sessionType,
      plannedDurationMinutes: plannedMin,
      actualDurationSeconds: actualSec,
      startTime: startTimeStr,
      endTime: endTimeStr,
      isBreak: false,
    );

    if (focusedTaskId != null) {
      ref.read(tasksProvider.notifier).attributeFocusTime(focusedTaskId, minutes);
    }

    ref.read(timerProvider.notifier).complete();
    FokusHistoryService.recordLastSession(
      '$minutes min',
      FokusHistoryService.totalSessionsCount(),
    );

    setState(() => _showCompletion = true);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showCompletion = false);
    });
  }

  void _endSession() {
    final timerState = ref.read(timerProvider);
    if (timerState.elapsed >= timerState.totalSeconds) {
      _completeSession();
    } else if (timerState.elapsed > 0) {
      _savePartial();
    }
  }

  void _savePartial() {
    final timerState = ref.read(timerProvider);
    final minutes = (timerState.elapsed ~/ 60).clamp(1, 9999);
    final focusedTaskId = ref.read(focusedTaskProvider);

    final isCountdown = timerState.isCountdown;
    final isDeepWork = ref.read(deepWorkModeProvider);
    final sessionType = isDeepWork
        ? 'Deep Work'
        : (!isCountdown
            ? 'Flow'
            : (timerState.totalSeconds == 1500 ? 'Pomodoro' : 'Custom Timer'));

    // Compute detailed tracking fields
    final plannedMin = (timerState.plannedSeconds ?? timerState.totalSeconds) ~/ 60;
    final actualSec = timerState.elapsed;
    final startTimeStr = timerState.sessionStartTime?.toIso8601String() ?? DateTime.now().toIso8601String();
    final endTimeStr = DateTime.now().toIso8601String();

    ref.read(fokusHistoryProvider.notifier).logSession(
      minutes,
      taskId: focusedTaskId,
      isInterrupted: true,
      sessionType: sessionType,
      plannedDurationMinutes: plannedMin,
      actualDurationSeconds: actualSec,
      startTime: startTimeStr,
      endTime: endTimeStr,
      isBreak: false,
    );

    if (focusedTaskId != null) {
      ref.read(tasksProvider.notifier).attributeInterruption(focusedTaskId, minutes);
    }

    ref.read(timerProvider.notifier).interrupt();
  }

  void _toggleTimer() {
    if (ref.read(timerSoundProvider).isAlarmPlaying) {
      ref.read(timerSoundProvider.notifier).stopAlarm();
      return;
    }
    if (_showCompletion) return;
    final notifier = ref.read(timerProvider.notifier);
    final timerState = ref.read(timerProvider);
    if (timerState.running) {
      notifier.pause();
    } else {
      notifier.start();
    }
  }

  Future<void> _toggleFullscreen() async {
    final currentlyFullscreen = ref.read(fullscreenProvider);
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      if (currentlyFullscreen) {
        await wm.WindowManager.instance.setFullScreen(false);
      } else {
        await wm.WindowManager.instance.setFullScreen(true);
      }
    }
    ref.read(fullscreenProvider.notifier).setFullscreen(!currentlyFullscreen);
  }

  Future<void> _pickWallpaper() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result != null && result.files.single.path != null) {
      ref.read(wallpaperProvider.notifier).setImagePath(result.files.single.path);
    }
  }

  void _clearWallpaper() {
    ref.read(wallpaperProvider.notifier).resetToDefault();
  }

  @override
  Widget build(BuildContext context) {
    // Only watch infrequently-changing providers at the page level.
    // timerProvider is watched inside a Consumer below to prevent
    // full-page rebuilds on every 1-second timer tick.
    final isDeepWork = ref.watch(deepWorkModeProvider);
    final wallpaperState = ref.watch(wallpaperProvider);
    final isFullscreen = ref.watch(fullscreenProvider);

    return FadeTransition(
      opacity: _fadeAnim,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Consumer(builder: (context, ref, _) {
          final timerState = ref.watch(timerProvider);
          final focusedTaskId = ref.watch(focusedTaskProvider);
          final tasks = ref.watch(tasksProvider);
          final hasWallpaper = wallpaperState.imagePath != null;

          Task? activeFocusedTask;
          if (focusedTaskId != null) {
            final found = tasks.where((t) => t.id == focusedTaskId);
            if (found.isNotEmpty) activeFocusedTask = found.first;
          }

          return Stack(
            children: [
              // Layer 1: Premium background (handled with transitions & animations)
              const PremiumBackground(),

              // Layer 4: Breathing ambient glow behind timer
              Positioned.fill(
                child: IgnorePointer(
                  child: _AmbientBreathingGlow(
                    color: FocusOsTheme.of(context).accent,
                    isActive: timerState.running || timerState.elapsed > 0,
                  ),
                ),
              ),

              // Layer 5: Top-right action buttons
              Positioned(
                top: MediaQuery.of(context).padding.top + 20,
                right: 24,
                child: _buildTopBarButtons(hasWallpaper, isFullscreen),
              ),

              // Main Content Layer: Centered hero + optional Side Panel
              Positioned.fill(
                child: Row(
                  children: [
                    // Left balancing spacer (matches the right sidebar width to keep the timer centered)
                    if (!isDeepWork && MediaQuery.of(context).size.width > 1150)
                      SizedBox(width: _taskSelectorCollapsed ? 80.0 : 322.0),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minWidth: constraints.maxWidth,
                                minHeight: constraints.maxHeight,
                              ),
                              child: IntrinsicHeight(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Vertical offset to place timer at ~44% viewport height
                                    const Spacer(flex: 5),

                                    // ── Status label ──
                                    if (!isDeepWork)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 20),
                                        child: _buildStatusLabel(timerState),
                                      ),

                                    // ── Timer display with RepaintBoundary isolation ──
                                    RepaintBoundary(
                                      child: _buildTimerDisplay(timerState),
                                    ),

                                    const SizedBox(height: 28),

                                    // ── Primary CTA — Pill button ──
                                    if (!isDeepWork)
                                      _buildPrimaryCTA(timerState, activeFocusedTask, tasks),

                                    // ── Break options card (when paused) ──
                                    if (!isDeepWork && timerState.elapsed > 0 && !timerState.running && !timerState.isBreak) ...[
                                      const SizedBox(height: 16),
                                      _buildBreakOptionsCard(FocusOsTheme.of(context)),
                                    ],

                                    const SizedBox(height: 16),

                                    // ── Secondary controls ──
                                    if (!isDeepWork)
                                      _buildSecondaryControls(timerState),

                                    // Bottom spacer for balance
                                    const Spacer(flex: 6),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    if (!isDeepWork && MediaQuery.of(context).size.width > 960)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: motion.PremiumCurves.easeOutCubic,
                        width: _taskSelectorCollapsed ? 80.0 : 322.0,
                        padding: EdgeInsets.only(
                          top: MediaQuery.of(context).padding.top + 90,
                          right: 32,
                          bottom: 100,
                        ),
                        child: FocusTimerTaskSelectorPanel(
                          onCollapseChanged: (collapsed) {
                            setState(() {
                              _taskSelectorCollapsed = collapsed;
                            });
                          },
                        ),
                      ),
                  ],
                ),
              ),
              
              // Layer 7: Floating pill-shaped glassmorphism sound player
              if (!isDeepWork)
                const Positioned(
                  bottom: 24,
                  left: 24,
                  child: AmbientSoundMiniPlayer(),
                ),


            ],
          );
        }),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Top-right buttons: Wallpaper + Fullscreen + Theme
  // ──────────────────────────────────────────────

  Widget _buildTopBarButtons(bool hasWallpaper, bool isFullscreen) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Wallpaper picker
        _TopBarButton(
          icon: hasWallpaper ? Icons.wallpaper_rounded : Icons.image_outlined,
          tooltip: 'Set background wallpaper',
          active: hasWallpaper,
          onTap: _pickWallpaper,
        ),
        if (hasWallpaper) ...[
          const SizedBox(width: 8),
          _TopBarButton(
            icon: Icons.close_rounded,
            tooltip: 'Clear wallpaper',
            active: true,
            onTap: _clearWallpaper,
          ),
        ],
        const SizedBox(width: 8),

        // Fullscreen toggle
        _TopBarButton(
          icon: isFullscreen
              ? Icons.fullscreen_exit_rounded
              : Icons.fullscreen_rounded,
          tooltip: isFullscreen ? 'Exit fullscreen' : 'Fullscreen',
          active: isFullscreen,
          onTap: _toggleFullscreen,
        ),
        const SizedBox(width: 8),

        // Theme shortcut
        _TopBarButton(
          icon: Icons.palette_outlined,
          tooltip: 'Change theme',
          active: false,
          onTap: () => ref.read(settingsModalOpenProvider.notifier).state = true,
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────
  // Status Label
  // ──────────────────────────────────────────────

  Widget _buildStatusLabel(TimerState timerState) {
    final tokens = FocusOsTheme.of(context);

    String label;
    Color color;
    if (_showCompletion) {
      label = 'SESSION COMPLETE';
      color = tokens.accent;
    } else if (timerState.running) {
      label = 'FOCUSING';
      color = tokens.accent;
    } else if (timerState.elapsed > 0) {
      label = 'PAUSED';
      color = tokens.textSecondary;
    } else {
      label = 'READY';
      color = tokens.textSecondary;
    }

    return AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 300),
      style: GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: 4.5,
      ),
      child: Text(label),
    );
  }

  // ──────────────────────────────────────────────
  // Timer Display
  // ──────────────────────────────────────────────

  Widget _buildTimerDisplay(TimerState timerState) {
    final viewport = MediaQuery.of(context).size;
    final customization = ref.watch(timerCustomizationProvider);

    double maxAllowedSize;
    switch (customization.size) {
      case 'small':
        maxAllowedSize = 260.0;
        break;
      case 'medium':
        maxAllowedSize = 340.0;
        break;
      case 'large':
        maxAllowedSize = 440.0;
        break;
      case 'xl':
        maxAllowedSize = 540.0;
        break;
      default:
        maxAllowedSize = 440.0;
    }

    final cardSize = min(min(viewport.width, viewport.height) * 0.82, maxAllowedSize);

    return SizedBox(
      width: cardSize,
      height: cardSize,
      child: const FocusTimerDisplay(
        showCompletion: false,
        onTap: null,
        hideLabel: true,
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Primary CTA — Premium Pill Button
  // ──────────────────────────────────────────────

  Widget _buildPrimaryCTA(
    TimerState timerState,
    Task? activeFocusedTask,
    List<Task> tasks,
  ) {
    final tokens = FocusOsTheme.of(context);
    final soundState = ref.watch(timerSoundProvider);
    final isAlarmPlaying = soundState.isAlarmPlaying;

    final isRunning = timerState.running;
    final isComplete = _showCompletion;
    final hasElapsed = timerState.elapsed > 0;

    String label;
    IconData icon;
    if (isAlarmPlaying) {
      label = 'Stop Alarm';
      icon = Icons.stop_rounded;
    } else if (isComplete) {
      label = 'Session Complete';
      icon = Icons.check_circle_rounded;
    } else if (timerState.isBreak) {
      if (!timerState.running && timerState.breakElapsed >= timerState.breakDuration) {
        label = 'Resume Fokus';
        icon = Icons.play_arrow_rounded;
      } else {
        label = 'Skip Break';
        icon = Icons.fast_forward_rounded;
      }
    } else if (isRunning) {
      label = 'Pause';
      icon = Icons.pause_rounded;
    } else if (hasElapsed) {
      label = 'Resume';
      icon = Icons.play_arrow_rounded;
    } else {
      label = 'Start Fokus';
      icon = Icons.play_arrow_rounded;
    }

    final isSubtle = !isAlarmPlaying && (isRunning || (timerState.isBreak && timerState.running));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Active task indicator (subtle, above button)
        if (activeFocusedTask != null && !isComplete && !timerState.isBreak && !isAlarmPlaying)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildTaskIndicator(activeFocusedTask, tokens),
          ),

        // Pill button
        motion.PremiumHoverEffect(
          hoverScale: 1.03,
          pressScale: 0.96,
          onTap: isAlarmPlaying
              ? () => ref.read(timerSoundProvider.notifier).stopAlarm()
              : (isComplete
                  ? null
                  : (timerState.isBreak
                      ? () => ref.read(timerProvider.notifier).resumeFocus()
                      : _toggleTimer)),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: const Cubic(0.16, 1.0, 0.3, 1.0),
            padding: const EdgeInsets.symmetric(
              horizontal: 40,
              vertical: 16,
            ),
            decoration: BoxDecoration(
              gradient: isAlarmPlaying
                  ? const LinearGradient(
                      colors: [Colors.redAccent, Colors.orangeAccent],
                    )
                  : (isSubtle
                      ? LinearGradient(
                          colors: [
                            tokens.accent.withValues(alpha: 0.15),
                            tokens.accent.withValues(alpha: 0.05),
                          ],
                        )
                      : LinearGradient(
                          colors: [tokens.accent, tokens.accentSecondary],
                        )),
              borderRadius: BorderRadius.circular(50),
              border: Border.all(
                color: isSubtle
                    ? tokens.accent.withValues(alpha: 0.3)
                    : Colors.transparent,
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: isAlarmPlaying
                      ? Colors.redAccent.withValues(alpha: 0.3)
                      : tokens.accent.withValues(alpha: isSubtle ? 0.1 : 0.2),
                  blurRadius: isAlarmPlaying ? 30 : (isSubtle ? 16 : 24),
                  offset: Offset(0, isSubtle ? 2 : 6),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: isSubtle ? tokens.accent : Colors.white,
                ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isSubtle ? tokens.accent : Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────
  // Break Options Card
  // ──────────────────────────────────────────────

  Widget _buildBreakOptionsCard(ThemeTokens tokens) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surface.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: tokens.borderSubtle.withValues(alpha: 0.15),
          width: 1.0,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.coffee_rounded,
                size: 16,
                color: tokens.accentSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                'Take a Break?',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Presets row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildBreakPresetButton(5, tokens),
              _buildBreakPresetButton(10, tokens),
              _buildBreakPresetButton(15, tokens),
            ],
          ),
          const SizedBox(height: 12),
          // Custom duration input
          _buildCustomBreakInput(tokens),
        ],
      ),
      ),
    );
  }

  Widget _buildBreakPresetButton(int minutes, ThemeTokens tokens) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: motion.PremiumHoverEffect(
          hoverScale: 1.05,
          pressScale: 0.95,
          onTap: () {
            ref.read(timerProvider.notifier).startBreak(minutes * 60);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: tokens.surface.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: tokens.borderSubtle.withValues(alpha: 0.2),
                width: 1.0,
              ),
            ),
            child: Center(
              child: Text(
                '${minutes}m',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: tokens.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomBreakInput(ThemeTokens tokens) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: tokens.brightness == Brightness.dark
            ? Colors.black.withValues(alpha: 0.2)
            : Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: tokens.borderSubtle.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(
            Icons.edit_note_rounded,
            size: 18,
            color: tokens.textSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _breakDurationController,
              keyboardType: TextInputType.number,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: tokens.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Custom break (mins)...',
                hintStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: tokens.textSecondary,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              onSubmitted: (val) {
                final mins = int.tryParse(val.trim());
                if (mins != null && mins > 0) {
                  ref.read(timerProvider.notifier).startBreak(mins * 60);
                  _breakDurationController.clear();
                }
              },
            ),
          ),
          motion.PremiumHoverEffect(
            hoverScale: 1.1,
            pressScale: 0.9,
            onTap: () {
              final val = _breakDurationController.text;
              final mins = int.tryParse(val.trim());
              if (mins != null && mins > 0) {
                ref.read(timerProvider.notifier).startBreak(mins * 60);
                _breakDurationController.clear();
              }
            },
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: tokens.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.arrow_forward_rounded,
                size: 14,
                color: tokens.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Task Indicator Chip
  // ──────────────────────────────────────────────

  Widget _buildTaskIndicator(Task task, ThemeTokens tokens) {
    final taskColor = Color(task.colorValue);
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      constraints: BoxConstraints(
        maxWidth: screenWidth > 600 ? 360 : screenWidth * 0.8,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: taskColor.safeWithOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: taskColor.safeWithOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: taskColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              task.title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: tokens.textSecondary,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          if (task.totalFocusMinutes > 0) ...[
            const SizedBox(width: 6),
            Text(
              '· ${task.formattedFocusTime}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: tokens.textSecondary,
              ),
            ),
          ],
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => ref.read(focusedTaskProvider.notifier).state = null,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Icon(
                Icons.close_rounded,
                size: 13,
                color: tokens.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Secondary Controls
  // ──────────────────────────────────────────────

  void _showTaskSelectorBottomSheet(BuildContext context) {
    final tokens = FocusOsTheme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: tokens.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => const FocusTimerTaskSelectorPanel(isBottomSheet: true),
    );
  }

  Widget _buildSecondaryControls(TimerState timerState) {
    final tokens = FocusOsTheme.of(context);
    final hasElapsed = timerState.elapsed > 0;
    final isRunning = timerState.running;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Presets dropdown / quick selector
          const FocusTimerPresets(),

          const SizedBox(width: 12),

          // Stop button (only when timer is active)
          if (hasElapsed && !_showCompletion)
            _SecondaryIconButton(
              icon: Icons.stop_rounded,
              tooltip: 'End session',
              onTap: _endSession,
              tokens: tokens,
            ),

          if (hasElapsed && !_showCompletion) const SizedBox(width: 8),

          // Reset button (only when timer is active)
          if (hasElapsed && !_showCompletion)
            _SecondaryIconButton(
              icon: Icons.refresh_rounded,
              tooltip: 'Reset',
              onTap: () => ref.read(timerProvider.notifier).reset(),
              tokens: tokens,
            ),

          if (hasElapsed && !_showCompletion && (timerState.running))
            const SizedBox(width: 8),

          // Today stats chip
          if (!isRunning && !hasElapsed)
            _TodayStatsChip(tokens: tokens),

          // Select task shortcut on narrow screens
          if (!isRunning && !hasElapsed && MediaQuery.of(context).size.width <= 960) ...[
            const SizedBox(width: 8),
            _SecondaryIconButton(
              icon: Icons.assignment_outlined,
              tooltip: 'Select fokus task',
              onTap: () => _showTaskSelectorBottomSheet(context),
              tokens: tokens,
            ),
          ],
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Ambient Breathing Glow
// ──────────────────────────────────────────────

class _AmbientBreathingGlow extends StatefulWidget {
  final Color color;
  final bool isActive;

  const _AmbientBreathingGlow({
    required this.color,
    required this.isActive,
  });

  @override
  State<_AmbientBreathingGlow> createState() => _AmbientBreathingGlowState();
}

class _AmbientBreathingGlowState extends State<_AmbientBreathingGlow>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final pulse = _controller.value;
        return CustomPaint(
          painter: _GlowPainter(
            color: widget.color,
            phase: pulse,
          ),
        );
      },
    );
  }
}

class _GlowPainter extends CustomPainter {
  final Color color;
  final double phase;

  _GlowPainter({required this.color, required this.phase});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = min(size.width, size.height) * 0.25;

    for (int i = 0; i < 3; i++) {
      final radius = baseRadius + (i * 30) + (phase * 20);
      final alpha = ((0.04 - i * 0.012) * (0.6 + 0.4 * phase)).clamp(0.0, 0.04);

      final paint = Paint()
        ..color = color.withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 - (i * 0.5);

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GlowPainter old) =>
      old.phase != phase || old.color != color;
}

// ──────────────────────────────────────────────
// Top Bar Button — unified glass style
// ──────────────────────────────────────────────

class _TopBarButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback onTap;

  const _TopBarButton({
    required this.icon,
    required this.tooltip,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = FocusOsTheme.of(context);

    final child = Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: active
            ? tokens.accent.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active
              ? tokens.accent.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.08),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        icon,
        size: 18,
        color: active ? tokens.accent : tokens.textSecondary,
      ),
    );

    return Tooltip(
      message: tooltip,
      child: motion.PremiumHoverEffect(
        hoverScale: 1.08,
        pressScale: 0.94,
        onTap: onTap,
        child: child,
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Secondary Icon Button
// ──────────────────────────────────────────────

class _SecondaryIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final ThemeTokens tokens;

  const _SecondaryIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return motion.PremiumHoverEffect(
      hoverScale: 1.08,
      pressScale: 0.94,
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Tooltip(
          message: tooltip,
          child: Icon(icon, size: 18, color: tokens.textSecondary),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Today Stats Chip
// ──────────────────────────────────────────────

class _TodayStatsChip extends StatelessWidget {
  final ThemeTokens tokens;

  const _TodayStatsChip({required this.tokens});

  @override
  Widget build(BuildContext context) {
    final todayMinutes = FokusHistoryService.todayMinutes();
    final todaySessions = FokusHistoryService.todaySessions();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.today_outlined, size: 13, color: tokens.textMuted),
          const SizedBox(width: 6),
          Text(
            'Today: ${todayMinutes ~/ 60}h ${todayMinutes % 60}m · $todaySessions sessions',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: tokens.textMuted,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}


