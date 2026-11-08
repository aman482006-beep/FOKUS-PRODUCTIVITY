// ignore_for_file: non_const_argument_for_const_parameter

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/ambient_sound_service.dart';

// ──────────────────────────────────────────────
// Focus Profile Model
// ──────────────────────────────────────────────

class FocusProfile {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final int fokusMinutes;
  final AmbientSoundType ambientSound;
  final double ambientVolume;
  final int blueLightTemperature;
  final bool blueLightEnabled;
  final bool blockDistractions;
  final List<String> blockedWebsites;
  final List<String> blockedApps;
  final bool enableHardcoreLock;

  FocusProfile({
    required this.id,
    required this.name,
    this.description = '',
    this.icon = Icons.auto_awesome,
    this.fokusMinutes = 25,
    this.ambientSound = AmbientSoundType.none,
    this.ambientVolume = 0.3,
    this.blueLightTemperature = 4500,
    this.blueLightEnabled = false,
    this.blockDistractions = false,
    this.blockedWebsites = const [],
    this.blockedApps = const [],
    this.enableHardcoreLock = false,
  });

  String get iconName => icon.codePoint.toString();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'icon': icon.codePoint,
        'fokusMinutes': fokusMinutes,
        'ambientSound': ambientSound.name,
        'ambientVolume': ambientVolume,
        'blueLightTemperature': blueLightTemperature,
        'blueLightEnabled': blueLightEnabled,
        'blockDistractions': blockDistractions,
        'blockedWebsites': blockedWebsites,
        'blockedApps': blockedApps,
        'enableHardcoreLock': enableHardcoreLock,
      };

  factory FocusProfile.fromJson(Map<String, dynamic> json) {
    final iconCode = json['icon'] as int? ?? 0xe5b1;
    final icon = IconData(iconCode, fontFamily: 'MaterialIcons');
    return FocusProfile(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        icon: icon,
        fokusMinutes: json['fokusMinutes'] as int? ?? 25,
        ambientSound: AmbientSoundType.values.firstWhere(
          (t) => t.name == json['ambientSound'],
          orElse: () => AmbientSoundType.none,
        ),
        ambientVolume: (json['ambientVolume'] as num?)?.toDouble() ?? 0.3,
        blueLightTemperature: json['blueLightTemperature'] as int? ?? 4500,
        blueLightEnabled: json['blueLightEnabled'] as bool? ?? false,
        blockDistractions: json['blockDistractions'] as bool? ?? false,
        blockedWebsites: (json['blockedWebsites'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        blockedApps: (json['blockedApps'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        enableHardcoreLock: json['enableHardcoreLock'] as bool? ?? false,
      );
  }

  FocusProfile copyWith({
    String? id,
    String? name,
    String? description,
    IconData? icon,
    int? fokusMinutes,
    AmbientSoundType? ambientSound,
    double? ambientVolume,
    int? blueLightTemperature,
    bool? blueLightEnabled,
    bool? blockDistractions,
    List<String>? blockedWebsites,
    List<String>? blockedApps,
    bool? enableHardcoreLock,
  }) =>
      FocusProfile(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        icon: icon ?? this.icon,
        fokusMinutes: fokusMinutes ?? this.fokusMinutes,
        ambientSound: ambientSound ?? this.ambientSound,
        ambientVolume: ambientVolume ?? this.ambientVolume,
        blueLightTemperature: blueLightTemperature ?? this.blueLightTemperature,
        blueLightEnabled: blueLightEnabled ?? this.blueLightEnabled,
        blockDistractions: blockDistractions ?? this.blockDistractions,
        blockedWebsites: blockedWebsites ?? this.blockedWebsites,
        blockedApps: blockedApps ?? this.blockedApps,
        enableHardcoreLock: enableHardcoreLock ?? this.enableHardcoreLock,
      );
}

// ──────────────────────────────────────────────
// Profile Engine Service
// ──────────────────────────────────────────────

/// Manages focus profiles (presets + custom).
///
/// This is a purely static service. For DI-aware access, use [ProfileEngineServiceAdapter].
class ProfileEngineService {
  ProfileEngineService._();

  static const _storageKey = 'focus_profiles';
  static const _activeKey = 'active_profile_id';

  /// Built-in presets
  static final List<FocusProfile> builtInProfiles = [
    FocusProfile(
      id: 'study',
      name: 'Study',
      description: 'Deep reading & memorization',
      icon: Icons.menu_book,
      fokusMinutes: 45,
      ambientSound: AmbientSoundType.rain,
      ambientVolume: 0.25,
      blueLightEnabled: true,
      blueLightTemperature: 4000,
      blockDistractions: true,
      blockedWebsites: [
        'youtube.com', 'instagram.com', 'facebook.com',
        'twitter.com', 'reddit.com', 'tiktok.com',
      ],
      blockedApps: ['discord.exe', 'steam.exe'],
    ),
    FocusProfile(
      id: 'coding',
      name: 'Coding',
      description: 'Deep work & programming',
      icon: Icons.code,
      fokusMinutes: 50,
      ambientSound: AmbientSoundType.whiteNoise,
      ambientVolume: 0.3,
      blueLightEnabled: false,
      blockDistractions: true,
      blockedWebsites: [
        'youtube.com', 'reddit.com', 'twitter.com', 'instagram.com',
      ],
      blockedApps: ['discord.exe', 'steam.exe'],
    ),
    FocusProfile(
      id: 'writing',
      name: 'Writing',
      description: 'Creative flow without interruption',
      icon: Icons.edit,
      fokusMinutes: 25,
      ambientSound: AmbientSoundType.cafe,
      ambientVolume: 0.25,
      blueLightEnabled: true,
      blueLightTemperature: 3800,
      blockDistractions: true,
      blockedWebsites: [
        'youtube.com', 'reddit.com', 'twitter.com', 'instagram.com',
        'facebook.com', 'news.ycombinator.com',
      ],
      blockedApps: ['discord.exe', 'steam.exe'],
    ),
    FocusProfile(
      id: 'exam_prep',
      name: 'Exam Prep',
      description: 'Maximum concentration mode',
      icon: Icons.school,
      fokusMinutes: 60,
      ambientSound: AmbientSoundType.rain,
      ambientVolume: 0.2,
      blueLightEnabled: true,
      blueLightTemperature: 3500,
      blockDistractions: true,
      blockedWebsites: [
        'youtube.com', 'instagram.com', 'facebook.com',
        'twitter.com', 'reddit.com', 'tiktok.com',
        'netflix.com', 'twitch.tv',
      ],
      blockedApps: [
        'discord.exe', 'steam.exe', 'spotify.exe',
        'epicgameslauncher.exe',
      ],
      enableHardcoreLock: true,
    ),
    FocusProfile(
      id: 'reading',
      name: 'Reading Mode',
      description: 'Relaxed fokus for reading',
      icon: Icons.chrome_reader_mode,
      fokusMinutes: 30,
      ambientSound: AmbientSoundType.whiteNoise,
      ambientVolume: 0.2,
      blueLightEnabled: true,
      blueLightTemperature: 3400,
      blockDistractions: false,
    ),
  ];

  // ── Public Static API ──

  /// Load all profiles (built-in + custom).
  static Future<List<FocusProfile>> loadProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey) ?? '[]';
    try {
      final custom = (jsonDecode(raw) as List)
          .map((e) => FocusProfile.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      return [...builtInProfiles, ...custom];
    } catch (_) {
      return [...builtInProfiles];
    }
  }

  /// Save a custom profile.
  static Future<void> saveProfile(FocusProfile profile) async {
    final all = await loadProfiles();
    all.removeWhere((p) => p.id == profile.id);
    all.add(profile);
    await _persistCustom(all);
  }

  /// Delete a profile by id.
  static Future<void> deleteProfile(String id) async {
    final all = await loadProfiles();
    all.removeWhere((p) => p.id == id);
    await _persistCustom(all);
  }

  /// Get the currently active profile id.
  static Future<String?> getActiveProfileId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activeKey);
  }

  /// Set the active profile id.
  static Future<void> setActiveProfileId(String? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id != null) {
      await prefs.setString(_activeKey, id);
    } else {
      await prefs.remove(_activeKey);
    }
  }

  // ── Internal ──

  static Future<void> _persistCustom(List<FocusProfile> all) async {
    final prefs = await SharedPreferences.getInstance();
    final customIds = builtInProfiles.map((p) => p.id).toSet();
    final custom = all.where((p) => !customIds.contains(p.id)).toList();
    await prefs.setString(
        _storageKey, jsonEncode(custom.map((p) => p.toJson()).toList()));
  }
}
