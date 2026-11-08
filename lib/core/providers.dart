import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:window_manager/window_manager.dart' as wm;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/task.dart';
import '../models/fokus_session.dart';
import '../models/habit.dart';
import '../models/quick_capture_item.dart';
import '../models/timeline_goal.dart';
import '../models/reminder.dart';
import '../services/ambient_sound_service.dart';
import '../services/blue_light_service.dart';
import '../services/sound_service.dart';
import '../services/timer_sound_service.dart';
import '../services/fokus_history_service.dart';
import '../services/habit_service.dart';
import '../services/analytics_service.dart';
import '../services/notification_service.dart';
import '../shared/widgets/brain_dump_overlay.dart';
import '../shared/theme_definitions.dart';

// ──────────────────────────────────────────────
// Theme Provider
// ──────────────────────────────────────────────

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeDefinition>((ref) => ThemeNotifier());

class ThemeNotifier extends StateNotifier<ThemeDefinition> {
  ThemeNotifier() : super(AppThemes.oceanicLight) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString('active_theme_id');
    if (savedId != null) {
      state = AppThemes.byId(savedId);
    } else {
      state = AppThemes.oceanicLight;
    }
  }

  Future<void> setTheme(String id) async {
    state = AppThemes.byId(id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_theme_id', id);
  }
}

// ──────────────────────────────────────────────
// Focus Scene Provider
// ──────────────────────────────────────────────

final fokusSceneProvider = StateNotifierProvider<FocusSceneNotifier, FocusScene>((ref) => FocusSceneNotifier());

class FocusSceneNotifier extends StateNotifier<FocusScene> {
  FocusSceneNotifier() : super(AppScenes.none) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString('active_scene_id');
    if (savedId != null) {
      var scene = AppScenes.byId(savedId);
      final savedImagePath = prefs.getString('active_scene_image_path_$savedId');
      if (savedImagePath != null && savedImagePath.isNotEmpty) {
        scene = scene.copyWith(imagePath: savedImagePath);
      }
      state = scene;
    }
  }

  Future<void> setScene(String id) async {
    final prefs = await SharedPreferences.getInstance();
    var scene = AppScenes.byId(id);
    final savedImagePath = prefs.getString('active_scene_image_path_$id');
    if (savedImagePath != null && savedImagePath.isNotEmpty) {
      scene = scene.copyWith(imagePath: savedImagePath);
    }
    state = scene;
    await prefs.setString('active_scene_id', id);
  }

  Future<void> setSceneVariant(String sceneId, String imagePath) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_scene_image_path_$sceneId', imagePath);
    if (state.id == sceneId) {
      state = state.copyWith(imagePath: imagePath);
    }
  }
}

// ──────────────────────────────────────────────
// Keyboard Shortcuts Toggle
// ──────────────────────────────────────────────

final keyboardShortcutsProvider = StateNotifierProvider<KeyboardShortcutsNotifier, bool>((ref) => KeyboardShortcutsNotifier());

class KeyboardShortcutsNotifier extends StateNotifier<bool> {
  KeyboardShortcutsNotifier() : super(true) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool('keyboard_shortcuts_enabled') ?? true;
  }

  Future<void> setEnabled(bool v) async {
    state = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('keyboard_shortcuts_enabled', v);
  }

  void toggle() => setEnabled(!state);
}

// ──────────────────────────────────────────────
// Fullscreen Mode
// ──────────────────────────────────────────────

final fullscreenProvider =
    StateNotifierProvider<FullscreenNotifier, bool>((ref) => FullscreenNotifier());

class FullscreenNotifier extends StateNotifier<bool> {
  FullscreenNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = prefs.getBool('fullscreen_enabled') ?? false;
    } catch (_) {}
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('fullscreen_enabled', state);
    } catch (_) {}
  }

  void setFullscreen(bool v) {
    state = v;
    _persist();
  }

  void toggle() {
    state = !state;
    _persist();
  }
}

// ──────────────────────────────────────────────
// User Profile
// ──────────────────────────────────────────────

class UserProfile {
  final String name;
  final String email;
  final String avatarBase64;
  final int lifetimeFocusTasks;
  final String status;

  const UserProfile({
    this.name = 'User',
    this.email = 'user@fokus.app',
    this.avatarBase64 = '',
    this.lifetimeFocusTasks = 0,
    this.status = 'Fokus operative',
  });

  UserProfile copyWith({
    String? name,
    String? email,
    String? avatarBase64,
    int? lifetimeFocusTasks,
    String? status,
  }) =>
      UserProfile(
        name: name ?? this.name,
        email: email ?? this.email,
        avatarBase64: avatarBase64 ?? this.avatarBase64,
        lifetimeFocusTasks: lifetimeFocusTasks ?? this.lifetimeFocusTasks,
        status: status ?? this.status,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'email': email,
        'avatarBase64': avatarBase64,
        'lifetimeFocusTasks': lifetimeFocusTasks,
        'status': status,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        name: json['name'] as String? ?? 'User',
        email: json['email'] as String? ?? 'user@fokus.app',
        avatarBase64: json['avatarBase64'] as String? ?? '',
        lifetimeFocusTasks: json['lifetimeFocusTasks'] as int? ?? 0,
        status: json['status'] as String? ?? 'Fokus operative',
      );
}

final userProfileProvider =
    StateNotifierProvider<UserProfileNotifier, UserProfile>((ref) => UserProfileNotifier());

class UserProfileNotifier extends StateNotifier<UserProfile> {
  UserProfileNotifier() : super(const UserProfile()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('user_profile');
    if (raw != null) {
      try {
        final json = Map<String, dynamic>.from(
            jsonDecode(raw) as Map);
        state = UserProfile.fromJson(json);
      } catch (_) {}
    }
  }

  Future<void> _persist() async {
    final localState = state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_profile', jsonEncode(localState.toJson()));
  }

  void updateName(String name) {
    state = state.copyWith(name: name);
    _persist();
  }

  void updateEmail(String email) {
    state = state.copyWith(email: email);
    _persist();
  }

  void updateAvatar(String base64) {
    state = state.copyWith(avatarBase64: base64);
    _persist();
  }

  void incrementLifetimeTasks() {
    state = state.copyWith(lifetimeFocusTasks: state.lifetimeFocusTasks + 1);
    _persist();
  }

  void updateStatus(String status) {
    state = state.copyWith(status: status);
    _persist();
  }

  void restoreFromJson(Map<String, dynamic> json) {
    state = UserProfile.fromJson(json);
    _persist();
  }
}

// ──────────────────────────────────────────────
// Blue Light Filter (enhanced)
// ──────────────────────────────────────────────

class BlueLightState {
  final bool enabled;
  final int temperature;
  final bool autoMode;
  final int scheduledStartHour;
  final int scheduledStartMinute;
  final int scheduledEndHour;
  final int scheduledEndMinute;
  final bool sessionLinked;
  final bool grayscale;
  final String? activePreset;
  final bool isLoading;

  const BlueLightState({
    this.enabled = false,
    this.temperature = 4500,
    this.autoMode = false,
    this.scheduledStartHour = 20,
    this.scheduledStartMinute = 0,
    this.scheduledEndHour = 7,
    this.scheduledEndMinute = 0,
    this.sessionLinked = false,
    this.grayscale = false,
    this.activePreset,
    this.isLoading = true,
  });

  double get intensity => ColorTemperature.kelvinToIntensity(temperature);

  BlueLightSettings toSettings() => BlueLightSettings(
        enabled: enabled,
        temperature: temperature,
        autoMode: autoMode,
        scheduledStartHour: scheduledStartHour,
        scheduledStartMinute: scheduledStartMinute,
        scheduledEndHour: scheduledEndHour,
        scheduledEndMinute: scheduledEndMinute,
        sessionLinked: sessionLinked,
        grayscale: grayscale,
        activePreset: activePreset,
      );

  factory BlueLightState.fromSettings(BlueLightSettings s) => BlueLightState(
        enabled: s.enabled,
        temperature: s.temperature,
        autoMode: s.autoMode,
        scheduledStartHour: s.scheduledStartHour,
        scheduledStartMinute: s.scheduledStartMinute,
        scheduledEndHour: s.scheduledEndHour,
        scheduledEndMinute: s.scheduledEndMinute,
        sessionLinked: s.sessionLinked,
        grayscale: s.grayscale,
        activePreset: s.activePreset,
      );

  BlueLightState copyWith({
    bool? enabled,
    int? temperature,
    bool? autoMode,
    int? scheduledStartHour,
    int? scheduledStartMinute,
    int? scheduledEndHour,
    int? scheduledEndMinute,
    bool? sessionLinked,
    bool? grayscale,
    String? activePreset,
    bool? isLoading,
  }) =>
      BlueLightState(
        enabled: enabled ?? this.enabled,
        temperature: temperature ?? this.temperature,
        autoMode: autoMode ?? this.autoMode,
        scheduledStartHour: scheduledStartHour ?? this.scheduledStartHour,
        scheduledStartMinute: scheduledStartMinute ?? this.scheduledStartMinute,
        scheduledEndHour: scheduledEndHour ?? this.scheduledEndHour,
        scheduledEndMinute: scheduledEndMinute ?? this.scheduledEndMinute,
        sessionLinked: sessionLinked ?? this.sessionLinked,
        grayscale: grayscale ?? this.grayscale,
        activePreset: activePreset ?? this.activePreset,
        isLoading: isLoading ?? this.isLoading,
      );
}

class BlueLightNotifier extends StateNotifier<BlueLightState> {
  Timer? _autoTimer;

