import 'dart:convert';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/navigation.dart';
import '../../core/providers.dart';
import '../motion.dart';
import '../theme.dart';
import '../shortcuts.dart';

/// Premium desktop sidebar — smooth, alive, tactile navigation.
/// Inspired by Linear, Raycast, and Arc Browser aesthetics.
class FocusOsSidebar extends ConsumerStatefulWidget {
  const FocusOsSidebar({super.key});

  @override
  ConsumerState<FocusOsSidebar> createState() => _FocusOsSidebarState();
}

class _FocusOsSidebarState extends ConsumerState<FocusOsSidebar>
    with SingleTickerProviderStateMixin {
  late AnimationController _indicatorController;
  @override
  void initState() {
    super.initState();
    _indicatorController = AnimationController(
      vsync: this,
      duration: PremiumDurations.panelSlide,
    );
  }

  @override
  void didUpdateWidget(covariant FocusOsSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    _indicatorController.dispose();
    super.dispose();
  }

  void _onNavChanged() {
    _indicatorController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(navigationProvider);
    final expanded = ref.watch(sidebarExpandedProvider);
    final tokens = FocusOsTheme.of(context);

    return AnimatedContainer(
      duration: PremiumDurations.panelSlide,
      curve: PremiumCurves.easeOutCubic,
      width: expanded ? 200 : 60,
      decoration: BoxDecoration(
        color: tokens.surface.withValues(alpha: 0.85),
        border: Border(
          right: BorderSide(color: tokens.borderSubtle.withValues(alpha: 0.5), width: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Column(
            children: [
              const _SidebarHeader(),
              const SizedBox(height: 8),

              // ── Navigation items with animated active indicator ──
              Expanded(
                child: Stack(
                  children: [
                    // Animated active indicator pill
                    AnimatedPositioned(
                      duration: PremiumDurations.panelSlide,
                      curve: PremiumCurves.easeOutCubic,
                      left: expanded ? 8 : 8,
                      top: (current.index * 44.0) + 8,
                      width: expanded ? 184 : 44,
                      height: 36,
                      child: AnimatedContainer(
                        duration: PremiumDurations.panelSlide,
                        curve: PremiumCurves.easeOutCubic,
                        decoration: BoxDecoration(
                          color: tokens.accent.safeWithOpacity(0.10),
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(
                            color: tokens.accent.safeWithOpacity(0.15),
                            width: 1,
                          ),
                        ),
                      ),
                    ),

                    // Nav items
                    ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      physics: const ClampingScrollPhysics(),
                      itemCount: NavDestination.values.length,
                      itemBuilder: (context, index) {
                        final dest = NavDestination.values[index];
                        final active = dest == current;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: HoverNavItem(
                            icon: dest.icon,
                            label: dest.label,
                            active: active,
                            expanded: expanded,
                            onTap: () {
                              _onNavChanged();
                              ref.read(navigationProvider.notifier).state = dest;
                            },
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // ── Bottom actions ──
              PremiumEnterTransition(
                duration: PremiumDurations.panelFade,
                child: Container(
                  padding: EdgeInsets.only(
                    left: expanded ? 12 : 0,
                    right: expanded ? 12 : 0,
                    bottom: 12,
                  ),
                  child: Column(
                    children: [
                      _divider(tokens),
                      const SizedBox(height: 8),
                      // Profile Card
                      _ProfileCard(expanded: expanded),
                      const SizedBox(height: 6),
                      // Quick capture button
                      _QuickCaptureButton(expanded: expanded),
                      const SizedBox(height: 6),
                      // Toggle sidebar collapse
                      _SidebarToggle(expanded: expanded),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _divider(ThemeTokens tokens) {
  return Container(
    height: 1,
    margin: const EdgeInsets.symmetric(horizontal: 12),
    color: tokens.borderSubtle,
  );
}

// ──────────────────────────────────────────────
// Sidebar Header
// ──────────────────────────────────────────────

class _SidebarHeader extends ConsumerWidget {
  const _SidebarHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded = ref.watch(sidebarExpandedProvider);
    final tokens = FocusOsTheme.of(context);

    return PremiumHoverEffect(
      hoverScale: 1.02,
      pressScale: 0.98,
      child: Container(
        height: 56,
        padding: EdgeInsets.only(left: expanded ? 14 : 0, right: expanded ? 14 : 0),
        alignment: expanded ? Alignment.centerLeft : Alignment.center,
        child: expanded
            ? Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.asset(
                      'assets/logo.png',
                      width: 24,
                      height: 24,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      'Fokus',
                      style: GoogleFonts.caveat(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: tokens.textPrimary,
                        letterSpacing: 0.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Image.asset(
                  'assets/logo.png',
                  width: 28,
                  height: 28,
                  fit: BoxFit.cover,
                ),
              ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Quick Capture Button
// ──────────────────────────────────────────────

class _QuickCaptureButton extends ConsumerStatefulWidget {
  final bool expanded;

  const _QuickCaptureButton({required this.expanded});

  @override
  ConsumerState<_QuickCaptureButton> createState() => _QuickCaptureButtonState();
}

class _QuickCaptureButtonState extends ConsumerState<_QuickCaptureButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = FocusOsTheme.of(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => ref.read(quickCaptureOpenProvider.notifier).state = true,
        child: AnimatedContainer(
          duration: PremiumDurations.hover,
          curve: PremiumCurves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: widget.expanded ? 12 : 0,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: _hovered ? tokens.textPrimary.safeWithOpacity(0.06) : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.edit_outlined,
                size: 15,
                color: _hovered ? tokens.textPrimary : tokens.textSecondary,
              ),
              if (widget.expanded) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Quick capture',
                    style: TextStyle(
                      fontSize: 12,
                      color: _hovered ? tokens.textPrimary : tokens.textMuted,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: tokens.borderSubtle,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${FocusOsShortcut.modifierLabel}Q',
                    style: TextStyle(fontSize: 9, color: tokens.textMuted),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Sidebar Toggle
// ──────────────────────────────────────────────

class _SidebarToggle extends ConsumerStatefulWidget {
  final bool expanded;

  const _SidebarToggle({required this.expanded});

  @override
  ConsumerState<_SidebarToggle> createState() => _SidebarToggleState();
}

class _SidebarToggleState extends ConsumerState<_SidebarToggle> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = FocusOsTheme.of(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () {
          ref.read(sidebarExpandedProvider.notifier).state = !widget.expanded;
        },
        child: AnimatedContainer(
          duration: PremiumDurations.hover,
          curve: PremiumCurves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: widget.expanded ? 12 : 0,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: _hovered ? tokens.textPrimary.safeWithOpacity(0.06) : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedRotation(
                turns: widget.expanded ? 0.0 : 0.5,
                duration: PremiumDurations.panelSlide,
                curve: PremiumCurves.easeOutCubic,
                child: Icon(
                  Icons.chevron_left_rounded,
                  size: 17,
                  color: tokens.textMuted,
                ),
              ),
              if (widget.expanded) ...[
                const SizedBox(width: 8),
                Text(
                  'Collapse',
                  style: TextStyle(fontSize: 12, color: tokens.textMuted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Profile Card
// ──────────────────────────────────────────────

class _ProfileCard extends ConsumerStatefulWidget {
  final bool expanded;

  const _ProfileCard({required this.expanded});

  @override
  ConsumerState<_ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends ConsumerState<_ProfileCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider);
    final tokens = FocusOsTheme.of(context);

    Widget avatar;
    if (profile.avatarBase64.isNotEmpty) {
      try {
        final bytes = base64Decode(profile.avatarBase64);
        avatar = CircleAvatar(
          radius: 12,
          backgroundImage: MemoryImage(bytes),
        );
      } catch (_) {
        avatar = _buildDefaultAvatar(tokens);
      }
    } else {
      avatar = _buildDefaultAvatar(tokens);
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () {
          ref.read(activeSettingsSectionProvider.notifier).state = SettingsSection.account;
          ref.read(settingsModalOpenProvider.notifier).state = true;
        },
        child: AnimatedContainer(
          duration: PremiumDurations.hover,
          curve: PremiumCurves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: widget.expanded ? 12 : 8,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: _hovered ? tokens.textPrimary.safeWithOpacity(0.06) : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(
            mainAxisAlignment: widget.expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              avatar,
              if (widget.expanded) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        profile.name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: tokens.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        profile.status,
                        style: TextStyle(
                          fontSize: 10,
                          color: tokens.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar(ThemeTokens tokens) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: tokens.accent.safeWithOpacity(0.15),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(
          Icons.person_outline,
          size: 14,
          color: tokens.accent,
        ),
      ),
    );
  }
}
