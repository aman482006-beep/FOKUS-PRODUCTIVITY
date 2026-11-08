import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';
import '../../../shared/theme.dart';

/// Layered premium background with animated scene support, custom wallpaper support, and smooth cross-fade transitions.
class PremiumBackground extends ConsumerWidget {
  const PremiumBackground({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = FocusOsTheme.of(context);
    final activeScene = ref.watch(fokusSceneProvider);
    final wallpaperState = ref.watch(wallpaperProvider);

    Widget backgroundContent;

    if (wallpaperState.imagePath != null) {
      backgroundContent = AnimatedCustomWallpaper(
        key: ValueKey('wallpaper_${wallpaperState.imagePath}'),
        imagePath: wallpaperState.imagePath!,
      );
    } else if (activeScene.id == 'none') {
      backgroundContent = Container(
        key: const ValueKey('none'),
        color: tokens.background,
      );
    } else {
      backgroundContent = AnimatedSceneWidget(
        key: ValueKey('scene_${activeScene.id}_${activeScene.imagePath}'),
        sceneId: activeScene.id,
        imagePath: activeScene.imagePath,
        fallbackGradientColors: activeScene.gradientColors,
        tokens: tokens,
      );
    }

    return Positioned.fill(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 1000),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
          return Stack(
            children: <Widget>[
              ...previousChildren.map((child) => Positioned.fill(child: child)),
              if (currentChild != null) Positioned.fill(child: currentChild),
            ],
          );
        },
        child: backgroundContent,
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Reusable Animated Transforms
// ──────────────────────────────────────────────

class AnimatedBackgroundTransform extends StatelessWidget {
  final Widget child;
  final Animation<double> animation;
  final double minScale;
  final double maxScale;
  final Offset translateRange;

  const AnimatedBackgroundTransform({
    super.key,
    required this.child,
    required this.animation,
    required this.minScale,
    required this.maxScale,
    required this.translateRange,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final val = animation.value; // oscillates between 0.0 and 1.0
        final scale = minScale + (maxScale - minScale) * val;
        final dx = translateRange.dx * (val * 2 - 1);
        final dy = translateRange.dy * (val * 2 - 1);
        return Transform.translate(
          offset: Offset(dx, dy),
          child: Transform.scale(
            scale: scale,
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

// ──────────────────────────────────────────────
// Scene-Specific Animated Widget
// ──────────────────────────────────────────────

class AnimatedSceneWidget extends StatefulWidget {
  final String sceneId;
  final String imagePath;
  final List<Color> fallbackGradientColors;
  final ThemeTokens tokens;

  const AnimatedSceneWidget({
    super.key,
    required this.sceneId,
    required this.imagePath,
    required this.fallbackGradientColors,
    required this.tokens,
  });

  @override
  State<AnimatedSceneWidget> createState() => _AnimatedSceneWidgetState();
}

class _AnimatedSceneWidgetState extends State<AnimatedSceneWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _transformController;

  @override
  void initState() {
    super.initState();
    _transformController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 25),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double minScale = 1.05;
    double maxScale = 1.15;
    Offset translateRange = const Offset(8, 8);

    if (widget.sceneId == 'rain') {
      minScale = 1.05;
      maxScale = 1.15;
      translateRange = const Offset(0, 12); // vertical drift
    } else if (widget.sceneId == 'forest') {
      minScale = 1.04;
      maxScale = 1.12;
      translateRange = const Offset(6, 6);
    } else if (widget.sceneId == 'beach') {
      minScale = 1.10;
      maxScale = 1.10;
      translateRange = const Offset(15, 0); // horizontal pan
    } else if (widget.sceneId == 'night_sky') {
      minScale = 1.06;
      maxScale = 1.12;
      translateRange = const Offset(8, 8); // diagonal drift
    } else if (widget.sceneId == 'library') {
      minScale = 1.04;
      maxScale = 1.12;
      translateRange = const Offset(0, 6); // vertical drift
    } else if (widget.sceneId == 'coding_desk') {
      minScale = 1.05;
      maxScale = 1.10;
      translateRange = const Offset(6, 4); // parallax shift
    }

    Widget? overlayWidget;
    if (widget.sceneId == 'rain') {
      overlayWidget = const _RainOverlay();
    } else if (widget.sceneId == 'forest') {
      overlayWidget = const _ForestFogOverlay();
    } else if (widget.sceneId == 'beach') {
      overlayWidget = const _BeachShimmerOverlay();
    } else if (widget.sceneId == 'night_sky') {
      overlayWidget = const _NightSkyStarsOverlay();
    } else if (widget.sceneId == 'library') {
      overlayWidget = const _LibraryDustOverlay();
    } else if (widget.sceneId == 'coding_desk') {
      overlayWidget = const _CodingDeskGlowOverlay();
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Layer 1: Fallback scene-specific gradient
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: widget.fallbackGradientColors,
            ),
          ),
        ),

        // Layer 2: Asset background image with subtle scale & translate transform
        AnimatedBackgroundTransform(
          animation: _transformController,
          minScale: minScale,
          maxScale: maxScale,
          translateRange: translateRange,
          child: Image.asset(
            widget.imagePath,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: widget.tokens.background.withValues(alpha: 0.8),
              );
            },
          ),
        ),

        // Layer 3: Scene specific cinematic animated overlay
        if (overlayWidget != null) Positioned.fill(child: overlayWidget),

        // Layer 4: Dark overlay for premium text contrast
        Positioned.fill(
          child: Container(
            color: Colors.black.withValues(alpha: 0.35),
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────
// Custom Wallpaper Animated Widget
// ──────────────────────────────────────────────

class AnimatedCustomWallpaper extends StatefulWidget {
  final String imagePath;

  const AnimatedCustomWallpaper({
    super.key,
    required this.imagePath,
  });

  @override
  State<AnimatedCustomWallpaper> createState() => _AnimatedCustomWallpaperState();
}

class _AnimatedCustomWallpaperState extends State<AnimatedCustomWallpaper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _transformController;

  @override
  void initState() {
    super.initState();
    _transformController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Fallback solid black container
        Container(color: Colors.black),

        // Wallpaper image with smooth zoom + drift animation
        AnimatedBackgroundTransform(
          animation: _transformController,
          minScale: 1.05,
          maxScale: 1.15,
          translateRange: const Offset(8, 8),
          child: kIsWeb
              ? Image.network(
                  widget.imagePath,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                )
              : Image.file(
                  File(widget.imagePath),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
        ),

        // Subtle dark overlay to match original app design and preserve readability
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              color: Colors.black.withValues(alpha: 0.35),
            ),
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────
// Rain Particle Animated Overlay
// ──────────────────────────────────────────────

class _RainDrop {
  final double xPercentage;
  final double yPercentage;
  final double speed;
  final double length;
  final double opacity;
  const _RainDrop(this.xPercentage, this.yPercentage, this.speed, this.length, this.opacity);
}

class _RainOverlay extends StatefulWidget {
  const _RainOverlay();

  @override
  State<_RainOverlay> createState() => _RainOverlayState();
}

class _RainOverlayState extends State<_RainOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _RainPainter(animationValue: _controller.value),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _RainPainter extends CustomPainter {
  final double animationValue;
  static List<_RainDrop>? _cachedDrops;

  _RainPainter({required this.animationValue}) {
    _cachedDrops ??= List.generate(70, (index) {
      final r = Random(index * 3);
      return _RainDrop(
        r.nextDouble(),
        r.nextDouble(),
        1.2 + r.nextDouble() * 0.8,
        20.0 + r.nextDouble() * 25.0,
        0.05 + r.nextDouble() * 0.15,
      );
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    for (final drop in _cachedDrops!) {
      double y = (drop.yPercentage * size.height + animationValue * drop.speed * size.height) % size.height;
      double x = drop.xPercentage * size.width - (y * 0.08); // slight slant
      
      paint.color = Colors.white.withValues(alpha: drop.opacity);
      canvas.drawLine(
        Offset(x, y),
        Offset(x - 1.5, y + drop.length),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_RainPainter oldDelegate) => oldDelegate.animationValue != animationValue;
}

// ──────────────────────────────────────────────
// Forest Fog Animated Overlay
// ──────────────────────────────────────────────

class _FogLayer {
  final double yPercentage;
  final double heightPercentage;
  final double speed;
  final double opacity;
  final bool movingRight;
  const _FogLayer(this.yPercentage, this.heightPercentage, this.speed, this.opacity, this.movingRight);
}

class _ForestFogOverlay extends StatefulWidget {
  const _ForestFogOverlay();

  @override
  State<_ForestFogOverlay> createState() => _ForestFogOverlayState();
}

class _ForestFogOverlayState extends State<_ForestFogOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _ForestFogPainter(animationValue: _controller.value),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _ForestFogPainter extends CustomPainter {
  final double animationValue;
  static List<_FogLayer>? _cachedFog;

  _ForestFogPainter({required this.animationValue}) {
    _cachedFog ??= [
      const _FogLayer(0.40, 0.25, 0.08, 0.06, true),
      const _FogLayer(0.60, 0.30, -0.12, 0.08, false),
      const _FogLayer(0.75, 0.35, 0.05, 0.07, true),
    ];
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final layer in _cachedFog!) {
      final double progress = animationValue * layer.speed;
      final double xOffset = (progress * size.width) % size.width;
      final double y = layer.yPercentage * size.height;
      final double h = layer.heightPercentage * size.height;

      // Draw horizontal bands seamlessly
      _drawFogBand(canvas, size, xOffset, y, h, layer.opacity);
      _drawFogBand(canvas, size, xOffset - size.width, y, h, layer.opacity);
      _drawFogBand(canvas, size, xOffset + size.width, y, h, layer.opacity);
    }
  }

  void _drawFogBand(Canvas canvas, Size size, double x, double y, double h, double maxOpacity) {
    final rect = Rect.fromLTWH(x, y - h / 2, size.width, h);
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          Colors.white.withValues(alpha: maxOpacity),
          Colors.white.withValues(alpha: maxOpacity * 0.5),
          Colors.transparent,
        ],
      ).createShader(rect);

    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(_ForestFogPainter oldDelegate) => oldDelegate.animationValue != animationValue;
}

// ──────────────────────────────────────────────
// Beach Shimmer Animated Overlay
// ──────────────────────────────────────────────

class _BeachShimmerOverlay extends StatefulWidget {
  const _BeachShimmerOverlay();

  @override
  State<_BeachShimmerOverlay> createState() => _BeachShimmerOverlayState();
}

class _BeachShimmerOverlayState extends State<_BeachShimmerOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _BeachShimmerPainter(animationValue: _controller.value),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _BeachShimmerPainter extends CustomPainter {
  final double animationValue;
  const _BeachShimmerPainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Sun glow at top right
    final sunCenter = Offset(size.width * 0.82, size.height * 0.18);
    final sunRadius = size.width * 0.45 + (15.0 * animationValue);
    final sunRect = Rect.fromCircle(center: sunCenter, radius: sunRadius);

    final sunPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.amber.withValues(alpha: 0.08 + (0.04 * animationValue)),
          Colors.orange.withValues(alpha: 0.02 + (0.01 * animationValue)),
          Colors.transparent,
        ],
      ).createShader(sunRect);

    canvas.drawCircle(sunCenter, sunRadius, sunPaint);

    // 2. Water reflection shimmer glow at bottom
    final reflectRect = Rect.fromLTWH(0, size.height * 0.65, size.width, size.height * 0.35);
    final reflectPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          Colors.white.withValues(alpha: 0.02 + (0.03 * animationValue)),
          Colors.amber.withValues(alpha: 0.04 + (0.04 * (1.0 - animationValue))),
          Colors.transparent,
        ],
      ).createShader(reflectRect);

    canvas.drawRect(reflectRect, reflectPaint);
  }

  @override
  bool shouldRepaint(_BeachShimmerPainter oldDelegate) => oldDelegate.animationValue != animationValue;
}

// ──────────────────────────────────────────────
// Night Sky Stars Animated Overlay
// ──────────────────────────────────────────────

class _Star {
  final double xPercentage;
  final double yPercentage;
  final double size;
  final double phaseOffset;
  const _Star(this.xPercentage, this.yPercentage, this.size, this.phaseOffset);
}

class _NightSkyStarsOverlay extends StatefulWidget {
  const _NightSkyStarsOverlay();

  @override
  State<_NightSkyStarsOverlay> createState() => _NightSkyStarsOverlayState();
}

class _NightSkyStarsOverlayState extends State<_NightSkyStarsOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _NightSkyStarsPainter(animationValue: _controller.value),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _NightSkyStarsPainter extends CustomPainter {
  final double animationValue;
  static List<_Star>? _cachedStars;

  _NightSkyStarsPainter({required this.animationValue}) {
    _cachedStars ??= List.generate(45, (index) {
      final r = Random(index * 11);
      return _Star(
        r.nextDouble(),
        r.nextDouble() * 0.65, // top 65% of screen
        0.8 + r.nextDouble() * 1.6,
        r.nextDouble() * 2 * pi,
      );
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;

    for (final star in _cachedStars!) {
      double t = (animationValue * 2 * pi) + star.phaseOffset;
      double twinkle = 0.15 + 0.85 * (0.5 + 0.5 * sin(t));
      
      paint.color = Colors.white.withValues(alpha: twinkle);
      canvas.drawCircle(
        Offset(star.xPercentage * size.width, star.yPercentage * size.height),
        star.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_NightSkyStarsPainter oldDelegate) => oldDelegate.animationValue != animationValue;
}

// ──────────────────────────────────────────────
// Library Dust Animated Overlay
// ──────────────────────────────────────────────

class _Dust {
  final double xPercentage;
  final double yPercentage;
  final double size;
  final double speed;
  final double driftAmplitude;
  final double phaseOffset;
  const _Dust(this.xPercentage, this.yPercentage, this.size, this.speed, this.driftAmplitude, this.phaseOffset);
}

class _LibraryDustOverlay extends StatefulWidget {
  const _LibraryDustOverlay();

  @override
  State<_LibraryDustOverlay> createState() => _LibraryDustOverlayState();
}

class _LibraryDustOverlayState extends State<_LibraryDustOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _LibraryDustPainter(animationValue: _controller.value),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _LibraryDustPainter extends CustomPainter {
  final double animationValue;
  static List<_Dust>? _cachedDust;

  _LibraryDustPainter({required this.animationValue}) {
    _cachedDust ??= List.generate(20, (index) {
      final r = Random(index * 17);
      return _Dust(
        r.nextDouble(),
        r.nextDouble(),
        1.0 + r.nextDouble() * 1.5,
        0.05 + r.nextDouble() * 0.08,
        4.0 + r.nextDouble() * 6.0,
        r.nextDouble() * 2 * pi,
      );
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final goldColor = const Color(0xFFFCD34D);

    for (final dust in _cachedDust!) {
      double y = (dust.yPercentage * size.height - animationValue * dust.speed * size.height) % size.height;
      double x = dust.xPercentage * size.width + sin(animationValue * 2 * pi + dust.phaseOffset) * dust.driftAmplitude;

      double edgeFade = 1.0;
      if (y < 60) {
        edgeFade = y / 60;
      } else if (y > size.height - 60) {
        edgeFade = (size.height - y) / 60;
      }

      double opacity = (0.05 + 0.15 * (0.5 + 0.5 * sin(animationValue * 2 * pi + dust.phaseOffset))) * edgeFade;

      paint.color = goldColor.withValues(alpha: opacity);
      canvas.drawCircle(Offset(x, y), dust.size, paint);
    }
  }

  @override
  bool shouldRepaint(_LibraryDustPainter oldDelegate) => oldDelegate.animationValue != animationValue;
}

// ──────────────────────────────────────────────
// Coding Desk Monitor Glow Animated Overlay
// ──────────────────────────────────────────────

class _CodingDeskGlowOverlay extends StatefulWidget {
  const _CodingDeskGlowOverlay();

  @override
  State<_CodingDeskGlowOverlay> createState() => _CodingDeskGlowOverlayState();
}

class _CodingDeskGlowOverlayState extends State<_CodingDeskGlowOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _CodingDeskGlowPainter(
            animationValue: _controller.value,
            accentColor: FocusOsTheme.of(context).accent,
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _CodingDeskGlowPainter extends CustomPainter {
  final double animationValue;
  final Color accentColor;
  const _CodingDeskGlowPainter({required this.animationValue, required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final glowCenter = Offset(size.width * 0.5, size.height * 1.05);
    final glowRadius = size.height * 0.55 + (20.0 * animationValue);
    final glowRect = Rect.fromCircle(center: glowCenter, radius: glowRadius);

    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          accentColor.withValues(alpha: 0.12 + (0.06 * animationValue)),
          accentColor.withValues(alpha: 0.03 + (0.01 * animationValue)),
          Colors.transparent,
        ],
      ).createShader(glowRect);

    canvas.drawCircle(glowCenter, glowRadius, glowPaint);
  }

  @override
  bool shouldRepaint(_CodingDeskGlowPainter oldDelegate) => 
      oldDelegate.animationValue != animationValue || oldDelegate.accentColor != accentColor;
}
