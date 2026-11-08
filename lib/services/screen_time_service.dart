import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'window_helper_stub.dart'
    if (dart.library.ffi) 'window_helper_win32.dart';

/// Represents tracked app usage for a given date.
class AppUsageEntry {
  final String appName;
  final int totalSeconds;
  final String category; // e.g. 'Browser', 'Game', 'Productivity'

  const AppUsageEntry({
    required this.appName,
    required this.totalSeconds,
    this.category = 'Other',
  });

  String get formatted => ScreenTimeService._formatDuration(totalSeconds);

  Map<String, dynamic> toJson() => {
        'appName': appName,
        'totalSeconds': totalSeconds,
        'category': category,
      };

  factory AppUsageEntry.fromJson(Map<String, dynamic> json) => AppUsageEntry(
        appName: json['appName'] as String? ?? '',
        totalSeconds: json['totalSeconds'] as int? ?? 0,
        category: json['category'] as String? ?? 'Other',
      );
}

/// Tracks active window / process names on Windows to identify distraction patterns.
///
/// This is a purely static service. For DI-aware access, use [ScreenTimeServiceAdapter].
class ScreenTimeService {
  ScreenTimeService._();

  static const _storageKey = 'screen_time_data';
  static const _trackingInterval = Duration(seconds: 5);

  static String? _lastActiveWindow;
  static int _currentSessionSeconds = 0;
  static bool _tracking = false;

  static const _distractionProcesses = {
    'chrome.exe': 'Browser',
    'msedge.exe': 'Browser',
    'firefox.exe': 'Browser',
    'opera.exe': 'Browser',
    'brave.exe': 'Browser',
    'steam.exe': 'Game',
    'epicgameslauncher.exe': 'Game',
    'battlenet.exe': 'Game',
    'discord.exe': 'Social',
    'spotify.exe': 'Music',
    'youtube.exe': 'Video',
    'vlc.exe': 'Video',
    'code.exe': 'Productivity',
    'notepad++.exe': 'Productivity',
    'wmplayer.exe': 'Video',
  };

  // ── Public Static API ──

  /// Get the title of the currently active window.
  static Future<String> getActiveWindowTitle() async {
    try {
      if (kIsWeb) return 'Unknown';
      if (Platform.isWindows) {
        return WindowHelper.getActiveWindowTitle();
      }
    } catch (_) {}
    return 'Unknown';
  }

  /// Get the process name of the currently active window.
  static Future<String> getActiveProcessName() async {
    try {
      if (kIsWeb) return 'unknown.exe';
      if (Platform.isWindows) {
        return WindowHelper.getActiveProcessName();
      }
    } catch (_) {}
    return 'unknown.exe';
  }

  /// Start tracking active window usage.
  static void startTracking() {
    if (kIsWeb) return;
    if (_tracking) return;
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return;
    }
    _tracking = true;
    _trackingLoop();
  }

  /// Stop tracking active window usage.
  static void stopTracking() {
    _tracking = false;
  }

  /// Get today's app usage entries, sorted by most-used first.
  static Future<List<AppUsageEntry>> getTodayUsage() async {
    final data = await _loadAll();
    final today = _todayKey();
    final raw = data[today] as List? ?? [];
    return raw
        .map((e) => AppUsageEntry.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList()
      ..sort((a, b) => b.totalSeconds.compareTo(a.totalSeconds));
  }

  /// Get aggregated usage over the last [days] days.
  static Future<List<AppUsageEntry>> getUsageLastDays(int days) async {
    final data = await _loadAll();
    final aggregated = <String, int>{};
    final now = DateTime.now();

    for (int i = 0; i < days; i++) {
      final date = now.subtract(Duration(days: i));
      final key = _dateKey(date);
      final raw = data[key] as List? ?? [];
      for (final entry in raw) {
        final name = entry['appName'] as String? ?? '';
        final seconds = entry['totalSeconds'] as int? ?? 0;
        aggregated[name] = (aggregated[name] ?? 0) + seconds;
      }
    }

    return aggregated.entries
        .map((e) => AppUsageEntry(
              appName: e.key,
              totalSeconds: e.value,
              category: _distractionProcesses[e.key.toLowerCase()] ?? 'Other',
            ))
        .toList()
      ..sort((a, b) => b.totalSeconds.compareTo(a.totalSeconds));
  }

  /// Get total seconds tracked today.
  static Future<int> getTodayTotalSeconds() async {
    final entries = await getTodayUsage();
    return entries.fold<int>(0, (int sum, AppUsageEntry e) => sum + e.totalSeconds);
  }

  /// Get total seconds per day for the last [days] days.
  static Future<List<MapEntry<DateTime, int>>> getDailyHistoryLastDays(int days) async {
    final data = await _loadAll();
    final result = <MapEntry<DateTime, int>>[];
    final now = DateTime.now();

    for (int i = days - 1; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final key = _dateKey(date);
      final raw = data[key] as List? ?? [];
      int totalSeconds = 0;
      for (final entry in raw) {
        totalSeconds += entry['totalSeconds'] as int? ?? 0;
      }
      result.add(MapEntry(DateTime(date.year, date.month, date.day), totalSeconds));
    }
    return result;
  }

  /// Clear all stored screen time data.
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  // ── Internal ──

  static Future<void> _trackingLoop() async {
    while (_tracking) {
      try {
        final processName = await getActiveProcessName();
        if (processName == _lastActiveWindow) {
          _currentSessionSeconds += _trackingInterval.inSeconds;
        } else {
          if (_lastActiveWindow != null && _currentSessionSeconds > 0) {
            await _recordUsage(_lastActiveWindow!, _currentSessionSeconds);
          }
          _lastActiveWindow = processName;
          _currentSessionSeconds = 0;
        }
      } catch (_) {}
      await Future.delayed(_trackingInterval);
    }
  }

  static Future<void> _recordUsage(String appName, int seconds) async {
    final data = await _loadAll();
    final today = _todayKey();

    if (!data.containsKey(today)) {
      data[today] = <Map<String, dynamic>>[];
    }

    final entries = data[today] as List;
    final existingIdx = entries.indexWhere((e) => e['appName'] == appName);

    if (existingIdx >= 0) {
      entries[existingIdx]['totalSeconds'] =
          (entries[existingIdx]['totalSeconds'] as int) + seconds;
    } else {
      final category = _distractionProcesses[appName.toLowerCase()] ?? 'Other';
      entries.add({
        'appName': appName,
        'totalSeconds': seconds,
        'category': category,
      });
    }

    await _saveAll(data);
  }

  static String _todayKey() => _dateKey(DateTime.now());

  static String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  static Future<Map<String, dynamic>> _loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey) ?? '{}';
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }

  static Future<void> _saveAll(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(data));
  }

  static String _formatDuration(int totalSeconds) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }
}
