import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/motion.dart' as motion;
import '../../../shared/theme.dart';
import '../../../services/ambient_sound_service.dart';
import '../../../../core/providers.dart';
import 'ambient_sound_picker_sheet.dart';

class AmbientSoundMiniPlayer extends ConsumerWidget {
  const AmbientSoundMiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = FocusOsTheme.of(context);
    final audioState = ref.watch(ambientSoundProvider);
    final audioNotifier = ref.read(ambientSoundProvider.notifier);

    final currentType = audioState.type;
    final soundTitle = audioState.selectedCustomSoundId != null
        ? (audioState.activeCustomSound?.name ?? 'Custom Sound')
        : (currentType == AmbientSoundType.none
            ? (audioState.isCustomActive ? (audioState.customName ?? 'Custom Sound') : 'No Sound Selected')
            : currentType.title);

    return motion.PremiumEnterTransition(
      duration: const Duration(milliseconds: 600),
      child: Material(
        color: Colors.transparent,
        child: Container(
          height: 60,
          constraints: const BoxConstraints(maxWidth: 325),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: tokens.brightness == Brightness.dark
                      ? Colors.black.withValues(alpha: 0.45)
                      : Colors.white.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: tokens.brightness == Brightness.dark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.08),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  children: [
                    // LEFT: Sound Metadata (taps to open bottom sheet)
                    Expanded(
                      child: InkWell(
                        onTap: () => AmbientSoundPickerSheet.show(context),
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    soundTitle,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: tokens.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.keyboard_arrow_up_rounded,
                                  size: 14,
                                  color: tokens.textSecondary,
                                ),
                              ],
                            ),
                            const SizedBox(height: 1),
                            Text(
                              'Ambient Sound',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: tokens.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
  
                    const SizedBox(width: 8),
  
                    // RIGHT: Controls Row
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Previous Track
                        _ControlButton(
                          icon: Icons.skip_previous_rounded,
                          tooltip: 'Previous sound',
                          onTap: audioNotifier.previousSound,
                          tokens: tokens,
                        ),
                        const SizedBox(width: 6),
  
                        // Play/Pause Pill Button
                        _PlayPauseButton(
                          isPlaying: audioState.isPlaying,
                          onTap: audioNotifier.togglePlayPause,
                          tokens: tokens,
                        ),
                        const SizedBox(width: 6),
  
                        // Next Track
                        _ControlButton(
                          icon: Icons.skip_next_rounded,
                          tooltip: 'Next sound',
                          onTap: audioNotifier.nextSound,
                          tokens: tokens,
                        ),
                        const SizedBox(width: 8),
  
                        // Loop Toggle
                        _LoopButton(
                          isLooping: audioState.isLooping,
                          onTap: audioNotifier.toggleLoop,
                          tokens: tokens,
                        ),
                        const SizedBox(width: 8),
  
                        // Browse Library
                        _ControlButton(
                          icon: Icons.library_music_rounded,
                          tooltip: 'Choose sound...',
                          onTap: () => AmbientSoundPickerSheet.show(context),
                          tokens: tokens,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final ThemeTokens tokens;

  const _ControlButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: motion.PremiumHoverEffect(
        hoverScale: 1.15,
        pressScale: 0.9,
        onTap: onTap,
        child: Icon(
          icon,
          size: 18,
          color: tokens.textSecondary,
        ),
      ),
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onTap;
  final ThemeTokens tokens;

  const _PlayPauseButton({
    required this.isPlaying,
    required this.onTap,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: isPlaying ? 'Pause sound' : 'Play sound',
      child: motion.PremiumHoverEffect(
        hoverScale: 1.1,
        pressScale: 0.95,
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: tokens.accent,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: tokens.accent.withValues(alpha: 0.35),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(
            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            size: 18,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _LoopButton extends StatelessWidget {
  final bool isLooping;
  final VoidCallback onTap;
  final ThemeTokens tokens;

  const _LoopButton({
    required this.isLooping,
    required this.onTap,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: isLooping ? 'Disable loop' : 'Enable loop',
      child: motion.PremiumHoverEffect(
        hoverScale: 1.15,
        pressScale: 0.9,
        onTap: onTap,
        child: Icon(
          Icons.repeat_rounded,
          size: 18,
          color: isLooping ? tokens.accent : tokens.textSecondary,
        ),
      ),
    );
  }
}