  BlueLightNotifier() : super(const BlueLightState()) {
    _load();
    _startTimer();
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _autoTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (state.autoMode) {
        _evaluateAutoMode();
      }
    });
  }

  Future<void> _load() async {
    final saved = await BlueLightService.load();
    state = BlueLightState.fromSettings(saved).copyWith(isLoading: false);
    _evaluateAutoMode();
  }

  Future<void> _persist() async {
    await BlueLightService.save(state.toSettings());
  }

  Future<void> reload() async {
    await _load();
  }

  void _evaluateAutoMode() {
    if (!state.autoMode) return;
    final shouldBeOn = BlueLightService.isWithinSchedule(state.toSettings());
    if (shouldBeOn != state.enabled) {
      state = state.copyWith(enabled: shouldBeOn);
    }
  }

  void toggle() => setEnabled(!state.enabled);

  void setEnabled(bool v) {
    state = state.copyWith(enabled: v);
    _persist();
  }

  void setTemperature(int kelvin) {
    state = state.copyWith(
      temperature: kelvin.clamp(3400, 6500),
      activePreset: null,
    );
    _persist();
  }

  void applyPreset(String presetId) {
    final preset = BlueLightPreset.presets.firstWhere(
      (p) => p.id == presetId,
      orElse: () => BlueLightPreset.presets.first,
    );
    state = state.copyWith(
      temperature: preset.temperature,
      activePreset: preset.id,
    );
    _persist();
  }

  void setAutoMode(bool v) {
    state = state.copyWith(autoMode: v);
    _persist();
    if (v) _evaluateAutoMode();
  }

  void setSchedule({
    required int startHour,
    required int startMinute,
    required int endHour,
    required int endMinute,
  }) {
    state = state.copyWith(
      scheduledStartHour: startHour,
      scheduledStartMinute: startMinute,
      scheduledEndHour: endHour,
      scheduledEndMinute: endMinute,
    );
    _persist();
    if (state.autoMode) _evaluateAutoMode();
  }

  void setSessionLinked(bool v) {
    state = state.copyWith(sessionLinked: v);
    _persist();
  }

  void toggleGrayscale() => setGrayscale(!state.grayscale);

  void setGrayscale(bool v) {
    state = state.copyWith(grayscale: v);
    _persist();
  }

  void tickAutoMode() {
    if (state.autoMode) _evaluateAutoMode();
  }

  void onFokusSessionStart() {
    if (state.sessionLinked && !state.enabled) {
      setEnabled(true);
    }
  }

  void onFokusSessionEnd() {
    if (state.sessionLinked && !state.autoMode) {
      setEnabled(false);
    }
  }
}

final blueLightProvider =
    StateNotifierProvider<BlueLightNotifier, BlueLightState>(
        (ref) => BlueLightNotifier());

// ──────────────────────────────────────────────
// Focus / Do-Not-Disturb mode
// ──────────────────────────────────────────────

final fokusModeProvider = StateProvider<bool>((ref) => false);

// ──────────────────────────────────────────────
// Ambient Sound
// ──────────────────────────────────────────────

class AmbientSoundState {
  final AmbientSoundType type;
  final double volume;
  final String? customPath;
  final String? customName;
  final bool isCustomActive;
  final bool isPlaying;
  final bool isLooping;
  final List<CustomSound>? _customSounds;
  final String? selectedCustomSoundId;
  final bool isLoading;

  const AmbientSoundState({
    this.type = AmbientSoundType.none,
    this.volume = 0.3,
    this.customPath,
    this.customName,
    this.isCustomActive = false,
    this.isPlaying = false,
    this.isLooping = true,
    List<CustomSound>? customSounds = const [],
    this.selectedCustomSoundId,
    this.isLoading = true,
  }) : _customSounds = customSounds;

  List<CustomSound> get customSounds => _customSounds ?? const [];

  bool get isCustomPlaying => selectedCustomSoundId != null;

  CustomSound? get activeCustomSound {
    if (selectedCustomSoundId == null) return null;
    final index = customSounds.indexWhere((s) => s.id == selectedCustomSoundId);
    return index != -1 ? customSounds[index] : null;
  }

  AmbientSoundState copyWith({
    AmbientSoundType? type,
    double? volume,
    String? customPath,
    String? customName,
    bool? isCustomActive,
    bool? isPlaying,
    bool? isLooping,
    List<CustomSound>? customSounds,
    String? selectedCustomSoundId,
    bool clearSelectedCustomSoundId = false,
    bool? isLoading,
  }) =>
      AmbientSoundState(
        type: type ?? this.type,
        volume: volume ?? this.volume,
        customPath: customPath ?? this.customPath,
        customName: customName ?? this.customName,
        isCustomActive: isCustomActive ?? this.isCustomActive,
        isPlaying: isPlaying ?? this.isPlaying,
        isLooping: isLooping ?? this.isLooping,
        customSounds: customSounds ?? this.customSounds,
        selectedCustomSoundId: clearSelectedCustomSoundId ? null : (selectedCustomSoundId ?? this.selectedCustomSoundId),
        isLoading: isLoading ?? this.isLoading,
      );
}

final ambientSoundProvider =
    StateNotifierProvider<AmbientSoundNotifier, AmbientSoundState>(
        (ref) => AmbientSoundNotifier());

class AmbientSoundNotifier extends StateNotifier<AmbientSoundState> {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription? _playerStateSubscription;

