import 'package:fokus/shared/theme.dart';
import 'package:flutter/material.dart';
export 'widgets/hover_architecture.dart';


// ═══════════════════════════════════════════════════
// Fokus — Premium Motion Design System
// ═══════════════════════════════════════════════════
// Defines all animation durations, easing curves,
// and reusable animation widgets for the entire app.
//
// Premium apps feel premium because of:
//   - physicality in interactions
//   - natural-feeling transitions
//   - motion that communicates hierarchy
//   - latency that feels invisible
// ═══════════════════════════════════════════════════

// ──────────────────────────────────────────────
// CURVES — custom premium easing curves
// ──────────────────────────────────────────────

/// Arc-style easeOutCubic with a slight overshoot at the end
/// for a premium "snap" feel on buttons and cards.
class PremiumCurves {
  /// Smooth deceleration — best for enter animations, panel slides.
  /// Replaced default cubic with a custom easeOutQuart (0.16, 1, 0.3, 1) for a premium snappy native feel.
  static const easeOutCubic = Cubic(0.16, 1.0, 0.3, 1.0);

  /// Subtle overshoot for tactile button press release
  static const springyOut = Cubic(0.34, 1.56, 0.64, 1.0);

  /// Smooth ease-in — best for exit animations
  static const easeInCubic = Curves.easeInCubic;

  /// Fast-out, slow-in — Material-inspired, great for micro-interactions
  static const fastOutSlowIn = Curves.fastOutSlowIn;

  /// Very soft deceleration for subtle fades
  static const softOut = Cubic(0.0, 0.0, 0.2, 1.0);

  /// Premium elastic for immersive transitions
  static const elasticOut = Cubic(0.175, 0.885, 0.32, 1.275);

  /// Gentle ease for hover transitions
  static const hoverCurve = Cubic(0.25, 0.1, 0.25, 1.0);

  /// Button press compression
  static const pressCurve = Cubic(0.4, 0.0, 0.6, 1.0);

  /// Rebound after press release
  static const releaseCurve = Cubic(0.34, 1.4, 0.64, 1.0);
}

// ──────────────────────────────────────────────
// DURATIONS — timing hierarchy
// ──────────────────────────────────────────────

class PremiumDurations {
  // Micro feedback — instant tactile response
  static const microFeedback = Duration(milliseconds: 80);
  static const microFeedbackLong = Duration(milliseconds: 120);

  // Hover transitions
  static const hover = Duration(milliseconds: 150);
  static const hoverLong = Duration(milliseconds: 200);

  // Button press feedback
  static const buttonPress = Duration(milliseconds: 70);
  static const buttonRelease = Duration(milliseconds: 120);

  // Panel transitions
  static const panelSlide = Duration(milliseconds: 220);
  static const panelFade = Duration(milliseconds: 180);

  // Page transitions
  static const pageTransition = Duration(milliseconds: 240);
  static const pageTransitionLong = Duration(milliseconds: 280);

  // Immersive mode transitions
  static const immersiveEnter = Duration(milliseconds: 600);
  static const immersiveExit = Duration(milliseconds: 400);

  // Overlay transitions
  static const overlayFade = Duration(milliseconds: 250);
  static const overlaySlide = Duration(milliseconds: 350);

  // Toggle / switch animations
  static const toggle = Duration(milliseconds: 200);

  // Theme changes
  static const themeTransition = Duration(milliseconds: 400);
}

// ──────────────────────────────────────────────
// REUSABLE ANIMATION WIDGETS
// ──────────────────────────────────────────────

/// Fade + slight vertical slide on entry — for page content, cards, panels.
class PremiumEnterTransition extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Curve curve;
  final double slideOffset;
  final double beginOpacity;
  final bool animate;

  const PremiumEnterTransition({
    super.key,
    required this.child,
    this.duration = PremiumDurations.pageTransition,
    this.curve = PremiumCurves.easeOutCubic,
    this.slideOffset = 0.04,
    this.beginOpacity = 0.0,
    this.animate = true,
  });

  @override
  State<PremiumEnterTransition> createState() => _PremiumEnterTransitionState();
}

class _PremiumEnterTransitionState extends State<PremiumEnterTransition>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _fadeAnim = Tween<double>(begin: widget.beginOpacity, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: widget.curve),
    );
    _slideAnim = Tween<Offset>(
      begin: Offset(0, widget.slideOffset),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));
    if (widget.animate) _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.animate
        ? FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(position: _slideAnim, child: widget.child),
          )
        : widget.child;
  }
}

/// Staggered enter — for lists of items that reveal one after another.
class PremiumStaggeredEnter extends StatelessWidget {
  final List<Widget> children;
  final Duration itemDuration;
  final Duration staggerDelay;
  final Curve curve;

  const PremiumStaggeredEnter({
    super.key,
    required this.children,
    this.itemDuration = PremiumDurations.pageTransition,
    this.staggerDelay = const Duration(milliseconds: 60),
    this.curve = PremiumCurves.easeOutCubic,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(children.length, (index) {
        return _StaggeredItem(
          index: index,
          duration: itemDuration,
          delay: staggerDelay,
          curve: curve,
          child: children[index],
        );
      }),
    );
  }
}

class _StaggeredItem extends StatefulWidget {
  final int index;
  final Duration duration;
  final Duration delay;
  final Curve curve;
  final Widget child;

