import 'package:flutter/material.dart';
import '../motion.dart';
import '../theme.dart';

// ═══════════════════════════════════════════════════
// Hover Architecture — Fokus
// ═══════════════════════════════════════════════════
// Centralized hover state management to eliminate
// repetitive _hovered / setState patterns.
//
// Provides:
//   - Unified hover state builder
//   - Common hover decoration presets
//   - Hover-aware icon/color interpolations
// ═══════════════════════════════════════════════════

/// Signature for building a widget tree with hover state.
typedef HoverWidgetBuilder = Widget Function(
  BuildContext context,
  bool hovered,
  bool pressed,
);

/// Wraps a widget with unified hover + press state management.
/// Handles MouseRegion, GestureDetector click, and AnimatedScale
/// with premium curves and durations.
class HoverBuilder extends StatefulWidget {
  final HoverWidgetBuilder builder;
  final VoidCallback? onTap;
  final bool enabled;
  final double hoverScale;
  final double pressScale;
  final Duration hoverDuration;
  final Duration pressDuration;

  const HoverBuilder({
    super.key,
    required this.builder,
    this.onTap,
    this.enabled = true,
    this.hoverScale = 1.02,
    this.pressScale = 0.97,
    this.hoverDuration = PremiumDurations.hover,
    this.pressDuration = PremiumDurations.buttonPress,
  });

  @override
  State<HoverBuilder> createState() => _HoverBuilderState();
}

class _HoverBuilderState extends State<HoverBuilder> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final showClickCursor = widget.enabled && widget.onTap != null;
    final enableHover = widget.enabled;

    return MouseRegion(
      cursor: showClickCursor ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: enableHover ? (_) => setState(() => _hovered = true) : null,
      onExit: enableHover ? (_) => setState(() => _hovered = false) : null,
      child: GestureDetector(
        onTapDown: showClickCursor ? (_) => setState(() => _pressed = true) : null,
        onTapUp: showClickCursor ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: showClickCursor ? () => setState(() => _pressed = false) : null,
        onTap: showClickCursor ? widget.onTap : null,
        child: AnimatedScale(
          scale: _pressed
              ? widget.pressScale
              : _hovered
                  ? widget.hoverScale
                  : 1.0,
          duration: _pressed ? widget.pressDuration : widget.hoverDuration,
          curve: _pressed ? PremiumCurves.pressCurve : PremiumCurves.releaseCurve,
          child: widget.builder(context, _hovered, _pressed),
        ),
      ),
    );
  }
}

/// Color interpolation helper for hover states.
extension HoverColors on Color {
  Color withHover(double amount) {
    final factor = 1.0 + amount;
    return Color.fromARGB(
      (a * 255.0).round().clamp(0, 255),
      ((r * 255.0) * factor).round().clamp(0, 255),
      ((g * 255.0) * factor).round().clamp(0, 255),
      ((b * 255.0) * factor).round().clamp(0, 255),
    );
  }

  Color hoverLighten() => withHover(0.15);
  Color hoverDarken() => withHover(-0.1);
}

/// Preset hover decoration builder.
/// Returns a decoration for a given hover/active/pressed state.
BoxDecoration hoverDecoration({
  required ThemeTokens tokens,
  required bool hovered,
  bool active = false,
  bool pressed = false,
  BorderRadiusGeometry borderRadius = const BorderRadius.all(Radius.circular(7)),
}) {
  Color bgColor;
  if (active) {
    bgColor = tokens.accent.safeWithOpacity(0.12);
  } else if (pressed) {
    bgColor = tokens.textPrimary.safeWithOpacity(0.08);
  } else if (hovered) {
    bgColor = tokens.textPrimary.safeWithOpacity(0.04);
  } else {
    bgColor = Colors.transparent;
  }

  Color borderColor;
  if (active) {
    borderColor = tokens.accent.safeWithOpacity(0.3);
  } else if (hovered) {
    borderColor = tokens.borderMedium;
  } else {
    borderColor = Colors.transparent;
  }

  return BoxDecoration(
    color: bgColor,
    borderRadius: borderRadius,
    border: active || hovered ? Border.all(color: borderColor) : null,
  );
}

/// Hover-aware row with icon + label, commonly used for nav items.
class HoverNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool expanded;
  final VoidCallback onTap;
  final String? shortcut;

  const HoverNavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.active,
    required this.expanded,
    required this.onTap,
    this.shortcut,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = FocusOsTheme.of(context);

    return HoverBuilder(
      onTap: onTap,
      hoverScale: active ? 1.0 : 1.02,
      pressScale: active ? 1.0 : 0.97,
      builder: (context, hovered, pressed) {
        final effectiveColor = active
            ? tokens.accent
            : hovered
                ? tokens.textPrimary
                : tokens.textSecondary;

        return AnimatedContainer(
          duration: PremiumDurations.hover,
          curve: PremiumCurves.easeOutCubic,
          height: 36.0,
          padding: EdgeInsets.symmetric(
            horizontal: expanded ? 10 : 0,
          ),
          decoration: hoverDecoration(
            tokens: tokens,
            hovered: hovered && !active,
            active: false,
            pressed: pressed && !active,
          ),
          alignment: Alignment.center,
          child: Row(
            children: [
              Container(
                width: 36,
                alignment: Alignment.center,
                child: Icon(icon, size: 18, color: effectiveColor),
              ),
              if (expanded) ...[
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                      color: effectiveColor,
                      letterSpacing: -0.1,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (active)
                  AnimatedContainer(
                    duration: PremiumDurations.panelSlide,
                    width: 3,
                    height: 3,
                    decoration: BoxDecoration(
                      color: tokens.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                if (shortcut != null && !active)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: tokens.borderSubtle,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      shortcut!,
                      style: TextStyle(fontSize: 9, color: tokens.textMuted),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}