  AmbientSoundNotifier() : super(const AmbientSoundState()) {
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedType = prefs.getString('ambient_sound_type') ?? 'none';
    final savedVolume = prefs.getDouble('ambient_sound_volume') ?? 0.3;
    final savedCustomPath = prefs.getString('ambient_sound_custom_path');
    final savedCustomName = prefs.getString('ambient_sound_custom_name');
    final savedIsCustomActive = prefs.getBool('ambient_sound_custom_active') ?? false;
    final savedLoop = prefs.getBool('ambient_sound_loop') ?? true;
    final savedPlaying = prefs.getBool('ambient_sound_playing') ?? false;

    // Load custom sounds list
    final savedCustomSoundsRaw = prefs.getString('custom_ambient_sounds');
    List<CustomSound> customSounds = [];
    if (savedCustomSoundsRaw != null) {
      try {
        final decoded = jsonDecode(savedCustomSoundsRaw) as List;
        customSounds = decoded.map((e) => CustomSound.fromJson(Map<String, dynamic>.from(e))).toList();
      } catch (e) {
        debugPrint('Error loading custom sounds: $e');
      }
    }
    final savedSelectedCustomSoundId = prefs.getString('selected_custom_sound_id');

    final type = AmbientSoundType.values.firstWhere(
      (t) => t.name == savedType,
      orElse: () => AmbientSoundType.none,
    );

    state = AmbientSoundState(
      type: type,
      volume: savedVolume,
      customPath: savedCustomPath,
      customName: savedCustomName,
      isCustomActive: savedIsCustomActive,
      isLooping: savedLoop,
      isPlaying: false,
      customSounds: customSounds,
      selectedCustomSoundId: savedSelectedCustomSoundId,
    );

    try {
      await _player.setLoopMode(savedLoop ? LoopMode.one : LoopMode.off);
      await _player.setVolume(savedVolume);
    } catch (e) {
      debugPrint('Failed to set initial loop mode or volume: $e');
    }

    try {
      if (savedSelectedCustomSoundId != null && customSounds.isNotEmpty) {
        final activeCustom = customSounds.firstWhere(
          (s) => s.id == savedSelectedCustomSoundId,
          orElse: () => customSounds.first,
        );
        if (!kIsWeb) {
          await _player.setAudioSource(AudioSource.file(activeCustom.filePath));
          if (savedPlaying) {
            await _player.play();
          }
        }
      } else if (savedIsCustomActive && savedCustomPath != null) {
        if (!kIsWeb) {
          await _player.setAudioSource(AudioSource.file(savedCustomPath));
          if (savedPlaying) {
            await _player.play();
          }
        }
      } else if (type != AmbientSoundType.none) {
        final path = type.assetPath;
        if (path != null) {
          await _player.setAudioSource(AudioSource.asset(path));
          if (savedPlaying) {
            try {
              await _player.play();
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to load initial ambient sound: $e');
    }

    state = state.copyWith(isLoading: false);

    _playerStateSubscription = _player.playerStateStream.listen((playerState) {
      final isPlaying = playerState.playing;
      final processingState = playerState.processingState;

      if (processingState == ProcessingState.completed) {
        state = state.copyWith(isPlaying: false);
        _persistPlaying(false);
      } else if (processingState != ProcessingState.loading && processingState != ProcessingState.buffering) {
        state = state.copyWith(isPlaying: isPlaying);
        _persistPlaying(isPlaying);
      }
    }, onError: (Object e, StackTrace stackTrace) {
      debugPrint('Audio player stream error: $e');
    });
  }

  Future<void> _persistPlaying(bool playing) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('ambient_sound_playing', playing);
  }

  Future<void> _persist() async {
    final localState = state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ambient_sound_type', localState.type.name);
    await prefs.setDouble('ambient_sound_volume', localState.volume);
    await prefs.setBool('ambient_sound_custom_active', localState.isCustomActive);
    await prefs.setBool('ambient_sound_loop', localState.isLooping);
    await prefs.setBool('ambient_sound_playing', localState.isPlaying);
    if (localState.customPath != null) {
      await prefs.setString('ambient_sound_custom_path', localState.customPath!);
      await prefs.setString('ambient_sound_custom_name', localState.customName!);
    } else {
      await prefs.remove('ambient_sound_custom_path');
      await prefs.remove('ambient_sound_custom_name');
    }

    // Persist custom sounds list
    final serialized = jsonEncode(localState.customSounds.map((e) => e.toJson()).toList());
    await prefs.setString('custom_ambient_sounds', serialized);
    if (localState.selectedCustomSoundId != null) {
      await prefs.setString('selected_custom_sound_id', localState.selectedCustomSoundId!);
    } else {
      await prefs.remove('selected_custom_sound_id');
    }
  }

  Future<void> setType(AmbientSoundType type) async {
    try {
      try {
        await _player.stop();
      } catch (_) {}

      state = state.copyWith(
        type: type,
        isCustomActive: false,
        clearSelectedCustomSoundId: true,
      );

      if (type != AmbientSoundType.none) {
        final path = type.assetPath;
        if (path != null) {
          final loadFuture = _player.setAudioSource(AudioSource.asset(path));
          final playFuture = _player.play();
          await Future.wait([loadFuture, playFuture]);
        }
      }
      await _persist();
    } catch (e) {
      debugPrint('Error setting ambient type: $e');
    }
  }

  Future<void> setCustomType(CustomSound sound) async {
    if (kIsWeb) {
      debugPrint('Playing custom sound from path is not supported on web');
      return;
    }
    try {
      try {
        await _player.stop();
      } catch (_) {}

      state = state.copyWith(
        type: AmbientSoundType.none,
        isCustomActive: false,
        selectedCustomSoundId: sound.id,
      );

      final loadFuture = _player.setAudioSource(AudioSource.file(sound.filePath));
      final playFuture = _player.play();
      await Future.wait([loadFuture, playFuture]);
      await _persist();
    } catch (e) {
      debugPrint('Error playing custom sound: $e');
    }
  }

  Future<void> uploadCustomSound(String name, String sourcePath, String category) async {
    if (kIsWeb) {
      debugPrint('Uploading custom sound from path is not supported on web');
      return;
    }
    try {
      final file = File(sourcePath);
      if (!await file.exists()) {
        throw Exception("Source file does not exist");
      }

      final appDir = await getApplicationDocumentsDirectory();
      final uuid = const Uuid().v4();
      final extension = sourcePath.split('.').last;
      final targetFileName = 'custom_sound_$uuid.$extension';
      final targetPath = '${appDir.path}/$targetFileName';

      // Copy file physically
      await file.copy(targetPath);

      final newSound = CustomSound(
        id: uuid,
        name: name,
        filePath: targetPath,
        category: category.trim().isEmpty ? 'Custom' : category.trim(),
      );

      final updatedList = List<CustomSound>.from(state.customSounds)..add(newSound);
      state = state.copyWith(customSounds: updatedList);
      await _persist();
    } catch (e) {
      debugPrint('Error uploading custom sound: $e');
      rethrow;
    }
  }

  Future<void> deleteCustomSound(String id) async {
    try {
      final index = state.customSounds.indexWhere((s) => s.id == id);
      if (index == -1) return;

      final sound = state.customSounds[index];

      // If active, stop playing
      if (state.selectedCustomSoundId == id) {
        try {
          await _player.stop();
        } catch (_) {}
        state = state.copyWith(clearSelectedCustomSoundId: true);
      }

      // Delete physical file
      if (!kIsWeb) {
        final file = File(sound.filePath);
        if (await file.exists()) {
          await file.delete();
        }
      }

      final updatedList = List<CustomSound>.from(state.customSounds)..removeAt(index);
      state = state.copyWith(customSounds: updatedList);
      await _persist();
    } catch (e) {
      debugPrint('Error deleting custom sound: $e');
    }
  }

  Future<void> renameCustomSound(String id, String newName) async {
    final updatedList = state.customSounds.map((s) {
      if (s.id == id) {
        return s.copyWith(name: newName);
      }
      return s;
    }).toList();

    state = state.copyWith(customSounds: updatedList);
    await _persist();
  }

  Future<void> reorderCustomSoundCategory(String id, String newCategory) async {
    final updatedList = state.customSounds.map((s) {
      if (s.id == id) {
        return s.copyWith(category: newCategory.trim().isEmpty ? 'Custom' : newCategory.trim());
      }
      return s;
    }).toList();

    state = state.copyWith(customSounds: updatedList);
    await _persist();
  }

  Future<void> setCustomSound(String path, String name) async {
    if (kIsWeb) {
      debugPrint('Playing custom sound from path is not supported on web');
      return;
    }
    try {
      try {
        await _player.stop();
      } catch (_) {}

      state = state.copyWith(
        type: AmbientSoundType.none,
        customPath: path,
        customName: name,
        isCustomActive: true,
      );

      final loadFuture = _player.setAudioSource(AudioSource.file(path));
      final playFuture = _player.play();
      await Future.wait([loadFuture, playFuture]);
      await _persist();
    } catch (e) {
      debugPrint('Error playing custom sound: $e');
    }
  }

  Future<void> toggleCustomSound() async {
    if (state.customPath == null || kIsWeb) return;
    try {
      if (state.isCustomActive && state.isPlaying) {
        try {
          await _player.pause();
        } catch (_) {}
      } else {
        try {
          await _player.stop();
        } catch (_) {}

        state = state.copyWith(
          type: AmbientSoundType.none,
          isCustomActive: true,
        );
        await _player.setAudioSource(AudioSource.file(state.customPath!));
        await _player.play();
      }
      await _persist();
    } catch (e) {
      debugPrint('Error toggling custom sound: $e');
    }
  }

  Future<void> removeCustomSound() async {
    try {
      try {
        await _player.stop();
      } catch (_) {}

      state = state.copyWith(
        customPath: null,
        customName: null,
        isCustomActive: false,
      );
      await _persist();
    } catch (e) {
      debugPrint('Error removing custom sound: $e');
    }
  }

  Future<void> setVolume(double v) async {
    final clamped = v.clamp(0.0, 1.0);
    state = state.copyWith(volume: clamped);
    await _persist();
    try {
      await _player.setVolume(clamped);
    } catch (e) {
      debugPrint('Error setting volume: $e');
    }
  }

  Future<void> toggleLoop() async {
    final nextLoop = !state.isLooping;
    state = state.copyWith(isLooping: nextLoop);
    await _persist();
    try {
      await _player.setLoopMode(nextLoop ? LoopMode.one : LoopMode.off);
    } catch (e) {
      debugPrint('Error toggling loop: $e');
    }
  }

  Future<void> togglePlayPause() async {
    try {
      if (state.isPlaying) {
        try {
          await _player.pause();
        } catch (_) {}
        state = state.copyWith(isPlaying: false);
      } else {
        state = state.copyWith(isPlaying: true);
        if (state.selectedCustomSoundId != null) {
          final activeCustom = state.customSounds.firstWhere(
            (s) => s.id == state.selectedCustomSoundId,
            orElse: () => state.customSounds.first,
          );
          if (!kIsWeb) {
            if (_player.audioSource == null) {
              final loadFuture = _player.setAudioSource(AudioSource.file(activeCustom.filePath));
              final playFuture = _player.play();
              await Future.wait([loadFuture, playFuture]);
            } else {
              await _player.play();
            }
          }
        } else if (state.isCustomActive && state.customPath != null) {
          if (!kIsWeb) {
            if (_player.audioSource == null) {
              final loadFuture = _player.setAudioSource(AudioSource.file(state.customPath!));
              final playFuture = _player.play();
              await Future.wait([loadFuture, playFuture]);
            } else {
              await _player.play();
            }
          }
        } else if (state.type != AmbientSoundType.none) {
          final path = state.type.assetPath;
          if (path != null) {
            if (_player.audioSource == null) {
              final loadFuture = _player.setAudioSource(AudioSource.asset(path));
              final playFuture = _player.play();
              await Future.wait([loadFuture, playFuture]);
            } else {
              await _player.play();
            }
          }
        } else {
          await setType(AmbientSoundType.brownNoise);
        }
      }
      await _persist();
    } catch (e) {
      debugPrint('Error toggling play/pause: $e');
      state = state.copyWith(isPlaying: false);
      await _persistPlaying(false);
    }
  }

  void nextSound() {
    final bundledSounds = AmbientSoundType.values.where((t) => t != AmbientSoundType.none && t != AmbientSoundType.cafe).toList();
    final customSoundsList = state.customSounds;

    final totalCount = bundledSounds.length + customSoundsList.length;
    if (totalCount == 0) return;

    int currentIndex = -1;
    if (state.selectedCustomSoundId != null) {
      final customIdx = customSoundsList.indexWhere((s) => s.id == state.selectedCustomSoundId);
      if (customIdx != -1) {
        currentIndex = bundledSounds.length + customIdx;
      }
    } else if (state.type != AmbientSoundType.none) {
      currentIndex = bundledSounds.indexOf(state.type);
    }

    if (currentIndex == -1) currentIndex = 0;
    final nextIndex = (currentIndex + 1) % totalCount;

    if (nextIndex < bundledSounds.length) {
      setType(bundledSounds[nextIndex]);
    } else {
      setCustomType(customSoundsList[nextIndex - bundledSounds.length]);
    }
  }

  void previousSound() {
    final bundledSounds = AmbientSoundType.values.where((t) => t != AmbientSoundType.none && t != AmbientSoundType.cafe).toList();
    final customSoundsList = state.customSounds;

    final totalCount = bundledSounds.length + customSoundsList.length;
    if (totalCount == 0) return;

    int currentIndex = -1;
    if (state.selectedCustomSoundId != null) {
      final customIdx = customSoundsList.indexWhere((s) => s.id == state.selectedCustomSoundId);
      if (customIdx != -1) {
        currentIndex = bundledSounds.length + customIdx;
      }
    } else if (state.type != AmbientSoundType.none) {
      currentIndex = bundledSounds.indexOf(state.type);
    }

    if (currentIndex == -1) currentIndex = 0;
    final prevIndex = (currentIndex - 1 + totalCount) % totalCount;

    if (prevIndex < bundledSounds.length) {
      setType(bundledSounds[prevIndex]);
    } else {
      setCustomType(customSoundsList[prevIndex - bundledSounds.length]);
    }
  }

  Future<void> toggle() async {
    if (state.type == AmbientSoundType.none && state.selectedCustomSoundId == null && !state.isCustomActive) {
      if (state.customSounds.isNotEmpty) {
        await setCustomType(state.customSounds.first);
      } else if (state.customPath != null) {
        await toggleCustomSound();
      } else {
        await setType(AmbientSoundType.rain);
      }
    } else {
      try {
        await _player.pause();
      } catch (_) {}
      state = state.copyWith(isPlaying: false);
    }
  }

  @override
  void dispose() {
    _playerStateSubscription?.cancel();
    _player.dispose();
    super.dispose();
  }
}

// ──────────────────────────────────────────────
// Focus Profiles
// ──────────────────────────────────────────────

final activeProfileProvider = StateProvider<String?>((ref) => null);

// ──────────────────────────────────────────────
// Brain Dump
// ──────────────────────────────────────────────

final brainDumpOpenProvider = StateProvider<bool>((ref) => false);

// Provider for brain dump entries
final brainDumpEntriesProvider = StateNotifierProvider<BrainDumpNotifier, List<BrainDumpEntry>>((ref) {
  return BrainDumpNotifier();
});

class BrainDumpNotifier extends StateNotifier<List<BrainDumpEntry>> {
  BrainDumpNotifier() : super([]) {
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    final entries = await BrainDumpService.loadEntries();
    state = entries;
  }

  Future<void> refresh() async {
    await _loadEntries();
  }

  Future<void> deleteEntry(String id) async {
    await BrainDumpService.deleteEntry(id);
    await _loadEntries();
  }

  Future<void> markReviewed(String id) async {
    await BrainDumpService.markReviewed(id);
    await _loadEntries();
  }

  Future<void> clearAll() async {
    await BrainDumpService.clearAll();
    state = [];
  }
}

// ──────────────────────────────────────────────
// Hardcore Lock Mode
// ──────────────────────────────────────────────

class HardcoreLockState {
  final bool enabled;
  final String? passwordHash;
  final bool locked;
  final int penaltySeconds;

  const HardcoreLockState({
    this.enabled = false,
    this.passwordHash,
    this.locked = false,
    this.penaltySeconds = 30,
  });

  HardcoreLockState copyWith({
    bool? enabled,
    String? passwordHash,
    bool? locked,
    int? penaltySeconds,
  }) =>
      HardcoreLockState(
        enabled: enabled ?? this.enabled,
        passwordHash: passwordHash ?? this.passwordHash,
        locked: locked ?? this.locked,
        penaltySeconds: penaltySeconds ?? this.penaltySeconds,
      );
}

final hardcoreLockProvider =
    StateNotifierProvider<HardcoreLockNotifier, HardcoreLockState>(
        (ref) => HardcoreLockNotifier());

class HardcoreLockNotifier extends StateNotifier<HardcoreLockState> {
  HardcoreLockNotifier() : super(const HardcoreLockState()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('hardcore_lock_enabled') ?? false;
    final passwordHash = prefs.getString('hardcore_lock_password');
    final penalty = prefs.getInt('hardcore_lock_penalty') ?? 30;
    state = HardcoreLockState(
      enabled: enabled,
      passwordHash: passwordHash,
      penaltySeconds: penalty,
    );
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hardcore_lock_enabled', state.enabled);
    if (state.passwordHash != null) {
      await prefs.setString('hardcore_lock_password', state.passwordHash!);
    }
    await prefs.setInt('hardcore_lock_penalty', state.penaltySeconds);
  }

  void setEnabled(bool v) {
    state = state.copyWith(enabled: v);
    _persist();
  }

  void setPassword(String password) {
    // Simple base64 encoding as hash (not crypto-strong, but fine for local use)
    final hash = base64Encode(password.codeUnits);
    state = state.copyWith(passwordHash: hash);
    _persist();
  }

  bool verifyPassword(String password) {
    if (state.passwordHash == null) return true;
    final hash = base64Encode(password.codeUnits);
    return hash == state.passwordHash;
  }

  void setPenaltySeconds(int s) {
    state = state.copyWith(penaltySeconds: s.clamp(10, 300));
    _persist();
  }

  void setLocked(bool v) {
    state = state.copyWith(locked: v);
  }
}

// ──────────────────────────────────────────────
// Wallpaper — custom background for focus sessions
// ──────────────────────────────────────────────

class WallpaperState {
  final String? imagePath;
  final bool rememberForFuture;

  const WallpaperState({
    this.imagePath,
    this.rememberForFuture = false,
  });

  WallpaperState copyWith({String? imagePath, bool? rememberForFuture}) =>
      WallpaperState(
        imagePath: imagePath ?? this.imagePath,
        rememberForFuture: rememberForFuture ?? this.rememberForFuture,
      );
}

final wallpaperProvider =
    StateNotifierProvider<WallpaperNotifier, WallpaperState>(
        (ref) => WallpaperNotifier());

class WallpaperNotifier extends StateNotifier<WallpaperState> {
  WallpaperNotifier() : super(const WallpaperState()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPath = prefs.getString('wallpaper_image_path');
      if (savedPath != null && savedPath.isNotEmpty) {
        state = WallpaperState(
          imagePath: savedPath,
          rememberForFuture: true,
        );
      }
    } catch (_) {}
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (state.rememberForFuture && state.imagePath != null) {
        await prefs.setString('wallpaper_image_path', state.imagePath!);
      } else {
        await prefs.remove('wallpaper_image_path');
      }
    } catch (_) {}
  }

  void setImagePath(String? path) {
    state = state.copyWith(imagePath: path);
    _persist();
  }

  void setRememberForFuture(bool v) {
    state = state.copyWith(rememberForFuture: v);
    _persist();
  }

  void resetToDefault() {
    state = const WallpaperState();
    // Clear persisted wallpaper
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove('wallpaper_image_path');
    });
  }
}

