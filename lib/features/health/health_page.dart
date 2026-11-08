import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/motion.dart' as motion;
import '../../shared/theme.dart';
import '../../shared/widgets/premium_card.dart';
import '../../shared/widgets/shimmer_loading.dart';
import '../../core/providers.dart';

/// Health page — calm, premium interface for blue light, reminders, and 20-20-20 eye health.
class HealthPage extends ConsumerStatefulWidget {
  const HealthPage({super.key});

  @override
  ConsumerState<HealthPage> createState() => _HealthPageState();
}

class _HealthPageState extends ConsumerState<HealthPage> {
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToTop = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final show = _scrollController.offset > 400;
    if (show != _showScrollToTop) {
      setState(() => _showScrollToTop = show);
    }
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = FocusOsTheme.of(context);
    final blueLight = ref.watch(blueLightProvider);
    final eyeBreak = ref.watch(eyeBreakProvider);

    // Show shimmer skeleton while data is loading
    if (blueLight.isLoading || eyeBreak.isLoading) {
      return const HealthPageShimmer();
    }

    return motion.PremiumEnterTransition(
      duration: motion.PremiumDurations.pageTransition,
      child: Padding(
        padding: const EdgeInsets.only(left: 32, right: 32, top: 32, bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Text(
              'Health',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: tokens.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Eye care, posture, hydration, and wellness tools',
              style: TextStyle(fontSize: 13, color: tokens.textMuted),
            ),
            const SizedBox(height: 28),

            Expanded(
              child: Stack(
                children: [
                  SingleChildScrollView(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(
                        parent: ClampingScrollPhysics()),
                    child: motion.PremiumStaggeredEnter(
                  staggerDelay: const Duration(milliseconds: 60),
                  children: [
                    // ── Blue Light Filter ──
                    _HealthPanel(
                      title: 'Blue Light Filter',
                      subtitle: 'Reduce eye strain with warm display tones',
                      icon: Icons.light_mode_outlined,
                      tokens: tokens,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SettingsToggle(
                            label: 'Enable filter',
                            value: blueLight.enabled,
                            tokens: tokens,
                            onChanged: (v) =>
                                ref.read(blueLightProvider.notifier).setEnabled(v),
                          ),
                          const SizedBox(height: 12),
                          // Temperature slider
                          Row(
                            children: [
                              Text('6500K',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: tokens.textMuted)),
                              Expanded(
                                child: SliderTheme(
                                  data: SliderThemeData(
                                    trackHeight: 3,
                                    activeTrackColor: tokens.accent,
                                    inactiveTrackColor: tokens.borderSubtle,
                                    thumbColor: tokens.accent,
                                    overlayColor:
                                        tokens.accent.safeWithOpacity(0.1),
                                    thumbShape:
                                        const RoundSliderThumbShape(
                                            enabledThumbRadius: 6),
                                  ),
                                  child: Slider(
                                    value: (6500 - blueLight.temperature) /
                                        3100.0,
                                    onChanged: (v) {
                                      final kelvin = (6500 - (v * 3100))
                                          .round()
                                          .clamp(3400, 6500);
                                      ref
                                          .read(blueLightProvider.notifier)
                                          .setTemperature(kelvin);
                                    },
                                  ),
                                ),
                              ),
                              Text('3400K',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: tokens.textMuted)),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Daylight',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: tokens.textMuted)),
                              Text('Warm',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: tokens.textMuted)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _SettingsToggle(
                            label: 'Auto mode',
                            subtitle: 'Schedule by time',
                            value: blueLight.autoMode,
                            tokens: tokens,
                            onChanged: (v) =>
                                ref.read(blueLightProvider.notifier).setAutoMode(v),
                          ),
                          const SizedBox(height: 8),
                          _SettingsToggle(
                            label: 'Grayscale',
                            subtitle: 'Desaturate display',
                            value: blueLight.grayscale,
                            tokens: tokens,
                            onChanged: (v) =>
                                ref.read(blueLightProvider.notifier).setGrayscale(v),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Eye Care ──
                    _HealthPanel(
                      title: 'Eye Care',
                      subtitle: '20-20-20 rule, blink, and break reminders',
                      icon: Icons.visibility_outlined,
                      tokens: tokens,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SettingsToggle(
                            label: '20-20-20 Rule',
                            subtitle: 'Look 20ft away for 20s every 20min',
                            value: eyeBreak.twentyTwentyEnabled,
                            tokens: tokens,
                            onChanged: (v) => ref
                                .read(eyeBreakProvider.notifier)
                                .setTwentyTwenty(v),
                          ),
                          const SizedBox(height: 8),
                          _SettingsToggle(
                            label: 'Blink reminders',
                            subtitle: 'Gentle blink prompts',
                            value: eyeBreak.blinkReminders,
                            tokens: tokens,
                            onChanged: (v) => ref
                                .read(eyeBreakProvider.notifier)
                                .setBlinkReminders(v),
                          ),
                          const SizedBox(height: 8),
                          _SettingsToggle(
                            label: 'Break reminders',
                            subtitle: 'Stand up and stretch',
                            value: eyeBreak.breakReminders,
                            tokens: tokens,
                            onChanged: (v) => ref
                                .read(eyeBreakProvider.notifier)
                                .setBreakReminders(v),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Posture & Hydration ──
                    _HealthPanel(
                      title: 'Posture & Hydration',
                      subtitle: 'Physical wellness reminders',
                      icon: Icons.accessibility_new_outlined,
                      tokens: tokens,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SettingsToggle(
                            label: 'Posture reminders',
                            subtitle: 'Sit up straight',
                            value: eyeBreak.postureReminders,
                            tokens: tokens,
                            onChanged: (v) => ref
                                .read(eyeBreakProvider.notifier)
                                .setPostureReminders(v),
                          ),
                          const SizedBox(height: 8),
                          _SettingsToggle(
                            label: 'Hydration reminders',
                            subtitle: 'Drink water every 30min',
                            value: eyeBreak.hydrationReminders,
                            tokens: tokens,
                            onChanged: (v) => ref
                                .read(eyeBreakProvider.notifier)
                                .setHydrationReminders(v),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // ── Scroll-to-top FAB ──
              Positioned(
                  right: 16,
                  bottom: 16,
                  child: AnimatedScale(
                    scale: _showScrollToTop ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutBack,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _scrollToTop,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: tokens.accentGradient,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: tokens.accent.safeWithOpacity(0.35),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.keyboard_arrow_up_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
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
    );
  }
}


// ──────────────────────────────────────────────
// Health Panel — PremiumCard with section header
// ──────────────────────────────────────────────

class _HealthPanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final ThemeTokens tokens;
  final Widget child;

  const _HealthPanel({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tokens,
    required this.child,
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
            subtitle: subtitle,
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Settings Toggle — with PremiumToggle
// ──────────────────────────────────────────────

class _SettingsToggle extends StatelessWidget {
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final ThemeTokens tokens;

  const _SettingsToggle({
    required this.label,
    this.subtitle,
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                    if (subtitle != null)
                      Text(
                        subtitle!,
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
