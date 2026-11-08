import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../shared/motion.dart' as motion;
import '../../shared/theme.dart';

import '../../shared/widgets/premium_button.dart';

class GodsWishPage extends StatefulWidget {
  final VoidCallback onBack;

  const GodsWishPage({super.key, required this.onBack});

  @override
  State<GodsWishPage> createState() => _GodsWishPageState();
}

class _GodsWishPageState extends State<GodsWishPage> with TickerProviderStateMixin {
  final TextEditingController _topicCtrl = TextEditingController();
  final TextEditingController _optionCtrl = TextEditingController();
  final List<String> _options = [];
  
  bool _isSpinning = false;
  String? _selectedOption;
  
  late AnimationController _wheelController;
  late Animation<double> _wheelAnimation;
  
  // Ambient glow pulsing
  late AnimationController _glowController;
  
  // Floating ambient particles
  late AnimationController _ambientController;
  final List<_AmbientParticle> _ambientParticles = [];
  
  // Idle wheel rotation
  late AnimationController _idleController;
  
  // Title shimmer
  late AnimationController _shimmerController;
  
  double _currentRotation = 0.0;
  double _startRotation = 0.0;
  double _endRotation = 0.0;
  int _lastTickSliceIndex = -1;

  static const List<Color> _defaultColors = [
    Color(0xFF6366F1), // Indigo
    Color(0xFF10B981), // Emerald
    Color(0xFFF59E0B), // Amber
    Color(0xFF3B82F6), // Blue
    Color(0xFFEC4899), // Pink
    Color(0xFF14B8A6), // Teal
    Color(0xFF8B5CF6), // Purple
    Color(0xFFEF4444), // Red
  ];