// Navigation is now in core/navigation.dart

// ──────────────────────────────────────────────
// Focused Task — which task is linked to the current session
// ──────────────────────────────────────────────

final focusedTaskProvider = StateProvider<String?>((ref) => null);

// ──────────────────────────────────────────────
// Interruption Prompt — shown when user stops early
// ──────────────────────────────────────────────

final interruptionPromptProvider = StateProvider<bool>((ref) => false);

// ──────────────────────────────────────────────
// Tasks
// ──────────────────────────────────────────────

final tasksProvider =
    StateNotifierProvider<TasksNotifier, List<Task>>((ref) => TasksNotifier());

class TasksNotifier extends StateNotifier<List<Task>> {
  TasksNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('tasks_list');
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List;
        state = list
            .map((e) => Task.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }
  }

  Future<void> _persist() async {
    final localState = state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'tasks_list', jsonEncode(localState.map((t) => t.toJson()).toList()));
  }

  void reload() => _load();

  Task addTask(String title, {String? color, String? priority, DateTime? dueDate, int estimatedMinutes = 0}) {
    final task = Task(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      color: color,
      priority: priority ?? 'medium',
      dueDate: dueDate,
      estimatedMinutes: estimatedMinutes,
    );
    state = [task, ...state];
    _persist();
    return task;
  }

  void toggleTask(String id) {
    state = state.map((t) {
      if (t.id == id) {
        final newDone = !t.done;
        return t.copyWith(
          done: newDone,
          completedAt: newDone ? DateTime.now() : null,
        );
      }
      return t;
    }).toList();
    _persist();
  }

  void removeTask(String id) {
    state = state.where((t) => t.id != id).toList();
    _persist();
  }

  void updateTask(String id, String newTitle) {
    state = state.map((t) {
      if (t.id == id) return t.copyWith(title: newTitle);
      return t;
    }).toList();
    _persist();
  }

  void updateTaskColor(String id, String color) {
    state = state.map((t) {
      if (t.id == id) return t.copyWith(color: color);
      return t;
    }).toList();
    _persist();
  }

  void updateTaskNotes(String id, String notes) {
    state = state.map((t) {
      if (t.id == id) return t.copyWith(notes: notes);
      return t;
    }).toList();
    _persist();
  }

  /// Attribue a focus session to a task (completed).
  void attributeFocusTime(String id, int minutes) {
    state = state.map((t) {
      if (t.id == id) {
        return t.copyWith(
          totalFocusMinutes: t.totalFocusMinutes + minutes,
          completedSessions: t.completedSessions + 1,
          lastActiveAt: DateTime.now(),
        );
      }
      return t;
    }).toList();
    _persist();
  }

  /// Attribue an interrupted session.
  void attributeInterruption(String id, int minutes) {
    state = state.map((t) {
      if (t.id == id) {
        return t.copyWith(
          totalFocusMinutes: t.totalFocusMinutes + minutes,
          interruptedSessions: t.interruptedSessions + 1,
          lastActiveAt: DateTime.now(),
        );
      }
      return t;
    }).toList();
    _persist();
  }

  void archiveTask(String id) {
    state = state.map((t) {
      if (t.id == id) return t.copyWith(archived: true);
      return t;
    }).toList();
    _persist();
  }

  void duplicateTask(String id) {
    final original = state.firstWhere((t) => t.id == id);
    final dup = Task(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: '${original.title} (copy)',
      color: original.color,
    );
    state = [dup, ...state];
    _persist();
  }

  void clearCompleted() {
    state = state.where((t) => !t.done).toList();
    _persist();
  }
}

// ──────────────────────────────────────────────
// Quick Capture
// ──────────────────────────────────────────────

final quickCaptureProvider =
    StateNotifierProvider<QuickCaptureNotifier, List<QuickCaptureItem>>(
        (ref) => QuickCaptureNotifier());

class QuickCaptureNotifier extends StateNotifier<List<QuickCaptureItem>> {
  QuickCaptureNotifier() : super([]) {
    _load();
  }

  static const _storageKey = 'quick_capture_items';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw) as List;
        state = decoded.map((e) => QuickCaptureItem.fromJson(Map<String, dynamic>.from(e))).toList();
      } catch (_) {}
    }
  }

  Future<void> _persist() async {
    final localState = state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(localState.map((e) => e.toJson()).toList()));
  }

  void reload() => _load();

  void addEntry(String text, {List<String>? mediaPaths}) {
    final urls = extractUrls(text);

    final item = QuickCaptureItem(
      id: const Uuid().v4(),
      text: text,
      timestamp: DateTime.now(),
      linkUrls: urls,
      mediaPaths: mediaPaths ?? const [],
    );
    state = [item, ...state];
    _persist();
  }

  void updateEntry(String id, String newText) {
    state = state.map((item) {
      if (item.id == id) {
        final urls = extractUrls(newText);
        return item.copyWith(text: newText, linkUrls: urls);
      }
      return item;
    }).toList();
    _persist();
  }

  void toggleActioned(String id) {
    state = state.map((item) {
      if (item.id == id) {
        return item.copyWith(isActioned: !item.isActioned);
      }
      return item;
    }).toList();
    _persist();
  }

  void removeEntry(String id) {
    state = state.where((item) => item.id != id).toList();
    _persist();
  }

  void clear() {
    state = [];
    _persist();
  }
}

// ──────────────────────────────────────────────
// Eye Break / Health Reminders
// ──────────────────────────────────────────────

class EyeBreakState {
  final bool twentyTwentyEnabled;
  final bool blinkReminders;
  final bool breakReminders;
  final bool postureReminders;
  final bool hydrationReminders;
  final bool isLoading;

  const EyeBreakState({
    this.twentyTwentyEnabled = false,
    this.blinkReminders = false,
    this.breakReminders = false,
    this.postureReminders = false,
    this.hydrationReminders = false,
    this.isLoading = true,
  });

  EyeBreakState copyWith({
    bool? twentyTwentyEnabled,
    bool? blinkReminders,
    bool? breakReminders,
    bool? postureReminders,
    bool? hydrationReminders,
    bool? isLoading,
  }) =>
      EyeBreakState(
        twentyTwentyEnabled: twentyTwentyEnabled ?? this.twentyTwentyEnabled,
        blinkReminders: blinkReminders ?? this.blinkReminders,
        breakReminders: breakReminders ?? this.breakReminders,
        postureReminders: postureReminders ?? this.postureReminders,
        hydrationReminders: hydrationReminders ?? this.hydrationReminders,
        isLoading: isLoading ?? this.isLoading,
      );
}

final eyeBreakProvider =
    StateNotifierProvider<EyeBreakNotifier, EyeBreakState>(
        (ref) => EyeBreakNotifier());

class EyeBreakNotifier extends StateNotifier<EyeBreakState> {
  EyeBreakNotifier() : super(const EyeBreakState()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = EyeBreakState(
      twentyTwentyEnabled: prefs.getBool('twenty_twenty') ?? false,
      blinkReminders: prefs.getBool('blink_reminders') ?? false,
      breakReminders: prefs.getBool('break_reminders') ?? false,
      postureReminders: prefs.getBool('posture_reminders') ?? false,
      hydrationReminders: prefs.getBool('hydration_reminders') ?? false,
      isLoading: false,
    );
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('twenty_twenty', state.twentyTwentyEnabled);
    await prefs.setBool('blink_reminders', state.blinkReminders);
    await prefs.setBool('break_reminders', state.breakReminders);
    await prefs.setBool('posture_reminders', state.postureReminders);
    await prefs.setBool('hydration_reminders', state.hydrationReminders);
  }

  void setTwentyTwenty(bool v) {
    state = state.copyWith(twentyTwentyEnabled: v);
    _persist();
  }

  void setBlinkReminders(bool v) {
    state = state.copyWith(blinkReminders: v);
    _persist();
  }

  void setBreakReminders(bool v) {
    state = state.copyWith(breakReminders: v);
    _persist();
  }

  void setPostureReminders(bool v) {
    state = state.copyWith(postureReminders: v);
    _persist();
  }

  void setHydrationReminders(bool v) {
    state = state.copyWith(hydrationReminders: v);
    _persist();
  }
}

