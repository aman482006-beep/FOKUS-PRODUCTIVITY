import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/providers.dart';
import '../../core/navigation.dart';
import '../../shared/motion.dart' as motion;
import '../../shared/theme.dart';
import '../../services/ambient_sound_service.dart';
import 'widgets/premium_background.dart';
import 'widgets/fokus_timer_display.dart';

/// Deep Work Mode — immersive fullscreen focus experience with premium visuals.
class DeepWorkMode extends ConsumerStatefulWidget {
  const DeepWorkMode({super.key});

  @override
  ConsumerState<DeepWorkMode> createState() => _DeepWorkModeState();
}

class _DeepWorkModeState extends ConsumerState<DeepWorkMode>
    with TickerProviderStateMixin {
  late AnimationController _enterController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late AnimationController _controlsController;
  Timer? _controlsTimer;
  bool _showCompletion = false;

  @override
  void initState() {
    super.initState();

    // Staged cinematic entry
    _enterController = AnimationController(
      vsync: this,
      duration: motion.PremiumDurations.immersiveEnter,
    );

    _controlsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _controlsController.value = 1.0;

    // Stage 1: Fade in background
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _enterController,
        curve: const Interval(0.0, 0.5, curve: motion.PremiumCurves.easeOutCubic),
      ),
    );

    // Stage 2: Timer grows from center
    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(
        parent: _enterController,
        curve: const Interval(0.2, 0.7, curve: motion.PremiumCurves.elasticOut),
      ),
    );

    // Stage 3: Fade slide up
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _enterController,
        curve: const Interval(0.15, 0.55, curve: motion.PremiumCurves.easeOutCubic),
      ),
    );

    _enterController.forward();
    _startControlsTimer();
  }

  @override
  void dispose() {
    _enterController.dispose();
    _controlsController.dispose();
    _controlsTimer?.cancel();
    super.dispose();
  }

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        _controlsController.reverse();
      }
    });
  }

  void _showControls() {
    _controlsController.forward();
    _startControlsTimer();
  }

  void _endSession() {
    final timerState = ref.read(timerProvider);
    if (timerState.running) {
      final elapsed = timerState.elapsed;
      final minutes = elapsed ~/ 60;
      final focusedTaskId = ref.read(focusedTaskProvider);

      final plannedMin = (timerState.plannedSeconds ?? timerState.totalSeconds) ~/ 60;
      final startTimeStr = timerState.sessionStartTime?.toIso8601String() ?? DateTime.now().toIso8601String();
      final endTimeStr = DateTime.now().toIso8601String();

      ref.read(fokusHistoryProvider.notifier).logSession(
        minutes,
        taskId: focusedTaskId,
        isInterrupted: false,
        sessionType: 'Deep Work',
        plannedDurationMinutes: plannedMin,
        actualDurationSeconds: elapsed,
        startTime: startTimeStr,
        endTime: endTimeStr,
        isBreak: false,
      );

      if (focusedTaskId != null) {
        ref.read(tasksProvider.notifier).attributeFocusTime(focusedTaskId, minutes);
      }
    }
    ref.read(timerProvider.notifier).reset();

    // Show completion briefly before exiting
    setState(() => _showCompletion = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        ref.read(deepWorkModeProvider.notifier).state = false;
        ref.read(fokusModeProvider.notifier).state = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = FocusOsTheme.of(context);

    return GestureDetector(
      onTap: _showControls,
      onLongPress: _showControls,
      child: AnimatedBuilder(
        animation: _enterController,
        builder: (context, child) {
          return Stack(
            children: [
              // Layer 1: Premium layered background
              const PremiumBackground(),

              // ── Subtle pulsing ring ──
              if (_enterController.value > 0)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: 0.03 * _fadeAnimation.value,
                      child: CustomPaint(
                        painter: _AmbientPulsePainter(
                          color: tokens.accent,
                          progress: _enterController.value,
                        ),
                      ),
                    ),
                  ),
                ),

              // ── Centered timer area ──
              Center(
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Premium large timer display
                        const SizedBox(
                          width: 480,
                          height: 480,
                          child: FocusTimerDisplay(
                            showCompletion: false,
                            onTap: null,
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Current task
                        const _DeepWorkTask(),

                        const SizedBox(height: 40),

                        // Controls
                        if (_showCompletion)
                          _SessionCompletion(tokens: tokens)
                        else
                          FadeTransition(
                            opacity: _controlsController,
                            child: const _DeepWorkControls(),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Bottom subtle hint ──
              Positioned(
                bottom: 24,
                left: 0,
                right: 0,
                child: FadeTransition(
                  opacity: _controlsController,
                  child: Center(
                    child: Text(
                      'Tap anywhere to show controls',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: tokens.textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),

              // ── Top right sound indicator ──
              Positioned(
                top: 24,
                right: 24,
                child: FadeTransition(
                  opacity: Tween<double>(begin: 0.0, end: 0.3).animate(
                    CurvedAnimation(
                      parent: _controlsController,
                      curve: motion.PremiumCurves.easeOutCubic,
                    ),
                  ),
                  child: const _DeepWorkSoundIndicator(),
                ),
              ),

              // ── Top left exit ──
              Positioned(
                top: 24,
                left: 24,
                child: FadeTransition(
                  opacity: _controlsController,
                  child: motion.PremiumHoverEffect(
                    hoverScale: 1.04,
                    pressScale: 0.96,
                    onTap: _endSession,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: tokens.surface.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: tokens.borderSubtle.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.close,
                              size: 14, color: tokens.textSecondary),
                          const SizedBox(width: 6),
                          Text(
                            'End session',
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 12, color: tokens.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Ambient pulse painter — subtle radial breathing rings
class _AmbientPulsePainter extends CustomPainter {
  final Color color;
  final double progress;

  _AmbientPulsePainter({
    required this.color,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = min(size.width, size.height) * 0.48;

    for (int i = 0; i < 3; i++) {
      final phase = (progress * 6.283 + i * 2.094) % 6.283;
      final radius = maxRadius * (0.6 + 0.4 * (phase / 6.283));
      final alpha = ((0.3 - i * 0.08) * (0.5 + 0.5 * (phase / 6.283))).clamp(0.0, 0.3);

      final paint = Paint()
        ..color = color.withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AmbientPulsePainter old) =>
      old.progress != progress || old.color != color;
}

// ──────────────────────────────────────────────
// Current Task Display
// ──────────────────────────────────────────────

class _DeepWorkTask extends ConsumerWidget {
  const _DeepWorkTask();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(tasksProvider);
    final activeTask = tasks.where((t) => !t.done).isNotEmpty
        ? tasks.firstWhere((t) => !t.done)
        : null;
    final tokens = FocusOsTheme.of(context);

    if (activeTask == null) {
      return Text(
        'No active task',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          color: tokens.textMuted,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: tokens.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.borderSubtle.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: tokens.accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            activeTask.title,
            style: GoogleFonts.plusJakartaSans(fontSize: 14, color: tokens.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Deep Work Controls — premium buttons
// ──────────────────────────────────────────────

class _DeepWorkControls extends ConsumerWidget {
  const _DeepWorkControls();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timerState = ref.watch(timerProvider);
    final soundState = ref.watch(ambientSoundProvider);
    final tokens = FocusOsTheme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Pause/Resume
        motion.PremiumHoverEffect(
          hoverScale: 1.06,
          pressScale: 0.94,
          onTap: () {
            final notifier = ref.read(timerProvider.notifier);
            if (timerState.running) {
              notifier.pause();
            } else {
              notifier.start();
            }
          },
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: timerState.running
                  ? LinearGradient(
                      colors: [
                        tokens.accent.withValues(alpha: 0.2),
                        tokens.accent.withValues(alpha: 0.05),
                      ],
                    )
                  : tokens.accentGradient,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: timerState.running
                    ? tokens.accent.withValues(alpha: 0.3)
                    : Colors.transparent,
              ),
              boxShadow: [
                BoxShadow(
                  color: tokens.accent.withValues(alpha: 0.1),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              timerState.running
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              size: 26,
              color: timerState.running ? tokens.accent : Colors.white,
            ),
          ),
        ),

        const SizedBox(width: 12),

        // Sound toggle
        motion.PremiumHoverEffect(
          hoverScale: 1.06,
          pressScale: 0.94,
          onTap: () {
            final notifier = ref.read(ambientSoundProvider.notifier);
            if (soundState.isPlaying) {
              notifier.setType(AmbientSoundType.none);
            } else {
              if (soundState.customPath != null) {
                notifier.toggleCustomSound();
              } else {
                notifier.setType(AmbientSoundType.rain);
              }
            }
          },
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: soundState.isPlaying
                  ? tokens.accent.withValues(alpha: 0.12)
                  : tokens.surface.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: soundState.isPlaying
                    ? tokens.accent.withValues(alpha: 0.3)
                    : tokens.borderSubtle.withValues(alpha: 0.5),
              ),
            ),
            child: Icon(
              soundState.isPlaying
                  ? Icons.volume_up_outlined
                  : Icons.volume_off_outlined,
              size: 20,
              color: soundState.isPlaying
                  ? tokens.accent
                  : tokens.textMuted,
            ),
          ),
        ),

        const SizedBox(width: 12),

        // Add note
        motion.PremiumHoverEffect(
          hoverScale: 1.06,
          pressScale: 0.94,
          onTap: () {
            ref.read(quickCaptureOpenProvider.notifier).state = true;
          },
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: tokens.surface.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: tokens.borderSubtle.withValues(alpha: 0.5)),
            ),
            child: Icon(
              Icons.edit_outlined,
              size: 20,
              color: tokens.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────
// Session Completion — elegant celebration
// ──────────────────────────────────────────────

class _SessionCompletion extends StatefulWidget {
  final ThemeTokens tokens;

  const _SessionCompletion({required this.tokens});

  @override
  State<_SessionCompletion> createState() => _SessionCompletionState();
}

class _SessionCompletionState extends State<_SessionCompletion>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scaleAnim = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: motion.PremiumCurves.springyOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnim,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: widget.tokens.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.check_circle_outline,
                size: 32, color: widget.tokens.accent),
          ),
          const SizedBox(height: 12),
          Text(
            'Session complete',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: widget.tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Great fokus session',
            style: GoogleFonts.plusJakartaSans(fontSize: 13, color: widget.tokens.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Sound Indicator
// ──────────────────────────────────────────────

class _DeepWorkSoundIndicator extends ConsumerWidget {
  const _DeepWorkSoundIndicator();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final soundState = ref.watch(ambientSoundProvider);
    final tokens = FocusOsTheme.of(context);

    if (!soundState.isPlaying) {
      return const SizedBox.shrink();
    }

    final label = soundState.isCustomActive
        ? (soundState.customName ?? 'Custom')
        : soundState.type.name;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: tokens.surface.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.borderSubtle.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.volume_up_outlined, size: 12, color: tokens.textMuted),
          const SizedBox(width: 4),
          Text(label,
              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: tokens.textMuted)),
        ],
      ),
    );
  }
}
