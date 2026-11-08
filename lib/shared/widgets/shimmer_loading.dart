import 'package:flutter/material.dart';
import '../theme.dart';

/// A premium shimmer/skeleton loading effect.
///
/// When [child] is provided, the shimmer animation overlays the child —
/// use this to skeletonize any widget (cards, list tiles, etc.).
///
/// When [child] is null, a simple shimmer rectangle is rendered using
/// [width], [height], and [borderRadius].
class ShimmerLoading extends StatefulWidget {
  final Widget? child;
  final double? width;
  final double? height;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;

  const ShimmerLoading({
    super.key,
    this.child,
    this.width,
    this.height,
    this.borderRadius = 8,
    this.margin,
  });

  /// A horizontal line placeholder (full width, 14px tall).
  factory ShimmerLoading.line({
    Key? key,
    double width = double.infinity,
    double height = 14,
    double borderRadius = 6,
    EdgeInsetsGeometry? margin,
  }) {
    return ShimmerLoading(
      key: key,
      width: width,
      height: height,
      borderRadius: borderRadius,
      margin: margin,
    );
  }

  /// A square/rectangle card placeholder.
  factory ShimmerLoading.card({
    Key? key,
    double width = double.infinity,
    double height = 120,
    double borderRadius = 12,
    EdgeInsetsGeometry? margin,
  }) {
    return ShimmerLoading(
      key: key,
      width: width,
      height: height,
      borderRadius: borderRadius,
      margin: margin,
    );
  }

  /// A circular placeholder (perfect for icons/avatars).
  factory ShimmerLoading.circle({
    Key? key,
    double size = 36,
    EdgeInsetsGeometry? margin,
  }) {
    return ShimmerLoading(
      key: key,
      width: size,
      height: size,
      borderRadius: size / 2,
      margin: margin,
    );
  }

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = Tween<double>(begin: -2.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.child != null) {
      // Wrap mode: shimmer overlay on child
      return _ShimmerWrap(
        animation: _animation,
        borderRadius: widget.borderRadius,
        margin: widget.margin,
        child: widget.child!,
      );
    }

    // Box mode: standalone shimmer rectangle
    final tokens = FocusOsTheme.of(context);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return Container(
          width: widget.width == double.infinity ? double.infinity : widget.width,
          height: widget.height,
          margin: widget.margin,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              colors: [
                tokens.surfaceAlt,
                tokens.borderSubtle.safeWithOpacity(0.6),
                tokens.surfaceAlt,
              ],
              stops: const [0.0, 0.5, 1.0],
              begin: Alignment(-1.0 + _animation.value * 0.5, 0.0),
              end: Alignment(1.0 + _animation.value * 0.5, 0.0),
            ),
          ),
        );
      },
    );
  }
}

/// Internal widget that applies shimmer gradient as an overlay on [child].
class _ShimmerWrap extends StatelessWidget {
  final Animation<double> animation;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;
  final Widget child;

  const _ShimmerWrap({
    required this.animation,
    required this.borderRadius,
    this.margin,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = FocusOsTheme.of(context);

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return Container(
          margin: margin,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              child,
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          tokens.borderSubtle.safeWithOpacity(0.15),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.5, 1.0],
                        begin: Alignment(-1.0 + animation.value * 0.5, 0.0),
                        end: Alignment(1.0 + animation.value * 0.5, 0.0),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────
// Page-specific skeleton screens
// ─────────────────────────────────────────────────────

/// A shimmer skeleton that mimics the health page layout.
class HealthPageShimmer extends StatelessWidget {
  const HealthPageShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = FocusOsTheme.of(context);

    return Padding(
      padding: const EdgeInsets.only(left: 32, right: 32, top: 32, bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header shimmer
          ShimmerLoading.line(width: 120, height: 24, borderRadius: 6),
          const SizedBox(height: 8),
          ShimmerLoading.line(width: 280, height: 13, borderRadius: 6),
          const SizedBox(height: 28),
          // Health panels
          Expanded(
            child: ListView(
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildPanelCard(toggles: 2, tokens: tokens),
                const SizedBox(height: 12),
                _buildPanelCard(toggles: 3, tokens: tokens),
                const SizedBox(height: 12),
                _buildPanelCard(toggles: 2, tokens: tokens),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPanelCard({required int toggles, required ThemeTokens tokens}) {
    return Container(
      height: 60.0 + (toggles * 58.0),
      margin: const EdgeInsets.only(bottom: 0),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.borderSubtle),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header row
          Row(
            children: [
              ShimmerLoading.circle(size: 16),
              const SizedBox(width: 10),
              ShimmerLoading.line(width: 140, height: 14),
            ],
          ),
          const SizedBox(height: 16),
          // Toggle rows
          ...List.generate(toggles, (i) => Padding(
            padding: EdgeInsets.only(bottom: i < toggles - 1 ? 8 : 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerLoading.line(width: 100, height: 13),
                      const SizedBox(height: 4),
                      ShimmerLoading.line(width: 160, height: 11),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ShimmerLoading.circle(size: 24),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

/// A shimmer skeleton that mimics the library page layout.
class LibraryPageShimmer extends StatelessWidget {
  const LibraryPageShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 32, right: 32, top: 32, bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header shimmer
          ShimmerLoading.line(width: 100, height: 24, borderRadius: 6),
          const SizedBox(height: 8),
          ShimmerLoading.line(width: 260, height: 13, borderRadius: 6),
          const SizedBox(height: 24),
          // Tab bar shimmer
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.transparent),
            ),
            child: Row(
              children: List.generate(3, (i) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: i > 0 ? 6 : 0,
                    right: i < 2 ? 6 : 0,
                  ),
                  child: ShimmerLoading.card(height: 40, borderRadius: 8),
                ),
              )),
            ),
          ),
          const SizedBox(height: 20),
          // Grid content shimmer
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.3,
              ),
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 6,
              itemBuilder: (context, index) {
                return ShimmerLoading.card(borderRadius: 12);
              },
            ),
          ),
        ],
      ),
    );
  }
}