// ──────────────────────────────────────────────
// Session State Machine — explicit lifecycle with crash recovery
// ──────────────────────────────────────────────

/// Explicit session states for premium UX.
/// Each state corresponds to a visual treatment and interaction mode.
enum SessionState {
  idle,
  armed,     // Timer set, waiting to start
  active,    // Timer running
  paused,    // Timer paused
  completed, // Session completed
  interrupted, // Session ended early
}

/// Information needed to recover an interrupted session after a crash.
class RecoverableSession {
  final String sessionId;
  final int elapsedSeconds;
  final int totalSeconds;
  final String? taskId;
  final String? taskName;
  final Color? taskColor;
  final DateTime timestamp;

  const RecoverableSession({
    required this.sessionId,
    required this.elapsedSeconds,
    required this.totalSeconds,
    this.taskId,
    this.taskName,
    this.taskColor,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'elapsedSeconds': elapsedSeconds,
        'totalSeconds': totalSeconds,
        'taskId': taskId,
        'taskName': taskName,
        'taskColor': taskColor?.toARGB32(),
        'timestamp': timestamp.toIso8601String(),
      };

  factory RecoverableSession.fromJson(Map<String, dynamic> json) =>
      RecoverableSession(
        sessionId: json['sessionId'] as String? ?? '',
        elapsedSeconds: json['elapsedSeconds'] as int? ?? 0,
        totalSeconds: json['totalSeconds'] as int? ?? 1500,
        taskId: json['taskId'] as String?,
        taskName: json['taskName'] as String?,
        taskColor: json['taskColor'] != null
            ? Color(json['taskColor'] as int)
            : null,
        timestamp: json['timestamp'] != null
            ? DateTime.parse(json['timestamp'] as String)
            : DateTime.now(),
      );
}

/// Provider that holds any recoverable session found on startup.
/// Starts as null; populated during app initialization.
final recoverableSessionProvider =
    StateProvider<RecoverableSession?>((ref) => null);

class SessionStateNotifier extends StateNotifier<SessionState> {
  final Ref _ref;

  SessionStateNotifier(this._ref) : super(SessionState.idle);

  void arm() {
    if (state == SessionState.idle) state = SessionState.armed;
  }

  void activate() {
    state = SessionState.active;
  }

  void pause() {
    if (state == SessionState.active) state = SessionState.paused;
  }

  void resume() {
    if (state == SessionState.paused) state = SessionState.active;
  }

  void complete() {
    state = SessionState.completed;
    _clearActiveSession();
  }

  void interrupt() {
    state = SessionState.interrupted;
    _clearActiveSession();
  }

  void reset() {
    state = SessionState.idle;
    _clearActiveSession();
  }

  // ── Crash recovery persistence ──

  static const _activeSessionKey = 'active_session_recovery';

  /// Persist the current session state so it can be recovered after a crash.
  void persistActiveSession({
    required String sessionId,
    required int elapsedSeconds,
    required int totalSeconds,
    String? taskId,
    String? taskName,
    Color? taskColor,
  }) {
    try {
      final recovery = RecoverableSession(
        sessionId: sessionId,
        elapsedSeconds: elapsedSeconds,
        totalSeconds: totalSeconds,
        taskId: taskId,
        taskName: taskName,
        taskColor: taskColor,
        timestamp: DateTime.now(),
      );
      final jsonStr = _encodeRecovery(recovery);
      // Use synchronous SharedPreferences access for crash resilience
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString(_activeSessionKey, jsonStr);
      });
    } catch (_) {}
  }

  void _clearActiveSession() {
    try {
      SharedPreferences.getInstance().then((prefs) {
        prefs.remove(_activeSessionKey);
      });
      // Also clear the provider
      _ref.read(recoverableSessionProvider.notifier).state = null;
    } catch (_) {}
  }

  /// Check for a recoverable session on startup and populate the provider.
  static Future<RecoverableSession?> checkForRecoverableSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_activeSessionKey);
      if (raw == null) return null;
      final session = _decodeRecovery(raw);
      // Only recover sessions less than 24 hours old
      if (session.timestamp.isBefore(
          DateTime.now().subtract(const Duration(hours: 24)))) {
        await prefs.remove(_activeSessionKey);
        return null;
      }
      return session;
    } catch (_) {
      return null;
    }
  }

  static String _encodeRecovery(RecoverableSession session) {
    return jsonEncode(session.toJson());
  }

  static RecoverableSession _decodeRecovery(String raw) {
    final json = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    return RecoverableSession.fromJson(json);
  }
}

final sessionStateProvider =
    StateNotifierProvider<SessionStateNotifier, SessionState>(
        (ref) => SessionStateNotifier(ref));

/// Call this during app initialization to check for a crashed session.
Future<void> initializeRecoverySession(ProviderContainer container) async {
  final recovery = await SessionStateNotifier.checkForRecoverableSession();
  if (recovery != null) {
    container.read(recoverableSessionProvider.notifier).state = recovery;
  }
}

// ──────────────────────────────────────────────
// Focus Timer — full session lifecycle management
// ──────────────────────────────────────────────

class TimerState {
  final int elapsed;
  final int totalSeconds;
  final bool running;
  final bool isCountdown;
  final DateTime? sessionStartTime;
  final int? plannedSeconds;
  final bool isBreak;
  final int breakDuration;
  final int breakElapsed;

  const TimerState({
    this.elapsed = 0,
    this.totalSeconds = 0, // Default to 0 for count-up stopwatch
    this.running = false,
    this.isCountdown = false,
    this.sessionStartTime,
    this.plannedSeconds,
    this.isBreak = false,
    this.breakDuration = 0,
    this.breakElapsed = 0,
  });

  TimerState copyWith({
    int? elapsed,
    int? totalSeconds,
    bool? running,
    bool? isCountdown,
    DateTime? sessionStartTime,
    int? plannedSeconds,
    bool? isBreak,
    int? breakDuration,
    int? breakElapsed,
  }) =>
      TimerState(
        elapsed: elapsed ?? this.elapsed,
        totalSeconds: totalSeconds ?? this.totalSeconds,
        running: running ?? this.running,
        isCountdown: isCountdown ?? this.isCountdown,
        sessionStartTime: sessionStartTime ?? this.sessionStartTime,
        plannedSeconds: plannedSeconds ?? this.plannedSeconds,
        isBreak: isBreak ?? this.isBreak,
        breakDuration: breakDuration ?? this.breakDuration,
        breakElapsed: breakElapsed ?? this.breakElapsed,
      );

  /// Generate a unique session ID for tracking.
  String get sessionId => 'session_${DateTime.now().millisecondsSinceEpoch}';
}

final timerProvider =
    StateNotifierProvider<TimerNotifier, TimerState>((ref) => TimerNotifier(ref));

class TimerNotifier extends StateNotifier<TimerState> {
  Timer? _tick;
  DateTime? _startedAt;
  final Ref _ref;

  TimerNotifier(this._ref) : super(const TimerState());

  void setDuration(int totalSeconds) {
    if (state.running) return;
    state = state.copyWith(
      totalSeconds: totalSeconds,
      elapsed: 0,
      isCountdown: totalSeconds > 0,
      plannedSeconds: totalSeconds,
      sessionStartTime: null,
      isBreak: false,
      breakDuration: 0,
      breakElapsed: 0,
    );
    // Arm the session when a duration is set
    _ref.read(sessionStateProvider.notifier).arm();
  }

  void start() {
    if (state.running) return;
    _ref.read(timerSoundProvider.notifier).stopAlarm();
    _startedAt = DateTime.now().subtract(Duration(seconds: state.elapsed));
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
    
    DateTime? startTime = state.sessionStartTime;
    if (state.elapsed == 0 || startTime == null) {
      startTime = DateTime.now();
    }

    state = state.copyWith(
      running: true,
      sessionStartTime: startTime,
      plannedSeconds: state.plannedSeconds ?? state.totalSeconds,
      isBreak: false,
    );
    _ref.read(sessionStateProvider.notifier).activate();
  }

  void startBreak(int seconds) {
    _tick?.cancel();
    _ref.read(timerSoundProvider.notifier).stopAlarm();
    _startedAt = DateTime.now();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
    state = state.copyWith(
      isBreak: true,
      breakDuration: seconds,
      breakElapsed: 0,
      running: true,
    );
  }

  void resumeFocus() {
    _tick?.cancel();
    _tick = null;
    _startedAt = null;
    state = state.copyWith(
      isBreak: false,
      breakDuration: 0,
      breakElapsed: 0,
      running: false,
    );
    _ref.read(timerSoundProvider.notifier).stopAlarm();
    start();
  }

  void cancelBreak() {
    _tick?.cancel();
    _tick = null;
    _startedAt = null;
    _ref.read(timerSoundProvider.notifier).stopTick();
    _ref.read(timerSoundProvider.notifier).stopAlarm();
    state = state.copyWith(
      isBreak: false,
      breakDuration: 0,
      breakElapsed: 0,
      running: false,
    );
  }

  void pause() {
    _tick?.cancel();
    _tick = null;
    _startedAt = null;
    _ref.read(timerSoundProvider.notifier).stopTick();
    state = state.copyWith(running: false);
    _ref.read(sessionStateProvider.notifier).pause();
  }

  void complete() {
    _tick?.cancel();
    _tick = null;
    _startedAt = null;
    state = const TimerState();
    _ref.read(sessionStateProvider.notifier).complete();
    _ref.read(timerSoundProvider.notifier).stopTick();
    final customization = _ref.read(timerCustomizationProvider);
    if (!customization.isMuted) {
      _ref.read(timerSoundProvider.notifier).playAlarm();
    }
  }

  void reset() {
    _tick?.cancel();
    _tick = null;
    _startedAt = null;
    _ref.read(timerSoundProvider.notifier).stopTick();
    _ref.read(timerSoundProvider.notifier).stopAlarm();
    state = const TimerState();
    _ref.read(sessionStateProvider.notifier).reset();
  }

  void interrupt() {
    _tick?.cancel();
    _tick = null;
    _startedAt = null;
    _ref.read(timerSoundProvider.notifier).stopTick();
    _ref.read(timerSoundProvider.notifier).stopAlarm();
    state = const TimerState();
    _ref.read(sessionStateProvider.notifier).interrupt();
  }

