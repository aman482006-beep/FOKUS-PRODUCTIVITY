import 'package:flutter/material.dart';
import '../motion.dart';
import '../theme.dart';

/// Premium smooth slider with animated fill, elegant thumb, and subtle glow.
class PremiumSlider extends StatefulWidget {
  final double value;
  final ValueChanged<double> onChanged;
  final String label;
  final String? subtitle;
  final double min;
  final double max;
  final int divisions;
  final String? displayValue;
  final IconData? icon;

  const PremiumSlider({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
    this.subtitle,
    this.min = 0,
    this.max = 1,
    this.divisions = 100,
    this.displayValue,
    this.icon,
  });

  @override
  State<PremiumSlider> createState() => _PremiumSliderState();
}

class _PremiumSliderState extends State<PremiumSlider> {
  bool _hovered = false;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final tokens = FocusOsTheme.of(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: PremiumDurations.hover,
        curve: PremiumCurves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _hovered || _dragging
              ? tokens.textPrimary.safeWithOpacity(0.04)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, size: 14, color: tokens.textSecondary),
                  const SizedBox(width: 6),
                ],
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: tokens.textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  widget.displayValue ?? '${(widget.value * 100).round()}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: tokens.accent,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
            if (widget.subtitle != null) ...[
              const SizedBox(height: 1),
              Text(
                widget.subtitle!,
                style: TextStyle(fontSize: 11, color: tokens.textMuted),
              ),
            ],
            const SizedBox(height: 8),
            // ── Premium slider track ──
            LayoutBuilder(
              builder: (context, constraints) {
                final progress = (widget.value - widget.min) / (widget.max - widget.min);
                return GestureDetector(
                  onTapDown: (details) {
                    final ratio = (details.localPosition.dx / constraints.maxWidth)
                        .clamp(0.0, 1.0);
                    final newValue = widget.min + ratio * (widget.max - widget.min);
                    widget.onChanged(newValue);
                  },
                  child: SizedBox(
                    height: 20,
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        // Track background
                        Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: tokens.borderMedium.safeWithOpacity(0.5),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        // Animated fill
                        FractionallySizedBox(
                          widthFactor: progress.clamp(0.0, 1.0),
                          child: AnimatedContainer(
                            duration: _dragging
                                ? Duration.zero
                                : PremiumDurations.microFeedbackLong,
                            curve: PremiumCurves.easeOutCubic,
                            height: 4,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  tokens.accent.safeWithOpacity(0.7),
                                  tokens.accent,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(2),
                              boxShadow: [
                                BoxShadow(
                                  color: tokens.accent.safeWithOpacity(0.2),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Thumb
                        Positioned(
                          left: progress.clamp(0.0, 1.0) * constraints.maxWidth - 8,
                          child: GestureDetector(
                            onPanStart: (_) => setState(() => _dragging = true),
                            onPanEnd: (_) => setState(() => _dragging = false),
                            onPanUpdate: (details) {
                              final newDx = details.localPosition.dx.clamp(
                                0.0, constraints.maxWidth,
                              );
                              final ratio = newDx / constraints.maxWidth;
                              final newValue = widget.min + ratio * (widget.max - widget.min);
                              widget.onChanged(newValue);
                            },
                            child: AnimatedContainer(
                              duration: _dragging
                                  ? Duration.zero
                                  : PremiumDurations.toggle,
                              curve: PremiumCurves.springyOut,
                              width: _dragging ? 18 : 14,
                              height: _dragging ? 18 : 14,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                border: Border.all(
                                  color: _dragging
                                      ? tokens.accent
                                      : tokens.accent.safeWithOpacity(0.6),
                                  width: 2.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: tokens.accent.safeWithOpacity(_dragging ? 0.3 : 0.15),
                                    blurRadius: _dragging ? 8 : 4,
                                    offset: Offset(0, _dragging ? 3 : 1),
                                  ),
                                  BoxShadow(
                                    color: Colors.black.safeWithOpacity(0.15),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// A slider variant with compact layout for use in settings groups.
class PremiumCompactSlider extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final double min;
  final double max;
  final int? divisions;
  final String? displayValue;

  const PremiumCompactSlider({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.displayValue,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = FocusOsTheme.of(context);

    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: tokens.textPrimary,
          ),
        ),
        const Spacer(),
        SizedBox(
          width: 120,
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              activeTrackColor: tokens.accent,
              inactiveTrackColor: tokens.borderMedium.safeWithOpacity(0.5),
              thumbColor: Colors.white,
              overlayColor: tokens.accent.safeWithOpacity(0.12),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 36,
          child: Text(
            displayValue ?? '${(value * 100).round()}%',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: tokens.textSecondary,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }
}
