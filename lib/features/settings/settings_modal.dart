import 'dart:convert';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart' as wm;
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/providers.dart';
import '../../core/navigation.dart';
import '../../services/ambient_sound_service.dart';
import '../../shared/motion.dart';
import '../../shared/theme.dart';
import '../../shared/widgets/premium_dropdown.dart';
import '../../shared/widgets/premium_slider.dart';
import '../fokus_timer/widgets/fokus_timer_display.dart';
import '../../services/fokus_history_service.dart';
import '../../services/timer_sound_service.dart';


/// A floating centered modal settings window with premium desktop feel.
/// Inspired by macOS, Raycast, Linear, Arc Browser settings panels.
class SettingsModal extends ConsumerStatefulWidget {
  final VoidCallback onClose;

  const SettingsModal({super.key, required this.onClose});

  @override
  ConsumerState<SettingsModal> createState() => _SettingsModalState();
}

class _SettingsModalState extends ConsumerState<SettingsModal>
    with SingleTickerProviderStateMixin {
  late AnimationController _enterController;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  bool _closing = false;

  @override
  void initState() {
    super.initState();

    // Modal entrance animation
    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnim = CurvedAnimation(
      parent: _enterController,
      curve: PremiumCurves.easeOutCubic,
    );
    _scaleAnim = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _enterController, curve: PremiumCurves.springyOut),
    );
    _enterController.forward();
  }

  @override
  void dispose() {
    _enterController.dispose();
    super.dispose();
  }

  void _switchSection(SettingsSection section) {
    ref.read(activeSettingsSectionProvider.notifier).state = section;
  }

  Future<void> _close() async {
    if (_closing) return;
    _closing = true;
    await _enterController.reverse();
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = FocusOsTheme.of(context);
    final activeSection = ref.watch(activeSettingsSectionProvider);

    return FadeTransition(
      opacity: _fadeAnim,
      child: GestureDetector(
        onTap: _close,
        child: Container(
          color: Colors.black.safeWithOpacity(0.55),
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: GestureDetector(
                onTap: () {}, // Prevent close when tapping inside
                child: ScaleTransition(
                  scale: _scaleAnim,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Container(
                      constraints: const BoxConstraints(
                        maxWidth: 1100,
                        maxHeight: 760,
                      ),
                      width: double.infinity,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        color: tokens.surfaceAlt,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: tokens.borderMedium.safeWithOpacity(0.4),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.safeWithOpacity(0.4),
                            blurRadius: 60,
                            offset: const Offset(0, 20),
                          ),
                          BoxShadow(
                            color: Colors.black.safeWithOpacity(0.2),
                            blurRadius: 120,
                            offset: const Offset(0, 40),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                          child: Row(
                            children: [
                              // ── Left Sidebar Navigation ──
                              _SettingsSidebar(
                                activeSection: activeSection,
                                onSectionChanged: _switchSection,
                              ),
                              // ── Right Content Area ──
                              Expanded(
                                child: Column(
                                  children: [
                                    // ── Title bar ──
                                    _SettingsTitleBar(
                                      section: activeSection,
                                      onClose: _close,
                                    ),
                                    // ── Animated Section Content ──
                                    Expanded(
                                      child: ClipRect(
                                        child: AnimatedSwitcher(
                                          duration: const Duration(milliseconds: 240),
                                          switchInCurve: PremiumCurves.easeOutCubic,
                                          switchOutCurve: PremiumCurves.easeInCubic,
                                          transitionBuilder: (child, animation) {
                                            final isIncoming = child.key == ValueKey(activeSection);
                                            if (isIncoming) {
                                              return SlideTransition(
                                                position: Tween<Offset>(
                                                  begin: const Offset(0.015, 0),
                                                  end: Offset.zero,
                                                ).animate(CurvedAnimation(
                                                  parent: animation,
                                                  curve: PremiumCurves.easeOutCubic,
                                                )),
                                                child: FadeTransition(
                                                  opacity: animation,
                                                  child: child,
                                                ),
                                              );
                                            } else {
                                              return FadeTransition(
                                                opacity: animation,
                                                child: child,
                                              );
                                            }
                                          },
                                          child: KeyedSubtree(
                                            key: ValueKey(activeSection),
                                            child: _buildSection(activeSection),
                                          ),
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
          ),
        ),
      ),
    );
  }

  Widget _buildSection(SettingsSection section) {
    switch (section) {
      case SettingsSection.account:
        return const _AccountSection();
      case SettingsSection.general:
        return const _GeneralSection();
      case SettingsSection.fokusTimer:
        return const _FocusTimerSection();
      case SettingsSection.tasks:
        return const _TasksSection();
      case SettingsSection.ambientSounds:
        return const _AmbientSoundsSection();
      case SettingsSection.fokusScenes:
        return const _FocusScenesSection();
      case SettingsSection.analytics:
        return const _AnalyticsSection();
      case SettingsSection.health:
        return const _HealthSection();
      case SettingsSection.appearance:
        return const _AppearanceSection();
      case SettingsSection.keyboardShortcuts:
        return const _KeyboardShortcutsSection();
      case SettingsSection.about:
        return const _AboutSection();
    }
  }
}

// ═══════════════════════════════════════════════════
// SIDEBAR NAVIGATION
// ═══════════════════════════════════════════════════

class _SettingsSidebar extends ConsumerWidget {
  final SettingsSection activeSection;
  final ValueChanged<SettingsSection> onSectionChanged;

  const _SettingsSidebar({
    required this.activeSection,
    required this.onSectionChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = FocusOsTheme.of(context);

    return Container(
      width: 210,
      decoration: BoxDecoration(
        color: tokens.background.safeWithOpacity(0.4),
        border: Border(
          right: BorderSide(color: tokens.borderSubtle),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 20),
          // ── Header ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    gradient: tokens.accentGradient,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: const Icon(Icons.tune_rounded, size: 13, color: Colors.white),
                ),
                const SizedBox(width: 8),
                Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Divider(color: tokens.borderSubtle, height: 1),
          const SizedBox(height: 8),
          // ── Navigation Items ──
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              physics: const ClampingScrollPhysics(),
              children: SettingsSection.values.map((section) {
                final isActive = section == activeSection;
                final index = SettingsSection.values.indexOf(section);
                return Padding(
                  padding: EdgeInsets.only(
                    top: index == 0 ? 0 : 1,
                    bottom: 1,
                  ),
                  child: _SettingsNavItem(
                    icon: section.icon,
                    label: section.label,
                    isActive: isActive,
                    onTap: () => onSectionChanged(section),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _SettingsNavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _SettingsNavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_SettingsNavItem> createState() => _SettingsNavItemState();
}

class _SettingsNavItemState extends State<_SettingsNavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = FocusOsTheme.of(context);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: PremiumDurations.hover,
          curve: PremiumCurves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isActive
                ? tokens.accent.safeWithOpacity(0.10)
                : _hovered
                    ? tokens.textPrimary.safeWithOpacity(0.04)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            border: widget.isActive
                ? Border.all(color: tokens.accent.safeWithOpacity(0.15))
                : _hovered
                    ? Border.all(color: tokens.borderSubtle)
                    : null,
          ),
          child: Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    widget.icon,
                    size: 16,
                    color: widget.isActive
                        ? tokens.accent
                        : tokens.textSecondary,
                  ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: widget.isActive ? FontWeight.w600 : FontWeight.w400,
                    color: widget.isActive
                        ? tokens.accent
                        : tokens.textSecondary,
                  ),
                ),
              ),
              if (widget.isActive)
                AnimatedContainer(
                  duration: PremiumDurations.panelSlide,
                  width: 3,
                  height: 3,
                  decoration: BoxDecoration(
                    color: tokens.accent,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// TITLE BAR
// ═══════════════════════════════════════════════════

class _SettingsTitleBar extends StatelessWidget {
  final SettingsSection section;
  final VoidCallback onClose;

  const _SettingsTitleBar({
    required this.section,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = FocusOsTheme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: tokens.borderSubtle),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: tokens.accent.safeWithOpacity(0.12),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(section.icon, size: 14, color: tokens.accent),
          ),
          const SizedBox(width: 10),
          Text(
            section.label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
          const Spacer(),
          // ── Close button ──
          GestureDetector(
            onTap: onClose,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: tokens.borderMedium.safeWithOpacity(0.3),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(Icons.close, size: 14, color: tokens.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// SECTION CONTENT LAYOUT HELPERS
// ═══════════════════════════════════════════════════

/// A grouped content panel wrapping settings controls.
class _SettingsGroup extends StatelessWidget {
  final String title;
  final String? description;
  final List<Widget> children;
  final ThemeTokens tokens;
  final IconData? icon;

  const _SettingsGroup({
    required this.title,
    this.description,
    required this.children,
    required this.tokens,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: tokens.accent),
                const SizedBox(width: 8),
              ],
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                ),
              ),
            ],
          ),
          if (description != null) ...[
            const SizedBox(height: 4),
            Text(
              description!,
              style: TextStyle(fontSize: 12, color: tokens.textMuted),
            ),
          ],
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

/// A premium toggle row with label, subtitle, and animated toggle.
class _ToggleRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final ThemeTokens tokens;

  const _ToggleRow({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
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
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11, color: tokens.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          PremiumToggle(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// A premium text field for settings input.
class _SettingsTextField extends StatefulWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final ThemeTokens tokens;
  final String? suffix;
  final bool readOnly;

  const _SettingsTextField({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.tokens,
    this.suffix,
    // ignore: unused_element_parameter
    this.readOnly = false,
  });

  @override
  State<_SettingsTextField> createState() => _SettingsTextFieldState();
}

class _SettingsTextFieldState extends State<_SettingsTextField> {
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
  void didUpdateWidget(covariant _SettingsTextField oldWidget) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.label,
            style: TextStyle(fontSize: 11, color: widget.tokens.textMuted),
          ),
          const SizedBox(height: 4),
          AnimatedContainer(
            duration: PremiumDurations.microFeedbackLong,
            curve: PremiumCurves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: widget.readOnly
                  ? widget.tokens.background.safeWithOpacity(0.5)
                  : widget.tokens.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: widget.readOnly
                    ? widget.tokens.borderSubtle
                    : _focused
                        ? widget.tokens.accent.safeWithOpacity(0.5)
                        : widget.tokens.borderSubtle,
              ),
              boxShadow: _focused && !widget.readOnly
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
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: widget.readOnly ? null : _focusNode,
                    obscureText: false,
                    readOnly: widget.readOnly,
                    enabled: !widget.readOnly,
                    style: TextStyle(
                      color: widget.readOnly
                          ? widget.tokens.textMuted
                          : widget.tokens.textPrimary,
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onChanged: widget.onChanged,
                  ),
                ),
                if (widget.suffix != null)
                  Text(
                    widget.suffix!,
                    style: TextStyle(fontSize: 11, color: widget.tokens.textMuted),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// SECTION 1: ACCOUNT
// ═══════════════════════════════════════════════════

class _AccountSection extends ConsumerWidget {
  const _AccountSection();

  Future<void> _pickAvatar(WidgetRef ref) async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result != null && result.files.single.bytes != null) {
      final base64 = base64Encode(result.files.single.bytes!);
      ref.read(userProfileProvider.notifier).updateAvatar(base64);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = FocusOsTheme.of(context);
    final profile = ref.watch(userProfileProvider);
    final streak = FokusHistoryService.getDailyStreak();
    final totalSessions = FokusHistoryService.getDailyCounts(days: 28)
        .fold(0, (a, b) => a + b);
    final lifetime = profile.lifetimeFocusTasks;

    return _ScrollContent(
      children: [
        _SettingsGroup(
          title: 'Profile',
          description: 'Your personal information and avatar',
          icon: Icons.person_outline,
          tokens: tokens,
          children: [
            Row(
              children: [
                // Interactive Avatar
                GestureDetector(
                  onTap: () => _pickAvatar(ref),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Stack(
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: tokens.accent.safeWithOpacity(0.5),
                              width: 2,
                            ),
                          ),
                          child: profile.avatarBase64.isNotEmpty
                              ? ClipOval(
                                  child: Image.memory(
                                    base64Decode(profile.avatarBase64),
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Center(
                                  child: Text(
                                    profile.name.isNotEmpty
                                        ? profile.name.substring(0, 1).toUpperCase()
                                        : 'U',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w600,
                                      color: tokens.accent,
                                    ),
                                  ),
                                ),
                        ),
                        // Edit camera badge overlay
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: tokens.accent,
                              border: Border.all(
                                color: tokens.surfaceAlt,
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              size: 11,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: tokens.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      if (profile.status.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          profile.status,
                          style: TextStyle(
                            fontSize: 11,
                            color: tokens.textMuted,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SettingsTextField(
              label: 'Display Name',
              value: profile.name,
              tokens: tokens,
              onChanged: (v) => ref.read(userProfileProvider.notifier).updateName(v),
            ),

            _SettingsTextField(
              label: 'About You',
              value: profile.status,
              tokens: tokens,
              onChanged: (v) => ref.read(userProfileProvider.notifier).updateStatus(v),
            ),
          ],
        ),
        _SettingsGroup(
          title: 'Statistics',
          icon: Icons.bar_chart_outlined,
          tokens: tokens,
          children: [
            Row(
              children: [
                _StatCard(
                  icon: Icons.local_fire_department,
                  label: 'Current Streak',
                  value: '$streak days',
                  color: Colors.orange,
                  tokens: tokens,
                ),
                const SizedBox(width: 12),
                _StatCard(
                  icon: Icons.check_circle_outline,
                  label: '28-Day Sessions',
                  value: '$totalSessions',
                  color: tokens.accent,
                  tokens: tokens,
                ),
                const SizedBox(width: 12),
                _StatCard(
                  icon: Icons.emoji_events_outlined,
                  label: 'Lifetime Tasks',
                  value: '$lifetime',
                  color: const Color(0xFFF59E0B),
                  tokens: tokens,
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final ThemeTokens tokens;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: tokens.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: tokens.borderSubtle),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.safeWithOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: tokens.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: tokens.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// SECTION 2: GENERAL
// ═══════════════════════════════════════════════════

class _GeneralSection extends ConsumerWidget {
  const _GeneralSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = FocusOsTheme.of(context);
    final shortcutsEnabled = ref.watch(keyboardShortcutsProvider);
    final fullscreen = ref.watch(fullscreenProvider);
    final sidebarExpanded = ref.watch(sidebarExpandedProvider);
    final runInBackground = ref.watch(runInBackgroundProvider);

    return _ScrollContent(
      children: [
        _SettingsGroup(
          title: 'Behavior',
          icon: Icons.tune_rounded,
          tokens: tokens,
          children: [
            _ToggleRow(
              label: 'Keyboard Shortcuts',
              subtitle: 'Enable global keyboard shortcuts',
              value: shortcutsEnabled,
              tokens: tokens,
              onChanged: (v) => ref.read(keyboardShortcutsProvider.notifier).setEnabled(v),
            ),
            const SizedBox(height: 4),
            _ToggleRow(
              label: 'Fullscreen by Default',
              subtitle: 'Start application in fullscreen mode',
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
            const SizedBox(height: 4),
            _ToggleRow(
              label: 'Sidebar Labels',
              subtitle: 'Show text labels in the navigation sidebar',
              value: sidebarExpanded,
              tokens: tokens,
              onChanged: (v) => ref.read(sidebarExpandedProvider.notifier).state = v,
            ),
            if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) ...[
              const SizedBox(height: 4),
              _ToggleRow(
                label: 'Run in Background',
                subtitle: 'Minimize to taskbar when closing the application, instead of quitting',
                value: runInBackground,
                tokens: tokens,
                onChanged: (v) => ref.read(runInBackgroundProvider.notifier).setRunInBackground(v),
              ),
            ],
          ],
        ),
        if (!kIsWeb && (Platform.isAndroid || Platform.isIOS))
          _SettingsGroup(
            title: 'Background Permissions',
            icon: Icons.security_rounded,
            tokens: tokens,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Grant these permissions to ensure notifications and reminders trigger reliably when the app is in the background or closed.',
                  style: TextStyle(fontSize: 12, color: tokens.textSecondary, height: 1.4),
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: tokens.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.notifications_active_rounded, size: 16),
                    label: const Text('Allow Notifications', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    onPressed: () async {
                      final status = await Permission.notification.request();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(status.isGranted ? 'Notification Permission Granted' : 'Notification Permission Denied'),
                            backgroundColor: tokens.surfaceAlt,
                          ),
                        );
                      }
                    },
                  ),
                  if (Platform.isAndroid) ...[
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tokens.surface,
                        foregroundColor: tokens.textPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: tokens.borderSubtle),
                        ),
                      ),
                      icon: const Icon(Icons.battery_saver_rounded, size: 16),
                      label: const Text('Ignore Battery Limits', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      onPressed: () async {
                        final status = await Permission.ignoreBatteryOptimizations.request();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(status.isGranted ? 'Battery Optimization Disabled' : 'Battery Optimization Settings Opened'),
                              backgroundColor: tokens.surfaceAlt,
                            ),
                          );
                        }
                      },
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tokens.surface,
                        foregroundColor: tokens.textPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: tokens.borderSubtle),
                        ),
                      ),
                      icon: const Icon(Icons.alarm_rounded, size: 16),
                      label: const Text('Allow Exact Alarms', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      onPressed: () async {
                        final status = await Permission.scheduleExactAlarm.request();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(status.isGranted ? 'Exact Alarm Permission Granted' : 'Exact Alarm Settings Opened'),
                              backgroundColor: tokens.surfaceAlt,
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ],
              ),
            ],
          ),
        _SettingsGroup(
          title: 'Startup',
          icon: Icons.power_settings_new,
          tokens: tokens,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Startup behavior is managed by your operating system. '
                'Pin Fokus to your taskbar or add it to startup apps manually.',
                style: TextStyle(fontSize: 12, color: tokens.textSecondary, height: 1.4),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════
// PRESET SAVER WIDGET
// ═══════════════════════════════════════════════════

class _PresetSaver extends ConsumerStatefulWidget {
  final TimerCustomizationState currentSettings;
  final ThemeTokens tokens;

  const _PresetSaver({
    required this.currentSettings,
    required this.tokens,
  });

  @override
  ConsumerState<_PresetSaver> createState() => _PresetSaverState();
}

class _PresetSaverState extends ConsumerState<_PresetSaver> {
  final _controller = TextEditingController();
  bool _isExpanded = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final name = _controller.text.trim();
    if (name.isNotEmpty) {
      ref.read(timerPresetsProvider.notifier).savePreset(name, widget.currentSettings);
      _controller.clear();
      setState(() => _isExpanded = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: widget.tokens.accent.withValues(alpha: 0.1),
              border: Border.all(color: widget.tokens.accent.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isExpanded ? Icons.close_rounded : Icons.add_rounded,
                  size: 16,
                  color: widget.tokens.accent,
                ),
                const SizedBox(width: 6),
                Text(
                  _isExpanded ? 'Cancel' : 'Save Current as Preset',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: widget.tokens.accent,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_isExpanded) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  style: TextStyle(color: widget.tokens.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Preset name (e.g., "Deep Work")',
                    hintStyle: TextStyle(color: widget.tokens.textMuted, fontSize: 13),
                    filled: true,
                    fillColor: widget.tokens.background.withValues(alpha: 0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: widget.tokens.borderSubtle),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: widget.tokens.borderSubtle),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: widget.tokens.accent),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _save(),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _save,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: widget.tokens.accent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Save',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: widget.tokens.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════
// SECTION 3: FOCUS TIMER
// ═══════════════════════════════════════════════════

class _FocusTimerSection extends ConsumerWidget {
  const _FocusTimerSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = FocusOsTheme.of(context);
    final customization = ref.watch(timerCustomizationProvider);
    final presets = ref.watch(timerPresetsProvider);
    final isMini = ref.watch(miniModeProvider);
    final isFullscreen = ref.watch(fullscreenProvider);

    // Font family definition
    final fonts = [
      ('Minimal', 'minimal', GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500)),
      ('Bold Digital', 'bold_digital', GoogleFonts.quantico(fontWeight: FontWeight.bold)),
      ('Futuristic', 'futuristic', GoogleFonts.orbitron(fontWeight: FontWeight.w800)),
      ('Elegant', 'elegant', GoogleFonts.playfairDisplay(fontWeight: FontWeight.w600)),
      ('Mechanical', 'mechanical', GoogleFonts.shareTechMono(fontWeight: FontWeight.bold)),
    ];

    // Background Mode definitions
    final backgrounds = [
      ('Transparent', 'transparent', Icons.filter_hdr_outlined),
      ('Glassmorphism', 'glassmorphism', Icons.blur_on_rounded),
      ('Solid Dark', 'solid_dark', Icons.dark_mode_outlined),
      ('Gradient', 'gradient', Icons.gradient_rounded),
      ('Adaptive', 'adaptive', Icons.wallpaper_rounded),
    ];

    // Color Theme definitions
    final colorThemes = [
      ('Custom Color', 'auto', null),
      ('White', 'white', Colors.white),
      ('Blue Accent', 'blue', const Color(0xFF3B82F6)),
      ('Emerald Green', 'green', const Color(0xFF10B981)),
      ('Crimson Red', 'red', const Color(0xFFEF4444)),
      ('Amber Orange', 'amber', const Color(0xFFF59E0B)),
    ];

    final sizeIndex = switch (customization.size) {
      'small' => 0.0,
      'medium' => 1.0,
      'large' => 2.0,
      'xl' => 3.0,
      _ => 2.0,
    };

    final soundState = ref.watch(timerSoundProvider);
    final builtInAlarms = [
      {'name': 'Digital Alarm', 'path': 'assets/alarm_sounds/digital alarm.mp3'},
      {'name': 'Irritating Alarm', 'path': 'assets/alarm_sounds/irritating_alarm.mp3'},
      {'name': 'Soft Chime', 'path': 'assets/alarm_sounds/soft_chime.mp3'},
    ];
    final dropdownItems = [
      ...builtInAlarms.map((a) => DropdownMenuItem<String>(
            value: a['path']!,
            child: Text(a['name']!),
          )),
      ...soundState.customAlarms.map((a) => DropdownMenuItem<String>(
            value: a.id,
            child: Text(a.name),
          )),
    ];
    final selectedValueExists = dropdownItems.any((item) => item.value == soundState.selectedAlarmSound);
    final activeSelectedValue = selectedValueExists ? soundState.selectedAlarmSound : 'assets/alarm_sounds/digital alarm.mp3';

    Widget _buildCompactButton({
      required String label,
      required IconData icon,
      required ThemeTokens tokens,
      required VoidCallback onTap,
      bool isDanger = false,
    }) {
      return PremiumHoverEffect(
        hoverScale: 1.05,
        pressScale: 0.95,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDanger
                ? Colors.redAccent.withValues(alpha: 0.15)
                : tokens.accent.withValues(alpha: 0.1),
            border: Border.all(
              color: isDanger
                  ? Colors.redAccent.withValues(alpha: 0.3)
                  : tokens.accent.withValues(alpha: 0.3),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isDanger ? Colors.redAccent : tokens.accent,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDanger ? Colors.redAccent : tokens.accent,
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget _buildCustomAlarmItem(CustomAlarm alarm, ThemeTokens tokens, WidgetRef ref, bool isSelected) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? tokens.accent.withValues(alpha: 0.05)
              : tokens.background.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.audiotrack_rounded,
              size: 14,
              color: isSelected ? tokens.accent : tokens.textSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                alarm.name,
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected ? tokens.accent : tokens.textPrimary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            PremiumHoverEffect(
              hoverScale: 1.1,
              pressScale: 0.9,
              onTap: () {
                ref.read(timerSoundProvider.notifier).deleteCustomAlarm(alarm.id);
              },
              child: const Padding(
                padding: EdgeInsets.all(4.0),
                child: Icon(
                  Icons.delete_outline_rounded,
                  size: 16,
                  color: Colors.redAccent,
                ),
              ),
            ),
          ],
        ),
      );
    }

    Widget _buildUploadButton(ThemeTokens tokens, WidgetRef ref, BuildContext context) {
      return PremiumHoverEffect(
        hoverScale: 1.02,
        pressScale: 0.98,
        onTap: () async {
          try {
            final result = await FilePicker.pickFiles(
              type: FileType.custom,
              allowedExtensions: ['mp3', 'wav', 'ogg'],
              allowMultiple: false,
            );
            if (result != null && result.files.single.path != null) {
              final filePath = result.files.single.path!;
              final fileName = result.files.single.name;
              final name = fileName.split('.').first;
              await ref.read(timerSoundProvider.notifier).uploadCustomAlarm(name, filePath);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Uploaded custom alarm: $name'),
                  backgroundColor: tokens.accent,
                ),
              );
            }
          } catch (e) {
            final errorMsg = e.toString().replaceAll('Exception: ', '');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Upload failed: $errorMsg'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: tokens.background.withValues(alpha: 0.5),
            border: Border.all(color: tokens.borderSubtle),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.upload_file_rounded, size: 14, color: tokens.accent),
              const SizedBox(width: 6),
              Text(
                'Upload Custom Alarm (.mp3, .wav, .ogg)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _ScrollContent(
      children: [
        // ── LIVE PREVIEW PANEL ──
        _SettingsGroup(
          title: 'Live Preview',
          icon: Icons.remove_red_eye_outlined,
          tokens: tokens,
          description: 'A real-time preview of your timer configuration',
          children: [
            Container(
              height: 220,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF0F0F11),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: tokens.borderSubtle),
              ),
              child: const SizedBox(
                width: 200,
                height: 200,
                child: FocusTimerDisplay(
                  showCompletion: false,
                  onTap: null,
                  hideLabel: true,
                ),
              ),
            ),
          ],
        ),

        // ── QUICK FOCUS MODES ──
        _SettingsGroup(
          title: 'Quick Fokus Modes',
          icon: Icons.computer_rounded,
          tokens: tokens,
          description: 'One-click widgets and distraction-free layouts',
          children: [
            Row(
              children: [
                // Floating Mini Timer Toggle
                Expanded(
                  child: InkWell(
                    onTap: () {
                      ref.read(settingsModalOpenProvider.notifier).state = false; // Close settings modal
                      ref.read(miniModeProvider.notifier).toggle();
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      decoration: BoxDecoration(
                        color: tokens.background.withValues(alpha: 0.5),
                        border: Border.all(color: tokens.borderSubtle),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.picture_in_picture_alt_rounded, size: 16, color: tokens.accent),
                          const SizedBox(width: 8),
                          Text(
                            isMini ? 'Exit Floating Timer' : 'Mini Floating Timer',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: tokens.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Fullscreen Focus Toggle
                Expanded(
                  child: InkWell(
                    onTap: () {
                      ref.read(fullscreenProvider.notifier).setFullscreen(!isFullscreen);
                      if (!kIsWeb) {
                        try {
                          wm.WindowManager.instance.setFullScreen(!isFullscreen);
                        } catch (_) {}
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      decoration: BoxDecoration(
                        color: tokens.background.withValues(alpha: 0.5),
                        border: Border.all(color: tokens.borderSubtle),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(isFullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded, size: 16, color: tokens.accent),
                          const SizedBox(width: 8),
                          Text(
                            isFullscreen ? 'Exit Fullscreen' : 'Cinematic Fullscreen',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: tokens.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),

        // ── CLOCK LAYOUT & STYLES ──
        _SettingsGroup(
          title: 'Timer Font Styles',
          icon: Icons.font_download_outlined,
          tokens: tokens,
          description: 'Customize the typography family of the clock digits',
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: fonts.map((f) {
                final isSelected = customization.fontStyle == f.$2;
                return InkWell(
                  onTap: () {
                    ref.read(timerCustomizationProvider.notifier).update(
                      customization.copyWith(fontStyle: f.$2),
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? tokens.accent.withValues(alpha: 0.12)
                          : tokens.background.withValues(alpha: 0.5),
                      border: Border.all(
                        color: isSelected ? tokens.accent : tokens.borderSubtle,
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      f.$1,
                      style: f.$3.copyWith(
                        fontSize: 12,
                        color: isSelected ? tokens.accent : tokens.textPrimary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),

        _SettingsGroup(
          title: 'Timer Background Modes',
          icon: Icons.layers_outlined,
          tokens: tokens,
          description: 'Adjust the background opacity and blur of the clock face',
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: backgrounds.map((b) {
                final isSelected = customization.backgroundMode == b.$2;
                return InkWell(
                  onTap: () {
                    ref.read(timerCustomizationProvider.notifier).update(
                      customization.copyWith(backgroundMode: b.$2),
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? tokens.accent.withValues(alpha: 0.12)
                          : tokens.background.withValues(alpha: 0.5),
                      border: Border.all(
                        color: isSelected ? tokens.accent : tokens.borderSubtle,
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(b.$3, size: 14, color: isSelected ? tokens.accent : tokens.textSecondary),
                        const SizedBox(width: 6),
                        Text(
                          b.$1,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            color: isSelected ? tokens.accent : tokens.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),

        _SettingsGroup(
          title: 'Timer Color Themes',
          icon: Icons.color_lens_outlined,
          tokens: tokens,
          description: 'Choose a primary digit and glow accent color',
          children: [
            Row(
              children: colorThemes.map((c) {
                final isSelected = customization.colorTheme == c.$2;
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Tooltip(
                    message: c.$1,
                    child: InkWell(
                      onTap: () {
                        if (c.$2 == 'auto') {
                          _showCustomColorPicker(context, ref, tokens);
                        } else {
                          ref.read(timerCustomizationProvider.notifier).update(
                            customization.copyWith(colorTheme: c.$2),
                          );
                        }
                      },
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? tokens.accent : tokens.borderMedium,
                            width: isSelected ? 2.5 : 1.0,
                          ),
                        ),
                        padding: const EdgeInsets.all(2.0),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: c.$3,
                            gradient: c.$3 == null
                                ? const SweepGradient(
                                    colors: [
                                      Colors.red,
                                      Colors.amber,
                                      Colors.green,
                                      Colors.blue,
                                      Colors.indigo,
                                      Colors.red,
                                    ],
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),

        _SettingsGroup(
          title: 'Timer Dimensions',
          icon: Icons.aspect_ratio_rounded,
          tokens: tokens,
          children: [
            PremiumCompactSlider(
              label: 'Timer Max Size Limit',
              value: sizeIndex,
              min: 0,
              max: 3,
              divisions: 3,
              onChanged: (v) {
                final sizeStr = switch (v.round()) {
                  0 => 'small',
                  1 => 'medium',
                  2 => 'large',
                  3 => 'xl',
                  _ => 'large',
                };
                ref.read(timerCustomizationProvider.notifier).update(
                  customization.copyWith(size: sizeStr),
                );
              },
              displayValue: switch (sizeIndex.round()) {
                0 => 'Small (260px)',
                1 => 'Medium (340px)',
                2 => 'Large (440px)',
                3 => 'Extra Large (540px)',
                _ => 'Large (440px)',
              },
            ),
          ],
        ),

        // ── SHOW / HIDE ELEMENTS ──
        _SettingsGroup(
          title: 'Display Elements',
          icon: Icons.visibility_outlined,
          tokens: tokens,
          description: 'Toggle visibility of individual clock elements',
          children: [
            _ToggleRow(
              label: 'Show Seconds',
              subtitle: 'Display seconds in the active timer',
              value: customization.showSeconds,
              tokens: tokens,
              onChanged: (v) {
                ref.read(timerCustomizationProvider.notifier).update(
                  customization.copyWith(showSeconds: v),
                );
              },
            ),
            const SizedBox(height: 4),
            _ToggleRow(
              label: 'Show Milliseconds',
              subtitle: 'Display high-precision milliseconds',
              value: customization.showMilliseconds,
              tokens: tokens,
              onChanged: (v) {
                ref.read(timerCustomizationProvider.notifier).update(
                  customization.copyWith(showMilliseconds: v),
                );
              },
            ),
            const SizedBox(height: 4),
            _ToggleRow(
              label: 'Show Session Label',
              subtitle: 'Display active state label (FOKUSING, PAUSED)',
              value: customization.showSessionLabel,
              tokens: tokens,
              onChanged: (v) {
                ref.read(timerCustomizationProvider.notifier).update(
                  customization.copyWith(showSessionLabel: v),
                );
              },
            ),
            const SizedBox(height: 4),
            _ToggleRow(
              label: 'Show Task Title / Description',
              subtitle: 'Display current fokused task or session description',
              value: customization.showTaskName,
              tokens: tokens,
              onChanged: (v) {
                ref.read(timerCustomizationProvider.notifier).update(
                  customization.copyWith(showTaskName: v),
                );
              },
            ),
            const SizedBox(height: 4),
            _ToggleRow(
              label: 'Show Outer Progress Ring',
              subtitle: 'Display radial progress bar and glowing track',
              value: customization.showProgressRing,
              tokens: tokens,
              onChanged: (v) {
                ref.read(timerCustomizationProvider.notifier).update(
                  customization.copyWith(showProgressRing: v),
                );
              },
            ),
          ],
        ),

        // ── ANIMATION CONTROL ──
        _SettingsGroup(
          title: 'Animation Preferences',
          icon: Icons.animation_rounded,
          tokens: tokens,
          children: [
            _ToggleRow(
              label: 'Enable Breathing Glow',
              subtitle: 'Allow outermost ring to gently breathe',
              value: customization.enableAnimations,
              tokens: tokens,
              onChanged: (v) {
                ref.read(timerCustomizationProvider.notifier).update(
                  customization.copyWith(enableAnimations: v),
                );
              },
            ),
            const SizedBox(height: 4),
            _ToggleRow(
              label: 'Reduced Motion Mode',
              subtitle: 'Disable all non-essential movement and animations',
              value: customization.reducedMotion,
              tokens: tokens,
              onChanged: (v) {
                ref.read(timerCustomizationProvider.notifier).update(
                  customization.copyWith(reducedMotion: v),
                );
              },
            ),
            const SizedBox(height: 16),
            PremiumCompactSlider(
              label: 'Digit Flip Speed',
              value: customization.flipSpeed,
              min: 0.5,
              max: 2.0,
              onChanged: (v) {
                ref.read(timerCustomizationProvider.notifier).update(
                  customization.copyWith(flipSpeed: v),
                );
              },
              displayValue: '${customization.flipSpeed.toStringAsFixed(1)}x',
            ),
          ],
        ),

        // ── SOUND SETTINGS ──
        _SettingsGroup(
          title: 'Sound Settings',
          icon: Icons.volume_up_outlined,
          tokens: tokens,
          description: 'Customize clock ticking, volume, alarms, and custom sound uploads',
          children: [
            _ToggleRow(
              label: 'Mute Audio Feedback',
              subtitle: 'Silences all timer ticks, flips, and alarm alerts',
              value: customization.isMuted,
              tokens: tokens,
              onChanged: (v) {
                ref.read(timerCustomizationProvider.notifier).update(
                  customization.copyWith(isMuted: v),
                );
              },
            ),
            const SizedBox(height: 4),
            _ToggleRow(
              label: 'Enable ticking sound during countdown',
              subtitle: 'Play a clock ticking sound on every second interval',
              value: soundState.tickEnabled,
              tokens: tokens,
              onChanged: (v) {
                ref.read(timerSoundProvider.notifier).setTickEnabled(v);
              },
            ),
            const SizedBox(height: 4),
            _ToggleRow(
              label: 'Mechanical Digit Flip Sound',
              subtitle: 'Play mechanical click sound when digits update',
              value: customization.flipSoundEnabled,
              tokens: tokens,
              onChanged: (v) {
                ref.read(timerCustomizationProvider.notifier).update(
                  customization.copyWith(flipSoundEnabled: v),
                );
              },
            ),
            const SizedBox(height: 12),
            // Tick sound preview row
            Row(
              children: [
                Text(
                  'Tick Sound:',
                  style: TextStyle(
                    fontSize: 12,
                    color: tokens.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 12),
                _buildCompactButton(
                  label: 'Preview',
                  icon: Icons.play_arrow_rounded,
                  tokens: tokens,
                  onTap: () => ref.read(timerSoundProvider.notifier).previewTick(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Alarm Sound dropdown and preview row
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: PremiumDropdown<String>(
                    value: activeSelectedValue,
                    label: 'Alarm Sound',
                    width: 220,
                    icon: Icons.alarm_rounded,
                    items: dropdownItems,
                    onChanged: (v) {
                      if (v != null) {
                        ref.read(timerSoundProvider.notifier).setAlarmSound(v);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                _buildCompactButton(
                  label: 'Preview',
                  icon: Icons.play_arrow_rounded,
                  tokens: tokens,
                  onTap: () => ref.read(timerSoundProvider.notifier).previewAlarm(activeSelectedValue),
                ),
                if (soundState.isAlarmPlaying) ...[
                  const SizedBox(width: 8),
                  _buildCompactButton(
                    label: 'Stop',
                    icon: Icons.stop_rounded,
                    tokens: tokens,
                    onTap: () => ref.read(timerSoundProvider.notifier).stopAlarm(),
                    isDanger: true,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            _ToggleRow(
              label: 'Loop alarm until stopped',
              subtitle: 'Repeat alarm continuously when timer completes',
              value: soundState.loopAlarm,
              tokens: tokens,
              onChanged: (v) {
                ref.read(timerSoundProvider.notifier).setLoopEnabled(v);
              },
            ),
            const SizedBox(height: 16),
            // Custom alarm upload
            Text(
              'Custom Alarms',
              style: TextStyle(
                fontSize: 12,
                color: tokens.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            _buildUploadButton(tokens, ref, context),
            if (soundState.customAlarms.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: tokens.background.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: tokens.borderSubtle),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: soundState.customAlarms.length,
                  separatorBuilder: (context, index) => Divider(color: tokens.borderSubtle, height: 1),
                  itemBuilder: (context, index) {
                    final alarm = soundState.customAlarms[index];
                    final isSelected = activeSelectedValue == alarm.id || activeSelectedValue == alarm.filePath;
                    return _buildCustomAlarmItem(alarm, tokens, ref, isSelected);
                  },
                ),
              ),
            ],
          ],
        ),

        // ── CUSTOM PRESETS MANAGER ──
        _SettingsGroup(
          title: 'Timer Style Presets',
          icon: Icons.bookmark_added_outlined,
          tokens: tokens,
          description: 'Save and load custom clock configuration combinations',
          children: [
            _PresetSaver(
              currentSettings: customization,
              tokens: tokens,
            ),
            const SizedBox(height: 16),
            if (presets.isEmpty)
              Text(
                'No custom presets saved yet.',
                style: TextStyle(fontSize: 12, color: tokens.textMuted, fontStyle: FontStyle.italic),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: presets.keys.map((name) {
                  final presetSettings = presets[name]!;
                  final isCurrent = customization.activePresetName == name;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? tokens.accent.withValues(alpha: 0.1)
                          : tokens.background.withValues(alpha: 0.5),
                      border: Border.all(
                        color: isCurrent ? tokens.accent : tokens.borderSubtle,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () {
                            ref.read(timerCustomizationProvider.notifier).update(
                              presetSettings.copyWith(activePresetName: name),
                            );
                          },
                          child: Text(
                            name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                              color: isCurrent ? tokens.accent : tokens.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () {
                            ref.read(timerPresetsProvider.notifier).deletePreset(name);
                          },
                          child: Icon(
                            Icons.close_rounded,
                            size: 14,
                            color: Colors.redAccent.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),

        // ── ORIGINAL DURATIONS & BEHAVIORS ──
        _SettingsGroup(
          title: 'Durations',
          icon: Icons.timer_outlined,
          tokens: tokens,
          children: [
            _SettingsTextField(
              label: 'Fokus Duration',
              value: '25',
              suffix: 'min',
              tokens: tokens,
              onChanged: (_) {},
            ),
            _SettingsTextField(
              label: 'Short Break',
              value: '5',
              suffix: 'min',
              tokens: tokens,
              onChanged: (_) {},
            ),
            _SettingsTextField(
              label: 'Long Break',
              value: '15',
              suffix: 'min',
              tokens: tokens,
              onChanged: (_) {},
            ),
            _SettingsTextField(
              label: 'Cycles Before Long Break',
              value: '4',
              tokens: tokens,
              onChanged: (_) {},
            ),
          ],
        ),
        _SettingsGroup(
          title: 'Auto-Start',
          icon: Icons.play_circle_outline,
          tokens: tokens,
          children: [
            _ToggleRow(
              label: 'Auto-start Fokus',
              subtitle: 'Start timer automatically when a session begins',
              value: true,
              tokens: tokens,
              onChanged: (_) {},
            ),
            const SizedBox(height: 4),
            _ToggleRow(
              label: 'Auto-start Breaks',
              subtitle: 'Start break timer automatically after fokus',
              value: false,
              tokens: tokens,
              onChanged: (_) {},
            ),
          ],
        ),
        _SettingsGroup(
          title: 'Behavior',
          icon: Icons.tune_rounded,
          tokens: tokens,
          children: [
            _ToggleRow(
              label: 'Resume Interrupted Sessions',
              subtitle: 'Ask to resume when the app reopens',
              value: false,
              tokens: tokens,
              onChanged: (_) {},
            ),
            const SizedBox(height: 4),
            _ToggleRow(
              label: 'Completion Sound',
              subtitle: 'Play a sound when a session completes',
              value: true,
              tokens: tokens,
              onChanged: (_) {},
            ),
          ],
        ),
      ],
    );
  }

  void _showCustomColorPicker(BuildContext context, WidgetRef ref, ThemeTokens tokens) {
    final activeColor = ref.read(timerColorProvider) ?? tokens.accent;
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: tokens.surfaceAlt,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Choose Custom Timer Color',
            style: TextStyle(
              color: tokens.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Select a custom color for the fokus timer clock digits and progress ring:',
                style: TextStyle(color: tokens.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: 280,
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    const Color(0xFFEF4444), // Red
                    const Color(0xFFF97316), // Orange
                    const Color(0xFFFBBF24), // Yellow
                    const Color(0xFF10B981), // Emerald Green
                    const Color(0xFF34D399), // Mint Green
                    const Color(0xFF06B6D4), // Cyan
                    const Color(0xFF3B82F6), // Bright Blue
                    const Color(0xFF1D4ED8), // Royal Blue
                    const Color(0xFF6366F1), // Indigo
                    const Color(0xFF8B5CF6), // Violet
                    const Color(0xFFEC4899), // Pink
                    const Color(0xFFF43F5E), // Rose
                    Colors.white,
                    const Color(0xFF94A3B8), // Slate
                    tokens.accent, // Default Theme Accent
                  ].map((color) {
                    final isSelected = activeColor.toARGB32() == color.toARGB32();
                    return GestureDetector(
                      onTap: () {
                        ref.read(timerColorProvider.notifier).setColor(color);
                        ref.read(timerCustomizationProvider.notifier).update(
                          ref.read(timerCustomizationProvider).copyWith(colorTheme: 'auto'),
                        );
                        Navigator.of(context).pop();
                      },
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? (color == Colors.white ? Colors.black : Colors.white)
                                : tokens.borderSubtle,
                            width: isSelected ? 3.0 : 1.0,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.4),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: tokens.textSecondary),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════
// SECTION 4: TASKS / PROJECTS
// ═══════════════════════════════════════════════════

class _TasksSection extends ConsumerWidget {
  const _TasksSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = FocusOsTheme.of(context);

    return _ScrollContent(
      children: [
        _SettingsGroup(
          title: 'Default Behavior',
          icon: Icons.check_circle_outline,
          tokens: tokens,
          children: [
            _ToggleRow(
              label: 'Default Color on New Tasks',
              subtitle: 'Automatically assign a random color to new tasks',
              value: true,
              tokens: tokens,
              onChanged: (_) {},
            ),
            const SizedBox(height: 4),
            _ToggleRow(
              label: 'Archive Completed Tasks',
              subtitle: 'Move completed tasks to archive after 24 hours',
              value: true,
              tokens: tokens,
              onChanged: (_) {},
            ),
            const SizedBox(height: 4),
            _ToggleRow(
              label: 'Quick Add to Top',
              subtitle: 'New tasks appear at the top of the list',
              value: true,
              tokens: tokens,
              onChanged: (_) {},
            ),
          ],
        ),
        _SettingsGroup(
          title: 'Sorting',
          icon: Icons.sort_outlined,
          tokens: tokens,
          children: [
            PremiumDropdown<String>(
              label: 'Default Sort Order',
              value: 'newest',
              width: 200,
              items: const [
                DropdownMenuItem(value: 'newest', child: Text('Newest First')),
                DropdownMenuItem(value: 'oldest', child: Text('Oldest First')),
                DropdownMenuItem(value: 'color', child: Text('By Color')),
                DropdownMenuItem(value: 'alphabetical', child: Text('Alphabetical')),
              ],
              onChanged: (_) {},
            ),
          ],
        ),
        _SettingsGroup(
          title: 'Session Attribution',
          icon: Icons.timer_outlined,
          tokens: tokens,
          children: [
            _ToggleRow(
              label: 'Attribute Fokus to Task',
              subtitle: 'Link fokus sessions to the selected task',
              value: true,
              tokens: tokens,
              onChanged: (_) {},
            ),
            _ToggleRow(
              label: 'Track Interrupted Sessions',
              subtitle: 'Record interrupted fokus time per task',
              value: true,
              tokens: tokens,
              onChanged: (_) {},
            ),
          ],
        ),
        _SettingsGroup(
          title: 'Habit Tracker Settings',
          icon: Icons.table_chart_outlined,
          tokens: tokens,
          children: [
            PremiumSlider(
              value: ref.watch(habitEmojiSizeProvider),
              onChanged: (val) {
                ref.read(habitEmojiSizeProvider.notifier).setSize(val.roundToDouble());
              },
              label: 'Habit Icon / Emoji Size',
              subtitle: 'Size of emojis/icons displayed in the habits tracker table',
              min: 10,
              max: 28,
              divisions: 18,
              displayValue: '${ref.watch(habitEmojiSizeProvider).round()} px',
            ),
          ],
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════

// ═══════════════════════════════════════════════════
// SECTION 6: AMBIENT SOUNDS
// ═══════════════════════════════════════════════════

class _AmbientSoundsSection extends ConsumerWidget {
  const _AmbientSoundsSection();

  IconData _getIconForSound(AmbientSoundType type) {
    switch (type) {
      case AmbientSoundType.rain:
      case AmbientSoundType.calmingRain:
      case AmbientSoundType.heavyRain:
      case AmbientSoundType.thunderRain:
        return Icons.water_drop_rounded;
      case AmbientSoundType.birdsSingingInRain:
      case AmbientSoundType.birdsChirping:
        return Icons.flutter_dash_rounded;
      case AmbientSoundType.brownNoise:
      case AmbientSoundType.pinkNoise:
      case AmbientSoundType.whiteNoise:
        return Icons.air_rounded;
      case AmbientSoundType.campfire:
        return Icons.local_fire_department_rounded;
      case AmbientSoundType.forestAmbience:
        return Icons.forest_rounded;
      case AmbientSoundType.wavesSound:
        return Icons.waves_rounded;
      case AmbientSoundType.underwaterAmbience:
        return Icons.water_rounded;
      case AmbientSoundType.cafe:
        return Icons.coffee_rounded;
      default:
        return Icons.music_note_rounded;
    }
  }

  Future<void> _pickAndUploadSound(BuildContext context, WidgetRef ref) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result == null || result.files.single.path == null) return;
      final file = result.files.single;

      if (!context.mounted) return;

      final nameController = TextEditingController(text: file.name.split('.').first);
      final categoryController = TextEditingController(text: 'Custom');
      final tokens = FocusOsTheme.of(context);

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: tokens.surfaceAlt,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('Import Custom Sound', style: TextStyle(color: tokens.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  style: TextStyle(color: tokens.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Sound Name',
                    labelStyle: TextStyle(color: tokens.textMuted),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: tokens.borderSubtle)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: tokens.accent)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: categoryController,
                  style: TextStyle(color: tokens.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Section / Category',
                    labelStyle: TextStyle(color: tokens.textMuted),
                    helperText: 'e.g. Chill, Beats, Nature',
                    helperStyle: TextStyle(color: tokens.textMuted, fontSize: 10),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: tokens.borderSubtle)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: tokens.accent)),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Cancel', style: TextStyle(color: tokens.textSecondary)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(backgroundColor: tokens.accent),
                child: const Text('Import', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      );

      if (confirmed == true) {
        await ref.read(ambientSoundProvider.notifier).uploadCustomSound(
          nameController.text.trim(),
          file.path!,
          categoryController.text.trim(),
        );
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
    }
  }

  Future<void> _renameSoundDialog(BuildContext context, WidgetRef ref, CustomSound sound) async {
    final controller = TextEditingController(text: sound.name);
    final tokens = FocusOsTheme.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: tokens.surfaceAlt,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Rename Sound', style: TextStyle(color: tokens.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: controller,
            style: TextStyle(color: tokens.textPrimary),
            decoration: InputDecoration(
              labelText: 'New Name',
              labelStyle: TextStyle(color: tokens.textMuted),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: tokens.borderSubtle)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: tokens.accent)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel', style: TextStyle(color: tokens.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: tokens.accent),
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await ref.read(ambientSoundProvider.notifier).renameCustomSound(sound.id, controller.text.trim());
    }
  }

  Future<void> _changeSectionDialog(BuildContext context, WidgetRef ref, CustomSound sound) async {
    final controller = TextEditingController(text: sound.category);
    final tokens = FocusOsTheme.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: tokens.surfaceAlt,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Change Section / Category', style: TextStyle(color: tokens.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: controller,
            style: TextStyle(color: tokens.textPrimary),
            decoration: InputDecoration(
              labelText: 'Section Name',
              labelStyle: TextStyle(color: tokens.textMuted),
              helperText: 'e.g. Chill, Beats, Fokus',
              helperStyle: TextStyle(color: tokens.textMuted, fontSize: 10),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: tokens.borderSubtle)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: tokens.accent)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel', style: TextStyle(color: tokens.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: tokens.accent),
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await ref.read(ambientSoundProvider.notifier).reorderCustomSoundCategory(sound.id, controller.text.trim());
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = FocusOsTheme.of(context);
    final soundState = ref.watch(ambientSoundProvider);

    // Group bundled sounds by category
    final Map<String, List<AmbientSoundType>> groupedBundled = {};
    for (final sound in AmbientSoundType.values) {
      if (sound == AmbientSoundType.none || sound == AmbientSoundType.cafe) continue;
      groupedBundled.putIfAbsent(sound.category, () => []).add(sound);
    }

    // Group custom sounds by category
    final Map<String, List<CustomSound>> groupedCustom = {};
    for (final sound in soundState.customSounds) {
      groupedCustom.putIfAbsent(sound.category, () => []).add(sound);
    }

    return _ScrollContent(
      children: [
        _SettingsGroup(
          title: 'Sound Library',
          icon: Icons.headphones,
          tokens: tokens,
          description: 'Select an ambient sound for your fokus sessions',
          children: [
            ...groupedBundled.keys.map((category) {
              final sounds = groupedBundled[category]!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 8),
                    child: Text(
                      category.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: tokens.textMuted,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: sounds.map((sound) {
                      final isSelected = soundState.type == sound && soundState.selectedCustomSoundId == null;
                      return _SoundCard(
                        icon: _getIconForSound(sound),
                        label: sound.title,
                        isSelected: isSelected,
                        tokens: tokens,
                        onTap: () => ref.read(ambientSoundProvider.notifier).setType(
                          isSelected ? AmbientSoundType.none : sound,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                ],
              );
            }),
          ],
        ),
        _SettingsGroup(
          title: 'Custom Uploads',
          icon: Icons.library_music_outlined,
          tokens: tokens,
          description: 'Upload, arrange, and manage your own audio files',
          children: [
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () => _pickAndUploadSound(context, ref),
                  icon: const Icon(Icons.upload_file_rounded, size: 16, color: Colors.white),
                  label: const Text('Upload Custom Sound', style: TextStyle(color: Colors.white, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tokens.accent,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (soundState.customSounds.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No custom sounds uploaded yet. Select files from your device to save them.',
                  style: TextStyle(fontSize: 12, color: tokens.textMuted, fontStyle: FontStyle.italic),
                ),
              )
            else
              ...groupedCustom.keys.map((category) {
                final sounds = groupedCustom[category]!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 10, bottom: 8),
                      child: Text(
                        category.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: tokens.textMuted,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: sounds.length,
                      itemBuilder: (context, index) {
                        final sound = sounds[index];
                        final isSelected = soundState.selectedCustomSoundId == sound.id;
                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? tokens.accent.safeWithOpacity(0.08)
                                : tokens.background.safeWithOpacity(0.3),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? tokens.accent.safeWithOpacity(0.3) : tokens.borderSubtle,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  isSelected && soundState.isPlaying
                                      ? Icons.pause_circle_filled_rounded
                                      : Icons.play_circle_fill_rounded,
                                  color: isSelected ? tokens.accent : tokens.textSecondary,
                                  size: 24,
                                ),
                                onPressed: () {
                                  if (isSelected) {
                                    ref.read(ambientSoundProvider.notifier).togglePlayPause();
                                  } else {
                                    ref.read(ambientSoundProvider.notifier).setCustomType(sound);
                                  }
                                },
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      sound.name,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                        color: tokens.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      'Local File',
                                      style: TextStyle(fontSize: 10, color: tokens.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.edit_rounded, size: 15, color: tokens.textSecondary),
                                    tooltip: 'Rename sound',
                                    onPressed: () => _renameSoundDialog(context, ref, sound),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.folder_open_rounded, size: 15, color: tokens.textSecondary),
                                    tooltip: 'Change category',
                                    onPressed: () => _changeSectionDialog(context, ref, sound),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete_outline_rounded, size: 15, color: Colors.redAccent.withValues(alpha: 0.8)),
                                    tooltip: 'Delete sound',
                                    onPressed: () {
                                      ref.read(ambientSoundProvider.notifier).deleteCustomSound(sound.id);
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                );
              }),
          ],
        ),
        _SettingsGroup(
          title: 'Volume',
          icon: Icons.volume_up_outlined,
          tokens: tokens,
          children: [
            PremiumCompactSlider(
              label: 'Master Volume',
              value: soundState.volume,
              onChanged: (v) => ref.read(ambientSoundProvider.notifier).setVolume(v),
              displayValue: '${(soundState.volume * 100).round()}%',
            ),
          ],
        ),
      ],
    );
  }
}

class _SoundCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final ThemeTokens tokens;
  final VoidCallback onTap;

  const _SoundCard({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.tokens,
    required this.onTap,
  });

  @override
  State<_SoundCard> createState() => _SoundCardState();
}

class _SoundCardState extends State<_SoundCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: PremiumDurations.hoverLong,
          curve: PremiumCurves.easeOutCubic,
          width: 110,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? widget.tokens.accent.safeWithOpacity(0.10)
                : _hovered
                    ? widget.tokens.textPrimary.safeWithOpacity(0.04)
                    : widget.tokens.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.isSelected
                  ? widget.tokens.accent.safeWithOpacity(0.4)
                  : _hovered
                      ? widget.tokens.borderMedium
                      : widget.tokens.borderSubtle,
            ),
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: widget.tokens.accent.safeWithOpacity(0.12),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: widget.isSelected
                      ? widget.tokens.accent.safeWithOpacity(0.15)
                      : widget.tokens.borderSubtle,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  widget.icon,
                  size: 20,
                  color: widget.isSelected ? widget.tokens.accent : widget.tokens.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: widget.isSelected ? widget.tokens.accent : widget.tokens.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              if (widget.isSelected)
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: widget.tokens.accent,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// SECTION 7: FOCUS SCENES
// ═══════════════════════════════════════════════════

class _FocusScenesSection extends ConsumerWidget {
  const _FocusScenesSection();

  void _showVariantSelector(BuildContext context, WidgetRef ref, FocusScene scene, ThemeTokens tokens) {
    showDialog(
      context: context,
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            final activeScene = ref.watch(fokusSceneProvider);
            return AlertDialog(
              backgroundColor: tokens.surfaceAlt,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                'Select ${scene.name} Variant',
                style: TextStyle(color: tokens.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: scene.variants.map((variant) {
                      final isSelected = activeScene.id == scene.id && activeScene.imagePath == variant.imagePath;
                      return GestureDetector(
                        onTap: () {
                          ref.read(fokusSceneProvider.notifier).setSceneVariant(scene.id, variant.imagePath);
                          Navigator.of(context).pop();
                        },
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Container(
                            width: 110,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? tokens.accent.safeWithOpacity(0.08)
                                  : tokens.background.safeWithOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? tokens.accent : tokens.borderSubtle,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: SizedBox(
                                    width: double.infinity,
                                    height: 60,
                                    child: Image.asset(
                                      variant.imagePath,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  variant.name,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: tokens.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Close', style: TextStyle(color: tokens.textSecondary)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = FocusOsTheme.of(context);
    final activeScene = ref.watch(fokusSceneProvider);
    final scenes = AppScenes.all;

    return _ScrollContent(
      children: [
        _SettingsGroup(
          title: 'Fokus Scenes',
          icon: Icons.landscape,
          tokens: tokens,
          description: 'Choose a visual scene for your fokus environment',
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: scenes.map((scene) {
                return _SceneCard(
                  scene: scene,
                  isActive: activeScene.id == scene.id,
                  tokens: tokens,
                  onTap: () {
                    ref.read(fokusSceneProvider.notifier).setScene(scene.id);
                    if (scene.variants.length > 1) {
                      _showVariantSelector(context, ref, scene, tokens);
                    }
                  },
                );
              }).toList(),
            ),
          ],
        ),
        _SettingsGroup(
          title: 'Extensibility',
          icon: Icons.extension_outlined,
          tokens: tokens,
          description: 'Add custom scenes with your own images later.',
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'The scene system supports bundled visuals and future user-uploaded images. '
                'Drop scene images into the assets folder to add more scenes.',
                style: TextStyle(fontSize: 12, color: tokens.textSecondary, height: 1.4),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SceneCard extends StatefulWidget {
  final FocusScene scene;
  final bool isActive;
  final ThemeTokens tokens;
  final VoidCallback onTap;

  const _SceneCard({
    required this.scene,
    required this.isActive,
    required this.tokens,
    required this.onTap,
  });

  @override
  State<_SceneCard> createState() => _SceneCardState();
}

class _SceneCardState extends State<_SceneCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final gradientColors = widget.scene.gradientColors;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Transform(
          transform: _hovered && !widget.isActive                  ? Matrix4(
                  1.02, 0, 0, 0,
                  0, 1.02, 0, 0,
                  0, 0, 1, 0,
                  0, -3.06, 0, 1,
                )
              : Matrix4.identity(),
          alignment: Alignment.center,
          child: AnimatedContainer(
            duration: PremiumDurations.hoverLong,
            curve: PremiumCurves.easeOutCubic,
            width: 150,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: widget.isActive
                    ? Colors.white
                    : _hovered
                        ? Colors.white.safeWithOpacity(0.4)
                        : Colors.white.safeWithOpacity(0.15),
                width: widget.isActive ? 2 : 1,
              ),
              boxShadow: widget.isActive
                  ? [
                      BoxShadow(
                        color: gradientColors.last.safeWithOpacity(0.5),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : _hovered
                      ? [
                          BoxShadow(
                            color: gradientColors.last.safeWithOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.safeWithOpacity(0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(widget.scene.icon, size: 28, color: Colors.white.safeWithOpacity(0.9)),
                      const SizedBox(height: 10),
                      Text(
                        widget.scene.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                if (widget.isActive)
                  Positioned(
                    top: -6,
                    right: -6,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check,
                        size: 12,
                        color: gradientColors.first,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// SECTION 8: ANALYTICS
// ═══════════════════════════════════════════════════

class _AnalyticsSection extends ConsumerWidget {
  const _AnalyticsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = FocusOsTheme.of(context);

    return _ScrollContent(
      children: [
        _SettingsGroup(
          title: 'Statistics Preferences',
          icon: Icons.bar_chart_rounded,
          tokens: tokens,
          children: [
            _ToggleRow(
              label: 'Track Fokus Sessions',
              subtitle: 'Record all completed sessions for analytics',
              value: true,
              tokens: tokens,
              onChanged: (_) {},
            ),
            const SizedBox(height: 4),
            _ToggleRow(
              label: 'Track Interruptions',
              subtitle: 'Record interrupted sessions separately',
              value: true,
              tokens: tokens,
              onChanged: (_) {},
            ),
            const SizedBox(height: 4),
            _ToggleRow(
              label: 'Weekly Reports',
              subtitle: 'Show weekly fokus summary on analytics page',
              value: true,
              tokens: tokens,
              onChanged: (_) {},
            ),
          ],
        ),
        _SettingsGroup(
          title: 'Export',
          icon: Icons.file_download_outlined,
          tokens: tokens,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Export your fokus data as CSV or JSON for external analysis. '
                'All data is stored locally and never leaves your device.',
                style: TextStyle(fontSize: 12, color: tokens.textSecondary, height: 1.4),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════
// SECTION 9: HEALTH
// ═══════════════════════════════════════════════════

class _HealthSection extends ConsumerWidget {
  const _HealthSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = FocusOsTheme.of(context);
    final blueLight = ref.watch(blueLightProvider);
    final eyeBreak = ref.watch(eyeBreakProvider);

    return _ScrollContent(
      children: [
        _SettingsGroup(
          title: 'Blue Light Filter',
          icon: Icons.light_mode_outlined,
          tokens: tokens,
          children: [
            _ToggleRow(
              label: 'Enable Blue Light Filter',
              subtitle: 'Reduce blue light exposure during evening hours',
              value: blueLight.enabled,
              tokens: tokens,
              onChanged: (v) => ref.read(blueLightProvider.notifier).setEnabled(v),
            ),
            const SizedBox(height: 4),
            _ToggleRow(
              label: 'Auto Mode',
              subtitle: 'Automatically enable based on schedule',
              value: blueLight.autoMode,
              tokens: tokens,
              onChanged: (v) => ref.read(blueLightProvider.notifier).setAutoMode(v),
            ),
            const SizedBox(height: 4),
            _ToggleRow(
              label: 'Session-Linked',
              subtitle: 'Enable during fokus sessions automatically',
              value: blueLight.sessionLinked,
              tokens: tokens,
              onChanged: (v) => ref.read(blueLightProvider.notifier).setSessionLinked(v),
            ),
          ],
        ),
        _SettingsGroup(
          title: 'Eye Care Reminders',
          icon: Icons.remove_red_eye_outlined,
          tokens: tokens,
          children: [
            _ToggleRow(
              label: '20-20-20 Rule',
              subtitle: 'Every 20 min, look at something 20 ft away for 20 sec',
              value: eyeBreak.twentyTwentyEnabled,
              tokens: tokens,
              onChanged: (v) => ref.read(eyeBreakProvider.notifier).setTwentyTwenty(v),
            ),
            const SizedBox(height: 4),
            _ToggleRow(
              label: 'Blink Reminders',
              subtitle: 'Gentle reminders to blink regularly',
              value: eyeBreak.blinkReminders,
              tokens: tokens,
              onChanged: (v) => ref.read(eyeBreakProvider.notifier).setBlinkReminders(v),
            ),
            const SizedBox(height: 4),
            _ToggleRow(
              label: 'Break Reminders',
              subtitle: 'Remind you to take short breaks',
              value: eyeBreak.breakReminders,
              tokens: tokens,
              onChanged: (v) => ref.read(eyeBreakProvider.notifier).setBreakReminders(v),
            ),
          ],
        ),
        _SettingsGroup(
          title: 'Wellness',
          icon: Icons.favorite_outline,
          tokens: tokens,
          children: [
            _ToggleRow(
              label: 'Hydration Reminders',
              subtitle: 'Remind you to drink water during sessions',
              value: eyeBreak.hydrationReminders,
              tokens: tokens,
              onChanged: (v) => ref.read(eyeBreakProvider.notifier).setHydrationReminders(v),
            ),
            const SizedBox(height: 4),
            _ToggleRow(
              label: 'Posture Reminders',
              subtitle: 'Gentle nudges to check your posture',
              value: eyeBreak.postureReminders,
              tokens: tokens,
              onChanged: (v) => ref.read(eyeBreakProvider.notifier).setPostureReminders(v),
            ),
          ],
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════
// SECTION 10: APPEARANCE
// ═══════════════════════════════════════════════════

class _AppearanceSection extends ConsumerWidget {
  const _AppearanceSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = FocusOsTheme.of(context);
    final currentTheme = ref.watch(themeProvider);
    final activeColor = ref.watch(timerColorProvider);

    final darkThemes = AppThemes.all.where((t) => t.category == 'Dark').toList();
    final lightThemes = AppThemes.all.where((t) => t.category == 'Light').toList();

    return _ScrollContent(
      children: [
        _SettingsGroup(
          title: 'Theme Gallery',
          icon: Icons.palette_outlined,
          tokens: tokens,
          description: 'Choose your visual theme',
          children: [
            Text(
              'Dark Themes',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: tokens.textMuted,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: darkThemes.map((theme) {
                return _ThemeCard(
                  theme: theme,
                  isActive: theme.id == currentTheme.id,
                  tokens: tokens,
                  onTap: () => ref.read(themeProvider.notifier).setTheme(theme.id),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Text(
              'Light Themes',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: tokens.textMuted,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: lightThemes.map((theme) {
                return _ThemeCard(
                  theme: theme,
                  isActive: theme.id == currentTheme.id,
                  tokens: tokens,
                  onTap: () => ref.read(themeProvider.notifier).setTheme(theme.id),
                );
              }).toList(),
            ),
          ],
        ),
        _SettingsGroup(
          title: 'Timer Digit Color',
          icon: Icons.timer_outlined,
          tokens: tokens,
          description: 'Choose a custom color for the fokus timer clock digits',
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Reset / Default color option
                GestureDetector(
                  onTap: () => ref.read(timerColorProvider.notifier).setColor(null),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: activeColor == null
                            ? tokens.accent
                            : tokens.borderMedium,
                        width: activeColor == null ? 2.5 : 1,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.invert_colors_off,
                        size: 16,
                        color: activeColor == null ? tokens.accent : tokens.textSecondary,
                      ),
                    ),
                  ),
                ),
                ...[
                  Colors.white,
                  const Color(0xFFEF4444), // Red
                  const Color(0xFFF97316), // Orange
                  const Color(0xFFFBBF24), // Yellow
                  const Color(0xFF34D399), // Mint Green
                  const Color(0xFF10B981), // Emerald Green
                  const Color(0xFF06B6D4), // Cyan
                  const Color(0xFF3B82F6), // Bright Blue
                  const Color(0xFF1D4ED8), // Royal Blue
                  const Color(0xFF6366F1), // Indigo
                  const Color(0xFF8B5CF6), // Violet
                  const Color(0xFFEC4899), // Pink
                  const Color(0xFFF43F5E), // Rose
                  const Color(0xFFE2E8F0), // Slate Light
                  const Color(0xFF94A3B8), // Slate Medium
                  const Color(0xFF475569), // Slate Dark
                  const Color(0xFF0F172A), // Slate Deep
                ].map((color) {
                  final isSelected = activeColor?.toARGB32() == color.toARGB32();
                  return GestureDetector(
                    onTap: () => ref.read(timerColorProvider.notifier).setColor(color),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? (color == Colors.white || color == const Color(0xFFE2E8F0) ? Colors.black : Colors.white)
                              : tokens.borderMedium,
                          width: isSelected ? 2.5 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.4),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? Center(
                              child: Icon(
                                Icons.check,
                                size: 16,
                                color: color == Colors.white || color == const Color(0xFFE2E8F0) || color == const Color(0xFFFBBF24)
                                    ? Colors.black
                                    : Colors.white,
                              ),
                            )
                          : null,
                    ),
                  );
                }),
              ],
            ),
          ],
        ),
        _SettingsGroup(
          title: 'Theme Extensibility',
          icon: Icons.extension_outlined,
          tokens: tokens,
          description: 'Add custom themes by placing theme definition files in the assets folder.',
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'This system supports bundled default themes and future user-uploaded themes. '
                'New themes can be added programmatically via AppThemes.',
                style: TextStyle(fontSize: 12, color: tokens.textSecondary, height: 1.4),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ThemeCard extends StatefulWidget {
  final ThemeDefinition theme;
  final bool isActive;
  final ThemeTokens tokens;
  final VoidCallback onTap;

  const _ThemeCard({
    required this.theme,
    required this.isActive,
    required this.tokens,
    required this.onTap,
  });

  @override
  State<_ThemeCard> createState() => _ThemeCardState();
}

class _ThemeCardState extends State<_ThemeCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final themeTokens = widget.theme.tokens;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Transform(
          transform: _hovered && !widget.isActive                  ? Matrix4(
                  1.03, 0, 0, 0,
                  0, 1.03, 0, 0,
                  0, 0, 1, 0,
                  0, -3.09, 0, 1,
                )
              : Matrix4.identity(),
          alignment: Alignment.center,
          child: AnimatedContainer(
            duration: PremiumDurations.hoverLong,
            curve: PremiumCurves.easeOutCubic,
            width: 130,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.isActive
                    ? widget.tokens.accent.safeWithOpacity(0.6)
                    : _hovered
                        ? widget.tokens.borderMedium
                        : widget.tokens.borderSubtle,
                width: widget.isActive ? 2 : 1,
              ),
              boxShadow: widget.isActive
                  ? [
                      BoxShadow(
                        color: widget.tokens.accent.safeWithOpacity(0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : _hovered
                      ? [
                          BoxShadow(
                            color: Colors.black.safeWithOpacity(0.12),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Theme preview
                Container(
                  height: 70,
                  decoration: BoxDecoration(
                    color: themeTokens.background,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(11)),
                  ),
                  child: Stack(
                    children: [
                      // Surface preview
                      Positioned(
                        top: 10,
                        left: 10,
                        right: 10,
                        child: Container(
                          height: 18,
                          decoration: BoxDecoration(
                            color: themeTokens.surface,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: themeTokens.borderSubtle,
                            ),
                          ),
                        ),
                      ),
                      // Accent preview
                      Positioned(
                        top: 34,
                        left: 10,
                        child: Container(
                          width: 40,
                          height: 8,
                          decoration: BoxDecoration(
                            gradient: themeTokens.accentGradient,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 46,
                        left: 10,
                        right: 10,
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            color: themeTokens.borderSubtle,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 52,
                        left: 10,
                        right: 40,
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            color: themeTokens.textSecondary.safeWithOpacity(0.3),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Theme name
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(
                    color: widget.tokens.surface,
                    borderRadius:
                        const BorderRadius.vertical(bottom: Radius.circular(11)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        widget.theme.icon,
                        size: 12,
                        color: themeTokens.accent,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          widget.theme.name,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: widget.isActive
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: widget.isActive
                                ? widget.tokens.accent
                                : widget.tokens.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.isActive)
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: widget.tokens.accent,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            size: 10,
                            color: Colors.white,
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
    );
  }
}

// ═══════════════════════════════════════════════════
// SECTION 11: KEYBOARD SHORTCUTS
// ═══════════════════════════════════════════════════

class _KeyboardShortcutsSection extends ConsumerWidget {
  const _KeyboardShortcutsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = FocusOsTheme.of(context);
    final shortcutsEnabled = ref.watch(keyboardShortcutsProvider);

    return _ScrollContent(
      children: [
        _SettingsGroup(
          title: 'Global Shortcuts',
          icon: Icons.keyboard_outlined,
          tokens: tokens,
          children: [
            _ToggleRow(
              label: 'Enable Keyboard Shortcuts',
              subtitle: 'Master toggle for all global hotkeys',
              value: shortcutsEnabled,
              tokens: tokens,
              onChanged: (v) => ref.read(keyboardShortcutsProvider.notifier).setEnabled(v),
            ),
          ],
        ),
        _SettingsGroup(
          title: 'Shortcut Reference',
          icon: Icons.list_alt_outlined,
          tokens: tokens,
          children: [
            _ShortcutRow(
              keys: ['Ctrl', 'Space'],
              desc: 'Start / Pause focus session',
              tokens: tokens,
            ),
            _ShortcutRow(
              keys: ['Ctrl', 'R'],
              desc: 'Reset timer',
              tokens: tokens,
            ),
            _ShortcutRow(
              keys: ['Ctrl', 'Q'],
              desc: 'Quick capture task',
              tokens: tokens,
            ),
            _ShortcutRow(
              keys: ['Ctrl', 'Shift', 'C'],
              desc: 'Toggle calculator overlay',
              tokens: tokens,
            ),
            _ShortcutRow(
              keys: ['Ctrl', 'B'],
              desc: 'Brain dump overlay',
              tokens: tokens,
            ),
            _ShortcutRow(
              keys: ['Ctrl', ','],
              desc: 'Open settings',
              tokens: tokens,
            ),
            _ShortcutRow(
              keys: ['Ctrl', '\\'],
              desc: 'Toggle sidebar',
              tokens: tokens,
            ),
            _ShortcutRow(
              keys: ['Ctrl', 'D'],
              desc: 'Toggle Do Not Disturb',
              tokens: tokens,
            ),
            _ShortcutRow(
              keys: ['Ctrl', 'Shift', 'F'],
              desc: 'Toggle fullscreen',
              tokens: tokens,
            ),
            _ShortcutRow(
              keys: const ['Esc'],
              desc: 'Close overlays / Exit deep work',
              tokens: tokens,
            ),
            _ShortcutRow(
              keys: ['Ctrl', '/'],
              desc: 'Toggle shortcuts cheat sheet',
              tokens: tokens,
            ),
            _ShortcutRow(
              keys: ['Ctrl', '1-6'],
              desc: 'Direct page access (1: Fokus, 2: Tasks, 3: Analytics, 4: Health, 6: Tools)',
              tokens: tokens,
            ),
            _ShortcutRow(
              keys: ['Ctrl', 'T'],
              desc: 'Cycle timer style',
              tokens: tokens,
            ),
            _ShortcutRow(
              keys: ['Ctrl', 'M'],
              desc: 'Toggle mini floating timer',
              tokens: tokens,
            ),
          ],
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              desc,
              style: TextStyle(fontSize: 12, color: tokens.textSecondary),
            ),
          ),
          const SizedBox(width: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: keys.map((key) {
              return Padding(
                padding: const EdgeInsets.only(left: 3),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: tokens.borderMedium.safeWithOpacity(0.4),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: tokens.borderSubtle),
                  ),
                  child: Text(
                    key,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}


class _DataButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final String description;
  final ThemeTokens tokens;
  final VoidCallback onTap;
  final bool isDanger;

  const _DataButton({
    required this.icon,
    required this.label,
    required this.description,
    required this.tokens,
    required this.onTap,
    // ignore: unused_element_parameter
    this.isDanger = false,
  });

  @override
  State<_DataButton> createState() => _DataButtonState();
}

class _DataButtonState extends State<_DataButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.isDanger
        ? const Color(0xFFEF4444)
        : widget.tokens.accent;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: PremiumDurations.hover,
          curve: PremiumCurves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _hovered
                ? color.safeWithOpacity(0.08)
                : widget.tokens.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _hovered
                  ? color.safeWithOpacity(0.3)
                  : widget.tokens.borderSubtle,
            ),
          ),
          child: Row(
            children: [
              Icon(widget.icon, size: 16, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: widget.isDanger
                            ? const Color(0xFFEF4444)
                            : widget.tokens.textPrimary,
                      ),
                    ),
                    Text(
                      widget.description,
                      style: TextStyle(
                        fontSize: 11,
                        color: widget.tokens.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 12,
                color: widget.tokens.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// SECTION 13: ABOUT
// ═══════════════════════════════════════════════════

class _AboutSection extends ConsumerWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = FocusOsTheme.of(context);

    return _ScrollContent(
      children: [
        _SettingsGroup(
          title: 'Fokus',
          icon: Icons.info_outline_rounded,
          tokens: tokens,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset(
                    'assets/logo.png',
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fokus',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Version 0.1.0',
                      style: TextStyle(fontSize: 12, color: tokens.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: tokens.accent.safeWithOpacity(0.10),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        'Privacy-first · Offline-first',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: tokens.accent,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'A privacy-first, offline desktop fokus operating system. '
              'Built with Flutter for Windows. All data stored locally on your device.',
              style: TextStyle(
                fontSize: 12,
                color: tokens.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
        _SettingsGroup(
          title: 'Details',
          icon: Icons.info_outline,
          tokens: tokens,
          children: [
            _InfoRow(label: 'Version', value: '0.1.0 (build 1)', tokens: tokens),
            _InfoRow(label: 'Framework', value: 'Flutter', tokens: tokens),
            _InfoRow(label: 'Platform', value: 'Windows', tokens: tokens),
            _InfoRow(label: 'Data Storage', value: 'Local (Offline)', tokens: tokens),
            const SizedBox(height: 8),
            _DataButton(
              icon: Icons.article_outlined,
              label: 'Changelog',
              description: 'View version history',
              tokens: tokens,
              onTap: () {},
            ),
            const SizedBox(height: 8),
            _DataButton(
              icon: Icons.feedback_outlined,
              label: 'Send Feedback',
              description: 'Share your thoughts and suggestions',
              tokens: tokens,
              onTap: () {},
            ),
          ],
        ),
        _SettingsGroup(
          title: 'Legal',
          icon: Icons.gavel_outlined,
          tokens: tokens,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                '© 2026 Fokus. All rights reserved.\n'
                'Licensed under the MIT License.\n'
                'Built with ❤️ for deep fokus.',
                style: TextStyle(
                  fontSize: 12,
                  color: tokens.textSecondary,
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final ThemeTokens tokens;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: tokens.textSecondary),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: tokens.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// SCROLL CONTENT WRAPPER
// ═══════════════════════════════════════════════════

class _ScrollContent extends StatelessWidget {
  final List<Widget> children;

  const _ScrollContent({required this.children});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      physics: const BouncingScrollPhysics(
        parent: ClampingScrollPhysics(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

