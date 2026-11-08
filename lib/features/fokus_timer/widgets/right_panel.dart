import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/motion.dart' as motion;
import '../../../shared/theme.dart';
import '../../../core/providers.dart';
import '../../../core/navigation.dart';
import '../../../services/ambient_sound_service.dart';
import '../../../services/fokus_history_service.dart';
import '../../../models/quick_capture_item.dart';

/// Right panel — Ambient sound, Quick Capture, Tips, Session summary.
class RightPanel extends ConsumerWidget {
  const RightPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = FocusOsTheme.of(context);
    final timerState = ref.watch(timerProvider);
    final totalSessions = FokusHistoryService.totalSessionsCount();
    final averageMin = FokusHistoryService.averageMinutes();
    final todayMinutes = FokusHistoryService.todayMinutes();

    return Container(
      width: 320,
      margin: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            // ── Ambient Sound ──
            const _RightPanelSection(
              title: 'Soundscape',
              icon: Icons.headphones_outlined,
              child: _AmbientSoundControls(),
            ),
            const SizedBox(height: 12),

            // ── Quick Capture ──
            const _RightPanelSection(
              title: 'Quick Capture',
              icon: Icons.bolt_outlined,
              child: _QuickCaptureCard(),
            ),
            const SizedBox(height: 12),

            // ── Session Summary ──
            _RightPanelSection(
              title: 'Session Summary',
              icon: Icons.analytics_outlined,
              child: Column(
                children: [
                  _StatRow(
                    label: 'Sessions completed',
                    value: '$totalSessions',
                    tokens: tokens,
                  ),
                  const SizedBox(height: 6),
                  _StatRow(
                    label: 'Avg session length',
                    value: averageMin >= 1
                        ? '${averageMin.toStringAsFixed(0)} min'
                        : '—',
                    tokens: tokens,
                  ),
                  const SizedBox(height: 6),
                  _StatRow(
                    label: 'Today total',
                    value: todayMinutes > 0
                        ? '${todayMinutes ~/ 60}h ${todayMinutes % 60}m'
                        : '—',
                    tokens: tokens,
                  ),
                  const SizedBox(height: 10),
                  // Current session indicator
                  if (timerState.elapsed > 0)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: timerState.running
                            ? tokens.accent.withValues(alpha: 0.08)
                            : tokens.borderSubtle.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: timerState.running
                                  ? tokens.accent
                                  : tokens.textMuted,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            timerState.running
                                ? 'Session in progress'
                                : 'Session paused',
                            style: TextStyle(
                              fontSize: 11,
                              color: timerState.running
                                  ? tokens.accent
                                  : tokens.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Productivity Tip ──
            const _ProductivityTip(),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Right Panel Section
// ──────────────────────────────────────────────

class _RightPanelSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _RightPanelSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = FocusOsTheme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: tokens.borderSubtle.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: tokens.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, size: 14, color: tokens.accent),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: tokens.textSecondary,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Ambient Sound Controls
// ──────────────────────────────────────────────

class _AmbientSoundControls extends ConsumerWidget {
  const _AmbientSoundControls();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = FocusOsTheme.of(context);
    final soundState = ref.watch(ambientSoundProvider);

    final sounds = [
      (AmbientSoundType.rain, Icons.water_drop_outlined, 'Rain'),
      (AmbientSoundType.cafe, Icons.coffee_outlined, 'Cafe'),
      (AmbientSoundType.whiteNoise, Icons.graphic_eq, 'White Noise'),
    ];

    return Column(
      children: [
        // Sound type buttons
        Row(
          children: List.generate(sounds.length, (index) {
            final sound = sounds[index];
            final isActive = soundState.type == sound.$1 && soundState.isPlaying;

            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: index < sounds.length - 1 ? 6 : 0,
                ),
                child: motion.HoverBuilder(
                  onTap: () {
                    if (isActive) {
                      ref.read(ambientSoundProvider.notifier).toggle();
                    } else {
                      ref.read(ambientSoundProvider.notifier).setType(sound.$1);
                    }
                  },
                  hoverScale: 1.03,
                  pressScale: 0.96,
                  builder: (context, hovered, pressed) {
                    return AnimatedContainer(
                      duration: motion.PremiumDurations.hover,
                      curve: motion.PremiumCurves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isActive
                            ? tokens.accent.withValues(alpha: 0.1)
                            : hovered
                                ? tokens.textPrimary.withValues(alpha: 0.03)
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isActive
                              ? tokens.accent.withValues(alpha: 0.25)
                              : hovered
                                  ? tokens.borderMedium.withValues(alpha: 0.3)
                                  : Colors.transparent,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            sound.$2,
                            size: 18,
                            color: isActive
                                ? tokens.accent
                                : hovered
                                    ? tokens.textPrimary
                                    : tokens.textSecondary,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            sound.$3,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight:
                                  isActive ? FontWeight.w600 : FontWeight.w400,
                              color: isActive
                                  ? tokens.accent
                                  : tokens.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            );
          }),
        ),

        // Volume slider
        if (soundState.isPlaying) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                soundState.volume < 0.01
                    ? Icons.volume_mute_outlined
                    : soundState.volume < 0.5
                        ? Icons.volume_down_outlined
                        : Icons.volume_up_outlined,
                size: 14,
                color: tokens.textSecondary,
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 5,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 15,
                    ),
                    activeTrackColor: tokens.accent,
                    inactiveTrackColor: tokens.borderSubtle,
                    thumbColor: tokens.accent,
                    overlayColor: tokens.accent.withValues(alpha: 0.1),
                  ),
                  child: Slider(
                    value: soundState.volume,
                    onChanged: (v) =>
                        ref.read(ambientSoundProvider.notifier).setVolume(v),
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

// ──────────────────────────────────────────────
// Quick Capture Card
// ──────────────────────────────────────────────

class _QuickCaptureCard extends ConsumerWidget {
  const _QuickCaptureCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = FocusOsTheme.of(context);
    final List<QuickCaptureItem> captures = ref.watch(quickCaptureProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Capture button
        motion.HoverBuilder(
          onTap: () =>
              ref.read(quickCaptureOpenProvider.notifier).state = true,
          hoverScale: 1.01,
          pressScale: 0.98,
          builder: (context, hovered, pressed) {
            return AnimatedContainer(
              duration: motion.PremiumDurations.hover,
              curve: motion.PremiumCurves.easeOutCubic,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: hovered
                    ? tokens.textPrimary.withValues(alpha: 0.04)
                    : tokens.background.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: hovered
                      ? tokens.borderMedium.withValues(alpha: 0.3)
                      : Colors.transparent,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.add_rounded,
                    size: 16,
                    color: hovered ? tokens.textPrimary : tokens.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Quick capture...',
                    style: TextStyle(
                      fontSize: 12,
                      color: tokens.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          },
        ),

        // Recent captures
        if (captures.isNotEmpty) ...[
          const SizedBox(height: 10),
          ...captures.take(3).map(
                (capture) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 4,
                        height: 4,
                        margin: const EdgeInsets.only(top: 5, right: 8),
                        decoration: BoxDecoration(
                          color: tokens.textMuted.withValues(alpha: 0.4),
                          shape: BoxShape.circle,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          capture.text,
                          style: TextStyle(
                            fontSize: 11,
                            color: tokens.textSecondary,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ],
    );
  }
}

// ──────────────────────────────────────────────
// Stat Row
// ──────────────────────────────────────────────

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final ThemeTokens tokens;

  const _StatRow({
    required this.label,
    required this.value,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: tokens.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: tokens.textPrimary,
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────
// Productivity Tip
// ──────────────────────────────────────────────

class _ProductivityTip extends StatefulWidget {
  const _ProductivityTip();

  @override
  State<_ProductivityTip> createState() => _ProductivityTipState();
}

class _ProductivityTipState extends State<_ProductivityTip> {
  final _tips = [
    'Work in focused 90-minute blocks — your brain\'s ultradian rhythm.',
    'Take a 5-min break every 25 minutes to maintain peak fokus.',
    'Keep your workspace clutter-free for better concentration.',
    'Stay hydrated — even mild dehydration impacts cognitive performance.',
    'The 2-minute rule: if it takes <2 min, do it now.',
    'Turn off all notifications during deep work sessions.',
    'Use the Pomodoro technique to train your fokus muscle.',
    'Your environment affects productivity. Try ambient noise.',
    'Review your day\'s wins every evening to reinforce habits.',
    'Batch similar tasks together to reduce context switching.',
  ];

  late String _currentTip;

  @override
  void initState() {
    super.initState();
    _currentTip = _tips[DateTime.now().millisecondsSinceEpoch % _tips.length];
  }

  @override
  Widget build(BuildContext context) {
    final tokens = FocusOsTheme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            tokens.accent.withValues(alpha: 0.06),
            tokens.accentSecondary.withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: tokens.accent.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: tokens.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.lightbulb_outline,
              size: 13,
              color: tokens.accent,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tip',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: tokens.accent,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _currentTip,
                  style: TextStyle(
                    fontSize: 12,
                    color: tokens.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