  void _onTick() {
    if (_startedAt == null) return;
    final customization = _ref.read(timerCustomizationProvider);
    final soundNotifier = _ref.read(timerSoundProvider.notifier);
    final soundState = _ref.read(timerSoundProvider);

    if (state.isBreak) {
      final elapsedBreak = DateTime.now().difference(_startedAt!).inSeconds;
      if (elapsedBreak >= state.breakDuration) {
        _tick?.cancel();
        _tick = null;
        _startedAt = null;
        state = state.copyWith(
          running: false,
          breakElapsed: state.breakDuration,
        );
        soundNotifier.stopTick();
        if (!customization.isMuted) {
          soundNotifier.playAlarm();
        }
      } else {
        state = state.copyWith(breakElapsed: elapsedBreak);
        if (!customization.isMuted) {
          if (customization.flipSoundEnabled) {
            SoundService.playFlip();
          } else if (soundState.tickEnabled) {
            soundNotifier.playTick();
          }
        }
      }
      return;
    }

    final elapsed = DateTime.now().difference(_startedAt!).inSeconds;
    final isCountdown = state.isCountdown == true;
    if (isCountdown && elapsed >= ((state.totalSeconds as dynamic) ?? 0)) {
      _tick?.cancel();
      _tick = null;
      _startedAt = null;
      state = state.copyWith(elapsed: state.totalSeconds, running: false);
      _ref.read(sessionStateProvider.notifier).complete();
      soundNotifier.stopTick();
      if (!customization.isMuted) {
        soundNotifier.playAlarm();
      }
    } else {
      state = state.copyWith(elapsed: elapsed);
      if (!customization.isMuted) {
        if (customization.flipSoundEnabled) {
          SoundService.playFlip();
        } else if (soundState.tickEnabled) {
          soundNotifier.playTick();
        }
      }
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }
}

// ──────────────────────────────────────────────
// Timer Color Provider
// ──────────────────────────────────────────────

final timerColorProvider = StateNotifierProvider<TimerColorNotifier, Color?>((ref) => TimerColorNotifier());

class TimerColorNotifier extends StateNotifier<Color?> {
  TimerColorNotifier() : super(null) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedValue = prefs.getInt('timer_digit_color');
      if (savedValue != null) {
        state = Color(savedValue);
      }
    } catch (_) {}
  }

  Future<void> setColor(Color? color) async {
    state = color;
    final prefs = await SharedPreferences.getInstance();
    if (color != null) {
      await prefs.setInt('timer_digit_color', color.toARGB32());
    } else {
      await prefs.remove('timer_digit_color');
    }
  }
}

// ──────────────────────────────────────────────
// Timer Customization & Presets Providers
// ──────────────────────────────────────────────

class TimerCustomizationState {
  final String fontStyle;
  final String size;
  final String colorTheme;
  final String backgroundMode;
  final bool showSeconds;
  final bool showMilliseconds;
  final bool showSessionLabel;
  final bool showTaskName;
  final bool showProgressRing;
  final bool enableAnimations;
  final bool reducedMotion;
  final double flipSpeed;
  final bool tickSoundEnabled;
  final bool flipSoundEnabled;
  final bool completeSoundEnabled;
  final bool isMuted;
  final bool autoSwitchStyle;
  final String transitionEffect;
  final String? activePresetName;

  const TimerCustomizationState({
    this.fontStyle = 'minimal',
    this.size = 'large',
    this.colorTheme = 'auto',
    this.backgroundMode = 'glassmorphism',
    this.showSeconds = true,
    this.showMilliseconds = false,
    this.showSessionLabel = true,
    this.showTaskName = true,
    this.showProgressRing = true,
    this.enableAnimations = true,
    this.reducedMotion = false,
    this.flipSpeed = 1.0,
    this.tickSoundEnabled = false,
    this.flipSoundEnabled = false,
    this.completeSoundEnabled = true,
    this.isMuted = false,
    this.autoSwitchStyle = false,
    this.transitionEffect = 'fade',
    this.activePresetName,
  });

  TimerCustomizationState copyWith({
    String? fontStyle,
    String? size,
    String? colorTheme,
    String? backgroundMode,
    bool? showSeconds,
    bool? showMilliseconds,
    bool? showSessionLabel,
    bool? showTaskName,
    bool? showProgressRing,
    bool? enableAnimations,
    bool? reducedMotion,
    double? flipSpeed,
    bool? tickSoundEnabled,
    bool? flipSoundEnabled,
    bool? completeSoundEnabled,
    bool? isMuted,
    bool? autoSwitchStyle,
    String? transitionEffect,
    String? activePresetName,
  }) {
    return TimerCustomizationState(
      fontStyle: fontStyle ?? this.fontStyle,
      size: size ?? this.size,
      colorTheme: colorTheme ?? this.colorTheme,
      backgroundMode: backgroundMode ?? this.backgroundMode,
      showSeconds: showSeconds ?? this.showSeconds,
      showMilliseconds: showMilliseconds ?? this.showMilliseconds,
      showSessionLabel: showSessionLabel ?? this.showSessionLabel,
      showTaskName: showTaskName ?? this.showTaskName,
      showProgressRing: showProgressRing ?? this.showProgressRing,
      enableAnimations: enableAnimations ?? this.enableAnimations,
      reducedMotion: reducedMotion ?? this.reducedMotion,
      flipSpeed: flipSpeed ?? this.flipSpeed,
      tickSoundEnabled: tickSoundEnabled ?? this.tickSoundEnabled,
      flipSoundEnabled: flipSoundEnabled ?? this.flipSoundEnabled,
      completeSoundEnabled: completeSoundEnabled ?? this.completeSoundEnabled,
      isMuted: isMuted ?? this.isMuted,
      autoSwitchStyle: autoSwitchStyle ?? this.autoSwitchStyle,
      transitionEffect: transitionEffect ?? this.transitionEffect,
      activePresetName: activePresetName ?? this.activePresetName,
    );
  }

  Map<String, dynamic> toJson() => {
        'fontStyle': fontStyle,
        'size': size,
        'colorTheme': colorTheme,
        'backgroundMode': backgroundMode,
        'showSeconds': showSeconds,
        'showMilliseconds': showMilliseconds,
        'showSessionLabel': showSessionLabel,
        'showTaskName': showTaskName,
        'showProgressRing': showProgressRing,
        'enableAnimations': enableAnimations,
        'reducedMotion': reducedMotion,
        'flipSpeed': flipSpeed,
        'tickSoundEnabled': tickSoundEnabled,
        'flipSoundEnabled': flipSoundEnabled,
        'completeSoundEnabled': completeSoundEnabled,
        'isMuted': isMuted,
        'autoSwitchStyle': autoSwitchStyle,
        'transitionEffect': transitionEffect,
        'activePresetName': activePresetName,
      };

  factory TimerCustomizationState.fromJson(Map<String, dynamic> json) =>
      TimerCustomizationState(
        fontStyle: json['fontStyle'] ?? 'minimal',
        size: json['size'] ?? 'large',
        colorTheme: json['colorTheme'] ?? 'auto',
        backgroundMode: json['backgroundMode'] ?? 'glassmorphism',
        showSeconds: json['showSeconds'] ?? true,
        showMilliseconds: json['showMilliseconds'] ?? false,
        showSessionLabel: json['showSessionLabel'] ?? true,
        showTaskName: json['showTaskName'] ?? true,
        showProgressRing: json['showProgressRing'] ?? true,
        enableAnimations: json['enableAnimations'] ?? true,
        reducedMotion: json['reducedMotion'] ?? false,
        flipSpeed: (json['flipSpeed'] as num?)?.toDouble() ?? 1.0,
        tickSoundEnabled: json['tickSoundEnabled'] ?? false,
        flipSoundEnabled: json['flipSoundEnabled'] ?? false,
        completeSoundEnabled: json['completeSoundEnabled'] ?? true,
        isMuted: json['isMuted'] ?? false,
        autoSwitchStyle: json['autoSwitchStyle'] ?? false,
        transitionEffect: json['transitionEffect'] ?? 'fade',
        activePresetName: json['activePresetName'],
      );
}

final timerCustomizationProvider =
    StateNotifierProvider<TimerCustomizationNotifier, TimerCustomizationState>(
        (ref) => TimerCustomizationNotifier());

class TimerCustomizationNotifier extends StateNotifier<TimerCustomizationState> {
  TimerCustomizationNotifier() : super(const TimerCustomizationState()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('timer_customization');
      if (saved != null) {
        state = TimerCustomizationState.fromJson(jsonDecode(saved));
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final localState = state;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('timer_customization', jsonEncode(localState.toJson()));
    } catch (_) {}
  }

  Future<void> reload() async {
    await _load();
  }

  void update(TimerCustomizationState newState) {
    state = newState;
    _save();
  }

  void reset() {
    state = const TimerCustomizationState();
    _save();
  }
}

final timerPresetsProvider = StateNotifierProvider<TimerPresetsNotifier,
    Map<String, TimerCustomizationState>>((ref) => TimerPresetsNotifier());

class TimerPresetsNotifier
    extends StateNotifier<Map<String, TimerCustomizationState>> {
  TimerPresetsNotifier() : super(const {}) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('timer_presets');
      if (saved != null) {
        final Map<String, dynamic> decoded = jsonDecode(saved);
        state = decoded.map((key, value) => MapEntry(
            key, TimerCustomizationState.fromJson(value as Map<String, dynamic>)));
      } else {
        // Load default presets
        state = {
          'Deep Work Setup': const TimerCustomizationState(
            fontStyle: 'futuristic',
            size: 'xl',
            colorTheme: 'red',
            backgroundMode: 'solid_dark',
            showSeconds: true,
          ),
          'Night Study Setup': const TimerCustomizationState(
            fontStyle: 'elegant',
            size: 'medium',
            colorTheme: 'blue',
            backgroundMode: 'glassmorphism',
            showSeconds: false,
          ),
        };
        _save();
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> encoded =
          state.map((key, value) => MapEntry(key, value.toJson()));
      await prefs.setString('timer_presets', jsonEncode(encoded));
    } catch (_) {}
  }

  void savePreset(String name, TimerCustomizationState settings) {
    state = {
      ...state,
      name: settings.copyWith(activePresetName: name),
    };
    _save();
  }

  void deletePreset(String name) {
    final newState = Map<String, TimerCustomizationState>.from(state)
      ..remove(name);
    state = newState;
    _save();
  }
}

// ──────────────────────────────────────────────
// Mini Floating Timer mode Provider
// ──────────────────────────────────────────────

final miniModeProvider = StateNotifierProvider<MiniModeNotifier, bool>((ref) => MiniModeNotifier());

class MiniModeNotifier extends StateNotifier<bool> {
  MiniModeNotifier() : super(false);
  Rect? _preMiniBounds;

  Future<void> toggle() async {
    if (kIsWeb) return;
    final isDesktop = Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    if (!isDesktop) return;

    final instance = wm.WindowManager.instance;
    try {
      if (state) {
        // Exit mini mode
        state = false;
        await instance.setAlwaysOnTop(false);
        await instance.setResizable(true);
        if (_preMiniBounds != null) {
          await instance.setBounds(_preMiniBounds!);
        } else {
          await instance.setSize(const Size(1280, 800));
          await instance.center();
        }
      } else {
        // Enter mini mode
        _preMiniBounds = await instance.getBounds();
        state = true;
        await instance.setAlwaysOnTop(true);
        await instance.setResizable(false);
        await instance.setSize(const Size(320, 360));
      }
    } catch (_) {}
  }
}

