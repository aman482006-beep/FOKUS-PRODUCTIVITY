import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'sound_service.dart';

class CustomAlarm {
  final String id;
  final String name;
  final String filePath;

  CustomAlarm({
    required this.id,
    required this.name,
    required this.filePath,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'filePath': filePath,
      };

  factory CustomAlarm.fromJson(Map<String, dynamic> json) => CustomAlarm(
        id: json['id'] as String,
        name: json['name'] as String,
        filePath: json['filePath'] as String,
      );
}

class TimerSoundState {
  final bool loopAlarm;
  final String selectedAlarmSound; // Can be asset path or custom alarm ID
  final List<CustomAlarm> customAlarms;
  final bool isAlarmPlaying;
  final bool tickEnabled;

  const TimerSoundState({
    this.loopAlarm = true,
    this.selectedAlarmSound = 'assets/alarm_sounds/digital alarm.mp3',
    this.customAlarms = const [],
    this.isAlarmPlaying = false,
    this.tickEnabled = false,
  });

  TimerSoundState copyWith({
    bool? loopAlarm,
    String? selectedAlarmSound,
    List<CustomAlarm>? customAlarms,
    bool? isAlarmPlaying,
    bool? tickEnabled,
  }) {
    return TimerSoundState(
      loopAlarm: loopAlarm ?? this.loopAlarm,
      selectedAlarmSound: selectedAlarmSound ?? this.selectedAlarmSound,
      customAlarms: customAlarms ?? this.customAlarms,
      isAlarmPlaying: isAlarmPlaying ?? this.isAlarmPlaying,
      tickEnabled: tickEnabled ?? this.tickEnabled,
    );
  }
}

class TimerSoundNotifier extends StateNotifier<TimerSoundState> {
  final AudioPlayer _alarmPlayer = AudioPlayer();
  StreamSubscription? _alarmStateSubscription;