  const _StaggeredItem({
    required this.index,
    required this.duration,
    required this.delay,
    required this.curve,
    required this.child,
  });

  @override
  State<_StaggeredItem> createState() => _StaggeredItemState();
}

class _StaggeredItemState extends State<_StaggeredItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _anim = CurvedAnimation(parent: _controller, curve: widget.curve);
    Future.delayed(widget.delay * widget.index, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.03),
          end: Offset.zero,
        ).animate(_anim),
        child: widget.child,
      ),
    );
  }
}

/// Premium hover scale + elevation for cards and buttons.
class PremiumHoverEffect extends StatefulWidget {
  final Widget child;
  final double hoverScale;
  final double hoverElevation;
  final double pressScale;
  final Duration hoverDuration;
  final Duration pressDuration;
  final Curve hoverCurve;
  final Curve pressCurve;
  final VoidCallback? onTap;
  final bool enabled;

  const PremiumHoverEffect({
    super.key,
    required this.child,
    this.hoverScale = 1.02,
    this.hoverElevation = 4.0,
    this.pressScale = 0.97,
    this.hoverDuration = PremiumDurations.hover,
    this.pressDuration = PremiumDurations.buttonPress,
    this.hoverCurve = PremiumCurves.hoverCurve,
    this.pressCurve = PremiumCurves.pressCurve,
    this.onTap,
    this.enabled = true,
  });

  @override
  State<PremiumHoverEffect> createState() => _PremiumHoverEffectState();
}

class _PremiumHoverEffectState extends State<PremiumHoverEffect>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;
  bool _pressed = false;

  double get _targetScale {
    if (_pressed) return widget.pressScale;
    if (_hovered) return widget.hoverScale;
    return 1.0;
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.enabled && widget.onTap != null
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      onEnter: widget.enabled ? (_) => setState(() => _hovered = true) : null,
      onExit: widget.enabled ? (_) => setState(() => _hovered = false) : null,
      child: GestureDetector(
        onTapDown: widget.enabled && widget.onTap != null
            ? (_) => setState(() => _pressed = true)
            : null,
        onTapUp: widget.enabled && widget.onTap != null
            ? (_) => setState(() => _pressed = false)
            : null,
        onTapCancel: widget.enabled
            ? () => setState(() => _pressed = false)
            : null,
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedScale(
          scale: _targetScale,
          duration: _pressed ? widget.pressDuration : widget.hoverDuration,
          curve: _pressed ? widget.pressCurve : widget.hoverCurve,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Smooth digit/character transition for timer display.
/// Animates between old and new values with a vertical slide and fade.
class AnimatedDigit extends StatelessWidget {
  final String value;
  final TextStyle? style;
  final Duration duration;
  final Curve curve;

  const AnimatedDigit({
    super.key,
    required this.value,
    this.style,
    this.duration = PremiumDurations.microFeedbackLong,
    this.curve = PremiumCurves.easeOutCubic,
  });

  @override
  Widget build(BuildContext context) {
    final currentStyle = style ?? const TextStyle();

    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: curve,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
        return Stack(
          children: <Widget>[
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
          alignment: Alignment.center,
        );
      },
      transitionBuilder: (child, animation) {
        final offsetAnim = Tween<Offset>(
          begin: const Offset(0, 0.1),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offsetAnim, child: child),
        );
      },
      child: KeyedSubtree(
        key: ValueKey(value),
        child: Text(
          value,
          style: currentStyle,
        ),
      ),
    );
  }
}

/// Smooth progress ring with animated transitions.
class AnimatedRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;
  final double? startAngle;

  const AnimatedRingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    this.strokeWidth = 4,
    this.startAngle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2 - 8;
    final start = startAngle ?? -3.14159 / 2;

    // Track ring
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc — animated via lerp
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Subtle glow
    if (progress > 0.01) {
      final glowPaint = Paint()
        ..color = color.safeWithOpacity(0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 6
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        6.28318 * progress,
        false,
        glowPaint,
      );
    }

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      6.28318 * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant AnimatedRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color;
}

/// An interactive toggle switch with premium feel.
class PremiumToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color? activeColor;
  final double width;
  final double height;

  const PremiumToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor,
    this.width = 36,
    this.height = 20,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = FocusOsTheme.of(context);
    final isDark = tokens.brightness == Brightness.dark;
    final inactiveColor = isDark ? const Color(0x3AFFFFFF) : const Color(0x1F000000);

    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: PremiumDurations.toggle,
        curve: PremiumCurves.fastOutSlowIn,
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: value
              ? (activeColor ?? tokens.accent)
              : inactiveColor,
          borderRadius: BorderRadius.circular(height / 2),
        ),
        child: AnimatedAlign(
          duration: PremiumDurations.toggle,
          curve: PremiumCurves.springyOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: height - 4,
            height: height - 4,
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.safeWithOpacity(0.2),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Animated active indicator pill — morphs between items.
class AnimatedPill extends StatelessWidget {
  final bool isActive;
  final Widget child;
  final Color activeColor;
  final Color inactiveColor;
  final Duration duration;

  const AnimatedPill({
    super.key,
    required this.isActive,
    required this.child,
    required this.activeColor,
    required this.inactiveColor,
    this.duration = PremiumDurations.panelSlide,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: duration,
      curve: PremiumCurves.easeOutCubic,
      decoration: BoxDecoration(
        color: isActive ? activeColor : inactiveColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }
}
