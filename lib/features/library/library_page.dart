import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../shared/motion.dart' as motion;
import '../../shared/theme.dart';
import '../../shared/widgets/premium_card.dart';
import '../../shared/widgets/shimmer_loading.dart';
import '../../core/providers.dart';
import '../../services/ambient_sound_service.dart';

/// Library page — elegant card-based browsing for ambient sounds,
/// focus scenes, templates, and user-imported assets.
class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _indicatorController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _indicatorController = AnimationController(
      vsync: this,
      duration: motion.PremiumDurations.panelSlide,
    );
    _tabController.addListener(() {
      if (!mounted) return;
      if (!_tabController.indexIsChanging) {
        _indicatorController.forward(from: 0);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _indicatorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = FocusOsTheme.of(context);
    final soundState = ref.watch(ambientSoundProvider);

    // Show shimmer skeleton while ambient sounds are loading
    if (soundState.isLoading) {
      return const LibraryPageShimmer();
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
              'Library',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: tokens.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Ambient sounds, fokus scenes, and session templates',
              style: TextStyle(fontSize: 13, color: tokens.textMuted),
            ),
            const SizedBox(height: 24),

            // ── Premium Tab Bar ──
            Container(
              decoration: BoxDecoration(
                color: tokens.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: tokens.borderSubtle),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: tokens.accent.safeWithOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: tokens.accent,
                unselectedLabelColor: tokens.textSecondary,
                labelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
                tabs: const [
                  Tab(text: 'Sounds'),
                  Tab(text: 'Scenes'),
                  Tab(text: 'Templates'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Animated Tab Content ──
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
                  key: ValueKey('tab_${_tabController.index}'),
                  child: TabBarView(
                    controller: _tabController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      const _SoundsTab(),
                      _ScenesTab(),
                      _TemplatesTab(),
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
// Sounds Tab
// ──────────────────────────────────────────────

class _SoundsTab extends ConsumerStatefulWidget {
  const _SoundsTab();

  @override
  ConsumerState<_SoundsTab> createState() => _SoundsTabState();
}

class _SoundsTabState extends ConsumerState<_SoundsTab> {
  bool _isPicking = false;

  Future<void> _pickAudioFile() async {
    if (_isPicking) return;
    setState(() => _isPicking = true);

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'ogg', 'aac', 'm4a'],
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        final name = result.files.single.name;
        final nameWithoutExt = name.contains('.')
            ? name.substring(0, name.lastIndexOf('.'))
            : name;

        ref.read(ambientSoundProvider.notifier).setCustomSound(path, nameWithoutExt);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to import audio: $e'),
            backgroundColor: FocusOsTheme.of(context).surfaceAlt,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPicking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = FocusOsTheme.of(context);
    final soundState = ref.watch(ambientSoundProvider);

    final defaultSounds = [
      _SoundAsset(AmbientSoundType.rain, 'Rain', 'Calming rainfall', Icons.water_drop_outlined),
      _SoundAsset(AmbientSoundType.cafe, 'Cafe', 'Coffee shop ambiance', Icons.local_cafe_outlined),
      _SoundAsset(AmbientSoundType.whiteNoise, 'White Noise', 'Soothing static', Icons.graphic_eq_outlined),
      _SoundAsset(AmbientSoundType.none, 'None', 'Silence', Icons.volume_off_outlined),
    ];

    final hasCustom = soundState.customPath != null;
    final gridItemsCount = defaultSounds.length + (hasCustom ? 1 : 0) + 1;

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.3,
      ),
      physics: const BouncingScrollPhysics(parent: ClampingScrollPhysics()),
      itemCount: gridItemsCount,
      itemBuilder: (context, index) {
        // 1. Default Sounds
        if (index < defaultSounds.length) {
          final sound = defaultSounds[index];
          final isActive = soundState.type == sound.type && !soundState.isCustomActive;

          return _AssetCard(
            title: sound.title,
            subtitle: sound.subtitle,
            icon: sound.icon,
            isActive: isActive,
            onTap: () {
              final notifier = ref.read(ambientSoundProvider.notifier);
              if (isActive) {
                notifier.setType(AmbientSoundType.none);
              } else {
                notifier.setType(sound.type);
              }
            },
            tokens: tokens,
          );
        }

        // 2. Custom Sound Card (if exists)
        if (hasCustom && index == defaultSounds.length) {
          final isActive = soundState.isCustomActive;

          return PremiumCard(
            padding: const EdgeInsets.all(16),
            borderRadius: BorderRadius.circular(12),
            isActive: isActive,
            onTap: () {
              ref.read(ambientSoundProvider.notifier).toggleCustomSound();
            },
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isActive
                            ? tokens.accent.safeWithOpacity(0.15)
                            : tokens.borderSubtle,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.music_note_outlined,
                        size: 18,
                        color: isActive ? tokens.accent : tokens.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      soundState.customName ?? 'Custom Sound',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isActive ? tokens.accent : tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Custom Audio',
                      style: TextStyle(fontSize: 11, color: tokens.textMuted),
                    ),
                  ],
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () {
                      ref.read(ambientSoundProvider.notifier).removeCustomSound();
                    },
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: tokens.borderSubtle.safeWithOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.delete_outline,
                          size: 14,
                          color: tokens.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // 3. Import Sound Card (the last card)
        return PremiumCard(
          padding: const EdgeInsets.all(16),
          borderRadius: BorderRadius.circular(12),
          isActive: false,
          onTap: _pickAudioFile,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: tokens.borderSubtle,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: _isPicking
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(tokens.accent),
                          ),
                        ),
                      )
                    : Icon(
                        Icons.add_to_photos_outlined,
                        size: 18,
                        color: tokens.textSecondary,
                      ),
              ),
              const Spacer(),
              Text(
                'Import Sound',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _isPicking ? 'Browsing...' : 'Add local audio file',
                style: TextStyle(fontSize: 11, color: tokens.textMuted),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ──────────────────────────────────────────────
// Scenes Tab
// ──────────────────────────────────────────────

class _ScenesTab extends ConsumerWidget {
  const _ScenesTab();

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

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.3,
      ),
      physics: const BouncingScrollPhysics(parent: ClampingScrollPhysics()),
      itemCount: scenes.length,
      itemBuilder: (context, index) {
        final scene = scenes[index];
        final isActive = activeScene.id == scene.id;

        return _AssetCard(
          title: scene.name,
          subtitle: scene.description,
          icon: scene.icon,
          isActive: isActive,
          onTap: () {
            ref.read(fokusSceneProvider.notifier).setScene(scene.id);
            if (scene.variants.length > 1) {
              _showVariantSelector(context, ref, scene, tokens);
            }
          },
          tokens: tokens,
        );
      },
    );
  }
}

// ──────────────────────────────────────────────
// Templates Tab
// ──────────────────────────────────────────────

class _TemplatesTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = FocusOsTheme.of(context);

    final templates = [
      _TemplateAsset('Pomodoro', '25 min fokus + 5 min break', '25', '5'),
      _TemplateAsset('Deep Work', '52 min fokus + 17 min break', '52', '17'),
      _TemplateAsset('Quick Sprint', '15 min fokus + 3 min break', '15', '3'),
      _TemplateAsset('Marathon', '90 min fokus + 20 min break', '90', '20'),
      _TemplateAsset('Custom', 'Set your own timers', 'custom'),
    ];

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.3,
      ),
      physics: const BouncingScrollPhysics(parent: ClampingScrollPhysics()),
      itemCount: templates.length,
      itemBuilder: (context, index) {
        final tpl = templates[index];

        return _TemplateCard(
          title: tpl.title,
          subtitle: tpl.subtitle,
          isActive: index == 0,
          onTap: () {
            if (tpl.fokusMinutes != 'custom') {
              final focusMins = int.parse(tpl.fokusMinutes);
              ref.read(timerProvider.notifier).setDuration(focusMins * 60);
            }
          },
          tokens: tokens,
        );
      },
    );
  }
}

