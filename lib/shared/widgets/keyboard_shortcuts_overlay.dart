import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../theme.dart';
import '../shortcuts.dart';

class KeyboardShortcutsOverlay extends StatefulWidget {
  final VoidCallback onClose;
  const KeyboardShortcutsOverlay({super.key, required this.onClose});

  @override
  State<KeyboardShortcutsOverlay> createState() =>
      _KeyboardShortcutsOverlayState();
}

class _KeyboardShortcutsOverlayState
    extends State<KeyboardShortcutsOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOut),
    );
    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  void _close() {
    _slideController.reverse().then((_) => widget.onClose());
  }

  @override
  Widget build(BuildContext context) {
    final tokens = FocusOsTheme.of(context);
    final mod = FocusOsShortcut.modifierLabel;

    return Stack(
      children: [
        // ── Scrim backdrop (dismiss on tap) ──
        FadeTransition(
          opacity: _fadeAnimation,
          child: GestureDetector(
            onTap: _close,
            child: Container(
              color: tokens.surface == const Color(0xFF0D0D11) ||
                      tokens.surface.computeLuminance() < 0.3
                  ? Colors.black.withValues(alpha: 0.35)
                  : Colors.black.withValues(alpha: 0.15),
            ),
          ),
        ),

        // ── Sliding panel from right ──
        SlideTransition(
          position: _slideAnimation,
          child: Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: MediaQuery.of(context).size.width < 380
                  ? MediaQuery.of(context).size.width
                  : 380,
              height: double.infinity,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: Container(
                    decoration: BoxDecoration(
                      color: tokens.surface,
                      border: Border(
                        left: BorderSide(
                            color: tokens.borderSubtle, width: 1),
                      ),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Header ──
                          Row(
                            children: [
                              Icon(Icons.keyboard_outlined,
                                  size: 20, color: tokens.textPrimary),
                              const SizedBox(width: 10),
                              Text(
                                'Keyboard Shortcuts',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: tokens.textPrimary,
                                ),
                              ),
                              const Spacer(),
                              GestureDetector(
                                onTap: _close,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: tokens.borderMedium,
                                  ),
                                  child: Icon(Icons.close,
                                      size: 16,
                                      color: tokens.textSecondary),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Master keyboard shortcuts for Fokus.',
                            style: TextStyle(
                              fontSize: 12,
                              color: tokens.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // ── Timer Controls Section ──
                          _ShortcutSectionHeader(
                            icon: Icons.timer_outlined,
                            title: 'Timer & Fokus',
                            tokens: tokens,
                          ),
                          const SizedBox(height: 10),
                          _ShortcutRow(
                            keys: [mod, 'Space'],
                            desc: 'Start / Pause focus session',
                            tokens: tokens,
                          ),
                          _ShortcutRow(
                            keys: [mod, 'R'],
                            desc: 'Reset timer',
                            tokens: tokens,
                          ),
                          _ShortcutRow(
                            keys: [mod, 'D'],
                            desc: 'Toggle Do Not Disturb',
                            tokens: tokens,
                          ),
                          _ShortcutRow(
                            keys: [mod, '⇧', 'F'],
                            desc: 'Toggle fullscreen layout',
                            tokens: tokens,
                          ),
                          const SizedBox(height: 24),

                          // ── Quick Tools Section ──
                          _ShortcutSectionHeader(
                            icon: Icons.bolt_outlined,
                            title: 'Quick Tools',
                            tokens: tokens,
                          ),
                          const SizedBox(height: 10),
                          _ShortcutRow(
                            keys: [mod, 'Q'],
                            desc: 'Open Quick Capture modal',
                            tokens: tokens,
                          ),
                          _ShortcutRow(
                            keys: [mod, '⇧', 'C'],
                            desc: 'Toggle Calculator overlay',
                            tokens: tokens,
                          ),
                          _ShortcutRow(
                            keys: [mod, 'B'],
                            desc: 'Toggle Brain Dump overlay',
                            tokens: tokens,
                          ),
                          _ShortcutRow(
                            keys: [mod, ','],
                            desc: 'Open Settings modal',
                            tokens: tokens,
                          ),
                          _ShortcutRow(
                            keys: [mod, '\\'],
                            desc: 'Toggle sidebar collapse',
                            tokens: tokens,
                          ),
                          _ShortcutRow(
                            keys: const ['Esc'],
                            desc: 'Dismiss active overlays or modals',
                            tokens: tokens,
                          ),
                          const SizedBox(height: 24),

                          // ── Timer Customization ──
                          _ShortcutSectionHeader(
                            icon: Icons.timer_outlined,
                            title: 'Timer',
                            tokens: tokens,
                          ),
                          const SizedBox(height: 10),
                          _ShortcutRow(
                            keys: [mod, 'T'],
                            desc: 'Cycle timer style',
                            tokens: tokens,
                          ),
                          _ShortcutRow(
                            keys: [mod, 'M'],
                            desc: 'Toggle mini floating timer',
                            tokens: tokens,
                          ),
                          const SizedBox(height: 24),

                          // ── Navigation Section ──
                          _ShortcutSectionHeader(
                            icon: Icons.navigation_outlined,
                            title: 'Navigation',
                            tokens: tokens,
                          ),
                          const SizedBox(height: 10),
                          _ShortcutRow(
                            keys: [mod, '1'],
                            desc: 'Fokus page',
                            tokens: tokens,
                          ),
                          _ShortcutRow(
                            keys: [mod, '2'],
                            desc: 'Tasks page',
                            tokens: tokens,
                          ),
                          _ShortcutRow(
                            keys: [mod, '3'],
                            desc: 'Analytics page',
                            tokens: tokens,
                          ),
                          _ShortcutRow(
                            keys: [mod, '4'],
                            desc: 'Health page',
                            tokens: tokens,
                          ),
                          _ShortcutRow(
                            keys: [mod, '6'],
                            desc: 'Tools page',
                            tokens: tokens,
                          ),
                          const SizedBox(height: 24),

                          // ── Global Help Section ──
                          _ShortcutSectionHeader(
                            icon: Icons.public,
                            title: 'Help',
                            tokens: tokens,
                          ),
                          const SizedBox(height: 10),
                          _ShortcutRow(
                            keys: [mod, '/'],
                            desc: 'Toggle this cheat sheet',
                            tokens: tokens,
                          ),
                          const SizedBox(height: 28),

                          // ── Settings note ──
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: tokens.borderMedium.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: tokens.borderSubtle, width: 1),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.settings_outlined,
                                    size: 14,
                                    color: tokens.textMuted),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Shortcuts can be disabled in Settings \u2192 Global Shortcuts section.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: tokens.textMuted,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ShortcutSectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final ThemeTokens tokens;

  const _ShortcutSectionHeader({
    required this.icon,
    required this.title,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: tokens.accent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 14, color: tokens.accent),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: tokens.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  final List<String> keys;
  final String desc;
  final ThemeTokens tokens;

  const _ShortcutRow({
    required this.keys,
    required this.desc,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          // ── Key badges ──
          ...keyBadges(),
          const SizedBox(width: 12),
          // ── Description ──
          Expanded(
            child: Text(
              desc,
              style: TextStyle(
                fontSize: 12,
                color: tokens.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> keyBadges() {
    return List.generate(keys.length, (i) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (i > 0) ...[
            const SizedBox(width: 3),
            Text(
              '+',
              style: TextStyle(
                fontSize: 10,
                color: tokens.textMuted,
              ),
            ),
            const SizedBox(width: 3),
          ],
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: tokens.borderMedium.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: tokens.borderSubtle,
                width: 1,
              ),
            ),
            child: Text(
              keys[i],
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: tokens.textPrimary,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      );
    });
  }
}
