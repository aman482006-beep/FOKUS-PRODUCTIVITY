import 'dart:async';
import 'package:flutter/material.dart';
import '../motion.dart' as motion;
import '../theme.dart';

/// Premium, production-hardened tooltip widget for Fokus.
///
/// Bypasses the buggy framework-level [OverlayPortal] (which causes the
/// "Cannot hit test a render box that has never been laid out" exception)
/// by using a clean [OverlayEntry] managed with post-frame lifecycle callbacks.
class PremiumTooltip extends StatefulWidget {
  final Widget child;
  final String message;
  final bool enabled;

  const PremiumTooltip({
    super.key,
    required this.child,
    required this.message,
    this.enabled = true,
  });

  @override
  State<PremiumTooltip> createState() => _PremiumTooltipState();
}

class _PremiumTooltipState extends State<PremiumTooltip> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  Timer? _showTimer;
  bool _hovered = false;

  void _showTooltip() {
    if (!mounted || _overlayEntry != null || widget.message.isEmpty || !widget.enabled) return;

    final tokens = FocusOsTheme.of(context);

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            // Safe invisible tap-to-dismiss catcher
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _hideTooltip,
                child: const SizedBox.shrink(),
              ),
            ),
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              targetAnchor: Alignment.bottomCenter,
              followerAnchor: Alignment.topCenter,
              offset: const Offset(0, 6),
              child: Material(
                color: Colors.transparent,
                child: Center(
                  widthFactor: 1.0,
                  heightFactor: 1.0,
                  child: motion.PremiumEnterTransition(
                    duration: motion.PremiumDurations.hover,
                    curve: motion.PremiumCurves.easeOutCubic,
                    slideOffset: 0.02,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: tokens.surfaceAlt.safeWithOpacity(0.92),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: tokens.borderMedium),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.safeWithOpacity(0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        widget.message,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: tokens.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    // Hardened Overlay Insertion using Post-Frame scheduling to prevent build-phase exceptions
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _overlayEntry == null) return;
      
      try {
        final overlay = Overlay.of(context);
        overlay.insert(_overlayEntry!);
      } catch (_) {}
    });
  }

  void _hideTooltip() {
    _showTimer?.cancel();
    _showTimer = null;
    
    // Hardened Overlay Removal using scheduled callbacks to avoid tree locks
    if (_overlayEntry != null) {
      final entryToRemove = _overlayEntry;
      _overlayEntry = null;
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          entryToRemove?.remove();
        } catch (_) {}
      });
    }
  }

  @override
  void dispose() {
    _showTimer?.cancel();
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
    if (!widget.enabled || widget.message.isEmpty) {
      return widget.child;
    }

    return CompositedTransformTarget(
      link: _layerLink,
      child: MouseRegion(
        onEnter: (_) {
          _hovered = true;
          _showTimer?.cancel();
          _showTimer = Timer(const Duration(milliseconds: 300), () {
            if (_hovered) {
              _showTooltip();
            }
          });
        },
        onExit: (_) {
          _hovered = false;
          _hideTooltip();
        },
        child: widget.child,
      ),
    );
  }
}
