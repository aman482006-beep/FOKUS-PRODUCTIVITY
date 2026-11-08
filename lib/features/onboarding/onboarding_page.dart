import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/providers.dart';
import '../../shared/theme.dart';

/// Full-screen onboarding page shown after sign-up for first-time users.
/// Lets the user set their display name and pick an avatar before entering
/// the main Fokus app.
class OnboardingPage extends ConsumerStatefulWidget {
  final VoidCallback onComplete;

  const OnboardingPage({super.key, required this.onComplete});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _aboutController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;
  String? _avatarBase64;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    final profile = ref.read(userProfileProvider);
    _nameController.text = profile.name != 'User' ? profile.name : '';
    _aboutController.text = profile.status != 'Fokus operative' ? profile.status : '';

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    ));
    _fadeController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _aboutController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result != null && result.files.single.bytes != null) {
      setState(() {
        _avatarBase64 = base64Encode(result.files.single.bytes!);
      });
    }
  }

  Future<void> _completeOnboarding() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Save name to local profile (auto-syncs to Supabase)
      ref.read(userProfileProvider.notifier).updateName(_nameController.text.trim());

      // Save status/about to local profile
      final aboutText = _aboutController.text.trim();
      ref.read(userProfileProvider.notifier).updateStatus(
        aboutText.isNotEmpty ? aboutText : 'Fokus operative',
      );

      // Save avatar if one was picked (auto-syncs to Supabase)
      if (_avatarBase64 != null) {
        ref.read(userProfileProvider.notifier).updateAvatar(_avatarBase64!);
      }



      // Mark onboarding completed in local storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_completed', true);

      if (!mounted) return;
      widget.onComplete();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to save profile. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = FocusOsTheme.of(context);

    return Scaffold(
      backgroundColor: tokens.background,
      body: Stack(
        children: [
          // ── Animated background gradient ──
          Positioned.fill(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    tokens.accent.safeWithOpacity(0.08),
                    tokens.background,
                    tokens.accentSecondary.safeWithOpacity(0.05),
                    tokens.background,
                  ],
                  stops: const [0.0, 0.3, 0.7, 1.0],
                ),
              ),
            ),
          ),

          // ── Decorative orbs ──
          Positioned(
            top: -120,
            right: -60,
            child: Container(
              width: 340,
              height: 340,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: tokens.accent.safeWithOpacity(0.06),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: tokens.accentSecondary.safeWithOpacity(0.04),
              ),
            ),
          ),

          // ── Content ──
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Container(
                    width: 420,
                    constraints: const BoxConstraints(maxWidth: 420),
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: tokens.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: tokens.borderSubtle),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.safeWithOpacity(0.3),
                          blurRadius: 60,
                          offset: const Offset(0, 20),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ── Logo ──
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: tokens.accent.safeWithOpacity(0.3),
                                  blurRadius: 24,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.asset(
                                'assets/logo.png',
                                width: 64,
                                height: 64,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // ── Welcome title ──
                          Text(
                            'Welcome to Fokus',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: tokens.textPrimary,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Set up your profile to get started',
                            style: TextStyle(
                              fontSize: 14,
                              color: tokens.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 36),

                          // ── Avatar picker ──
                          Center(
                            child: GestureDetector(
                              onTap: _pickAvatar,
                              child: Stack(
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 96,
                                    height: 96,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: tokens.accent.safeWithOpacity(0.5),
                                        width: 2,
                                      ),
                                      gradient: LinearGradient(
                                        colors: [
                                          tokens.accent.safeWithOpacity(0.15),
                                          tokens.accentSecondary.safeWithOpacity(0.08),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                    ),
                                    child: _avatarBase64 != null
                                        ? ClipOval(
                                            child: Image.memory(
                                              base64Decode(_avatarBase64!),
                                              fit: BoxFit.cover,
                                            ),
                                          )
                                        : Center(
                                            child: Icon(
                                              Icons.person_outline,
                                              size: 40,
                                              color: tokens.accent.safeWithOpacity(0.5),
                                            ),
                                          ),
                                  ),
                                  // ── Camera badge ──
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      width: 30,
                                      height: 30,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: tokens.accent,
                                        border: Border.all(
                                          color: tokens.surface,
                                          width: 2.5,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.camera_alt,
                                        size: 15,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap to add a profile photo',
                            style: TextStyle(
                              fontSize: 11,
                              color: tokens.textMuted,
                            ),
                          ),
                          const SizedBox(height: 28),

                          // ── Display name field ──
                          TextFormField(
                            controller: _nameController,
                            autofocus: true,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your display name';
                              }
                              if (value.trim().length > 50) {
                                return 'Name is too long (max 50 characters)';
                              }
                              return null;
                            },
                            style: TextStyle(
                              color: tokens.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Enter your display name',
                              hintStyle: TextStyle(
                                color: tokens.textMuted.safeWithOpacity(0.6),
                                fontSize: 15,
                              ),
                              prefixIcon: Icon(
                                Icons.person_outline,
                                size: 20,
                                color: tokens.textMuted,
                              ),
                              filled: true,
                              fillColor: tokens.background,
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: tokens.borderSubtle),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: tokens.accent.safeWithOpacity(0.5),
                                  width: 1.5,
                                ),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: tokens.accent.safeWithOpacity(0.4),
                                ),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: tokens.accent.safeWithOpacity(0.6),
                                  width: 1.5,
                                ),
                              ),
                              errorStyle: TextStyle(
                                fontSize: 11,
                                color: tokens.accent.safeWithOpacity(0.8),
                              ),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 6),

                          // ── Hint text ──
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'This is how others will see you',
                              style: TextStyle(
                                fontSize: 11,
                                color: tokens.textMuted,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // ── About You / Description field ──
                          TextFormField(
                            controller: _aboutController,
                            textCapitalization: TextCapitalization.sentences,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _completeOnboarding(),
                            maxLines: 3,
                            maxLength: 150,
                            validator: (value) {
                              if (value != null && value.trim().length > 150) {
                                return 'Description is too long (max 150 characters)';
                              }
                              return null;
                            },
                            style: TextStyle(
                              color: tokens.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Tell us about yourself...',
                              hintStyle: TextStyle(
                                color: tokens.textMuted.safeWithOpacity(0.6),
                                fontSize: 15,
                              ),
                              prefixIcon: Padding(
                                padding: const EdgeInsets.only(bottom: 24),
                                child: Icon(
                                  Icons.badge_outlined,
                                  size: 20,
                                  color: tokens.textMuted,
                                ),
                              ),
                              filled: true,
                              fillColor: tokens.background,
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: tokens.borderSubtle),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: tokens.accent.safeWithOpacity(0.5),
                                  width: 1.5,
                                ),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: tokens.accent.safeWithOpacity(0.4),
                                ),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: tokens.accent.safeWithOpacity(0.6),
                                  width: 1.5,
                                ),
                              ),
                              errorStyle: TextStyle(
                                fontSize: 11,
                                color: tokens.accent.safeWithOpacity(0.8),
                              ),
                              isDense: true,
                              counterText: '',
                            ),
                          ),
                          const SizedBox(height: 6),

                          // ── Hint text for About You ──
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Write a description about yourself (bio)',
                              style: TextStyle(
                                fontSize: 11,
                                color: tokens.textMuted,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // ── Error message ──
                          if (_errorMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: tokens.accent.safeWithOpacity(0.08),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: tokens.accent.safeWithOpacity(0.2),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      size: 14,
                                      color: tokens.accent,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _errorMessage!,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: tokens.accent,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          // ── Get Started button ──
                          GestureDetector(
                            onTap: _isLoading ? null : _completeOnboarding,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOutCubic,
                              width: double.infinity,
                              height: 48,
                              decoration: BoxDecoration(
                                gradient: tokens.accentGradient,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: tokens.accent.safeWithOpacity(0.3),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.white),
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'Get Started',
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Icon(
                                            Icons.arrow_forward_rounded,
                                            size: 18,
                                            color: Colors.white
                                                .safeWithOpacity(0.9),
                                          ),
                                        ],
                                      ),
                              ),
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
        ],
      ),
    );
  }
}