// ──────────────────────────────────────────────
// Focus History Provider
// ──────────────────────────────────────────────

final fokusHistoryProvider =
    StateNotifierProvider<FocusHistoryNotifier, List<FokusSession>>(
        (ref) => FocusHistoryNotifier());

class FocusHistoryNotifier extends StateNotifier<List<FokusSession>> {
  FocusHistoryNotifier() : super([]) {
    refresh();
  }

  void refresh() {
    state = FokusHistoryService.loadSessions();
  }

  Future<void> logSession(
    int minutes, {
    String? taskId,
    bool isInterrupted = false,
    String? sessionType,
    int? plannedDurationMinutes,
    int? actualDurationSeconds,
    String? startTime,
    String? endTime,
    bool isBreak = false,
  }) async {
    await FokusHistoryService.logDetailedSession(
      minutes,
      taskId: taskId,
      isInterrupted: isInterrupted,
      sessionType: sessionType ?? 'Pomodoro',
      plannedDurationMinutes: plannedDurationMinutes,
      actualDurationSeconds: actualDurationSeconds,
      startTime: startTime,
      endTime: endTime,
      isBreak: isBreak,
    );

    refresh();
  }
}

// ──────────────────────────────────────────────
// Habits & Completions
// ──────────────────────────────────────────────

final habitCompletionsProvider =
    StateNotifierProvider<HabitCompletionsNotifier, List<HabitCompletion>>(
        (ref) => HabitCompletionsNotifier(ref));

class HabitCompletionsNotifier extends StateNotifier<List<HabitCompletion>> {
  final Ref _ref;

  HabitCompletionsNotifier(this._ref) : super([]) {
    _load();
  }

  void _load() {
    state = HabitService.loadCompletions();
  }

  Future<void> _persist() async {
    await HabitService.saveCompletions(state);
    // When completions change, we MUST recalculate streaks for habits!
    _ref.read(habitsProvider.notifier).recalculateStreaks(state);
  }

  void reload() => _load();

  Future<void> toggleCompletion(String habitId, DateTime date) async {
    final dateStr = date.toIso8601String().substring(0, 10);
    final existingIndex = state.indexWhere((c) => c.habitId == habitId && c.date == dateStr);

    if (existingIndex != -1) {
      // Remove completion
      state = state.where((c) => !(c.habitId == habitId && c.date == dateStr)).toList();
    } else {
      // Add completion
      final comp = HabitCompletion(
        id: 'comp_${DateTime.now().millisecondsSinceEpoch}_${habitId.hashCode}',
        habitId: habitId,
        date: dateStr,
        completed: true,
        timestamp: date,
      );
      state = [...state, comp];
    }
    await _persist();
  }

  Future<void> updateCompletionNotes(String habitId, DateTime date, String? notes) async {
    final dateStr = date.toIso8601String().substring(0, 10);
    final index = state.indexWhere((c) => c.habitId == habitId && c.date == dateStr);

    if (index != -1) {
      if (notes == null || notes.trim().isEmpty) {
        // Keep completion but clear notes
        state = state.map((c) => c.habitId == habitId && c.date == dateStr ? c.copyWith(notes: null) : c).toList();
      } else {
        // Update notes
        state = state.map((c) => c.habitId == habitId && c.date == dateStr ? c.copyWith(notes: notes) : c).toList();
      }
    } else {
      if (notes != null && notes.trim().isNotEmpty) {
        // Create new completed record with notes
        final comp = HabitCompletion(
          id: 'comp_${DateTime.now().millisecondsSinceEpoch}_${habitId.hashCode}',
          habitId: habitId,
          date: dateStr,
          completed: true,
          timestamp: date,
          notes: notes,
        );
        state = [...state, comp];
      }
    }
    await _persist();
  }

  Future<void> addCompletion(String habitId, DateTime date) async {
    final comp = HabitCompletion(
      id: 'comp_${DateTime.now().millisecondsSinceEpoch}_${habitId.hashCode}',
      habitId: habitId,
      date: date.toIso8601String().substring(0, 10),
      completed: true,
      timestamp: date,
    );
    state = [...state, comp];
    await _persist();
  }

  Future<void> removeCompletion(String completionId) async {
    state = state.where((c) => c.id != completionId).toList();
    await _persist();
  }
}

final habitsProvider =
    StateNotifierProvider<HabitsNotifier, List<Habit>>((ref) => HabitsNotifier());

class HabitsNotifier extends StateNotifier<List<Habit>> {
  HabitsNotifier() : super([]) {
    _load();
  }

  void _load() {
    state = HabitService.loadHabits();
  }

  Future<void> _persist() async {
    await HabitService.saveHabits(state);
  }

  void reload() => _load();

  void addHabit(
    String name,
    String icon,
    String color,
    String frequency, {
    int targetCount = 1,
    String targetPeriod = 'day',
    List<int>? customWeekdays,
    String? reminderTime,
  }) {
    final habit = Habit(
      id: 'habit_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      icon: icon,
      color: color,
      frequency: frequency,
      targetCount: targetCount,
      targetPeriod: targetPeriod,
      customWeekdays: customWeekdays,
      reminderTime: reminderTime,
    );
    state = [habit, ...state];
    _persist();
  }

  void deleteHabit(String id) {
    state = state.where((h) => h.id != id).toList();
    _persist();
  }

  void updateHabit(Habit updated) {
    state = state.map((h) => h.id == updated.id ? updated : h).toList();
    _persist();
  }

  void recalculateStreaks(List<HabitCompletion> completions) {
    state = state.map((h) {
      return HabitService.recalculateStreaksForHabit(h, completions);
    }).toList();
    _persist();
  }
}

// ──────────────────────────────────────────────
// Goals Provider
// ──────────────────────────────────────────────

final goalsProvider =
    StateNotifierProvider<GoalsNotifier, Map<String, double>>((ref) => GoalsNotifier());

class GoalsNotifier extends StateNotifier<Map<String, double>> {
  GoalsNotifier() : super({
    'dailyFocusMinutes': 120.0, // 2 hours
    'weeklyFocusMinutes': 600.0, // 10 hours
    'dailyTasksCount': 3.0,
    'dailyHabitCompletionPercent': 80.0, // 80%
  }) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('goals_map');
    if (raw != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(raw);
        state = decoded.map((k, v) => MapEntry(k, (v as num).toDouble()));
      } catch (_) {}
    }
  }

  Future<void> updateGoal(String key, double value) async {
    state = {...state, key: value};
    final localState = state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('goals_map', jsonEncode(localState));
  }

  Future<void> reset() async {
    state = {
      'dailyFocusMinutes': 120.0,
      'weeklyFocusMinutes': 600.0,
      'dailyTasksCount': 3.0,
      'dailyHabitCompletionPercent': 80.0,
    };
    final localState = state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('goals_map', jsonEncode(localState));
  }
}

// ──────────────────────────────────────────────
// Timeline Goals Provider (Target Countdown Goals)
// ──────────────────────────────────────────────

final timelineGoalsProvider =
    StateNotifierProvider<TimelineGoalsNotifier, List<TimelineGoal>>((ref) => TimelineGoalsNotifier());

class TimelineGoalsNotifier extends StateNotifier<List<TimelineGoal>> {
  TimelineGoalsNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('timeline_goals_list');
    if (raw != null) {
      try {
        final List decoded = jsonDecode(raw);
        state = decoded
            .map((e) => TimelineGoal.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      } catch (_) {}
    } else {
      // Add default demo goals if empty
      final now = DateTime.now();
      state = [
        TimelineGoal(
          id: 'goal_demo_1',
          title: 'Final Exam Preparation',
          targetDate: now.add(const Duration(days: 45)),
          notes: 'Revise syllabus, complete mock tests, and practice sample papers.',
          color: '#3B82F6', // Blue
        ),
        TimelineGoal(
          id: 'goal_demo_2',
          title: 'UPSC Civil Services Exam',
          targetDate: now.add(const Duration(days: 120)),
          notes: 'Fokus on General Studies, daily answer writing, and optional subjects.',
          color: '#F59E0B', // Amber
        ),
      ];
      _save();
    }
  }

  Future<void> _save() async {
    final localState = state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'timeline_goals_list', jsonEncode(localState.map((g) => g.toJson()).toList()));
  }

  void addGoal(String title, DateTime targetDate, {String? notes, String color = '#6366F1'}) {
    final goal = TimelineGoal(
      id: 'goal_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      targetDate: targetDate,
      notes: notes,
      color: color,
    );
    state = [goal, ...state];
    _save();
  }

  void deleteGoal(String id) {
    state = state.where((g) => g.id != id).toList();
    _save();
  }

  void toggleGoalCompletion(String id) {
    state = state.map((g) => g.id == id ? g.copyWith(isCompleted: !g.isCompleted) : g).toList();
    _save();
  }

  void updateGoal(TimelineGoal updated) {
    state = state.map((g) => g.id == updated.id ? updated : g).toList();
    _save();
  }
}

// ──────────────────────────────────────────────
// Analytics Provider (Derived)
// ──────────────────────────────────────────────

final analyticsProvider = Provider<AnalyticsState>((ref) {
  final habits = ref.watch(habitsProvider);
  final completions = ref.watch(habitCompletionsProvider);
  final sessions = ref.watch(fokusHistoryProvider);
  final goals = ref.watch(goalsProvider);
  final tasks = ref.watch(tasksProvider);

  return AnalyticsService.calculateAnalytics(
    habits: habits,
    completions: completions,
    sessions: sessions,
    goals: goals,
    tasks: tasks,
  );
});

// ── Data & Backup Settings Providers ──

final autoBackupProvider = StateProvider<bool>((ref) => false);
final sessionRecoveryProvider = StateProvider<bool>((ref) => true);

// Social / Friends Providers removed

final habitEmojiSizeProvider = StateNotifierProvider<HabitEmojiSizeNotifier, double>((ref) {
  return HabitEmojiSizeNotifier();
});

class HabitEmojiSizeNotifier extends StateNotifier<double> {
  HabitEmojiSizeNotifier() : super(14.0) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getDouble('habit_emoji_size') ?? 14.0;
  }

  Future<void> setSize(double size) async {
    state = size;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('habit_emoji_size', size);
  }
}

// ── Habit Column Order Provider ──

final habitOrderProvider = StateNotifierProvider<HabitOrderNotifier, List<String>>((ref) {
  return HabitOrderNotifier();
});

