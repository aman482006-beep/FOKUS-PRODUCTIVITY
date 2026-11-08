import 'dart:convert';
import 'dart:ui' show ImageFilter;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../core/navigation.dart';
import '../../services/fokus_history_service.dart';

import '../theme.dart';

/// A sliding frosted-glass panel that displays and edits the user profile.
/// Triggered by clicking the profile card in the sidebar.
class ProfileOverlay extends ConsumerStatefulWidget {
  final VoidCallback onClose;

  const ProfileOverlay({super.key, required this.onClose});

  @override
  ConsumerState<ProfileOverlay> createState() => _ProfileOverlayState();
}

class _ProfileOverlayState extends ConsumerState<ProfileOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  final _nameController = TextEditingController();
  bool _editingName = false;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(-1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOut),
    );
    _slideController.forward();

    final profile = ref.read(userProfileProvider);
    _nameController.text = profile.name;
  }

  @override
  void dispose() {
    _slideController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _close() {
    _slideController.reverse().then((_) => widget.onClose());
  }

  Future<void> _pickAvatar() async {
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
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider);
    final tokens = FocusOsTheme.of(context);
    final streak = FokusHistoryService.getDailyStreak();
    final totalSessions = FokusHistoryService.getDailyCounts(days: 28)
        .fold(0, (a, b) => a + b);
    final lifetime = profile.lifetimeFocusTasks;

    final displayName = profile.name;
    const isSupabaseUser = false;

    final expanded = ref.watch(sidebarExpandedProvider);
    final isDeepWork = ref.watch(deepWorkModeProvider);
    final fullscreen = ref.watch(fullscreenProvider);

    final bool sidebarHidden = isDeepWork || fullscreen;
    final double sidebarWidth = sidebarHidden ? 0.0 : (expanded ? 200.0 : 60.0);

    return Stack(
      children: [
        // ── Scrim backdrop (dismiss on tap) ──
        FadeTransition(
          opacity: _fadeAnimation,
          child: GestureDetector(
            onTap: _close,
            child: Container(color: Colors.black.safeWithOpacity(0.35)),
          ),
        ),

        // ── Sliding panel ──
        SlideTransition(
          position: _slideAnimation,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: (MediaQuery.of(context).size.width - sidebarWidth).clamp(0.0, 340.0),
              margin: EdgeInsets.only(left: sidebarWidth, top: 0),
              height: double.infinity,
              child: ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: Container(
                    decoration: BoxDecoration(
                      color: tokens.surface,
                      border: Border(
                        right: BorderSide(
                            color: tokens.borderSubtle, width: 1),
                      ),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Header ──
                          Row(
                            children: [
                              Text(
                                'Profile',
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
                          const SizedBox(height: 28),

                          // ── Avatar ──
                          Center(
                            child: GestureDetector(
                              onTap: _pickAvatar,
                              child: Stack(
                                children: [
                                  Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: tokens.accent.safeWithOpacity(0.5),
                                        width: 2,
                                      ),
                                      gradient: LinearGradient(
                                        colors: [
                                          tokens.accent.safeWithOpacity(0.15),
                                          tokens.accentSecondary
                                              .safeWithOpacity(0.08),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                    ),
                                    child: profile.avatarBase64.isNotEmpty
                                        ? ClipOval(
                                            child: Image.memory(
                                              base64Decode(
                                                  profile.avatarBase64),
                                              fit: BoxFit.cover,
                                            ),
                                          )
                                        : Center(
                                            child: Text(
                                              profile.name
                                                  .substring(0, 1)
                                                  .toUpperCase(),
                                              style: TextStyle(
                                                fontSize: 28,
                                                fontWeight: FontWeight.w600,
                                                color: tokens.accent,
                                              ),
                                            ),
                                          ),
                                  ),
                                  // ── Edit badge ──
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: tokens.accent,
                                        border: Border.all(
                                          color: tokens.background,
                                          width: 2,
                                        ),
                                      ),
                                      child: Icon(Icons.camera_alt,
                                          size: 14,
                                          color: tokens.textPrimary),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // ── Name field ──
                          _EditableField(
                            label: 'Display Name',
                            value: displayName,
                            controller: _nameController,
                            isEditing: _editingName && !isSupabaseUser,
                            tokens: tokens,
                            isSupabaseUser: isSupabaseUser,
                            onToggle: () =>
                                setState(() => _editingName = !_editingName),
                            onSave: () => ref
                                .read(userProfileProvider.notifier)
                                .updateName(_nameController.text),
                          ),
                          const SizedBox(height: 16),

                          // ── About You ──
                          _InfoRow(
                            icon: Icons.badge_outlined,
                            label: 'About You',
                            value: profile.status.isNotEmpty ? profile.status : 'No description',
                            tokens: tokens,
                          ),
                          const SizedBox(height: 24),

                          // ── Divider ──
                          Container(
                            height: 1,
                            color: tokens.borderSubtle,
                          ),
                          const SizedBox(height: 24),

                          // ── Stats ──
                          Text(
                            'Fokus Statistics',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: tokens.textSecondary,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 14),

                          _StatTile(
                            icon: Icons.local_fire_department,
                            label: 'Current Streak',
                            value: '$streak days',
                            color: Colors.orange,
                            tokens: tokens,
                          ),
                          const SizedBox(height: 8),
                          _StatTile(
                            icon: Icons.check_circle_outline,
                            label: '28-Day Sessions',
                            value: '$totalSessions',
                            color: tokens.accent,
                            tokens: tokens,
                          ),
                          const SizedBox(height: 8),
                          _StatTile(
                            icon: Icons.emoji_events_outlined,
                            label: 'Lifetime Fokus Tasks',
                            value: '$lifetime',
                            color: const Color(0xFFF59E0B),
                            tokens: tokens,
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

// ──────────────────────────────────────────────
// Sub-widgets
// ──────────────────────────────────────────────

class _EditableField extends StatelessWidget {
  final String label;
  final String value;
  final TextEditingController controller;
  final bool isEditing;
  final ThemeTokens tokens;
  final bool isSupabaseUser;
  final VoidCallback onToggle;
  final VoidCallback onSave;

  const _EditableField({
    required this.label,
    required this.value,
    required this.controller,
    required this.isEditing,
    required this.tokens,
    this.isSupabaseUser = false,
    required this.onToggle,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: tokens.textMuted),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: isEditing
                  ? SizedBox(
                      height: 32,
                      child: TextField(
                        controller: controller,
                        autofocus: true,
                        style: TextStyle(
                          fontSize: 14,
                          color: tokens.textPrimary,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 4),
                        ),
                        onSubmitted: (_) {
                          onSave();
                          onToggle();
                        },
                      ),
                    )
                  : GestureDetector(
                      onTap: onToggle,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                value,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: tokens.textPrimary,
                                ),
                              ),
                            ),
                            if (!isSupabaseUser)
                              Icon(Icons.edit_outlined,
                                  size: 14, color: tokens.textMuted),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
        if (isEditing)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: GestureDetector(
              onTap: () {
                onSave();
                onToggle();
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: tokens.accent.safeWithOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Save',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: tokens.accent,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final ThemeTokens tokens;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 16, color: tokens.textMuted),
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(fontSize: 12, color: tokens.textSecondary),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: tokens.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final ThemeTokens tokens;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tokens.borderSubtle.safeWithOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: tokens.textSecondary),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