  TimerSoundNotifier() : super(const TimerSoundState()) {
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final loopAlarm = prefs.getBool('timer_sound_loop_alarm') ?? true;
    final selectedAlarm = prefs.getString('timer_sound_selected_alarm') ?? 'assets/alarm_sounds/digital alarm.mp3';
    final tickEnabled = prefs.getBool('timer_sound_tick_enabled') ?? false;

    // Load custom alarms
    final customAlarmsRaw = prefs.getString('timer_sound_custom_alarms');
    List<CustomAlarm> customAlarms = [];
    if (customAlarmsRaw != null) {
      try {
        final decoded = jsonDecode(customAlarmsRaw) as List;
        customAlarms = decoded
            .map((e) => CustomAlarm.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      } catch (e) {
        debugPrint('Error loading custom alarms: $e');
      }
    }

    if (!mounted) return;

    state = TimerSoundState(
      loopAlarm: loopAlarm,
      selectedAlarmSound: selectedAlarm,
      customAlarms: customAlarms,
      isAlarmPlaying: false,
      tickEnabled: tickEnabled,
    );

    // Watch play completion stream for non-looping alarm to update playing state
    _alarmStateSubscription = _alarmPlayer.playerStateStream.listen((playerState) {
      if (!mounted) return;
      if (playerState.processingState == ProcessingState.completed) {
        state = state.copyWith(isAlarmPlaying: false);
      }
    });

    // Preload alarm sound
    _preloadAlarm();
  }

  Future<void> _preloadAlarm() async {
    try {
      final selected = state.selectedAlarmSound;
      if (selected.startsWith('assets/')) {
        await _alarmPlayer.setAudioSource(AudioSource.asset(selected), preload: true);
      } else {
        final customIndex = state.customAlarms.indexWhere((element) => element.id == selected);
        if (customIndex != -1) {
          final custom = state.customAlarms[customIndex];
          if (!kIsWeb) {
            await _alarmPlayer.setAudioSource(AudioSource.file(custom.filePath), preload: true);
          }
        }
      }
    } catch (e) {
      debugPrint('Error preloading alarm sound: $e');
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('timer_sound_loop_alarm', state.loopAlarm);
    await prefs.setString('timer_sound_selected_alarm', state.selectedAlarmSound);
    await prefs.setBool('timer_sound_tick_enabled', state.tickEnabled);

    final serialized = jsonEncode(state.customAlarms.map((e) => e.toJson()).toList());
    await prefs.setString('timer_sound_custom_alarms', serialized);
  }

  Future<void> setLoopEnabled(bool enabled) async {
    state = state.copyWith(loopAlarm: enabled);
    await _persist();
    if (state.isAlarmPlaying) {
      try {
        await _alarmPlayer.setLoopMode(enabled ? LoopMode.one : LoopMode.off);
      } catch (_) {}
    }
  }

  Future<void> setAlarmSound(String soundPathOrId) async {
    state = state.copyWith(selectedAlarmSound: soundPathOrId);
    await _persist();
    await _preloadAlarm(); // Preload new alarm sound
    if (state.isAlarmPlaying) {
      await playAlarm();
    }
  }

  Future<void> playAlarm() async {
    try {
      await _alarmPlayer.stop();
      await _preloadAlarm(); // Ensure it is fully preloaded
      await _alarmPlayer.setLoopMode(state.loopAlarm ? LoopMode.one : LoopMode.off);
      if (!mounted) return;
      state = state.copyWith(isAlarmPlaying: true);
      await _alarmPlayer.play();
    } catch (e) {
      debugPrint('Error playing alarm: $e');
      if (!mounted) return;
      state = state.copyWith(isAlarmPlaying: false);
    }
  }

  Future<void> stopAlarm() async {
    try {
      await _alarmPlayer.stop();
    } catch (_) {}
    if (!mounted) return;
    state = state.copyWith(isAlarmPlaying: false);
  }

  Future<void> previewAlarm(String soundPathOrId) async {
    try {
      await _alarmPlayer.stop();
      if (soundPathOrId.startsWith('assets/')) {
        await _alarmPlayer.setAudioSource(AudioSource.asset(soundPathOrId), preload: true);
      } else {
        final customIndex = state.customAlarms.indexWhere((element) => element.id == soundPathOrId);
        if (customIndex != -1) {
          final custom = state.customAlarms[customIndex];
          if (!kIsWeb) {
            await _alarmPlayer.setAudioSource(AudioSource.file(custom.filePath), preload: true);
          } else {
            throw Exception('Local file play not supported on web');
          }
        } else {
          throw Exception('Alarm sound not found: $soundPathOrId');
        }
      }
      await _alarmPlayer.setLoopMode(LoopMode.off); // Play once for preview
      if (!mounted) return;
      state = state.copyWith(isAlarmPlaying: true);
      await _alarmPlayer.play();
    } catch (e) {
      debugPrint('Error previewing alarm: $e');
      if (!mounted) return;
      state = state.copyWith(isAlarmPlaying: false);
    }
  }

  Future<void> uploadCustomAlarm(String name, String sourcePath) async {
    if (kIsWeb) {
      debugPrint('Uploading custom alarm from path is not supported on web');
      return;
    }
    try {
      final file = File(sourcePath);
      if (!await file.exists()) {
        throw Exception("Source file does not exist");
      }

      final size = await file.length();
      if (size > 5 * 1024 * 1024) {
        throw Exception("File is too large. Maximum size allowed is 5MB.");
      }

      final extension = sourcePath.split('.').last.toLowerCase();
      if (extension != 'mp3' && extension != 'wav' && extension != 'ogg') {
        throw Exception("Unsupported format. Only mp3, wav, and ogg are allowed.");
      }

      final appDir = await getApplicationDocumentsDirectory();
      final uuid = const Uuid().v4();
      final targetFileName = 'custom_alarm_$uuid.$extension';
      final targetPath = '${appDir.path}/$targetFileName';

      await file.copy(targetPath);

      final newAlarm = CustomAlarm(
        id: uuid,
        name: name,
        filePath: targetPath,
      );

      if (!mounted) return;
      final updatedList = List<CustomAlarm>.from(state.customAlarms)..add(newAlarm);
      state = state.copyWith(customAlarms: updatedList);
      await _persist();
    } catch (e) {
      debugPrint('Error uploading custom alarm: $e');
      rethrow;
    }
  }

  Future<void> deleteCustomAlarm(String id) async {
    try {
      final index = state.customAlarms.indexWhere((s) => s.id == id);
      if (index == -1) return;

      final alarm = state.customAlarms[index];

      if (state.selectedAlarmSound == id) {
        await stopAlarm();
        if (!mounted) return;
        state = state.copyWith(
          selectedAlarmSound: 'assets/alarm_sounds/digital alarm.mp3',
        );
      }

      if (!kIsWeb) {
        final file = File(alarm.filePath);
        if (await file.exists()) {
          await file.delete();
        }
      }

      if (!mounted) return;
      final updatedList = List<CustomAlarm>.from(state.customAlarms)..removeAt(index);
      state = state.copyWith(customAlarms: updatedList);
      await _persist();
    } catch (e) {
      debugPrint('Error deleting custom alarm: $e');
    }
  }

  // ── Tick sound methods ──

  Future<void> setTickEnabled(bool enabled) async {
    state = state.copyWith(tickEnabled: enabled);
    await _persist();
    if (!enabled) {
      SoundService.stopTick();
    }
  }

  Future<void> playTick() async {
    await SoundService.playTick();
  }

  Future<void> stopTick() async {
    SoundService.stopTick();
  }

  Future<void> previewTick() async {
    await SoundService.playTick();
  }

  @override
  void dispose() {
    _alarmStateSubscription?.cancel();
    _alarmPlayer.dispose();
    super.dispose();
  }
}

final timerSoundProvider =
    StateNotifierProvider<TimerSoundNotifier, TimerSoundState>(
        (ref) => TimerSoundNotifier());