// ──────────────────────────────────────────────
// Asset Card — PremiumCard with hover
// ──────────────────────────────────────────────

class _AssetCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;
  final ThemeTokens tokens;

  const _AssetCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isActive,
    required this.onTap,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(12),
      isActive: isActive,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isActive
                  ? tokens.accent.safeWithOpacity(0.15)
                  : tokens.borderSubtle,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 18,
              color: isActive ? tokens.accent : tokens.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isActive ? tokens.accent : tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(fontSize: 11, color: tokens.textMuted),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Template Card — PremiumCard with active badge
// ──────────────────────────────────────────────

class _TemplateCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isActive;
  final VoidCallback onTap;
  final ThemeTokens tokens;

  const _TemplateCard({
    required this.title,
    required this.subtitle,
    required this.isActive,
    required this.onTap,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(12),
      isActive: isActive,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isActive
                      ? tokens.accent.safeWithOpacity(0.15)
                      : tokens.borderSubtle,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.timer_outlined,
                  size: 18,
                  color: isActive ? tokens.accent : tokens.textSecondary,
                ),
              ),
              if (isActive)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: tokens.accent.safeWithOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Active',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: tokens.accent,
                    ),
                  ),
                ),
            ],
          ),
          const Spacer(),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isActive ? tokens.accent : tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(fontSize: 11, color: tokens.textMuted),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Data models
// ──────────────────────────────────────────────

class _SoundAsset {
  final AmbientSoundType type;
  final String title;
  final String subtitle;
  final IconData icon;

  const _SoundAsset(this.type, this.title, this.subtitle, this.icon);
}

class _TemplateAsset {
  final String title;
  final String subtitle;
  final String fokusMinutes;
  final String? breakMinutes;

  const _TemplateAsset(this.title, this.subtitle, this.fokusMinutes, [this.breakMinutes]);
}
