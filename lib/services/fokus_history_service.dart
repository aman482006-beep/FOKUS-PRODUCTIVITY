import 'dart:convert';

import '../models/fokus_session.dart';
import 'storage_service.dart';

/// Tracks completed focus sessions by date and computes analytics
/// such as the current daily streak, per-day counts, and per-task stats.
///
/// This is a purely static service. For DI-aware access, use [FokusHistoryServiceAdapter].
class FokusHistoryService {
  FokusHistoryService._();

  static const _datesKey = 'focus_dates';
  static const _sessionsKey = 'fokus_sessions';

  // ── Static API ──

  static List<String> _loadDates() {
    final raw = StorageService.prefsStatic.getString(_datesKey) ?? '[]';
    try {
      return List<String>.from(jsonDecode(raw) as List);
    } catch (_) {
      return [];
    }
  }

  static Future<void> _saveDates(List<String> dates) async {
    await StorageService.prefsStatic.setString(_datesKey, jsonEncode(dates));
  }

  static List<FokusSession> loadSessions() {
    final raw = StorageService.prefsStatic.getString(_sessionsKey) ?? '[]';
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => FokusSession.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _saveSessions(List<FokusSession> sessions) async {
    await StorageService.prefsStatic.setString(
        _sessionsKey, jsonEncode(sessions.map((s) => s.toJson()).toList()));
  }

  static Future<void> logFokusSession() async {
    final now = DateTime.now();
    final today = now.toIso8601String().substring(0, 10);
    final dates = _loadDates();
    if (!dates.contains(today)) {
      dates.add(today);
      await _saveDates(dates);
    }
  }

  static Future<void> logDetailedSession(
    int durationMinutes, {
    String? taskId,
    bool isInterrupted = false,
    String? sessionType,
    int? plannedDurationMinutes,
    int? actualDurationSeconds,
    String? startTime,
    String? endTime,
    bool isBreak = false,
  }) async {
    final now = DateTime.now();
    final today = now.toIso8601String().substring(0, 10);

    final session = FokusSession(
      date: today,
      durationMinutes: durationMinutes,
      timestamp: now.toIso8601String(),
      taskId: taskId,
      isInterrupted: isInterrupted,
      sessionType: sessionType ?? 'Pomodoro',
      plannedDurationMinutes: plannedDurationMinutes,
      actualDurationSeconds: actualDurationSeconds,
      startTime: startTime,
      endTime: endTime,
      isBreak: isBreak,
    );

    final sessions = loadSessions();
    sessions.add(session);
    await _saveSessions(sessions);

    final dates = _loadDates();
    if (!dates.contains(today)) {
      dates.add(today);
      await _saveDates(dates);
    }
  }

  static int todayMinutes() {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return loadSessions()
        .where((s) => s.date == today && !s.isBreak && s.durationMinutes > 0)
        .fold(0, (sum, s) => sum + s.durationMinutes);
  }

  static int todaySessions() {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return loadSessions()
        .where((s) => s.date == today && !s.isBreak && s.durationMinutes > 0)
        .length;
  }

  static List<int> dailyMinutes({int days = 7}) {
    final sessions = loadSessions();
    final now = DateTime.now();
    return List.generate(days, (i) {
      final day = now.subtract(Duration(days: days - 1 - i));
      final key = day.toIso8601String().substring(0, 10);
      return sessions
          .where((s) => s.date == key && !s.isBreak && s.durationMinutes > 0)
          .fold(0, (sum, s) => sum + s.durationMinutes);
    });
  }

  static int totalMinutes() {
    return loadSessions()
        .where((s) => !s.isBreak && s.durationMinutes > 0)
        .fold(0, (sum, s) => sum + s.durationMinutes);
  }

  static int totalSessionsCount() {
    return loadSessions().where((s) => !s.isBreak && s.durationMinutes > 0).length;
  }

  static double averageMinutes() {
    final sessions = loadSessions().where((s) => !s.isBreak && s.durationMinutes > 0).toList();
    if (sessions.isEmpty) return 0;
    return sessions.fold(0, (sum, s) => sum + s.durationMinutes) / sessions.length;
  }

  static List<FokusSession> recentSessions({int limit = 20}) {
    final sessions = loadSessions();
    sessions.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return sessions.take(limit).toList();
  }

  static int taskMinutes(String taskId) {
    return loadSessions()
        .where((s) => s.taskId == taskId && !s.isBreak && s.durationMinutes > 0)
        .fold(0, (sum, s) => sum + s.durationMinutes);
  }

  static int bestStreak() {
    final dates = _loadDates().toSet();
    if (dates.isEmpty) return 0;
    final sorted = dates.toList()..sort();
    int best = 1;
    int current = 1;
    for (int i = 1; i < sorted.length; i++) {
      final prev = DateTime.parse(sorted[i - 1]);
      final curr = DateTime.parse(sorted[i]);
      if (curr.difference(prev).inDays == 1) {
        current++;
        if (current > best) best = current;
      } else {
        current = 1;
      }
    }
    return best;
  }

  static int getDailyStreak() {
    final dates = _loadDates().toSet();
    if (dates.isEmpty) return 0;

    final today = DateTime.now();
    final todayStr = today.toIso8601String().substring(0, 10);
    final yesterdayStr = today.subtract(const Duration(days: 1)).toIso8601String().substring(0, 10);
    if (!dates.contains(todayStr) && !dates.contains(yesterdayStr)) return 0;

    int streak = 0;
    var cursor = dates.contains(todayStr) ? today : today.subtract(const Duration(days: 1));
    while (true) {
      final key = cursor.toIso8601String().substring(0, 10);
      if (dates.contains(key)) {
        streak++;
        cursor = cursor.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }

  static List<int> getDailyCounts({int days = 28}) {
    final dates = _loadDates();
    final now = DateTime.now();
    return List.generate(days, (i) {
      final day = now.subtract(Duration(days: days - 1 - i));
      final key = day.toIso8601String().substring(0, 10);
      return dates.where((d) => d == key).length;
    });
  }

  static String? _lastSessionDuration;
  static int? _lastSessionNumber;

  static void recordLastSession(String durationLabel, int sessionNumber) {
    _lastSessionDuration = durationLabel;
    _lastSessionNumber = sessionNumber;
  }

  static Map<String, dynamic>? get lastSessionInfo {
    if (_lastSessionDuration == null) return null;
    return {
      'duration': _lastSessionDuration,
      'number': _lastSessionNumber,
    };
  }

  static const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
}
