import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../shared/motion.dart' as motion;
import '../../shared/theme.dart';
import '../../shared/widgets/premium_button.dart';
import '../../services/sound_service.dart';

// ──────────────────────────────────────────────
// Breathing Pattern Data
// ──────────────────────────────────────────────

class _BreathingPhase {
  final String label;
  final int durationSeconds;
  final bool expands; // true = circle grows, false = circle shrinks

  const _BreathingPhase({
    required this.label,
    required this.durationSeconds,
    required this.expands,
  });
}

class _BreathingPattern {
  final String name;
  final String description;
  final List<_BreathingPhase> phases;
  final Color color;

  const _BreathingPattern({
    required this.name,
    required this.description,
    required this.phases,
    required this.color,
  });

  int get cycleDuration =>
      phases.fold(0, (sum, p) => sum + p.durationSeconds);
}

const List<_BreathingPattern> _breathingPatterns = [
  _BreathingPattern(
    name: 'Box Breathing',
    description: '4-4-4-4 — Used by Navy SEALs for calm and fokus',
    color: Color(0xFF6366F1), // Indigo
    phases: [
      _BreathingPhase(label: 'Breathe In', durationSeconds: 4, expands: true),
      _BreathingPhase(label: 'Hold', durationSeconds: 4, expands: false),
      _BreathingPhase(label: 'Breathe Out', durationSeconds: 4, expands: false),
      _BreathingPhase(label: 'Hold', durationSeconds: 4, expands: false),
    ],
  ),
  _BreathingPattern(
    name: '4-7-8 Relaxing',
    description: '4-7-8 — Dr. Weil\'s relaxing breath for deep calm',
    color: Color(0xFF10B981), // Emerald
    phases: [
      _BreathingPhase(label: 'Breathe In', durationSeconds: 4, expands: true),
      _BreathingPhase(label: 'Hold', durationSeconds: 7, expands: false),
      _BreathingPhase(label: 'Breathe Out', durationSeconds: 8, expands: false),
    ],
  ),
  _BreathingPattern(
    name: 'Simple Deep Breathing',
    description: '4-4-4 — A gentle rhythm for beginners',
    color: Color(0xFF14B8A6), // Teal
    phases: [
      _BreathingPhase(label: 'Breathe In', durationSeconds: 4, expands: true),
      _BreathingPhase(label: 'Hold', durationSeconds: 4, expands: false),
      _BreathingPhase(label: 'Breathe Out', durationSeconds: 4, expands: false),
    ],
  ),
];

// ──────────────────────────────────────────────
// Main Tool Page
// ──────────────────────────────────────────────

class BreathingTimerPage extends StatefulWidget {
  final VoidCallback onBack;

  const BreathingTimerPage({super.key, required this.onBack});

  @override
  State<BreathingTimerPage> createState() => _BreathingTimerPageState();
}

