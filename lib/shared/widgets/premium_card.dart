import 'package:flutter/material.dart';
import '../motion.dart';
import '../theme.dart';

// ═══════════════════════════════════════════════════
// Premium Card System
// ═══════════════════════════════════════════════════
// Cards with:
//   - Hover elevation + shadow interpolation
//   - Subtle movement (Y offset)
//   - Responsive highlighting
//   - Premium subtlety — no aggressive animation
// ═══════════════════════════════════════════════════

class PremiumCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final BorderRadiusGeometry borderRadius;
  final double hoverElevation;
  final double hoverYOffset;
  final double hoverScale;
  final Color? hoverBorderColor;
  final Color? activeBorderColor;
  final bool isActive;
  final bool enabled;
  final EdgeInsetsGeometry? margin;

  const PremiumCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.hoverElevation = 8.0,
    this.hoverYOffset = -1.5,
    this.hoverScale = 1.005,
    this.hoverBorderColor,
    this.activeBorderColor,
    this.isActive = false,
    this.enabled = true,
    this.margin,
  });

  @override
  State<PremiumCard> createState() => _PremiumCardState();
}

class _PremiumCardState extends State<PremiumCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = FocusOsTheme.of(context);
    final effectiveEnabled = widget.enabled;

    return MouseRegion(
      cursor: widget.onTap != null && effectiveEnabled
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      onEnter: effectiveEnabled ? (_) => setState(() => _hovered = true) : null,
      onExit: effectiveEnabled ? (_) => setState(() => _hovered = false) : null,
      child: GestureDetector(
        onTap: effectiveEnabled ? widget.onTap : null,
        child: AnimatedContainer(
          duration: PremiumDurations.hoverLong,
          curve: PremiumCurves.easeOutCubic,
          margin: widget.margin,
          padding: widget.padding,
          decoration: BoxDecoration(
            color: widget.isActive
                ? Color.alphaBlend(tokens.accent.safeWithOpacity(0.08), tokens.surface)
                : _hovered
                    ? Color.alphaBlend(tokens.textPrimary.safeWithOpacity(0.03), tokens.surface)
                    : tokens.surface,
            borderRadius: widget.borderRadius,
            border: Border.all(
              color: widget.isActive
                  ? (widget.activeBorderColor ?? tokens.accent)
                      .safeWithOpacity(0.3)
                  : _hovered
                      ? (widget.hoverBorderColor ?? tokens.borderMedium)
                      : tokens.borderSubtle,
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: tokens.accent.safeWithOpacity(0.06),
                      blurRadius: widget.hoverElevation,
                      offset: Offset(0, widget.hoverElevation * 0.4),
                    ),
                    BoxShadow(
                      color: Colors.black.safeWithOpacity(0.08),
                      blurRadius: widget.hoverElevation * 0.6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.safeWithOpacity(0.02),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
          ),
          transform: Matrix4.translationValues(
            0.0,
            _hovered ? widget.hoverYOffset : 0.0,
            0.0,
          ),
          transformAlignment: Alignment.center,
          child: DefaultTextStyle(
            style: TextStyle(
              color: tokens.textPrimary,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Mini card — for compact info displays (stats, metrics, badges)
class PremiumMiniCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;

  const PremiumMiniCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = FocusOsTheme.of(context);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? tokens.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: child,
    );
  }
}

/// Premium section header
class PremiumSectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const PremiumSectionHeader({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = FocusOsTheme.of(context);

    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: tokens.accent.safeWithOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: tokens.accent),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: tokens.textPrimary,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: TextStyle(fontSize: 11, color: tokens.textMuted),
                ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
