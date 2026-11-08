import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/motion.dart' as motion;
import '../../../shared/theme.dart';
import '../../../services/ambient_sound_service.dart';
import '../../../../core/providers.dart';

class AmbientSoundPickerSheet extends ConsumerWidget {
  const AmbientSoundPickerSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      isScrollControlled: true,
      builder: (context) {
        return const AmbientSoundPickerSheet();
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = FocusOsTheme.of(context);
    final audioState = ref.watch(ambientSoundProvider);
    final audioNotifier = ref.read(ambientSoundProvider.notifier);

    // Group sounds by category
    final Map<String, List<AmbientSoundType>> grouped = {};
    for (final sound in AmbientSoundType.values) {
      if (sound == AmbientSoundType.none || sound == AmbientSoundType.cafe) continue;
      grouped.putIfAbsent(sound.category, () => []).add(sound);
    }

    final Map<String, List<CustomSound>> customGrouped = {};
    for (final sound in audioState.customSounds) {
      customGrouped.putIfAbsent(sound.category, () => []).add(sound);
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: BoxDecoration(
        color: tokens.brightness == Brightness.dark
            ? const Color(0xFF141414).withValues(alpha: 0.95)
            : const Color(0xFFFAF9F6).withValues(alpha: 0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        border: Border.all(
          color: tokens.brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.08),
          width: 0.8,
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Pull handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: tokens.textMuted.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Title Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Ambient Library',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: tokens.textPrimary,
                        letterSpacing: -0.4,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: tokens.textSecondary, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Sound list categories
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    children: [
                      // 1. Bundled Categories
                      ...grouped.keys.map((category) {
                        final sounds = grouped[category]!;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 16, bottom: 10),
                              child: Text(
                                category.toUpperCase(),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: tokens.textMuted,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 8,
                                crossAxisSpacing: 8,
                                childAspectRatio: 2.9,
                              ),
                              itemCount: sounds.length,
                              itemBuilder: (context, index) {
                                final sound = sounds[index];
                                final isSelected = audioState.type == sound && audioState.selectedCustomSoundId == null;

                                return motion.PremiumHoverEffect(
                                  hoverScale: 1.02,
                                  pressScale: 0.98,
                                  onTap: () => audioNotifier.setType(sound),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? tokens.accent.withValues(alpha: tokens.brightness == Brightness.dark ? 0.12 : 0.06)
                                          : tokens.surface.withValues(alpha: 0.35),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: isSelected
                                            ? tokens.accent.withValues(alpha: 0.35)
                                            : tokens.borderSubtle,
                                        width: 1,
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                      child: Row(
                                        children: [
                                          Icon(
                                            isSelected
                                                ? (audioState.isPlaying ? Icons.volume_up_rounded : Icons.volume_mute_rounded)
                                                : Icons.play_circle_outline_rounded,
                                            color: isSelected ? tokens.accent : tokens.textSecondary,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              sound.title,
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 12,
                                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                                color: isSelected ? tokens.textPrimary : tokens.textSecondary,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        );
                      }),

                      // 2. Custom Categories
                      if (customGrouped.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.only(top: 24, bottom: 8),
                          child: Divider(height: 1),
                        ),
                        ...customGrouped.keys.map((category) {
                          final sounds = customGrouped[category]!;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 16, bottom: 10),
                                child: Text(
                                  category.toUpperCase(),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: tokens.textMuted,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 8,
                                  crossAxisSpacing: 8,
                                  childAspectRatio: 2.9,
                                ),
                                itemCount: sounds.length,
                                itemBuilder: (context, index) {
                                  final sound = sounds[index];
                                  final isSelected = audioState.selectedCustomSoundId == sound.id;

                                  return motion.PremiumHoverEffect(
                                    hoverScale: 1.02,
                                    pressScale: 0.98,
                                    onTap: () => audioNotifier.setCustomType(sound),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? tokens.accent.withValues(alpha: tokens.brightness == Brightness.dark ? 0.12 : 0.06)
                                            : tokens.surface.withValues(alpha: 0.35),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: isSelected
                                              ? tokens.accent.withValues(alpha: 0.35)
                                              : tokens.borderSubtle,
                                          width: 1,
                                        ),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                        child: Row(
                                          children: [
                                            Icon(
                                              isSelected
                                                  ? (audioState.isPlaying ? Icons.volume_up_rounded : Icons.volume_mute_rounded)
                                                  : Icons.play_circle_outline_rounded,
                                              color: isSelected ? tokens.accent : tokens.textSecondary,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                sound.name,
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 12,
                                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                                  color: isSelected ? tokens.textPrimary : tokens.textSecondary,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          );
                        }),
                      ],
                    ],
                  ),
                ),

                const Divider(height: 24),

                // Volume slider section
                Row(
                  children: [
                    Icon(
                      audioState.volume == 0
                          ? Icons.volume_mute_rounded
                          : (audioState.volume < 0.5 ? Icons.volume_down_rounded : Icons.volume_up_rounded),
                      color: tokens.textSecondary,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SliderTheme(
                        data: SliderThemeData(
                          activeTrackColor: tokens.accent,
                          inactiveTrackColor: tokens.borderSubtle,
                          thumbColor: tokens.accent,
                          overlayColor: tokens.accent.withValues(alpha: 0.2),
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                        ),
                        child: Slider(
                          value: audioState.volume,
                          onChanged: audioNotifier.setVolume,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(audioState.volume * 100).round()}%',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: tokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
