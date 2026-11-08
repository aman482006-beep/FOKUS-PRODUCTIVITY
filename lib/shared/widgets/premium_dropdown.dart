import 'package:flutter/material.dart';
import '../motion.dart';
import '../theme.dart';

/// Premium dropdown with smooth open animation, dark elegant menu,
/// rounded corners, hover highlight, and keyboard navigation.
class PremiumDropdown<T> extends StatefulWidget {
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String label;
  final IconData? icon;
  final double width;

  const PremiumDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.label,
    this.icon,
    this.width = 180,
  });

  @override
  State<PremiumDropdown<T>> createState() => _PremiumDropdownState<T>();
}

class _PremiumDropdownState<T> extends State<PremiumDropdown<T>> {
  bool _hovered = false;
  bool _open = false;
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  String get _selectedLabel {
    for (final item in widget.items) {
      if (item.value == widget.value) {
        final child = item.child;
        if (child is Text) {
          return child.data ?? '';
        }
        return child.toString();
      }
    }
    return '';
  }

  void _openMenu() {
    if (!mounted) return;
    final tokens = FocusOsTheme.of(context);
    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            // Tap outside to close
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _closeMenu,
              child: Container(),
            ),
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: const Offset(0, 42), // 38 height of dropdown + 4 margin
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: widget.width,
                  decoration: BoxDecoration(
                    color: tokens.surfaceAlt,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: tokens.borderMedium),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.safeWithOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: Colors.black.safeWithOpacity(0.15),
                        blurRadius: 40,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: widget.items.map((item) {
                        final isSelected = item.value == widget.value;
                        return _DropdownItem<T>(
                          item: item,
                          isSelected: isSelected,
                          tokens: tokens,
                          onTap: () {
                            widget.onChanged(item.value);
                            _closeMenu();
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _overlayEntry == null) return;
      try {
        Overlay.of(context).insert(_overlayEntry!);
        setState(() => _open = true);
      } catch (_) {}
    });
  }

  void _closeMenu() {
    if (_overlayEntry != null) {
      final entry = _overlayEntry;
      _overlayEntry = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          entry?.remove();
        } catch (_) {}
      });
    }
    if (mounted) {
      setState(() => _open = false);
    }
  }

  @override
  void dispose() {
    if (_overlayEntry != null) {
      try {
        _overlayEntry?.remove();
      } catch (_) {}
      _overlayEntry = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = FocusOsTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: TextStyle(
            fontSize: 11,
            color: tokens.textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        CompositedTransformTarget(
          link: _layerLink,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) {
              if (mounted) setState(() => _hovered = true);
            },
            onExit: (_) {
              if (mounted) setState(() => _hovered = false);
            },
            child: GestureDetector(
              onTap: () {
                if (_open) {
                  _closeMenu();
                } else {
                  _openMenu();
                }
              },
              child: AnimatedContainer(
                duration: PremiumDurations.hover,
                curve: PremiumCurves.easeOutCubic,
                width: widget.width,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: tokens.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _open
                        ? tokens.accent.safeWithOpacity(0.5)
                        : _hovered
                            ? tokens.borderMedium
                            : tokens.borderSubtle,
                  ),
                  boxShadow: _open
                      ? [
                          BoxShadow(
                            color: tokens.accent.safeWithOpacity(0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, size: 14, color: tokens.textSecondary),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(
                        _selectedLabel,
                        style: TextStyle(
                          fontSize: 13,
                          color: tokens.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: _open ? 0.5 : 0.0,
                      duration: PremiumDurations.microFeedbackLong,
                      curve: PremiumCurves.easeOutCubic,
                      child: Icon(
                        Icons.expand_more_rounded,
                        size: 16,
                        color: tokens.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DropdownItem<T extends Object?> extends StatefulWidget {
  final DropdownMenuItem<T> item;
  final bool isSelected;
  final ThemeTokens tokens;
  final VoidCallback onTap;

  const _DropdownItem({
    required this.item,
    required this.isSelected,
    required this.tokens,
    required this.onTap,
  });

  @override
  State<_DropdownItem<T>> createState() => _DropdownItemState<T>();
}

class _DropdownItemState<T extends Object?> extends State<_DropdownItem<T>> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        if (mounted) setState(() => _hovered = true);
      },
      onExit: (_) {
        if (mounted) setState(() => _hovered = false);
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: PremiumDurations.microFeedback,
          curve: PremiumCurves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? widget.tokens.accent.safeWithOpacity(0.10)
                : _hovered
                    ? widget.tokens.textPrimary.safeWithOpacity(0.04)
                    : Colors.transparent,
            border: widget.isSelected
                ? Border(
                    left: BorderSide(
                      color: widget.tokens.accent,
                      width: 2,
                    ),
                  )
                : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: DefaultTextStyle(
                  style: TextStyle(
                    fontSize: 13,
                    color: widget.isSelected
                        ? widget.tokens.accent
                        : widget.tokens.textPrimary,
                    fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                  child: widget.item,
                ),
              ),
              if (widget.isSelected)
                Icon(
                  Icons.check_rounded,
                  size: 16,
                  color: widget.tokens.accent,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
