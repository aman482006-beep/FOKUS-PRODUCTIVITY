import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math';
import 'dart:ui' show ImageFilter, FontFeature;
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/scheduler.dart';
import 'dart:async';
import '../../../shared/motion.dart' as motion;
import '../../../shared/theme.dart';
import '../../../core/providers.dart';
import '../../../models/task.dart';

/// Premium circular focus timer with extensive customization settings.
class FocusTimerDisplay extends ConsumerStatefulWidget {
  final bool showCompletion;
  final VoidCallback? onTap;
  final bool hideLabel;

  const FocusTimerDisplay({
    super.key,
    required this.showCompletion,
    required this.onTap,
    this.hideLabel = false,
  });

  @override
  ConsumerState<FocusTimerDisplay> createState() => _FocusTimerDisplayState();
}

class _FocusTimerDisplayState extends ConsumerState<FocusTimerDisplay>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Ticker _msTicker;
  StreamSubscription? _timerSubscription;
  StreamSubscription? _customizationSubscription;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _msTicker = createTicker((elapsed) {
      if (mounted) {
        setState(() {});
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _timerSubscription = ref.read(timerProvider.notifier).stream.listen((next) {
        if (!mounted) return;
        final customization = ref.read(timerCustomizationProvider);
        _updateTicker(next.running, customization.showMilliseconds);
      });

      _customizationSubscription = ref.read(timerCustomizationProvider.notifier).stream.listen((next) {
        if (!mounted) return;
        final timerState = ref.read(timerProvider);
        _updateTicker(timerState.running, next.showMilliseconds);
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final timerState = ref.read(timerProvider);
        final customization = ref.read(timerCustomizationProvider);
        _updateTicker(timerState.running, customization.showMilliseconds);
      }
    });
  }

  void _updateTicker(bool running, bool showMs) {
    if (running && showMs) {
      if (!_msTicker.isTicking) {
        _msTicker.start();
      }
    } else {
      if (_msTicker.isTicking) {
        _msTicker.stop();
      }
    }
  }

  @override
  void dispose() {
    _timerSubscription?.cancel();
    _customizationSubscription?.cancel();
    _pulseController.dispose();
    _msTicker.dispose();
    super.dispose();
  }

  TextStyle _getTimerTextStyle(String fontStyle, double fontSize, Color color) {
    final fontFeatures = const [FontFeature.tabularFigures()];
    switch (fontStyle) {
      case 'minimal':
        return GoogleFonts.plusJakartaSans(
          fontSize: fontSize,
          fontWeight: FontWeight.w400,
          color: color,
          letterSpacing: -2.0,
          height: 1.0,
          fontFeatures: fontFeatures,
        );
      case 'bold_digital':
        return GoogleFonts.quantico(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: -1.0,
          height: 1.0,
          fontFeatures: fontFeatures,
        );
      case 'futuristic':
        return GoogleFonts.orbitron(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: -1.0,
          height: 1.0,
          fontFeatures: fontFeatures,
        );
      case 'elegant':
        return GoogleFonts.playfairDisplay(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: -1.0,
          height: 1.0,
          fontFeatures: fontFeatures,
        );
      case 'mechanical':
        return GoogleFonts.shareTechMono(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: color,
          letterSpacing: -1.0,
          height: 1.0,
          fontFeatures: fontFeatures,
        );
      default:
        return GoogleFonts.manrope(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: -3.0,
          height: 1.0,
          fontFeatures: fontFeatures,
        );
    }
  }

  Color _resolveDigitColor(String theme, Color? customColor, ThemeTokens tokens) {
    switch (theme) {
      case 'white': return Colors.white;
      case 'blue': return const Color(0xFF3B82F6);
      case 'green': return const Color(0xFF10B981);
      case 'red': return const Color(0xFFEF4444);
      case 'amber': return const Color(0xFFF59E0B);
      case 'auto':
      default: return customColor ?? tokens.textPrimary;
    }
  }

  Color _resolveRingColor(String theme, Color? customColor, ThemeTokens tokens) {
    switch (theme) {
      case 'white': return Colors.white;
      case 'blue': return const Color(0xFF3B82F6);
      case 'green': return const Color(0xFF10B981);
      case 'red': return const Color(0xFFEF4444);
      case 'amber': return const Color(0xFFF59E0B);
      case 'auto':
      default: return customColor ?? tokens.accent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final timerState = ref.watch(timerProvider);
    final tokens = FocusOsTheme.of(context);
    final activeScene = ref.watch(fokusSceneProvider);
    final wallpaperState = ref.watch(wallpaperProvider);
    final hasWallpaper = wallpaperState.imagePath != null;
    final customColor = ref.watch(timerColorProvider);

    final customization = ref.watch(timerCustomizationProvider);

    // Watch tasks for remaining task display
    final focusedTaskId = ref.watch(focusedTaskProvider);
    final tasks = ref.watch(tasksProvider);
    Task? focusedTask;
    if (focusedTaskId != null) {
      try {
        focusedTask = tasks.firstWhere((t) => t.id == focusedTaskId);
      } catch (_) {}
    }

    // Handle animations enable/disable & reduced motion
    final isAnimEnabled = customization.enableAnimations && !customization.reducedMotion;
    if (!isAnimEnabled) {
      if (_pulseController.isAnimating) {
        _pulseController.stop();
      }
    } else {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    }



    final fontStyle = customization.fontStyle;
    final backgroundMode = customization.backgroundMode;

    // Resolve Colors
    final digitColor = _resolveDigitColor(customization.colorTheme, customColor, tokens);
    final ringColor = _resolveRingColor(customization.colorTheme, customColor, tokens);

    final totalSeconds = timerState.isBreak ? timerState.breakDuration : timerState.totalSeconds;
    final elapsed = timerState.isBreak ? timerState.breakElapsed : timerState.elapsed;
    final isCountdown = timerState.isBreak ? true : timerState.isCountdown;

    final displaySeconds = isCountdown
        ? (totalSeconds - elapsed).clamp(0, totalSeconds)
        : elapsed;

    final hours = (displaySeconds ~/ 3600);
    final minutes = ((displaySeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final seconds = (displaySeconds % 60).toString().padLeft(2, '0');

    // Milliseconds calculation
    final msVal = (timerState.running
        ? (isCountdown
            ? (1000 - (DateTime.now().millisecondsSinceEpoch % 1000))
            : (DateTime.now().millisecondsSinceEpoch % 1000))
        : 0).clamp(0, 999) ~/ 10;
    final msStr = msVal.toString().padLeft(2, '0');

    final progress = totalSeconds > 0
        ? elapsed / totalSeconds
        : 0.0;

    final isActive = timerState.running || timerState.elapsed > 0 || timerState.isBreak;

    // Session state label
    String stateLabel;
    Color stateColor;
    if (widget.showCompletion) {
      stateLabel = 'COMPLETE';
      stateColor = tokens.accent;
    } else if (timerState.isBreak) {
      if (!timerState.running && timerState.breakElapsed >= timerState.breakDuration) {
        stateLabel = 'RESUME';
        stateColor = tokens.accent;
      } else {
        stateLabel = 'BREAK';
        stateColor = tokens.accentSecondary;
      }
    } else if (timerState.running) {
      stateLabel = 'FOCUSING';
      stateColor = ringColor;
    } else if (timerState.elapsed > 0) {
      stateLabel = 'PAUSED';
      stateColor = tokens.textSecondary;
    } else {
      stateLabel = 'READY';
      stateColor = tokens.textSecondary;
    }

    // Resolve background mode decoration
    final isTransparent = backgroundMode == 'transparent';
    final isSolidDark = backgroundMode == 'solid_dark';
    final isGradient = backgroundMode == 'gradient';
    final isAdaptive = backgroundMode == 'adaptive';

    final effectiveIsSolid = isSolidDark || (isAdaptive && (activeScene.id == 'none' && !hasWallpaper));

    BoxDecoration innerPlateDecoration;
    bool shouldBlur = false;

    if (isTransparent) {
      innerPlateDecoration = const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.transparent,
      );
    } else if (effectiveIsSolid) {
      innerPlateDecoration = BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF0F0F11),
        border: Border.all(
          color: tokens.borderSubtle.withValues(alpha: 0.15),
        ),
      );
    } else if (isGradient) {
      innerPlateDecoration = BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            tokens.surface.withValues(alpha: 0.4),
            tokens.background.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: tokens.borderSubtle.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      );
    } else {
      shouldBlur = true;
      innerPlateDecoration = BoxDecoration(
        shape: BoxShape.circle,
        color: tokens.surface.withValues(alpha: 0.15),
        border: Border.all(
          color: tokens.borderSubtle.withValues(alpha: 0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 40,
            offset: const Offset(0, 12),
          ),
        ],
      );
    }

    final digitFlipDuration = isAnimEnabled
        ? motion.PremiumDurations.microFeedbackLong
        : Duration.zero;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Enforce maximum size from customization settings + support smaller containers
        double maxAllowedSize;
        switch (customization.size) {
          case 'small': maxAllowedSize = 260.0; break;
          case 'medium': maxAllowedSize = 340.0; break;
          case 'large': maxAllowedSize = 440.0; break;
          case 'xl': maxAllowedSize = 540.0; break;
          default: maxAllowedSize = 440.0;
        }

        final size = min(min(constraints.maxWidth, constraints.maxHeight), maxAllowedSize);
        final outerRingSize = size;
        const progressRingSize = 0.88; // % of outer
        const innerPanelSize = 0.70; // % of outer

        // Responsive typography scale factor (designed base scale at width 400.0)
        final scale = size / 400.0;

        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // ── Outermost breathing glow ring ──
              if (isAnimEnabled && customization.showProgressRing)
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, _) {
                    final pulse = _pulseController.value;
                    return Container(
                      width: outerRingSize,
                      height: outerRingSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: ringColor.withValues(
                                    alpha: 0.04 + (pulse * 0.03),
                                  ),
                                  blurRadius: 50 * scale + (pulse * 20),
                                  spreadRadius: 8 * scale + (pulse * 8),
                                ),
                                BoxShadow(
                                  color: ringColor.withValues(alpha: 0.015),
                                  blurRadius: 90 * scale,
                                  spreadRadius: 15 * scale,
                                ),
                              ]
                            : [],
                      ),
                    );
                  },
                ),

              // ── Progress ring ──
              SizedBox(
                width: outerRingSize * progressRingSize,
                height: outerRingSize * progressRingSize,
                child: CustomPaint(
                  painter: _TimerRingPainter(
                    progress: progress.clamp(0.0, 1.0),
                    color: isActive ? ringColor : tokens.textMuted,
                    trackColor: tokens.borderSubtle.withValues(alpha: isTransparent ? 0.08 : 0.25),
                    glowColor: ringColor,
                    isActive: isActive,
                    showProgressRing: customization.showProgressRing,
                  ),
                  child: Center(
                    child: Container(
                      width: outerRingSize * innerPanelSize,
                      height: outerRingSize * innerPanelSize,
                      decoration: innerPlateDecoration,
                      child: ClipOval(
                        child: Stack(
                          children: [
                            // Backdrop blur effect
                            if (shouldBlur)
                              Positioned.fill(
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(
                                    sigmaX: 20,
                                    sigmaY: 20,
                                  ),
                                  child: Container(
                                    color: tokens.surface.withValues(alpha: 0.1),
                                  ),
                                ),
                              ),
                            // Content wrapped in premium switcher styles
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 400),
                              switchInCurve: motion.PremiumCurves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              transitionBuilder: (child, animation) {
                                return FadeTransition(opacity: animation, child: child);
                              },
                              child: KeyedSubtree(
                                key: ValueKey('$fontStyle-$backgroundMode-${customization.colorTheme}-${customization.size}'),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // ── State label ──
                                      if (!widget.hideLabel && customization.showSessionLabel)
                                        AnimatedDefaultTextStyle(
                                          duration: motion.PremiumDurations.panelFade,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11 * scale,
                                            fontWeight: FontWeight.w600,
                                            color: stateColor,
                                            letterSpacing: 4.5 * scale,
                                          ),
                                          child: Text(stateLabel),
                                        ),
                                      SizedBox(height: 14 * scale),

                                      // ── Timer digits ──
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (customization.showMilliseconds)
                                              _buildMsPlaceholder(
                                                tokens,
                                                scale,
                                                fontStyle,
                                                hours > 0,
                                              ),
                                            if (customization.showSeconds) ...[
                                              if (hours > 0) ...[
                                                ..._buildDigitRow(
                                                  hours.toString().padLeft(2, '0'),
                                                  tokens,
                                                  digitColor,
                                                  hours > 0,
                                                  fontStyle,
                                                  scale,
                                                  digitFlipDuration,
                                                ),
                                                Padding(
                                                  padding: EdgeInsets.symmetric(
                                                      horizontal: 4 * scale),
                                                  child: Text(
                                                    ':',
                                                    style: _getTimerTextStyle(
                                                      fontStyle,
                                                      (hours > 0 ? 76.0 : 110.0) * scale,
                                                      digitColor.withValues(alpha: 0.35),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                              ..._buildDigitRow(
                                                minutes,
                                                tokens,
                                                digitColor,
                                                hours > 0,
                                                fontStyle,
                                                scale,
                                                digitFlipDuration,
                                              ),
                                              Padding(
                                                padding: EdgeInsets.symmetric(
                                                    horizontal: 4 * scale),
                                                child: Text(
                                                  ':',
                                                  style: _getTimerTextStyle(
                                                    fontStyle,
                                                    (hours > 0 ? 76.0 : 110.0) * scale,
                                                    digitColor.withValues(alpha: 0.35),
                                                  ),
                                                ),
                                              ),
                                              ..._buildDigitRow(
                                                seconds,
                                                tokens,
                                                digitColor,
                                                hours > 0,
                                                fontStyle,
                                                scale,
                                                digitFlipDuration,
                                              ),
                                            ] else ...[
                                              // Show seconds is false: HH:MM or just MM
                                              if (hours > 0) ...[
                                                ..._buildDigitRow(
                                                  hours.toString().padLeft(2, '0'),
                                                  tokens,
                                                  digitColor,
                                                  hours > 0,
                                                  fontStyle,
                                                  scale,
                                                  digitFlipDuration,
                                                ),
                                                Padding(
                                                  padding: EdgeInsets.symmetric(
                                                      horizontal: 4 * scale),
                                                  child: Text(
                                                    ':',
                                                    style: _getTimerTextStyle(
                                                      fontStyle,
                                                      (hours > 0 ? 76.0 : 110.0) * scale,
                                                      digitColor.withValues(alpha: 0.35),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                              ..._buildDigitRow(
                                                minutes,
                                                tokens,
                                                digitColor,
                                                hours > 0,
                                                fontStyle,
                                                scale,
                                                digitFlipDuration,
                                              ),
                                            ],

                                            // Milliseconds if enabled
                                            if (customization.showMilliseconds) ...[
                                              Padding(
                                                padding: EdgeInsets.symmetric(
                                                    horizontal: 2 * scale),
                                                child: Text(
                                                  '.',
                                                  style: _getTimerTextStyle(
                                                    fontStyle,
                                                    (hours > 0 ? 50.0 : 70.0) * scale,
                                                    digitColor.withValues(alpha: 0.35),
                                                  ),
                                                ),
                                              ),
                                              ..._buildDigitRow(
                                                msStr,
                                                tokens,
                                                digitColor,
                                                hours > 0,
                                                fontStyle,
                                                scale,
                                                digitFlipDuration,
                                                isMs: true,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      SizedBox(height: 14 * scale),

                                      // ── Session subtitle / Remaining task name ──
                                      if (customization.showTaskName)
                                        Text(
                                          timerState.isBreak
                                              ? (timerState.breakElapsed >= timerState.breakDuration
                                                  ? 'Break finished! Resume fokusing.'
                                                  : 'Taking a break')
                                              : focusedTask != null
                                                  ? focusedTask.title
                                                  : (isCountdown
                                                      ? '${totalSeconds ~/ 60} minute focus session'
                                                      : elapsed > 0
                                                          ? '${elapsed ~/ 60} minutes tracked'
                                                          : 'stopwatch mode'),
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 12 * scale,
                                            fontWeight: focusedTask != null
                                                ? FontWeight.w600
                                                : FontWeight.w500,
                                            color: focusedTask != null
                                                ? ringColor
                                                : tokens.textSecondary,
                                            letterSpacing: 0.2 * scale,
                                          ),
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildDigitRow(
    String value,
    ThemeTokens tokens,
    Color color,
    bool hasHours,
    String fontStyle,
    double scale,
    Duration duration, {
    bool isMs = false,
  }) {
    final baseFontSize = isMs
        ? (hasHours ? 40.0 : 60.0)
        : (hasHours ? 76.0 : 110.0);
    final fontSize = baseFontSize * scale;
    final style = _getTimerTextStyle(fontStyle, fontSize, color);

    final effectiveDuration = isMs
        ? Duration.zero
        : duration;

    return value.split('').map((char) {
      return motion.AnimatedDigit(
        value: char,
        style: style,
        duration: effectiveDuration,
      );
    }).toList();
  }

  Widget _buildMsPlaceholder(
    ThemeTokens tokens,
    double scale,
    String fontStyle,
    bool hasHours,
  ) {
    final baseFontSize = hasHours ? 40.0 : 60.0;
    final fontSize = baseFontSize * scale;
    final style = _getTimerTextStyle(fontStyle, fontSize, Colors.transparent);

    return Opacity(
      opacity: 0.0,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 2 * scale),
            child: Text(
              '.',
              style: _getTimerTextStyle(
                fontStyle,
                (hasHours ? 50.0 : 70.0) * scale,
                Colors.transparent,
              ),
            ),
          ),
          ...['0', '0'].map((char) {
            return motion.AnimatedDigit(
              value: char,
              style: style,
              duration: Duration.zero,
            );
          }).toList(),
        ],
      ),
    );
  }
}

/// Custom painter for the timer ring with gradient and subtle glow
class _TimerRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;
  final Color glowColor;
  final bool isActive;
  final bool showProgressRing;

  _TimerRingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.glowColor,
    required this.isActive,
    required this.showProgressRing,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!showProgressRing) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 6) / 2;
    const strokeWidth = 3.0;
    const startAngle = -3.14159 / 2;

    // Track ring
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0.01) return;

    // Glow behind the progress arc
    if (isActive && progress > 0.01) {
      final glowPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            glowColor.withValues(alpha: 0.12),
            glowColor.withValues(alpha: 0.04),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 6
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        6.28318 * progress,
        false,
        glowPaint,
      );
    }

    // Progress arc with subtle gradient
    final progressPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          color,
          Color.lerp(color, Colors.white, 0.25) ?? color,
          color,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      6.28318 * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _TimerRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.isActive != isActive ||
      oldDelegate.showProgressRing != showProgressRing;
}