  @override
  void initState() {
    super.initState();
    
    // Default initial options to give immediate visual value
    _options.addAll(['Red', 'Blue', 'Green']);
    _topicCtrl.text = "What should I wear today?";

    _wheelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4500),
    );

    _wheelAnimation = Tween<double>(begin: 0.0, end: 0.0).animate(_wheelController);

    _wheelController.addListener(() {
      setState(() {
        _currentRotation = _wheelAnimation.value;
        
        // Dynamic tick calculations for sound and pointer wiggle
        if (_options.isNotEmpty) {
          final double sliceAngle = 2 * pi / _options.length;
          // Calculate current pointer angle on the wheel (top is 3*pi/2 relative to rotation)
          final double relAngle = (3 * pi / 2 - _currentRotation) % (2 * pi);
          final double normalizedAngle = relAngle < 0 ? relAngle + 2 * pi : relAngle;
          final int currentSlice = (normalizedAngle / sliceAngle).floor() % _options.length;
          
          if (currentSlice != _lastTickSliceIndex) {
            // Trigger haptics and native click sound
            HapticFeedback.lightImpact();
            SystemSound.play(SystemSoundType.click);
            _lastTickSliceIndex = currentSlice;
          }
        }
      });
    });

    _wheelController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _isSpinning = false;
        });
        // Restart idle after spin completes
        _idleController.repeat();
        _showResultOverlay();
      }
    });

    // Ambient glow pulsing controller
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);

    // Floating ambient particles
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(() {
      setState(() {
        for (final p in _ambientParticles) {
          p.update();
        }
        _ambientParticles.removeWhere((p) => p.alpha <= 0);
        // Continuously spawn new particles
        if (_ambientParticles.length < 20) {
          _spawnAmbientParticle();
        }
      });
    });
    _ambientController.repeat();
    _initAmbientParticles();

    // Idle wheel rotation (very slow continuous spin)
    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();

    // Title shimmer animation
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();
  }

  void _initAmbientParticles() {
    final random = Random();
    for (int i = 0; i < 15; i++) {
      _ambientParticles.add(_AmbientParticle(
        x: random.nextDouble() * 400 - 200,
        y: random.nextDouble() * 400 - 200,
        vx: (random.nextDouble() - 0.5) * 0.3,
        vy: (random.nextDouble() - 0.5) * 0.3,
        size: random.nextDouble() * 3 + 1,
        alpha: random.nextDouble() * 0.4 + 0.1,
        maxAlpha: random.nextDouble() * 0.4 + 0.1,
        color: _defaultColors[random.nextInt(_defaultColors.length)],
        pulseSpeed: random.nextDouble() * 0.02 + 0.005,
      ));
    }
  }

  void _spawnAmbientParticle() {
    final random = Random();
    _ambientParticles.add(_AmbientParticle(
      x: random.nextDouble() * 400 - 200,
      y: random.nextDouble() * 400 - 200,
      vx: (random.nextDouble() - 0.5) * 0.3,
      vy: (random.nextDouble() - 0.5) * 0.3,
      size: random.nextDouble() * 3 + 1,
      alpha: 0.0,
      maxAlpha: random.nextDouble() * 0.4 + 0.1,
      color: _defaultColors[random.nextInt(_defaultColors.length)],
      pulseSpeed: random.nextDouble() * 0.02 + 0.005,
    ));
  }

  @override
  void dispose() {
    _topicCtrl.dispose();
    _optionCtrl.dispose();
    _wheelController.dispose();
    _glowController.dispose();
    _ambientController.dispose();
    _idleController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  void _addOption() {
    final text = _optionCtrl.text.trim();
    if (text.isEmpty) return;
    if (_options.contains(text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Option already exists!",
            style: TextStyle(color: FocusOsTheme.of(context).textPrimary, fontWeight: FontWeight.w600),
          ),
          backgroundColor: const Color(0xFFEF4444),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    setState(() {
      _options.add(text);
      _optionCtrl.clear();
    });
  }

  void _removeOption(int index) {
    if (_isSpinning) return;
    setState(() {
      _options.removeAt(index);
    });
  }

  void _clearAll() {
    if (_isSpinning) return;
    setState(() {
      _options.clear();
    });
  }

  void _setSampleOptions(List<String> samples, String topic) {
    if (_isSpinning) return;
    setState(() {
      _topicCtrl.text = topic;
      _options.clear();
      _options.addAll(samples);
    });
  }

  void _spinWheel() {
    if (_isSpinning || _options.length < 2) return;

    // Stop idle rotation
    _idleController.stop();

    final random = Random();
    final targetIndex = random.nextInt(_options.length);

    final double sliceAngle = 2 * pi / _options.length;
    // Angle of the center of target slice (clockwise from 3 o'clock)
    final double centerAngle = (targetIndex + 0.5) * sliceAngle;

    // Angle to rotate wheel by, to place centerAngle under pointer (at 12 o'clock, 3*pi/2 screen angle)
    double targetModulo = (3 * pi / 2) - centerAngle;
    targetModulo = targetModulo % (2 * pi);
    if (targetModulo < 0) targetModulo += 2 * pi;

    final double currentNormalized = _currentRotation % (2 * pi);
    _startRotation = _currentRotation;

    const int spins = 7; // Number of full spins
    double diff = targetModulo - currentNormalized;
    if (diff <= 0) {
      diff += 2 * pi;
    }

    _endRotation = _startRotation + (2 * pi * spins) + diff;

    _wheelAnimation = Tween<double>(
      begin: _startRotation,
      end: _endRotation,
    ).animate(CurvedAnimation(
      parent: _wheelController,
      curve: Curves.easeOutQuart,
    ));

    setState(() {
      _isSpinning = true;
      _selectedOption = _options[targetIndex];
    });

    _wheelController.reset();
    _wheelController.forward();
  }

  double _getPointerDeflection() {
    if (_options.isEmpty || !_isSpinning) return 0.0;

    final double sliceAngle = 2 * pi / _options.length;
    final double relAngle = (3 * pi / 2 - _currentRotation) % (2 * pi);
    final double normalizedAngle = relAngle < 0 ? relAngle + 2 * pi : relAngle;
    final double sliceIndexFrac = normalizedAngle / sliceAngle;
    final double frac = sliceIndexFrac - sliceIndexFrac.floor(); // [0.0, 1.0)

    // Deflect pointer slightly as boundary approach, snap back immediately
    if (frac < 0.15) {
      return -0.22 * (0.15 - frac) / 0.15;
    } else if (frac > 0.85) {
      return 0.08 * (1.0 - frac) / 0.15;
    }
    return 0.0;
  }

  void _showResultOverlay() {
    if (_selectedOption == null) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return _CelebrationOverlay(
          topic: _topicCtrl.text.trim(),
          option: _selectedOption!,
          onClose: () {
            Navigator.of(context).pop();
          },
          onRespin: () {
            Navigator.of(context).pop();
            _spinWheel();
          },
        );
      },
    );
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
            // Futuristic Header with shimmer
            _buildFuturisticHeader(tokens),
            const SizedBox(height: 28),

            // Layout responsive row/column
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth > 900) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 4,
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: _buildInputsSection(tokens),
                          ),
                        ),
                        const SizedBox(width: 32),
                        Expanded(
                          flex: 5,
                          child: _buildSpinnerSection(tokens),
                        ),
                      ],
                    );
                  } else {
                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        children: [
                          _buildSpinnerSection(tokens),
                          const SizedBox(height: 28),
                          _buildInputsSection(tokens),
                        ],
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFuturisticHeader(ThemeTokens tokens) {
    return Row(
      children: [
        // Animated back button with glow
        AnimatedBuilder(
          animation: _glowController,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: tokens.accent.withValues(alpha: 0.1 + _glowController.value * 0.1),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded,
                    size: 18, color: tokens.textPrimary),
                onPressed: widget.onBack,
                splashRadius: 20,
                tooltip: 'Back to Tools',
              ),
            );
          },
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Shimmer gradient title
            AnimatedBuilder(
              animation: _shimmerController,
              builder: (context, child) {
                return ShaderMask(
                  shaderCallback: (bounds) {
                    return LinearGradient(
                      colors: [
                        tokens.textPrimary,
                        tokens.accent,
                        const Color(0xFFFFD700),
                        tokens.accent,
                        tokens.textPrimary,
                      ],
                      stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
                      begin: Alignment(-1.0 + 3.0 * _shimmerController.value, 0),
                      end: Alignment(1.0 + 3.0 * _shimmerController.value, 0),
                    ).createShader(bounds);
                  },
                  child: Text(
                    "God's Wish",
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 4),
            Text(
              "Stuck in a dilemma? Let divine forces decide your fate.",
              style: TextStyle(fontSize: 13, color: tokens.textMuted),
            ),
          ],
        ),
        const Spacer(),
        // Animated cosmic icon
        AnimatedBuilder(
          animation: _glowController,
          builder: (context, child) {
            return Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    tokens.accent.withValues(alpha: 0.15 + _glowController.value * 0.1),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Transform.rotate(
                angle: _glowController.value * 0.3,
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: const Color(0xFFFFD700).withValues(alpha: 0.6 + _glowController.value * 0.4),
                  size: 22,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildInputsSection(ThemeTokens tokens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Topic Input Card — Glassmorphic
        _GlassmorphicCard(
          glowController: _glowController,
          tokens: tokens,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: tokens.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(Icons.topic_rounded, size: 14, color: tokens.accent),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Decision Topic',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: tokens.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  decoration: BoxDecoration(
                    color: tokens.background.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: tokens.accent.withValues(alpha: 0.15)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  child: TextField(
                    controller: _topicCtrl,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: tokens.textPrimary,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: "e.g., What should I wear today?",
                      hintStyle: TextStyle(color: tokens.textMuted, fontSize: 13),
                    ),
                    enabled: !_isSpinning,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Options Input Card — Glassmorphic
        _GlassmorphicCard(
          glowController: _glowController,
          tokens: tokens,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.format_list_bulleted_rounded, size: 14, color: Color(0xFF8B5CF6)),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Options List',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: tokens.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    if (_options.isNotEmpty)
                      _buildNeonTextButton(
                        'Clear All',
                        const Color(0xFFEF4444),
                        _isSpinning ? null : _clearAll,
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                
                // Text field to add option
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: tokens.background.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: tokens.accent.withValues(alpha: 0.15)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                        child: TextField(
                          controller: _optionCtrl,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: tokens.textPrimary,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: "Add option...",
                            hintStyle: TextStyle(color: tokens.textMuted, fontSize: 12),
                          ),
                          enabled: !_isSpinning,
                          onSubmitted: (_) => _addOption(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Animated add button
                    AnimatedBuilder(
                      animation: _glowController,
                      builder: (context, child) {
                        return Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: tokens.accent.withValues(alpha: 0.1 + _glowController.value * 0.08),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: PremiumIconButton(
                            icon: Icons.add_rounded,
                            iconSize: 20,
                            enabled: !_isSpinning,
                            onTap: _addOption,
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Empty or current list
                if (_options.isEmpty) ...[
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Column(
                        children: [
                          AnimatedBuilder(
                            animation: _glowController,
                            builder: (context, child) {
                              return Icon(
                                Icons.format_list_bulleted_rounded,
                                size: 32,
                                color: tokens.textMuted.withValues(alpha: 0.3 + _glowController.value * 0.2),
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "No options added yet.",
                            style: TextStyle(color: tokens.textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Divider(color: tokens.borderSubtle),
                  const SizedBox(height: 12),
                  Text(
                    "QUICK PRESETS",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: tokens.textMuted,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _sampleChip("Yes / No / Maybe", ['Yes', 'No', 'Maybe'], "Should I do this?"),
                      _sampleChip("What to Eat", ['Pizza', 'Sushi', 'Burger', 'Tacos', 'Salad'], "What should I eat?"),
                      _sampleChip("R-P-S", ['Rock ✊', 'Paper ✋', 'Scissors ✌️'], "Rock Paper Scissors!"),
                      _sampleChip("1 to 6 Dice", ['1 ⚀', '2 ⚁', '3 ⚂', '4 ⚃', '5 ⚄', '6 ⚅'], "Roll a dice:"),
                    ],
                  ),
                ] else ...[
                  // Animated scrollable list of options
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 280),
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _options.length,
                      itemBuilder: (context, index) {
                        final optionColor = _defaultColors[index % _defaultColors.length];
                        return TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: Duration(milliseconds: 300 + index * 60),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) {
                            return Opacity(
                              opacity: value,
                              child: Transform.translate(
                                offset: Offset(20 * (1 - value), 0),
                                child: child,
                              ),
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: optionColor.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: optionColor.withValues(alpha: 0.2)),
                            ),
                            child: Row(
                              children: [
                                // Glowing color indicator
                                Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: optionColor,
                                    borderRadius: BorderRadius.circular(4),
                                    boxShadow: [
                                      BoxShadow(
                                        color: optionColor.withValues(alpha: 0.5),
                                        blurRadius: 6,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _options[index],
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: tokens.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 16),
                                  color: tokens.textMuted,
                                  hoverColor: Colors.redAccent.withValues(alpha: 0.1),
                                  onPressed: _isSpinning ? null : () => _removeOption(index),
                                  splashRadius: 16,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNeonTextButton(String label, Color color, VoidCallback? onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: MouseRegion(
        cursor: onPressed != null ? SystemMouseCursors.click : MouseCursor.defer,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
            shadows: [
              Shadow(color: color.withValues(alpha: 0.5), blurRadius: 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sampleChip(String label, List<String> samples, String topic) {
    final tokens = FocusOsTheme.of(context);
    return ActionChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: tokens.textSecondary,
        ),
      ),
      backgroundColor: tokens.accent.withValues(alpha: 0.06),
      side: BorderSide(color: tokens.accent.withValues(alpha: 0.15)),
      onPressed: _isSpinning ? null : () => _setSampleOptions(samples, topic),
    );
  }

  Widget _buildSpinnerSection(ThemeTokens tokens) {
    return _GlassmorphicCard(
      glowController: _glowController,
      tokens: tokens,
      accentGlow: true,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated status text
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              switchInCurve: Curves.easeOutCubic,
              child: _isSpinning
                  ? _buildAnimatedStatus("Consulting the Heavens...", const Color(0xFFFFD700), tokens)
                  : (_options.length < 2
                      ? Text(
                          "Configure Options",
                          key: const ValueKey('configure'),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: tokens.textMuted,
                          ),
                        )
                      : _buildAnimatedStatus("Let God Decide", tokens.accent, tokens)),
            ),
            const SizedBox(height: 24),

            // Stack for Spinner + Ambient Particles + Pointer
            Center(
              child: SizedBox(
                width: 340,
                height: 350,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Ambient floating particles behind the wheel
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _AmbientParticlePainter(_ambientParticles),
                      ),
                    ),

                    // Outer glow ring
                    Positioned(
                      top: 14,
                      child: AnimatedBuilder(
                        animation: _glowController,
                        builder: (context, child) {
                          return Container(
                            width: 310,
                            height: 310,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: (_isSpinning ? const Color(0xFFFFD700) : tokens.accent)
                                      .withValues(alpha: 0.08 + _glowController.value * 0.12),
                                  blurRadius: 30 + _glowController.value * 15,
                                  spreadRadius: 5 + _glowController.value * 5,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    // Spinning Wheel with idle rotation
                    Positioned(
                      top: 24,
                      child: SizedBox(
                        width: 290,
                        height: 290,
                        child: AnimatedBuilder(
                          animation: Listenable.merge([_wheelController, _idleController]),
                          builder: (context, child) {
                            // Idle rotation only when not spinning
                            final idleAngle = _isSpinning ? 0.0 : _idleController.value * 2 * pi;
                            return Transform.rotate(
                              angle: _currentRotation + idleAngle,
                              child: CustomPaint(
                                size: const Size(290, 290),
                                painter: _options.length >= 2
                                    ? _FuturisticWheelPainter(
                                        options: _options,
                                        tokens: tokens,
                                        glowIntensity: _glowController.value,
                                      )
                                    : _EmptyWheelPainter(tokens: tokens),
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    // Neon pulsing pointer at the top
                    Positioned(
                      top: 0,
                      child: AnimatedBuilder(
                        animation: _glowController,
                        builder: (context, child) {
                          return _NeonPointerIndicator(
                            deflection: _getPointerDeflection(),
                            tokens: tokens,
                            glowIntensity: _glowController.value,
                            isSpinning: _isSpinning,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Futuristic Spin Button
            AnimatedBuilder(
              animation: _glowController,
              builder: (context, child) {
                final canSpin = !_isSpinning && _options.length >= 2;
                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: canSpin
                        ? [
                            BoxShadow(
                              color: tokens.accent.withValues(alpha: 0.15 + _glowController.value * 0.15),
                              blurRadius: 16 + _glowController.value * 8,
                              spreadRadius: 2,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: PremiumButton(
                      label: _isSpinning ? "✦ Divine force is spinning..." : "✦ Let's see what God wants you to do",
                      icon: _isSpinning ? null : Icons.auto_awesome_rounded,
                      variant: PremiumButtonVariant.gradient,
                      enabled: canSpin,
                      onTap: _spinWheel,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              },
            ),
            if (_options.length < 2) ...[
              const SizedBox(height: 10),
              Text(
                "Add at least 2 options to spin.",
                style: TextStyle(color: tokens.textMuted, fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedStatus(String text, Color color, ThemeTokens tokens) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      key: ValueKey(text),
      children: [
        AnimatedBuilder(
          animation: _glowController,
          builder: (context, child) {
            return Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3 + _glowController.value * 0.5),
                    blurRadius: 6 + _glowController.value * 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(width: 10),
        Text(
          text,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: color,
            shadows: [
              Shadow(color: color.withValues(alpha: 0.4), blurRadius: 8),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════
// GLASSMORPHIC CARD
// ═══════════════════════════════════════════════════

class _GlassmorphicCard extends StatelessWidget {
  final Widget child;
  final AnimationController glowController;
  final ThemeTokens tokens;
  final bool accentGlow;

  const _GlassmorphicCard({
    required this.child,
    required this.glowController,
    required this.tokens,
    this.accentGlow = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: glowController,
      builder: (context, _) {
        return Container(
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: accentGlow
                  ? tokens.accent.withValues(alpha: 0.1 + glowController.value * 0.08)
                  : tokens.borderSubtle,
              width: accentGlow ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
              if (accentGlow)
                BoxShadow(
                  color: tokens.accent.withValues(alpha: 0.04 + glowController.value * 0.04),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: child,
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════
// NEON POINTER
// ═══════════════════════════════════════════════════

class _NeonPointerIndicator extends StatelessWidget {
  final double deflection;
  final ThemeTokens tokens;
  final double glowIntensity;
  final bool isSpinning;

  const _NeonPointerIndicator({
    required this.deflection,
    required this.tokens,
    required this.glowIntensity,
    required this.isSpinning,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, 10),
      child: Transform.rotate(
        angle: deflection,
        origin: const Offset(0, -12),
        child: CustomPaint(
          size: const Size(26, 32),
          painter: _NeonPointerPainter(
            color: const Color(0xFFFFD700),
            glowIntensity: glowIntensity,
            isSpinning: isSpinning,
          ),
        ),
      ),
    );
  }
}

class _NeonPointerPainter extends CustomPainter {
  final Color color;
  final double glowIntensity;
  final bool isSpinning;

  _NeonPointerPainter({
    required this.color,
    required this.glowIntensity,
    required this.isSpinning,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(2, 0)
      ..lineTo(size.width - 2, 0)
      ..close();

    // Multi-layer glow for neon effect
    for (int i = 3; i >= 0; i--) {
      final glowPaint = Paint()
        ..color = color.withValues(alpha: (0.06 + glowIntensity * 0.06) * (i + 1))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4.0 + i * 3.0)
        ..style = PaintingStyle.fill;
      canvas.drawPath(path, glowPaint);
    }

    // Solid pointer
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, paint);

    // Bright inner highlight
    final highlightPath = Path()
      ..moveTo(size.width / 2, size.height - 4)
      ..lineTo(6, 4)
      ..lineTo(size.width - 6, 4)
      ..close();
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4 + glowIntensity * 0.2)
      ..style = PaintingStyle.fill;
    canvas.drawPath(highlightPath, highlightPaint);

    // Center dot
    final dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width / 2, 4), 2.5, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _NeonPointerPainter oldDelegate) =>
      oldDelegate.glowIntensity != glowIntensity || oldDelegate.isSpinning != isSpinning;
}

// ═══════════════════════════════════════════════════
// FUTURISTIC WHEEL PAINTER
// ═══════════════════════════════════════════════════

class _FuturisticWheelPainter extends CustomPainter {
  final List<String> options;
  final ThemeTokens tokens;
  final double glowIntensity;

  static const List<List<Color>> _neonGradients = [
    [Color(0xFF6366F1), Color(0xFF818CF8)],
    [Color(0xFF10B981), Color(0xFF34D399)],
    [Color(0xFFF59E0B), Color(0xFFFBBF24)],
    [Color(0xFF3B82F6), Color(0xFF60A5FA)],
    [Color(0xFFEC4899), Color(0xFFF472B6)],
    [Color(0xFF14B8A6), Color(0xFF2DD4BF)],
    [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
    [Color(0xFFEF4444), Color(0xFFF87171)],
  ];

  _FuturisticWheelPainter({
    required this.options,
    required this.tokens,
    required this.glowIntensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double centerX = size.width / 2;
    final double centerY = size.height / 2;
    final Offset center = Offset(centerX, centerY);
    final double radius = min(size.width, size.height) / 2;

    if (options.isEmpty) return;

    final double sliceAngle = 2 * pi / options.length;

    // Outer glow halo
    final haloPaint = Paint()
      ..color = tokens.accent.withValues(alpha: 0.06 + glowIntensity * 0.06)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;
    canvas.drawCircle(center, radius + 2, haloPaint);

    // Outer wheel shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(center, radius - 2, shadowPaint);

    // Slices drawing with gradient-like coloring
    for (int i = 0; i < options.length; i++) {
      final double startAngle = i * sliceAngle - pi / 2;
      final colors = _neonGradients[i % _neonGradients.length];
      
      // Use gradient via shader for each slice
      final slicePaint = Paint()
        ..shader = SweepGradient(
          center: Alignment.center,
          startAngle: startAngle,
          endAngle: startAngle + sliceAngle,
          colors: [colors[0], colors[1]],
        ).createShader(Rect.fromCircle(center: center, radius: radius - 6))
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 6),
        startAngle,
        sliceAngle,
        true,
        slicePaint,
      );

      // Inner glow at the edge of each slice
      final innerGlow = Paint()
        ..color = colors[1].withValues(alpha: 0.15 + glowIntensity * 0.1)
        ..maskFilter = const MaskFilter.blur(BlurStyle.inner, 8)
        ..style = PaintingStyle.fill;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 6),
        startAngle,
        sliceAngle,
        true,
        innerGlow,
      );
    }

    // Glowing dividers/seams between slices
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25 + glowIntensity * 0.1)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < options.length; i++) {
      final double boundaryAngle = i * sliceAngle - pi / 2;
      canvas.drawLine(
        center,
        Offset(
          centerX + (radius - 6) * cos(boundaryAngle),
          centerY + (radius - 6) * sin(boundaryAngle),
        ),
        linePaint,
      );
    }

    // Labels rendering radially
    for (int i = 0; i < options.length; i++) {
      final double startAngle = i * sliceAngle - pi / 2;
      final double angle = startAngle + sliceAngle / 2;

      double fontSize = 13;
      if (options.length > 6) fontSize = 11;
      if (options.length > 10) fontSize = 9.5;
      if (options.length > 15) fontSize = 8.0;

      final textStyle = TextStyle(
        color: Colors.white,
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
        shadows: [
          Shadow(
            color: Colors.black.withValues(alpha: 0.9),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
          Shadow(
            color: Colors.white.withValues(alpha: 0.15),
            blurRadius: 2,
          ),
        ],
      );

      final tp = TextPainter(
        text: TextSpan(text: options[i], style: textStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '...',
      );

      tp.layout(maxWidth: radius * 0.55);

      double normAngle = angle % (2 * pi);
      if (normAngle < 0) normAngle += 2 * pi;

      // Flip text on left hemisphere to keep it readable
      final bool flip = normAngle > pi / 2 && normAngle < 3 * pi / 2;

      canvas.save();
      canvas.translate(centerX, centerY);
      if (flip) {
        canvas.rotate(normAngle + pi);
        tp.paint(canvas, Offset(-radius * 0.75, -tp.height / 2));
      } else {
        canvas.rotate(normAngle);
        tp.paint(canvas, Offset(radius * 0.22, -tp.height / 2));
      }
      canvas.restore();
    }

    // Neon outer rim — double ring with glow
    final rimPaint = Paint()
      ..color = tokens.surfaceAlt.withValues(alpha: 0.8)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius - 3, rimPaint);

    // Neon glow on outer rim
    final rimGlowPaint = Paint()
      ..color = tokens.accent.withValues(alpha: 0.15 + glowIntensity * 0.1)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(center, radius, rimGlowPaint);

    final rimBorderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius - 6, rimBorderPaint);
    canvas.drawCircle(center, radius, rimBorderPaint);

    // Neon studs on outer rim at segment borders
    for (int i = 0; i < options.length; i++) {
      final double boundaryAngle = i * sliceAngle - pi / 2;
      final double studX = centerX + (radius - 3) * cos(boundaryAngle);
      final double studY = centerY + (radius - 3) * sin(boundaryAngle);

      // Stud glow
      final studGlow = Paint()
        ..color = const Color(0xFFFFD700).withValues(alpha: 0.4 + glowIntensity * 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(Offset(studX, studY), 4, studGlow);

      // Solid stud
      final studPaint = Paint()
        ..color = const Color(0xFFFFD700)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(studX, studY), 2.5, studPaint);
    }

    // Center hub cap — futuristic concentric rings
    final hubShadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(center, radius * 0.18, hubShadowPaint);

    // Hub outer ring glow
    final hubGlowPaint = Paint()
      ..color = tokens.accent.withValues(alpha: 0.2 + glowIntensity * 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(center, radius * 0.17, hubGlowPaint);

    final hubPaint = Paint()
      ..color = tokens.surface
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.15, hubPaint);

    final hubBorderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius * 0.15, hubBorderPaint);

    // Inner hub ring
    final innerHubPaint = Paint()
      ..color = tokens.accent.withValues(alpha: 0.3)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius * 0.1, innerHubPaint);

    // Center brass screw pin with glow
    final capGlow = Paint()
      ..color = const Color(0xFFFFD700).withValues(alpha: 0.5 + glowIntensity * 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawCircle(center, 6, capGlow);

    final capPaint = Paint()
      ..color = const Color(0xFFFFD700)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 4, capPaint);

    // Tiny white highlight on cap
    final capHighlight = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(centerX - 1, centerY - 1), 1.5, capHighlight);
  }

  @override
  bool shouldRepaint(covariant _FuturisticWheelPainter oldDelegate) {
    return oldDelegate.options != options ||
        oldDelegate.tokens != tokens ||
        oldDelegate.glowIntensity != glowIntensity;
  }
}

class _EmptyWheelPainter extends CustomPainter {
  final ThemeTokens tokens;

  _EmptyWheelPainter({required this.tokens});

  @override
  void paint(Canvas canvas, Size size) {
    final double centerX = size.width / 2;
    final double centerY = size.height / 2;
    final Offset center = Offset(centerX, centerY);
    final double radius = min(size.width, size.height) / 2;

    final dashPaint = Paint()
      ..color = tokens.textMuted.withValues(alpha: 0.25)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    const int dashCount = 36;
    const double dashAngle = 2 * pi / dashCount;
    for (int i = 0; i < dashCount; i += 2) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 12),
        i * dashAngle,
        dashAngle,
        false,
        dashPaint,
      );
    }

    canvas.drawCircle(center, radius * 0.2, dashPaint);

    final textStyle = TextStyle(
      color: tokens.textMuted,
      fontSize: 12,
      fontWeight: FontWeight.w500,
    );

    final tp = TextPainter(
      text: TextSpan(
        text: "Add at least 2 options\nto build the wheel",
        style: textStyle,
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    tp.layout();
    tp.paint(canvas, Offset(centerX - tp.width / 2, centerY - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _EmptyWheelPainter oldDelegate) => false;
}

// ═══════════════════════════════════════════════════
// AMBIENT PARTICLES
// ═══════════════════════════════════════════════════

class _AmbientParticle {
  double x;
  double y;
  double vx;
  double vy;
  double size;
  double alpha;
  double maxAlpha;
  final Color color;
  double pulseSpeed;
  double _pulsePhase = 0;

  _AmbientParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.alpha,
    required this.maxAlpha,
    required this.color,
    required this.pulseSpeed,
  }) {
    _pulsePhase = Random().nextDouble() * 2 * pi;
  }

  void update() {
    x += vx;
    y += vy;
    _pulsePhase += pulseSpeed;
    alpha = maxAlpha * (0.5 + 0.5 * sin(_pulsePhase));

    // Wrap around
    if (x > 200) x = -200;
    if (x < -200) x = 200;
    if (y > 200) y = -200;
    if (y < -200) y = 200;
  }
}

class _AmbientParticlePainter extends CustomPainter {
  final List<_AmbientParticle> particles;

  _AmbientParticlePainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    for (final p in particles) {
      if (p.alpha <= 0.01) continue;
      final pos = Offset(center.dx + p.x, center.dy + p.y);

      // Soft glow
      final glowPaint = Paint()
        ..color = p.color.withValues(alpha: p.alpha * 0.3)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.size * 3);
      canvas.drawCircle(pos, p.size * 2, glowPaint);

      // Core dot
      final paint = Paint()..color = p.color.withValues(alpha: p.alpha);
      canvas.drawCircle(pos, p.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AmbientParticlePainter oldDelegate) => true;
}

// ═══════════════════════════════════════════════════
// CELEBRATION OVERLAY — Enhanced
// ═══════════════════════════════════════════════════

class _Particle {
  double x;
  double y;
  double vx;
  double vy;
  double size;
  double alpha;
  final Color color;
  final bool isCircle;
  double rotation;
  double rotationSpeed;

  _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.alpha,
    required this.color,
    required this.isCircle,
    this.rotation = 0,
    this.rotationSpeed = 0,
  });

  void update() {
    x += vx;
    y += vy;
    vy += 0.15; // Gravity pull
    vx *= 0.98; // Wind drag
    vy *= 0.98; // Wind drag
    alpha -= 0.012; // Slower fade for longer celebration
    rotation += rotationSpeed;
  }
}

class _CelebrationOverlay extends StatefulWidget {
  final String topic;
  final String option;
  final VoidCallback onClose;
  final VoidCallback onRespin;

  const _CelebrationOverlay({
    required this.topic,
    required this.option,
    required this.onClose,
    required this.onRespin,
  });

  @override
  State<_CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<_CelebrationOverlay>
    with TickerProviderStateMixin {
  late AnimationController _ticker;
  late AnimationController _pulseController;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  final List<_Particle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..addListener(() {
        setState(() {
          for (final p in _particles) {
            p.update();
          }
          _particles.removeWhere((p) => p.alpha <= 0);
        });
      });

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: const Cubic(0.34, 1.56, 0.64, 1.0), // springy overshoot
    );

    _spawnParticles();
    _ticker.repeat();
    _scaleController.forward();
  }

  void _spawnParticles() {
    final colors = [
      const Color(0xFFFFD700), // Gold
      const Color(0xFF8B5CF6), // Purple
      const Color(0xFF10B981), // Emerald
      const Color(0xFF3B82F6), // Blue
      const Color(0xFFEC4899), // Pink
      const Color(0xFFF59E0B), // Orange
      const Color(0xFFFFFFFF), // White sparkle
    ];

    // Spawn 120 explosive sparkles for more dramatic effect
    for (int i = 0; i < 120; i++) {
      final angle = _random.nextDouble() * 2 * pi;
      final speed = _random.nextDouble() * 10 + 4;
      _particles.add(
        _Particle(
          x: 0,
          y: -40,
          vx: cos(angle) * speed,
          vy: sin(angle) * speed - 4.0,
          size: _random.nextDouble() * 7 + 3,
          alpha: 1.0,
          color: colors[_random.nextInt(colors.length)],
          isCircle: _random.nextBool(),
          rotation: _random.nextDouble() * pi,
          rotationSpeed: (_random.nextDouble() - 0.5) * 0.15,
        ),
      );
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _pulseController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = FocusOsTheme.of(context);

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.6),
      body: Stack(
        children: [
          // Background Backdrop Filter
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(color: Colors.transparent),
            ),
          ),
          
          // Particle system layer
          Positioned.fill(
            child: CustomPaint(
              painter: _ParticlePainter(_particles),
            ),
          ),
          
          // Congratulations Card
          Center(
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    width: 460,
                    padding: const EdgeInsets.all(36),
                    decoration: BoxDecoration(
                      color: tokens.surface.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.3 + _pulseController.value * 0.2),
                        width: 2.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFD700).withValues(alpha: 0.08 + _pulseController.value * 0.08),
                          blurRadius: 40 + _pulseController.value * 15,
                          spreadRadius: 8,
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: child,
                  );
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Animated glowing stars icon
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, _) {
                        return Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                const Color(0xFFFFD700).withValues(alpha: 0.15 + _pulseController.value * 0.1),
                                Colors.transparent,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFFD700).withValues(alpha: 0.15 + _pulseController.value * 0.15),
                                blurRadius: 20 + _pulseController.value * 10,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: Transform.rotate(
                            angle: _pulseController.value * 0.2,
                            child: const Icon(
                              Icons.auto_awesome_rounded,
                              color: Color(0xFFFFD700),
                              size: 42,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    
                    Text(
                      "GOD'S WISH DECISION",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFFFD700),
                        letterSpacing: 3.0,
                        shadows: [
                          Shadow(
                            color: const Color(0xFFFFD700).withValues(alpha: 0.5),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    
                    Text(
                      widget.topic.isNotEmpty ? widget.topic : "Decision Decided",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: tokens.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Decided Option display — enhanced
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, _) {
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                tokens.accent.withValues(alpha: 0.1 + _pulseController.value * 0.05),
                                const Color(0xFFFFD700).withValues(alpha: 0.05 + _pulseController.value * 0.03),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: tokens.accent.withValues(alpha: 0.2 + _pulseController.value * 0.1),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: tokens.accent.withValues(alpha: 0.08 + _pulseController.value * 0.05),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              widget.option,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: tokens.textPrimary,
                                shadows: [
                                  Shadow(
                                    color: tokens.accent.withValues(alpha: 0.5),
                                    blurRadius: 12,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 32),
                    
                    // Action buttons — futuristic
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: widget.onRespin,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: tokens.textSecondary,
                              side: BorderSide(color: tokens.borderMedium),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.refresh_rounded, size: 16, color: tokens.textSecondary),
                                const SizedBox(width: 6),
                                const Text(
                                  'Spin Again',
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: tokens.accent.withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: widget.onClose,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: tokens.accent,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'Accept Fate',
                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;

  _ParticlePainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    for (final p in particles) {
      if (p.alpha <= 0) continue;
      final pos = Offset(center.dx + p.x, center.dy + p.y);

      // Particle glow
      final glowPaint = Paint()
        ..color = p.color.withValues(alpha: p.alpha * 0.3)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.size);
      canvas.drawCircle(pos, p.size * 1.5, glowPaint);

      // Core particle
      final paint = Paint()..color = p.color.withValues(alpha: p.alpha);
      if (p.isCircle) {
        canvas.drawCircle(pos, p.size * 0.6, paint);
      } else {
        canvas.save();
        canvas.translate(pos.dx, pos.dy);
        canvas.rotate(p.rotation);
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size),
          paint,
        );
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => true;
}