class HabitOrderNotifier extends StateNotifier<List<String>> {
  HabitOrderNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('habit_column_order');
    if (raw != null) state = raw;
  }

  Future<void> setOrder(List<String> order) async {
    state = order;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('habit_column_order', order);
  }

  /// Ensure all habit IDs are represented. Add missing ones, remove stale ones.
  List<String> resolveOrder(List<String> activeHabitIds) {
    final ordered = <String>[];
    // Add ids that exist in saved order AND in active habits
    for (final id in state) {
      if (activeHabitIds.contains(id)) ordered.add(id);
    }
    // Add any new habits not in saved order
    for (final id in activeHabitIds) {
      if (!ordered.contains(id)) ordered.add(id);
    }
    return ordered;
  }
}

// ──────────────────────────────────────────────
// Sticky Notes
// ──────────────────────────────────────────────

class StickyNoteData {
  final String id;
  final String text;
  final Color color;
  final double x;
  final double y;
  final double width;
  final double height;
  final DateTime timestamp;

  StickyNoteData({
    required this.id,
    required this.text,
    required this.color,
    required this.x,
    required this.y,
    this.width = 220,
    this.height = 220,
    DateTime? timestamp,
  }) : this.timestamp = timestamp ?? DateTime.now();

  StickyNoteData copyWith({
    String? id,
    String? text,
    Color? color,
    double? x,
    double? y,
    double? width,
    double? height,
    DateTime? timestamp,
  }) =>
      StickyNoteData(
        id: id ?? this.id,
        text: text ?? this.text,
        color: color ?? this.color,
        x: x ?? this.x,
        y: y ?? this.y,
        width: width ?? this.width,
        height: height ?? this.height,
        timestamp: timestamp ?? this.timestamp,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'colorValue': color.toARGB32(),
        'x': x,
        'y': y,
        'width': width,
        'height': height,
        'timestamp': timestamp.toIso8601String(),
      };

  factory StickyNoteData.fromJson(Map<String, dynamic> json) => StickyNoteData(
        id: json['id'] as String,
        text: json['text'] as String? ?? '',
        color: Color(json['colorValue'] as int? ?? 0xFFFFF9C4),
        x: (json['x'] as num? ?? 100.0).toDouble(),
        y: (json['y'] as num? ?? 100.0).toDouble(),
        width: (json['width'] as num? ?? 220.0).toDouble(),
        height: (json['height'] as num? ?? 220.0).toDouble(),
        timestamp: json['timestamp'] != null
            ? DateTime.parse(json['timestamp'] as String)
            : DateTime.now(),
      );
}

final stickyNotesProvider =
    StateNotifierProvider<StickyNotesNotifier, List<StickyNoteData>>((ref) {
  return StickyNotesNotifier();
});

class StickyNotesNotifier extends StateNotifier<List<StickyNoteData>> {
  StickyNotesNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('sticky_notes');
    if (raw != null) {
      try {
        final List decoded = jsonDecode(raw);
        state = decoded
            .map((e) => StickyNoteData.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      } catch (e) {
        debugPrint('Error loading sticky notes: $e');
      }
    }
  }

  Future<void> _persist() async {
    final localState = state;
    final prefs = await SharedPreferences.getInstance();
    final serialized = jsonEncode(localState.map((e) => e.toJson()).toList());
    await prefs.setString('sticky_notes', serialized);
  }

  void addNote(double x, double y) {
    const colors = [
      Color(0xFFFFF9C4), // Pastel Yellow
      Color(0xFFF8BBD0), // Pastel Pink
      Color(0xFFB3E5FC), // Pastel Blue
      Color(0xFFC8E6C9), // Pastel Green
      Color(0xFFE1BEE7), // Pastel Purple
    ];
    final color = colors[state.length % colors.length];
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    state = [...state, StickyNoteData(id: id, text: '', color: color, x: x, y: y)];
    _persist();
  }

  void addNoteWithText(String text, {double x = 200, double y = 200}) {
    const colors = [
      Color(0xFFFFF9C4), // Pastel Yellow
      Color(0xFFF8BBD0), // Pastel Pink
      Color(0xFFB3E5FC), // Pastel Blue
      Color(0xFFC8E6C9), // Pastel Green
      Color(0xFFE1BEE7), // Pastel Purple
    ];
    final color = colors[state.length % colors.length];
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    state = [...state, StickyNoteData(id: id, text: text, color: color, x: x, y: y)];
    _persist();
  }

  void updateText(String id, String text) {
    state = state.map((n) => n.id == id ? n.copyWith(text: text, timestamp: DateTime.now()) : n).toList();
    _persist();
  }

  void updatePosition(String id, double x, double y) {
    state = state.map((n) => n.id == id ? n.copyWith(x: x, y: y) : n).toList();
    _persist();
  }

  void updateSize(String id, double width, double height) {
    state = state.map((n) => n.id == id ? n.copyWith(width: width, height: height) : n).toList();
    _persist();
  }

  void updateColor(String id, Color color) {
    state = state.map((n) => n.id == id ? n.copyWith(color: color) : n).toList();
    _persist();
  }

  void deleteNote(String id) {
    state = state.where((n) => n.id != id).toList();
    _persist();
  }
}

enum StickyOverlayState {
  off,
  bubble,
  expanded,
}

final stickyOverlayProvider = StateNotifierProvider<StickyOverlayNotifier, StickyOverlayState>((ref) {
  return StickyOverlayNotifier();
});

class StickyOverlayNotifier extends StateNotifier<StickyOverlayState> {
  StickyOverlayNotifier() : super(StickyOverlayState.off);
  Rect? _preOverlayBounds;

  Future<void> enterBubble() async {
    if (kIsWeb) return;
    final instance = wm.WindowManager.instance;
    try {
      if (state == StickyOverlayState.off) {
        _preOverlayBounds = await instance.getBounds();
      }
      state = StickyOverlayState.bubble;
      await instance.setAlwaysOnTop(true);
      await instance.setResizable(false);
      await instance.setSize(const Size(72, 72));
    } catch (_) {}
  }

  Future<void> enterExpanded() async {
    if (kIsWeb) return;
    final instance = wm.WindowManager.instance;
    try {
      if (state == StickyOverlayState.off) {
        _preOverlayBounds = await instance.getBounds();
      }
      state = StickyOverlayState.expanded;
      await instance.setAlwaysOnTop(true);
      await instance.setResizable(false);
      await instance.setSize(const Size(320, 380));
    } catch (_) {}
  }

  Future<void> exit() async {
    if (kIsWeb) return;
    final instance = wm.WindowManager.instance;
    try {
      state = StickyOverlayState.off;
      await instance.setAlwaysOnTop(false);
      await instance.setResizable(true);
      if (_preOverlayBounds != null) {
        await instance.setBounds(_preOverlayBounds!);
      } else {
        await instance.setSize(const Size(1280, 800));
        await instance.center();
      }
    } catch (_) {}
  }
}

// ──────────────────────────────────────────────
// Pinned Countdown Goal Provider
// ──────────────────────────────────────────────

final pinnedGoalIdProvider =
    StateNotifierProvider<PinnedGoalIdNotifier, String?>((ref) => PinnedGoalIdNotifier());

class PinnedGoalIdNotifier extends StateNotifier<String?> {
  PinnedGoalIdNotifier() : super(null) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString('pinned_goal_id');
  }

  Future<void> setPinnedGoalId(String? id) async {
    state = id;
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove('pinned_goal_id');
    } else {
      await prefs.setString('pinned_goal_id', id);
    }
  }
}

// Tracks the active tab index on the Tasks page (0: Tasks, 1: Habits, 2: Goals)
final tasksActiveTabIndexProvider = StateProvider<int>((ref) => 0);

// ──────────────────────────────────────────────
// Reminders Provider
// ──────────────────────────────────────────────

final remindersProvider =
    StateNotifierProvider<RemindersNotifier, List<Reminder>>((ref) => RemindersNotifier());

class RemindersNotifier extends StateNotifier<List<Reminder>> {
  RemindersNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('reminders_list');
    if (raw != null) {
      try {
        final List decoded = jsonDecode(raw);
        state = decoded
            .map((e) => Reminder.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      } catch (_) {}
    } else {
      state = [];
    }
  }

  Future<void> _save() async {
    final localState = state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'reminders_list', jsonEncode(localState.map((r) => r.toJson()).toList()));
  }

  int _getNotificationId(String id) {
    final numericString = id.replaceAll(RegExp(r'\D'), '');
    if (numericString.isNotEmpty) {
      final parsed = int.tryParse(numericString);
      if (parsed != null) {
        return parsed % 2147483647;
      }
    }
    return id.hashCode % 2147483647;
  }

  void addReminder(String title, String description, DateTime dateTime, String? alarmSoundPath) {
    final reminder = Reminder(
      id: 'reminder_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      description: description,
      dateTime: dateTime,
      isTriggered: false,
      alarmSoundPath: alarmSoundPath,
    );
    state = [reminder, ...state];
    _save();

    if (reminder.dateTime.isAfter(DateTime.now()) && reminder.alarmEnabled) {
      NotificationService.schedule(
        id: _getNotificationId(reminder.id),
        title: reminder.title,
        body: reminder.description.isNotEmpty ? reminder.description : 'Your scheduled reminder.',
        scheduledDate: reminder.dateTime,
      );
    }
  }

  void deleteReminder(String id) {
    NotificationService.cancel(_getNotificationId(id));
    state = state.where((r) => r.id != id).toList();
    _save();
  }

  void markAsTriggered(String id) {
    NotificationService.cancel(_getNotificationId(id));
    state = state.map((r) => r.id == id ? r.copyWith(isTriggered: true) : r).toList();
    _save();
  }

  void updateReminder(Reminder updated) {
    state = state.map((r) => r.id == updated.id ? updated : r).toList();
    _save();
  }

  void toggleAlarm(String id) {
    state = state.map((r) {
      if (r.id == id) {
        final updated = r.copyWith(alarmEnabled: !r.alarmEnabled);
        if (updated.alarmEnabled && !updated.isTriggered && updated.dateTime.isAfter(DateTime.now())) {
          NotificationService.schedule(
            id: _getNotificationId(updated.id),
            title: updated.title,
            body: updated.description.isNotEmpty ? updated.description : 'Your scheduled reminder.',
            scheduledDate: updated.dateTime,
          );
        } else {
          NotificationService.cancel(_getNotificationId(updated.id));
        }
        return updated;
      }
      return r;
    }).toList();
    _save();
  }

}

// Holds the currently triggered reminder that needs to be displayed in a popup overlay
final activeReminderPopupProvider = StateProvider<Reminder?>((ref) => null);

// State Provider to track if Focus should run in the background on close
final runInBackgroundProvider = StateNotifierProvider<RunInBackgroundNotifier, bool>((ref) {
  return RunInBackgroundNotifier();
});

class RunInBackgroundNotifier extends StateNotifier<bool> {
  RunInBackgroundNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool('run_in_background') ?? false;
  }

  Future<void> setRunInBackground(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('run_in_background', value);
  }
}





