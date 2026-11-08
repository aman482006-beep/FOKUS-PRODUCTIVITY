import 'package:flutter/material.dart';
import '../motion.dart';
import '../theme.dart';

// ═══════════════════════════════════════════════════
// Premium Button System
// ═══════════════════════════════════════════════════
// Tactile, responsive buttons with:
//   - Hover elevation / glow / scale
//   - Press compression with instant feedback
//   - Smooth rebound on release
//   - Disabled subdued appearance
// ═══════════════════════════════════════════════════

enum PremiumButtonVariant {
  primary,
  secondary,
  ghost,
  danger,
  gradient,
}

class PremiumButton extends StatefulWidget {
  final Widget? child;
  final String? label;
  final IconData? icon;
  final VoidCallback? onTap;
  final VoidCallback? onPressed;
  final PremiumButtonVariant variant;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry padding;
  final BorderRadiusGeometry borderRadius;
  final bool enabled;
  final String? tooltip;

  const PremiumButton({
    super.key,
    this.child,
    this.label,
    this.icon,
    this.onTap,
    this.onPressed,
    this.variant = PremiumButtonVariant.primary,
    this.width,
    this.height,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.enabled = true,
    this.tooltip,
  });

  @override
  State<PremiumButton> createState() => _PremiumButtonState();
}

class _PremiumButtonState extends State<PremiumButton>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final tokens = FocusOsTheme.of(context);
    final effectiveEnabled = widget.enabled && (widget.onTap != null || widget.onPressed != null);

    return MouseRegion(
      cursor: effectiveEnabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: effectiveEnabled ? (_) => setState(() => _hovered = true) : null,
      onExit: effectiveEnabled ? (_) => setState(() => _hovered = false) : null,
      child: GestureDetector(
        onTapDown: effectiveEnabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: effectiveEnabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: () => setState(() => _pressed = false),
        onTap: effectiveEnabled ? (widget.onTap ?? widget.onPressed) : null,
        child: AnimatedScale(
          scale: _pressed ? 0.97 : (_hovered ? 1.02 : 1.0),
          duration: _pressed
              ? PremiumDurations.buttonPress
              : PremiumDurations.buttonRelease,
          curve: _pressed
              ? PremiumCurves.pressCurve
              : PremiumCurves.releaseCurve,
          child: AnimatedContainer(
            duration: PremiumDurations.hover,
            curve: PremiumCurves.hoverCurve,
            width: widget.width,
            height: widget.height,
            padding: widget.padding,
            decoration: _buildDecoration(tokens, effectiveEnabled),
            child: DefaultTextStyle(
              style: _buildTextStyle(tokens, effectiveEnabled),
              child: AnimatedDefaultTextStyle(
                duration: PremiumDurations.hover,
                style: _buildTextStyle(tokens, effectiveEnabled),
                child: _buildChild(tokens, effectiveEnabled),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChild(ThemeTokens tokens, bool enabled) {
    if (widget.child != null) return widget.child!;
    final textColor = _buildTextStyle(tokens, enabled).color ?? Colors.white;
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, size: 14, color: textColor),
          const SizedBox(width: 6),
        ],
        if (widget.label != null)
          Text(
            widget.label!,
          ),
      ],
    );
  }

  BoxDecoration _buildDecoration(ThemeTokens tokens, bool enabled) {
    final base = BoxDecoration(
      borderRadius: widget.borderRadius,
    );

    switch (widget.variant) {
      case PremiumButtonVariant.primary:
        return base.copyWith(
          color: enabled ? tokens.accent : tokens.borderMedium,
          boxShadow: _hovered && enabled
              ? [
                  BoxShadow(
                    color: tokens.accent.safeWithOpacity(0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        );

      case PremiumButtonVariant.gradient:
        return base.copyWith(
          gradient: enabled ? tokens.accentGradient : null,
          color: enabled ? null : tokens.borderMedium,
          boxShadow: _hovered && enabled
              ? [
                  BoxShadow(
                    color: tokens.accent.safeWithOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        );

      case PremiumButtonVariant.secondary:
        return base.copyWith(
          color: _hovered && enabled
              ? tokens.textPrimary.safeWithOpacity(0.06)
              : Colors.transparent,
          border: Border.all(
            color: enabled ? tokens.borderMedium : tokens.borderSubtle,
          ),
        );

      case PremiumButtonVariant.ghost:
        return base.copyWith(
          color: _hovered && enabled
              ? tokens.textPrimary.safeWithOpacity(0.04)
              : Colors.transparent,
        );

      case PremiumButtonVariant.danger:
        return base.copyWith(
          color: _hovered && enabled
              ? const Color(0xFFEF4444).safeWithOpacity(0.12)
              : Colors.transparent,
          border: Border.all(
            color: enabled
                ? (_hovered
                    ? const Color(0xFFEF4444).safeWithOpacity(0.4)
                    : tokens.borderMedium)
                : tokens.borderSubtle,
          ),
          boxShadow: _hovered && enabled
              ? [
                  BoxShadow(
                    color: const Color(0xFFEF4444).safeWithOpacity(0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        );
    }
  }

  TextStyle _buildTextStyle(ThemeTokens tokens, bool enabled) {
    final base = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.1,
    );

    switch (widget.variant) {
      case PremiumButtonVariant.primary:
      case PremiumButtonVariant.gradient:
        return base.copyWith(
          color: enabled ? Colors.white : tokens.textMuted,
        );
      case PremiumButtonVariant.secondary:
        return base.copyWith(
          color: enabled ? tokens.textPrimary : tokens.textMuted,
        );
      case PremiumButtonVariant.ghost:
        return base.copyWith(
          color: enabled
              ? (_hovered ? tokens.textPrimary : tokens.textSecondary)
              : tokens.textMuted,
        );
      case PremiumButtonVariant.danger:
        return base.copyWith(
          color: enabled
              ? (_hovered ? const Color(0xFFEF4444) : tokens.textSecondary)
              : tokens.textMuted,
        );
    }
  }
}

/// Icon-only button with square container
class PremiumIconButton extends StatelessWidget {
  final IconData icon;
  final double iconSize;
  final VoidCallback? onTap;
  final bool enabled;
  final bool isActive;
  final String? tooltip;
  final Color? activeColor;

  const PremiumIconButton({
    super.key,
    required this.icon,
    this.iconSize = 16,
    this.onTap,
    this.enabled = true,
    this.isActive = false,
    this.tooltip,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = FocusOsTheme.of(context);
    final color = activeColor ?? tokens.accent;
    final effectiveEnabled = enabled && onTap != null;

    return PremiumHoverEffect(
      hoverScale: 1.08,
      pressScale: 0.92,
      enabled: effectiveEnabled,
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: isActive
              ? color.safeWithOpacity(0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Icon(
          icon,
          size: iconSize,
          color: isActive
              ? color
              : tokens.textSecondary,
        ),
      ),
    );
  }
}
