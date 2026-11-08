import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart' as wm;
import '../../shared/motion.dart' as motion;
import '../../shared/theme.dart';
import '../../shared/widgets/premium_card.dart';
import '../../core/providers.dart';
import '../../core/navigation.dart';

/// Settings page — professional grouped desktop settings architecture.
/// Premium cards, animated toggles, focused text fields, and hover interactions.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = FocusOsTheme.of(context);

    return motion.PremiumEnterTransition(
      duration: motion.PremiumDurations.pageTransition,
      child: Padding(
        padding: const EdgeInsets.only(left: 32, right: 32, top: 32, bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Text(
              'Settings',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: tokens.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Configure your fokus environment',
              style: TextStyle(fontSize: 13, color: tokens.textMuted),
            ),
            const SizedBox(height: 20),

            // ── Premium tab bar ──
            Container(
              height: 34,
              decoration: BoxDecoration(
                color: tokens.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: tokens.borderSubtle),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: tokens.accent.safeWithOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: tokens.accent,
                unselectedLabelColor: tokens.textSecondary,
                labelStyle:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                unselectedLabelStyle: const TextStyle(fontSize: 12),
                tabs: const [
                  Tab(text: 'General'),
                  Tab(text: 'Fokus'),
                  Tab(text: 'Display'),
                  Tab(text: 'About'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Animated tab content ──
            Expanded(
              child: AnimatedSwitcher(
                duration: motion.PremiumDurations.pageTransition,
                switchInCurve: motion.PremiumCurves.easeOutCubic,
                switchOutCurve: motion.PremiumCurves.easeInCubic,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.03),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                        parent: animation,
                        curve: motion.PremiumCurves.easeOutCubic,
                      )),
                      child: child,
                    ),
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey('settings_tab_${_tabController.index}'),
                  child: TabBarView(
                    controller: _tabController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _GeneralTab(),
                      _FocusTab(),
                      _DisplayTab(),
                      _AboutTab(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// General Tab
// ──────────────────────────────────────────────

class _GeneralTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = FocusOsTheme.of(context);
    final profile = ref.watch(userProfileProvider);
    final shortcuts = ref.watch(keyboardShortcutsProvider);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(parent: ClampingScrollPhysics()),
      child: motion.PremiumStaggeredEnter(
        staggerDelay: const Duration(milliseconds: 50),
        children: [
          _SettingsSection(
            title: 'Profile',
            icon: Icons.person_outline,
            tokens: tokens,
            children: [
              _PremiumTextField(
                label: 'Name',
                value: profile.name,
                tokens: tokens,
                onChanged: (v) =>
                    ref.read(userProfileProvider.notifier).updateName(v),
              ),
              _PremiumTextField(
                label: 'About You',
                value: profile.status,
                tokens: tokens,
                onChanged: (v) =>
                    ref.read(userProfileProvider.notifier).updateStatus(v),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SettingsSection(
            title: 'Keyboard',
            icon: Icons.keyboard_outlined,
            tokens: tokens,
            children: [
              _PremiumToggleRow(
                label: 'Keyboard shortcuts',
                subtitle: 'Enable global hotkeys',
                value: shortcuts,
                tokens: tokens,
                onChanged: (v) =>
                    ref.read(keyboardShortcutsProvider.notifier).setEnabled(v),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Focus Tab
// ──────────────────────────────────────────────

class _FocusTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = FocusOsTheme.of(context);
    final hardcore = ref.watch(hardcoreLockProvider);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(parent: ClampingScrollPhysics()),
      child: motion.PremiumStaggeredEnter(
        staggerDelay: const Duration(milliseconds: 50),
        children: [
          _SettingsSection(
            title: 'Timer Defaults',
            icon: Icons.timer_outlined,
            tokens: tokens,
            children: [
              _PremiumToggleRow(
                label: 'Auto-start fokus',
                subtitle: 'Start timer when session begins',
                value: false,
                tokens: tokens,
                onChanged: (v) {},
              ),
              const SizedBox(height: 8),
              _PremiumToggleRow(
                label: 'Resume interrupted sessions',
                subtitle: 'Ask to resume on app open',
                value: false,
                tokens: tokens,
                onChanged: (v) {},
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SettingsSection(
            title: 'Hardcore Lock',
            icon: Icons.lock_outline,
            tokens: tokens,
            children: [
              _PremiumToggleRow(
                label: 'Enable hardcore lock',
                subtitle: 'Requires password to exit fokus',
                value: hardcore.enabled,
                tokens: tokens,
                onChanged: (v) =>
                    ref.read(hardcoreLockProvider.notifier).setEnabled(v),
              ),
              if (hardcore.enabled) ...[
                const SizedBox(height: 8),
                _PremiumTextField(
                  label: 'Penalty seconds',
                  value: '${hardcore.penaltySeconds}',
                  tokens: tokens,
                  onChanged: (v) {
                    final s = int.tryParse(v);
                    if (s != null) {
                      ref
                          .read(hardcoreLockProvider.notifier)
                          .setPenaltySeconds(s);
                    }
                  },
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Display Tab
// ──────────────────────────────────────────────

class _DisplayTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = FocusOsTheme.of(context);
    final currentTheme = ref.watch(themeProvider);
    final fullscreen = ref.watch(fullscreenProvider);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(parent: ClampingScrollPhysics()),
      child: motion.PremiumStaggeredEnter(
        staggerDelay: const Duration(milliseconds: 50),
        children: [
          _SettingsSection(
            title: 'Theme',
            icon: Icons.palette_outlined,
            tokens: tokens,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AppThemes.all.map((theme) {
                  final active = theme.id == currentTheme.id;
                  return motion.HoverBuilder(
                    onTap: () =>
                        ref.read(themeProvider.notifier).setTheme(theme.id),
                    hoverScale: 1.03,
                    pressScale: 0.97,
                    builder: (context, hovered, pressed) {
                      return AnimatedContainer(
                        duration: motion.PremiumDurations.panelSlide,
                        curve: motion.PremiumCurves.easeOutCubic,
                        width: 130,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: active
                              ? tokens.accent.safeWithOpacity(0.08)
                              : hovered
                                  ? tokens.textPrimary
                                      .safeWithOpacity(0.04)
                                  : tokens.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: active
                                ? tokens.accent.safeWithOpacity(0.3)
                                : hovered
                                    ? tokens.borderMedium
                                    : tokens.borderSubtle,
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: theme.tokens.accent,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: theme.tokens.accentSecondary,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              theme.name,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: active
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: active
                                    ? tokens.accent
                                    : tokens.textSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    },
                  );
                }).toList(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SettingsSection(
            title: 'Display Options',
            icon: Icons.display_settings_outlined,
            tokens: tokens,
            children: [
              _PremiumToggleRow(
                label: 'Fullscreen by default',
                subtitle: 'Start in fullscreen mode',
                value: fullscreen,
                tokens: tokens,
                onChanged: (v) {
                  ref.read(fullscreenProvider.notifier).setFullscreen(v);
                  if (!kIsWeb) {
                    try {
                      if (v) {
                        wm.WindowManager.instance.setFullScreen(true);
                      } else {
                        wm.WindowManager.instance.setFullScreen(false);
                      }
                    } catch (_) {}
                  }
                },
              ),
              const SizedBox(height: 8),
              _PremiumToggleRow(
                label: 'Sidebar expanded',
                subtitle: 'Show labels in sidebar',
                value: ref.watch(sidebarExpandedProvider),
                tokens: tokens,
                onChanged: (v) =>
                    ref.read(sidebarExpandedProvider.notifier).state = v,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// About Tab
// ──────────────────────────────────────────────

class _AboutTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = FocusOsTheme.of(context);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(parent: ClampingScrollPhysics()),
      child: _SettingsSection(
        title: 'Fokus',
        icon: Icons.info_outline_rounded,
        tokens: tokens,
        children: [
          const SizedBox(height: 8),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  'assets/logo.png',
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fokus',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary,
                    ),
                  ),
                  Text(
                    'Version 0.1.0',
                    style: TextStyle(fontSize: 12, color: tokens.textMuted),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'A privacy-first, offline desktop fokus operating system. '
            'Built with Flutter for Windows.',
            style: TextStyle(
              fontSize: 12,
              color: tokens.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '© 2026 Fokus. All data stored locally.',
            style: TextStyle(fontSize: 11, color: tokens.textMuted),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Settings Section — PremiumCard with header
// ──────────────────────────────────────────────

class _SettingsSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final ThemeTokens tokens;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.icon,
    required this.tokens,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PremiumSectionHeader(
            icon: icon,
            title: title,
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Premium Text Field — animated focus border
// ──────────────────────────────────────────────

class _PremiumTextField extends StatefulWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final ThemeTokens tokens;
  const _PremiumTextField({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.tokens,
  });

  @override
  State<_PremiumTextField> createState() => _PremiumTextFieldState();
}

class _PremiumTextFieldState extends State<_PremiumTextField> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (mounted) setState(() => _focused = _focusNode.hasFocus);
    });
  }

  @override
  void didUpdateWidget(covariant _PremiumTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !_focused) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AnimatedContainer(
        duration: motion.PremiumDurations.panelFade,
        curve: motion.PremiumCurves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: widget.tokens.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _focused
                ? widget.tokens.accent.safeWithOpacity(0.5)
                : widget.tokens.borderSubtle,
          ),
          boxShadow: _focused
              ? [
                  BoxShadow(
                    color: widget.tokens.accent.safeWithOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 80,
              child: Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12,
                  color: _focused
                      ? widget.tokens.textPrimary
                      : widget.tokens.textSecondary,
                ),
              ),
            ),
            Expanded(
              child: TextField(
                controller: _controller,
                readOnly: false,
                enabled: true,
                style: TextStyle(
                  color: widget.tokens.textPrimary,
                  fontSize: 13,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
                onChanged: widget.onChanged,
                onSubmitted: widget.onChanged,
                onTap: () => setState(() => _focused = true),
                focusNode: _focusNode,
              ),
            ),
            if (_focused)
              motion.PremiumHoverEffect(
                hoverScale: 1.1,
                pressScale: 0.92,
                onTap: () => _controller.clear(),
                child: Icon(Icons.close, size: 14, color: widget.tokens.textMuted),
              ),
          ],
        ),
      ),
    );
  }


}

// ──────────────────────────────────────────────
// Premium Toggle Row — with PremiumToggle
// ──────────────────────────────────────────────

class _PremiumToggleRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final ThemeTokens tokens;

  const _PremiumToggleRow({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return motion.HoverBuilder(
      onTap: () => onChanged(!value),
      builder: (context, hovered, pressed) {
        return AnimatedContainer(
          duration: motion.PremiumDurations.hover,
          curve: motion.PremiumCurves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: hovered
                ? tokens.textPrimary.safeWithOpacity(0.04)
                : tokens.background,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 11, color: tokens.textMuted),
                    ),
                  ],
                ),
              ),
              motion.PremiumToggle(value: value, onChanged: onChanged),
            ],
          ),
        );
      },
    );
  }
}
