import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/motion.dart' as motion;
import '../../../shared/theme.dart';
import '../../../core/providers.dart';

/// Premium segmented control for timer duration presets.
/// [15m] [25m] [45m] [60m] with smooth transitions and hover effects.
class FocusTimerPresets extends ConsumerWidget {
  const FocusTimerPresets({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = FocusOsTheme.of(context);
    final currentTotal = ref.watch(timerProvider.select((s) => s.totalSeconds));
    final isRunning = ref.watch(timerProvider.select((s) => s.running));

    final presets = [
      ('15m', 900),
      ('25m', 1500),
      ('45m', 2700),
      ('60m', 3600),
      ('∞', 0),
    ];

    final isCustomSelected = !presets.any((p) => p.$2 == currentTotal);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: tokens.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: tokens.borderSubtle.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...List.generate(presets.length, (index) {
            final preset = presets[index];
            final isSelected = preset.$2 == currentTotal;

            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: motion.PremiumHoverEffect(
                hoverScale: 1.03,
                pressScale: 0.96,
                onTap: isRunning
                    ? null
                    : () =>
                        ref.read(timerProvider.notifier).setDuration(preset.$2),
                child: AnimatedContainer(
                  duration: motion.PremiumDurations.panelSlide,
                  curve: motion.PremiumCurves.springyOut,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? tokens.accent.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? tokens.accent.withValues(alpha: 0.3)
                          : Colors.transparent,
                    ),
                  ),
                  child: Text(
                    preset.$1,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected
                          ? tokens.accent
                          : tokens.textSecondary,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
            );
          }),
          // Custom
          motion.PremiumHoverEffect(
            hoverScale: 1.03,
            pressScale: 0.96,
            onTap: isRunning
                ? null
                : () => _showCustomDurationDialog(context, ref),
            child: AnimatedContainer(
              duration: motion.PremiumDurations.panelSlide,
              curve: motion.PremiumCurves.springyOut,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: isCustomSelected
                    ? tokens.accent.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isCustomSelected
                      ? tokens.accent.withValues(alpha: 0.3)
                      : Colors.transparent,
                ),
              ),
              child: Text(
                'Custom',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isCustomSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isCustomSelected
                      ? tokens.accent
                      : tokens.textSecondary,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Manual timer input with premium styling
class CustomTimerInput extends ConsumerStatefulWidget {
  const CustomTimerInput({super.key});

  @override
  ConsumerState<CustomTimerInput> createState() => _CustomTimerInputState();
}

class _CustomTimerInputState extends ConsumerState<CustomTimerInput> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.text = '30';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setTimer(int mins) {
    if (mins > 0 && mins <= 480) {
      ref.read(timerProvider.notifier).setDuration(mins * 60);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = FocusOsTheme.of(context);
    final isRunning = ref.watch(timerProvider.select((s) => s.running));

    return Container(
      decoration: BoxDecoration(
        color: tokens.surface.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: tokens.borderSubtle.withValues(alpha: 0.5),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer_outlined,
            size: 14,
            color: tokens.textMuted,
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 48,
            child: TextField(
              controller: _controller,
              enabled: !isRunning,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: tokens.textPrimary,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                hintText: '30',
                hintStyle: TextStyle(
                  color: tokens.textMuted,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'min',
            style: TextStyle(
              fontSize: 12,
              color: tokens.textMuted,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: isRunning
                ? null
                : () => _setTimer(int.tryParse(_controller.text) ?? 30),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: tokens.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Set',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: tokens.accent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void _showCustomDurationDialog(BuildContext context, WidgetRef ref) {
  final tokens = FocusOsTheme.of(context);
  final controller = TextEditingController(text: '30');

  showDialog(
    context: context,
    builder: (context) {
      return Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 320,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: tokens.borderSubtle),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 40,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.timer_outlined, color: tokens.accent, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Custom Duration',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: tokens.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Set a custom fokus duration in minutes:',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: tokens.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: tokens.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: tokens.borderSubtle),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          keyboardType: TextInputType.number,
                          autofocus: true,
                          style: GoogleFonts.plusJakartaSans(
                            color: tokens.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: '30',
                            isDense: true,
                          ),
                        ),
                      ),
                      Text(
                        'min',
                        style: GoogleFonts.plusJakartaSans(
                          color: tokens.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.plusJakartaSans(
                          color: tokens.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tokens.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        final mins = int.tryParse(controller.text) ?? 30;
                        if (mins > 0 && mins <= 480) {
                          ref.read(timerProvider.notifier).setDuration(mins * 60);
                        }
                        Navigator.pop(context);
                      },
                      child: Text(
                        'Set Timer',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