class _BreathingTimerPageState extends State<BreathingTimerPage>
    with TickerProviderStateMixin {
  int _selectedPatternIndex = 0;

  // Timer state
  Timer? _sessionTimer;
  Timer? _phaseTimer;
  bool _isRunning = false;
  bool _isPaused = false;

  // Current phase tracking
  int _currentPhaseIndex = 0;
  int _currentPhaseElapsed = 0; // seconds into current phase
  int _totalElapsed = 0; // total session seconds

  // Session duration config
  static const List<int> _sessionOptions = [1, 3, 5, 10, 15, 20, 30];
  int _sessionMinutes = 5;

  // Circle animation
  late AnimationController _circleController;
  late AnimationController _glowController;
  late AnimationController _ambientPulseController;



  // Circle scale: 0.5 = fully contracted, 1.0 = fully expanded
  double _circleScale = 0.5;

  // Floating ambient particles
  final List<_AmbientParticle> _particles = [];
  Timer? _particleTimer;
  bool _sessionComplete = false;

  _BreathingPattern get _pattern => _breathingPatterns[_selectedPatternIndex];
  Color get _patternColor => _pattern.color;

  @override
  void initState() {
    super.initState();

    _circleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    _ambientPulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();


    _initParticles();
  }

  void _initParticles() {
    final random = Random();
    for (int i = 0; i < 25; i++) {
      _particles.add(_AmbientParticle(
        x: random.nextDouble(),
        y: random.nextDouble(),
        vx: (random.nextDouble() - 0.5) * 0.002,
        vy: -(random.nextDouble() * 0.001 + 0.0005),
        size: random.nextDouble() * 3 + 1.5,
        alpha: random.nextDouble() * 0.3 + 0.05,
        color: _patternColor,
      ));
    }
  }

  void _spawnParticle() {
    final random = Random();
    _particles.add(_AmbientParticle(
      x: 0.2 + random.nextDouble() * 0.6,
      y: 1.05,
      vx: (random.nextDouble() - 0.5) * 0.002,
      vy: -(random.nextDouble() * 0.002 + 0.001),
      size: random.nextDouble() * 2.5 + 1,
      alpha: random.nextDouble() * 0.25 + 0.05,
      color: _patternColor,
    ));
  }

  void _updateParticles() {
    for (final p in _particles) {
      p.x += p.vx;
      p.y += p.vy;
      p.alpha -= 0.002;
    }
    _particles.removeWhere((p) => p.alpha <= 0 || p.y < -0.05);
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _phaseTimer?.cancel();
    _particleTimer?.cancel();
    _circleController.dispose();
    _glowController.dispose();
    _ambientPulseController.dispose();
    super.dispose();
  }

  void _startSession() {
    if (_isRunning) return;

    setState(() {
      _isRunning = true;
      _isPaused = false;
      _currentPhaseIndex = 0;
      _currentPhaseElapsed = 0;
      _totalElapsed = 0;
      _sessionComplete = false;
      _particles.clear();
      _initParticles();
    });

    _startPhaseTimer();
    _startSessionTimer();
    _startParticleSpawner();
    SoundService.playFlip();
  }

  void _pauseSession() {
    if (!_isRunning || _isPaused) return;
    setState(() => _isPaused = true);
    _phaseTimer?.cancel();
    _sessionTimer?.cancel();
    _particleTimer?.cancel();
    _circleController.stop();
  }

  void _resumeSession() {
    if (!_isRunning || !_isPaused) return;
    setState(() => _isPaused = false);
    _startPhaseTimer();
    _startSessionTimer();
    _startParticleSpawner();

    // Resume circle animation
    final phase = _pattern.phases[_currentPhaseIndex];
    final remaining = phase.durationSeconds - _currentPhaseElapsed;
    if (remaining > 0) {
      final progress = _currentPhaseElapsed / phase.durationSeconds;
      final adjustedProgress = (1.0 - progress).clamp(0.01, 1.0);

      _circleController.duration = Duration(milliseconds: remaining * 1000);
      _circleController.value = adjustedProgress;
      _circleController.forward(from: adjustedProgress);
    }
  }

  void _stopSession() {
    _phaseTimer?.cancel();
    _sessionTimer?.cancel();
    _particleTimer?.cancel();
    _circleController.stop();
    setState(() {
      _isRunning = false;
      _isPaused = false;
      _sessionComplete = false;
      _circleScale = 0.5;
    });
    SoundService.playNotification();
  }

  void _startPhaseTimer() {
    _phaseTimer?.cancel();
    final phase = _pattern.phases[_currentPhaseIndex];
    _currentPhaseElapsed = 0;

    // Start circle animation for this phase
    _startCircleAnimation(phase);

    _phaseTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _currentPhaseElapsed++;
      });

      if (_currentPhaseElapsed >= phase.durationSeconds) {
        // Move to next phase
        final nextIndex = (_currentPhaseIndex + 1) % _pattern.phases.length;
        if (nextIndex == 0) {
          // Completed a full cycle
          HapticFeedback.mediumImpact();
        }
        setState(() {
          _currentPhaseIndex = nextIndex;
          _currentPhaseElapsed = 0;
        });
        SoundService.playFlip();

        // Start new phase animation
        _startCircleAnimation(_pattern.phases[nextIndex]);
      }
    });
  }

  void _startCircleAnimation(_BreathingPhase phase) {
    _circleController.stop();
    _circleController.removeListener(_onCircleAnimationFrame);

    // Hold phases keep the circle at its current scale — no animation needed
    if (phase.label == 'Hold') {
      return;
    }

    _circleController.duration = Duration(seconds: phase.durationSeconds);
    _circleController.value = 0.0;

    _circleController.addListener(_onCircleAnimationFrame);

    _circleController.forward();
  }

  void _onCircleAnimationFrame() {
    if (!mounted) return;
    final phase = _pattern.phases[_currentPhaseIndex];
    final target = phase.expands ? 1.0 : 0.5;
    final start = phase.expands ? 0.5 : 1.0;
    setState(() {
      _circleScale = start + (_circleController.value * (target - start));
    });
  }

  void _startSessionTimer() {
    _sessionTimer?.cancel();
    final maxSeconds = _sessionMinutes * 60;
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _totalElapsed++;
      });
      if (_totalElapsed >= maxSeconds) {
        _completeSession();
      }
    });
  }

  void _startParticleSpawner() {
    _particleTimer?.cancel();
    _particleTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (!mounted) return;
      _spawnParticle();
      _updateParticles();
    });
  }

  void _completeSession() {
    _phaseTimer?.cancel();
    _sessionTimer?.cancel();
    _particleTimer?.cancel();
    _circleController.stop();
    setState(() {
      _isRunning = false;
      _isPaused = false;
      _sessionComplete = true;
      _circleScale = 0.5;
    });
    HapticFeedback.heavyImpact();
    SoundService.playNotification();
  }

  String _formatDuration(int totalSeconds) {
    final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _formatPhaseProgress(int elapsed, int total) {
    final remaining = total - elapsed;
    final s = remaining.toString().padLeft(2, '0');
    return ':$s';
  }

  String _getPhaseInstruction() {
    if (!_isRunning) return 'Press Start to begin';
    if (_isPaused) return 'Paused';
    return _pattern.phases[_currentPhaseIndex].label;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = FocusOsTheme.of(context);

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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Breathing Timer',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: tokens.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Guided breathing exercises for calm and fokus',
                      style: TextStyle(fontSize: 13, color: tokens.textMuted),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Main Content ──
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 700) {
                    return _buildNarrowLayout(tokens);
                  }
                  return _buildWideLayout(tokens);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Wide Layout ──
  Widget _buildWideLayout(ThemeTokens tokens) {
    return Row(
      children: [
        // Left: Breathing Circle + Controls
        Expanded(
          flex: 5,
          child: Column(
            children: [
              // Breathing Circle Area
              Expanded(
                child: Center(
                  child: _buildBreathingCircle(tokens),
                ),
              ),
              const SizedBox(height: 24),
              // Controls
              _buildControls(tokens),
              const SizedBox(height: 16),
              // Session Info
              _buildSessionInfo(tokens),
            ],
          ),
        ),
        const SizedBox(width: 32),
        // Right: Pattern Selection + Settings
        Expanded(
          flex: 3,
          child: _buildSettingsPanel(tokens),
        ),
      ],
    );
  }

  // ── Narrow Layout ──
  Widget _buildNarrowLayout(ThemeTokens tokens) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          SizedBox(
            height: 360,
            child: Center(
              child: _buildBreathingCircle(tokens),
            ),
          ),
          const SizedBox(height: 16),
          _buildControls(tokens),
          const SizedBox(height: 16),
          _buildSessionInfo(tokens),
          const SizedBox(height: 24),
          _buildSettingsPanel(tokens),
        ],
      ),
    );
  }

  // ── Breathing Circle ──
  Widget _buildBreathingCircle(ThemeTokens tokens) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxSize = min(constraints.maxWidth, constraints.maxHeight);
        final circleSize = min(maxSize * 0.65, 280.0);
        final expandedSize = circleSize * 1.0;
        final contractedSize = circleSize * 0.5;

        return SizedBox(
          width: circleSize + 60,
          height: circleSize + 60,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Ambient particles
              Positioned.fill(
                child: CustomPaint(
                  painter: _AmbientParticlesPainter(
                    _particles,
                    _ambientPulseController.value,
                  ),
                ),
              ),

              // Outer glow ring
              AnimatedBuilder(
                animation: _glowController,
                builder: (context, _) {
                  final glowOpacity = 0.08 + _glowController.value * 0.12;
                  return Container(
                    width: expandedSize + 50,
                    height: expandedSize + 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _patternColor
                              .withValues(alpha: glowOpacity),
                          blurRadius: 40 + _glowController.value * 20,
                          spreadRadius: 10 + _glowController.value * 8,
                        ),
                      ],
                    ),
                  );
                },
              ),

              // The breathing circle
              AnimatedBuilder(
                animation: Listenable.merge(
                    [_circleController, _glowController]),
                builder: (context, _) {
                  final currentSize = contractedSize +
                      (_circleScale * (expandedSize - contractedSize));
                  return Container(
                    width: currentSize,
                    height: currentSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          _patternColor
                              .withValues(alpha: 0.6 + _circleScale * 0.3),
                          _patternColor.withValues(
                              alpha: 0.2 + _circleScale * 0.15),
                          _patternColor
                              .withValues(alpha: _circleScale * 0.05),
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _patternColor.withValues(
                              alpha: 0.15 + _circleScale * 0.2),
                          blurRadius: 20 + _circleScale * 15,
                          spreadRadius: 2 + _circleScale * 4,
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Inner glow
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0.15),
                                Colors.transparent,
                              ],
                              stops: [
                                0.0,
                                0.6 - _circleScale * 0.3
                              ],
                            ),
                          ),
                        ),

                        // Phase instruction
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Phase label
                            AnimatedSwitcher(
                              duration:
                                  const Duration(milliseconds: 350),
                              transitionBuilder: (child, animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: ScaleTransition(
                                    scale: animation,
                                    child: child,
                                  ),
                                );
                              },
                              child: Text(
                                _getPhaseInstruction(),
                                key: ValueKey<String>(
                                    '${_currentPhaseIndex}_${_isRunning}_${_isPaused}'),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Countdown
                            if (_isRunning) ...[
                              AnimatedSwitcher(
                                duration:
                                    const Duration(milliseconds: 200),
                                child: Text(
                                  _isPaused
                                      ? '❚❚'
                                      : _formatPhaseProgress(
                                          _currentPhaseElapsed,
                                          _pattern
                                              .phases[_currentPhaseIndex]
                                              .durationSeconds),
                                  key: ValueKey<int>(
                                      _currentPhaseElapsed),
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w200,
                                    color: Colors.white
                                        .withValues(alpha: 0.8),
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                            ],

                            // State icon
                            if (_sessionComplete)
                              Icon(Icons.check_circle_rounded,
                                  size: 32,
                                  color: Colors.white
                                      .withValues(alpha: 0.9)),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),

              // Inhale/Exhale text flourish
              if (_isRunning && !_isPaused)
                Positioned(
                  bottom: 0,
                  child: AnimatedBuilder(
                    animation: _circleController,
                    builder: (context, _) {
                      final phase =
                          _pattern.phases[_currentPhaseIndex];
                      return Opacity(
                        opacity: 0.4,
                        child: Text(
                          phase.expands
                              ? '⬆  Breathe In'
                              : _currentPhaseIndex > 0 &&
                                      _pattern
                                              .phases[
                                                  _currentPhaseIndex]
                                              .label ==
                                          'Hold'
                                  ? '●  Hold'
                                  : '⬇  Breathe Out',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white
                                .withValues(alpha: 0.7),
                            letterSpacing: 1.0,
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // ── Control Buttons ──
  Widget _buildControls(ThemeTokens tokens) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Stop button (only visible when running)
        if (_isRunning)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _buildControlButton(
              icon: Icons.stop_rounded,
              tooltip: 'Stop',
              color: const Color(0xFFEF4444),
              onTap: _stopSession,
              tokens: tokens,
            ),
          ),

        // Start / Pause / Resume
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: !_isRunning
                ? [
                    BoxShadow(
                      color:
                          _patternColor.withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: PremiumButton(
            icon: _isRunning && !_isPaused
                ? Icons.pause_rounded
                : _isPaused
                    ? Icons.play_arrow_rounded
                    : Icons.play_arrow_rounded,
            label: _isRunning && !_isPaused
                ? 'Pause'
                : _isPaused
                    ? 'Resume'
                    : 'Start Session',
            variant: PremiumButtonVariant.gradient,
            onTap: () {
              if (!_isRunning) {
                _startSession();
              } else if (_isPaused) {
                _resumeSession();
              } else {
                _pauseSession();
              }
            },
            padding: const EdgeInsets.symmetric(
                horizontal: 28, vertical: 14),
          ),
        ),

        // Skip phase button (only when running)
        if (_isRunning)
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: _buildControlButton(
              icon: Icons.skip_next_rounded,
              tooltip: 'Skip Phase',
              color: tokens.textSecondary,
              onTap: () {
                _phaseTimer?.cancel();
                _circleController.stop();
                final nextIndex =
                    (_currentPhaseIndex + 1) %
                        _pattern.phases.length;
                setState(() {
                  _currentPhaseIndex = nextIndex;
                  _currentPhaseElapsed = 0;
                });
                _startCircleAnimation(
                    _pattern.phases[nextIndex]);
                _startPhaseTimer();
                SoundService.playFlip();
              },
              tokens: tokens,
            ),
          ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback onTap,
    required ThemeTokens tokens,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: tokens.borderSubtle),
            ),
            child: Icon(icon, size: 22, color: color),
          ),
        ),
      ),
    );
  }

  // ── Session Info (below controls) ──
  Widget _buildSessionInfo(ThemeTokens tokens) {
    final maxSeconds = _sessionMinutes * 60;
    final progress = maxSeconds > 0
        ? (_totalElapsed / maxSeconds).clamp(0.0, 1.0)
        : 0.0;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Elapsed
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.timer_outlined,
                    size: 14, color: tokens.textMuted),
                const SizedBox(width: 4),
                Text(
                  _formatDuration(_totalElapsed),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            Text(
              '/',
              style: TextStyle(color: tokens.textMuted),
            ),
            const SizedBox(width: 8),
            Text(
              _formatDuration(maxSeconds),
              style: TextStyle(
                fontSize: 14,
                color: tokens.textMuted,
                fontFamily: 'monospace',
              ),
            ),
            if (_isRunning) ...[
              const SizedBox(width: 8),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isPaused
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF10B981),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        // Progress bar
        SizedBox(
          width: 200,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: tokens.borderSubtle,
              valueColor: AlwaysStoppedAnimation(
                _sessionComplete
                    ? const Color(0xFF10B981)
                    : _patternColor,
              ),
              minHeight: 4,
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (_sessionComplete)
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: const Color(0xFF10B981)
                      .withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_rounded,
                    size: 12, color: Color(0xFF10B981)),
                const SizedBox(width: 4),
                Text(
                  'Session Complete!',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF10B981),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ── Settings Panel ──
  Widget _buildSettingsPanel(ThemeTokens tokens) {
    return Container(
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
              Icon(Icons.tune_rounded,
                  size: 16, color: tokens.textSecondary),
              const SizedBox(width: 8),
              Text(
                'Settings',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: tokens.textPrimary,
                ),
              ),
            ],
          ),
          const Divider(height: 24),

          // Breathing Pattern Selection
          Text(
            'BREATHING PATTERN',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: tokens.textMuted,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          ...List.generate(_breathingPatterns.length, (index) {
            final pattern = _breathingPatterns[index];
            final isSelected = _selectedPatternIndex == index;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: _isRunning
                    ? null
                    : () {
                        setState(() {
                          _selectedPatternIndex = index;
                          _particles.clear();
                          _initParticles();
                        });
                        HapticFeedback.selectionClick();
                      },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? pattern.color.withValues(alpha: 0.08)
                        : tokens.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? pattern.color
                              .withValues(alpha: 0.3)
                          : tokens.borderSubtle,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Color indicator
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: pattern.color,
                          shape: BoxShape.circle,
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: pattern.color
                                        .withValues(alpha: 0.4),
                                    blurRadius: 6,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              pattern.name,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: tokens.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              pattern.description,
                              style: TextStyle(
                                fontSize: 10,
                                color: tokens.textMuted,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Icon(
                          Icons.check_circle_rounded,
                          size: 16,
                          color: pattern.color,
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 20),

          // Session Duration
          Text(
            'SESSION DURATION',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: tokens.textMuted,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: _sessionOptions.map((minutes) {
                final isSelected = _sessionMinutes == minutes;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: _isRunning
                        ? null
                        : () {
                            setState(() {
                              _sessionMinutes = minutes;
                            });
                            HapticFeedback.selectionClick();
                          },
                    child: AnimatedContainer(
                      duration:
                          const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? _patternColor
                                .withValues(alpha: 0.12)
                            : tokens.background,
                        borderRadius:
                            BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? _patternColor
                                  .withValues(alpha: 0.25)
                              : tokens.borderSubtle,
                        ),
                      ),
                      child: Text(
                        '$minutes min',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isSelected
                              ? _patternColor
                              : tokens.textSecondary,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),

          // Cycle info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: tokens.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 14, color: tokens.textMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Each cycle: ${_pattern.cycleDuration}s — '
                    '${_sessionMinutes * 60 ~/ _pattern.cycleDuration} cycles per session',
                    style: TextStyle(
                        fontSize: 10, color: tokens.textMuted),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Ambient Particles
// ──────────────────────────────────────────────

class _AmbientParticle {
  double x;
  double y;
  double vx;
  double vy;
  double size;
  double alpha;
  final Color color;

  _AmbientParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.alpha,
    required this.color,
  });
}

class _AmbientParticlesPainter extends CustomPainter {
  final List<_AmbientParticle> particles;
  final double pulsePhase;

  _AmbientParticlesPainter(this.particles, this.pulsePhase);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      if (p.alpha <= 0.01) continue;
      final pos = Offset(p.x * size.width, p.y * size.height);

      // Glow
      final glowPaint = Paint()
        ..color = p.color.withValues(alpha: p.alpha * 0.3)
        ..maskFilter =
            MaskFilter.blur(BlurStyle.normal, p.size * 2);
      canvas.drawCircle(pos, p.size * 1.5, glowPaint);

      // Core
      final paint = Paint()
        ..color = p.color.withValues(alpha: p.alpha);
      canvas.drawCircle(pos, p.size * 0.6, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AmbientParticlesPainter oldDelegate) =>
      true;
}
