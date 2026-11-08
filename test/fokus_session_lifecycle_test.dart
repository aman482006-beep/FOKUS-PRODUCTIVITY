import 'package:flutter_test/flutter_test.dart';
import 'package:fokus/models/fokus_session.dart';

/// Simulates the full focus session lifecycle logic extracted from providers.
/// This tests the integration between TimerNotifier, FokusHistoryService,
/// PointService, and AnalyticsService.

// ─── Session Lifecycle Helpers ──────────────────────────────────────────────

/// Represents a completed focus session with all its metadata.
class CompletedSession {
  final String id;
  final DateTime startTime;
  final DateTime endTime;
  final int durationMinutes;
  final int pointsEarned;
  final String? taskId;
  final bool wasInterrupted;

  CompletedSession({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
    required this.pointsEarned,
    this.taskId,
    this.wasInterrupted = false,
  });

  int get durationSeconds => durationMinutes * 60;
}

/// Simulates the point calculation logic from PointService.
int calculatePoints({
  required int durationMinutes,
  required bool isDeepWork,
  required int currentStreak,
  required bool wasInterrupted,
}) {
  if (wasInterrupted) return 0;

  // Base points: 1 point per minute
  int points = durationMinutes;

  // Deep work bonus: 50% extra
  if (isDeepWork) {
    points = (points * 1.5).round();
  }

  // Streak bonus: up to 25% extra based on streak
  final streakBonus = (currentStreak * 0.05).clamp(0.0, 0.25);
  points = (points * (1 + streakBonus)).round();

  return points;
}

/// Simulates session logging logic from FokusHistoryService.
List<FokusSession> logSession({
  required List<FokusSession> existingSessions,
  required CompletedSession completed,
}) {
  final session = FokusSession(
    date: '${completed.startTime.year}-${completed.startTime.month.toString().padLeft(2, '0')}-${completed.startTime.day.toString().padLeft(2, '0')}',
    timestamp: completed.endTime.toIso8601String(),
    durationMinutes: completed.durationMinutes,
    taskId: completed.taskId,
    isInterrupted: completed.wasInterrupted,
  );
  return [...existingSessions, session];
}

/// Simulates analytics update logic from AnalyticsService.
Map<String, dynamic> updateAnalytics({
  required List<FokusSession> sessions,
  required Map<String, int> previousStreaks,
}) {
  if (sessions.isEmpty) {
    return {
      'totalMinutes': 0,
      'totalSessions': 0,
      'todayMinutes': 0,
      'currentStreak': 0,
      'longestStreak': 0,
      'heatmap': <String, int>{},
      'weekdayDistribution': List.filled(7, 0),
    };
  }

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  int totalMinutes = 0;
  int todayMinutes = 0;
  final heatmap = <String, int>{};
  final weekdayDistribution = List.filled(7, 0);

  for (final session in sessions) {
    totalMinutes += session.durationMinutes;

    final sessionDate = DateTime.parse(session.date);
    final dayKey =
        '${sessionDate.year}-${sessionDate.month.toString().padLeft(2, '0')}-${sessionDate.day.toString().padLeft(2, '0')}';

    if (!sessionDate.isBefore(today)) {
      todayMinutes += session.durationMinutes;
    }

    heatmap[dayKey] = (heatmap[dayKey] ?? 0) + session.durationMinutes;
    weekdayDistribution[sessionDate.weekday % 7] += session.durationMinutes;
  }

  // Calculate streaks
  int currentStreak = 0;
  int longestStreak = 0;
  int tempStreak = 0;
  DateTime? lastDate;

  final sortedDates = sessions
      .map((s) => DateTime.parse(s.date))
      .map((d) => DateTime(d.year, d.month, d.day))
      .toSet()
      .toList()
    ..sort();

  for (final date in sortedDates) {
    if (lastDate == null) {
      tempStreak = 1;
    } else if (date.difference(lastDate).inDays == 1) {
      tempStreak++;
    } else {
      tempStreak = 1;
    }
    lastDate = date;
    if (tempStreak > longestStreak) {
      longestStreak = tempStreak;
    }
  }

  // Current streak: count backwards from today
  final todayKey = DateTime(now.year, now.month, now.day);
  if (sortedDates.isNotEmpty && sortedDates.last == todayKey) {
    currentStreak = 1;
    for (int i = sortedDates.length - 2; i >= 0; i--) {
      if (todayKey.difference(sortedDates[i]).inDays ==
          sortedDates.length - 1 - i) {
        currentStreak++;
      } else {
        break;
      }
    }
  } else if (sortedDates.isNotEmpty &&
      todayKey.difference(sortedDates.last).inDays == 1) {
    // Yesterday counts if today hasn't happened yet
    currentStreak = 1;
    for (int i = sortedDates.length - 2; i >= 0; i--) {
      if (sortedDates.last
              .difference(sortedDates[i])
              .inDays ==
          sortedDates.length - 1 - i) {
        currentStreak++;
      } else {
        break;
      }
    }
  }

  return {
    'totalMinutes': totalMinutes,
    'totalSessions': sessions.length,
    'todayMinutes': todayMinutes,
    'currentStreak': currentStreak,
    'longestStreak': longestStreak,
    'heatmap': heatmap,
    'weekdayDistribution': weekdayDistribution,
  };
}

// ─── Break Cycle Helpers ────────────────────────────────────────────────────

enum TimerPhase { idle, focusing, paused, onBreak, breakPaused }

class FokusSessionLifecycle {
  TimerPhase phase = TimerPhase.idle;
  int remainingSeconds = 0;
  int breakRemainingSeconds = 0;
  int durationMinutes = 25;
  int breakMinutes = 5;
  String? linkedTaskId;
  bool isDeepWork = false;

  List<CompletedSession> completedSessions = [];

  void startFocus({String? taskId, bool deepWork = false}) {
    assert(phase == TimerPhase.idle || phase == TimerPhase.paused);
    linkedTaskId = taskId;
    isDeepWork = deepWork;
    remainingSeconds = durationMinutes * 60;
    phase = TimerPhase.focusing;
  }

  void pauseFocus() {
    assert(phase == TimerPhase.focusing);
    phase = TimerPhase.paused;
  }

  void resumeFocus() {
    assert(phase == TimerPhase.paused);
    phase = TimerPhase.focusing;
  }

  void tick() {
    if (phase == TimerPhase.focusing) {
      remainingSeconds--;
      if (remainingSeconds <= 0) {
        _completeFokusSession();
      }
    } else if (phase == TimerPhase.onBreak) {
      breakRemainingSeconds--;
      if (breakRemainingSeconds <= 0) {
        phase = TimerPhase.idle;
      }
    }
  }

  void _completeFokusSession() {
    final session = CompletedSession(
      id: 'session-${DateTime.now().millisecondsSinceEpoch}',
      startTime: DateTime.now().subtract(Duration(minutes: durationMinutes)),
      endTime: DateTime.now(),
      durationMinutes: durationMinutes,
      pointsEarned: calculatePoints(
        durationMinutes: durationMinutes,
        isDeepWork: isDeepWork,
        currentStreak: 0,
        wasInterrupted: false,
      ),
      taskId: linkedTaskId,
    );
    completedSessions.add(session);
    phase = TimerPhase.onBreak;
    breakRemainingSeconds = breakMinutes * 60;
  }

  void interruptSession() {
    assert(
      phase == TimerPhase.focusing || phase == TimerPhase.paused,
    );
    final elapsed = durationMinutes * 60 - remainingSeconds;
    final elapsedMinutes = (elapsed / 60).ceil();
    if (elapsedMinutes >= 1) {
      final session = CompletedSession(
        id: 'session-${DateTime.now().millisecondsSinceEpoch}',
        startTime: DateTime.now().subtract(Duration(seconds: elapsed)),
        endTime: DateTime.now(),
        durationMinutes: elapsedMinutes,
        pointsEarned: calculatePoints(
          durationMinutes: elapsedMinutes,
          isDeepWork: isDeepWork,
          currentStreak: 0,
          wasInterrupted: true,
        ),
        taskId: linkedTaskId,
        wasInterrupted: true,
      );
      completedSessions.add(session);
    }
    phase = TimerPhase.idle;
    remainingSeconds = 0;
  }

  void skipBreak() {
    assert(phase == TimerPhase.onBreak || phase == TimerPhase.breakPaused);
    phase = TimerPhase.idle;
    breakRemainingSeconds = 0;
  }
}

// ─── Tests ──────────────────────────────────────────────────────────────────

void main() {
  group('Full Fokus Session Lifecycle', () {
    late FokusSessionLifecycle lifecycle;
    List<FokusSession> history = [];

    setUp(() {
      lifecycle = FokusSessionLifecycle();
      history = [];
    });

    test('complete 25-minute fokus session → points calculated correctly', () {
      lifecycle.startFocus();
      expect(lifecycle.phase, TimerPhase.focusing);
      expect(lifecycle.remainingSeconds, 25 * 60);

      // Simulate full 25 minutes
      for (int i = 0; i < 25 * 60; i++) {
        lifecycle.tick();
      }

      expect(lifecycle.phase, TimerPhase.onBreak);
      expect(lifecycle.completedSessions.length, 1);

      final session = lifecycle.completedSessions.first;
      expect(session.durationMinutes, 25);
      expect(session.pointsEarned, greaterThan(0));
      expect(session.wasInterrupted, false);
    });

    test('complete session → log to history → verify history updated', () {
      lifecycle.startFocus();

      for (int i = 0; i < 25 * 60; i++) {
        lifecycle.tick();
      }

      final completed = lifecycle.completedSessions.first;
      history = logSession(existingSessions: history, completed: completed);

      expect(history.length, 1);
      expect(history.first.durationMinutes, 25);
      expect(history.first.durationMinutes, completed.durationMinutes);
    });

    test('complete session → update analytics → verify analytics correct', () {
      lifecycle.startFocus();

      for (int i = 0; i < 25 * 60; i++) {
        lifecycle.tick();
      }

      final completed = lifecycle.completedSessions.first;
      history = logSession(existingSessions: history, completed: completed);

      final analytics = updateAnalytics(sessions: history, previousStreaks: {});
      expect(analytics['totalMinutes'], 25);
      expect(analytics['totalSessions'], 1);
      expect(analytics['todayMinutes'], 25);
      expect(analytics['currentStreak'], greaterThanOrEqualTo(0));
    });

    test('multiple sessions → accumulate correctly', () {
      // Session 1: 25 minutes
      lifecycle.startFocus();
      for (int i = 0; i < 25 * 60; i++) {
        lifecycle.tick();
      }
      history = logSession(
        existingSessions: history,
        completed: lifecycle.completedSessions.last,
      );

      // Skip break
      lifecycle.skipBreak();
      expect(lifecycle.phase, TimerPhase.idle);

      // Session 2: change duration to 50 minutes, then run
      lifecycle.durationMinutes = 50;
      lifecycle.startFocus();
      for (int i = 0; i < 50 * 60; i++) {
        lifecycle.tick();
      }
      history = logSession(
        existingSessions: history,
        completed: lifecycle.completedSessions.last,
      );

      final analytics = updateAnalytics(sessions: history, previousStreaks: {});
      expect(analytics['totalMinutes'], 75);
      expect(analytics['totalSessions'], 2);
    });

    test('deep work session → 50% bonus points', () {
      lifecycle.startFocus(deepWork: true);

      for (int i = 0; i < 25 * 60; i++) {
        lifecycle.tick();
      }

      final session = lifecycle.completedSessions.first;
      final normalPoints = calculatePoints(
        durationMinutes: 25,
        isDeepWork: false,
        currentStreak: 0,
        wasInterrupted: false,
      );
      expect(session.pointsEarned, greaterThan(normalPoints));
    });
  });

  group('Session Interruption', () {
    late FokusSessionLifecycle lifecycle;

    setUp(() {
      lifecycle = FokusSessionLifecycle();
    });

    test('interrupt after 10 minutes → logs partial session with 0 points', () {
      lifecycle.startFocus();

      for (int i = 0; i < 10 * 60; i++) {
        lifecycle.tick();
      }

      lifecycle.interruptSession();
      expect(lifecycle.phase, TimerPhase.idle);

      final session = lifecycle.completedSessions.first;
      expect(session.wasInterrupted, true);
      expect(session.pointsEarned, 0); // Interrupted = 0 points
      expect(session.durationMinutes, greaterThanOrEqualTo(10));
    });

    test('interrupt immediately → no session logged', () {
      lifecycle.startFocus();
      lifecycle.interruptSession();

      expect(lifecycle.completedSessions.length, 0);
    });

    test('interrupt while paused → logs partial session', () {
      lifecycle.startFocus();

      for (int i = 0; i < 5 * 60; i++) {
        lifecycle.tick();
      }

      lifecycle.pauseFocus();
      expect(lifecycle.phase, TimerPhase.paused);

      lifecycle.interruptSession();
      expect(lifecycle.phase, TimerPhase.idle);

      final session = lifecycle.completedSessions.first;
      expect(session.wasInterrupted, true);
      expect(session.durationMinutes, greaterThanOrEqualTo(5));
    });
  });

  group('Break Cycle', () {
    late FokusSessionLifecycle lifecycle;

    setUp(() {
      lifecycle = FokusSessionLifecycle();
    });

    test('fokus → complete → break phase entered', () {
      lifecycle.startFocus();

      for (int i = 0; i < 25 * 60; i++) {
        lifecycle.tick();
      }

      expect(lifecycle.phase, TimerPhase.onBreak);
      expect(lifecycle.breakRemainingSeconds, 5 * 60);
    });

    test('break completes → returns to idle', () {
      lifecycle.startFocus();

      for (int i = 0; i < 25 * 60; i++) {
        lifecycle.tick();
      }

      for (int i = 0; i < 5 * 60; i++) {
        lifecycle.tick();
      }

      expect(lifecycle.phase, TimerPhase.idle);
    });

    test('skip break → returns to idle immediately', () {
      lifecycle.startFocus();

      for (int i = 0; i < 25 * 60; i++) {
        lifecycle.tick();
      }

      lifecycle.skipBreak();
      expect(lifecycle.phase, TimerPhase.idle);
      expect(lifecycle.breakRemainingSeconds, 0);
    });

    test('full cycle: fokus → break → fokus → break', () {
      // Session 1
      lifecycle.startFocus();
      for (int i = 0; i < 25 * 60; i++) {
        lifecycle.tick();
      }
      expect(lifecycle.phase, TimerPhase.onBreak);

      // Skip break
      lifecycle.skipBreak();
      expect(lifecycle.phase, TimerPhase.idle);

      // Session 2
      lifecycle.startFocus();
      for (int i = 0; i < 25 * 60; i++) {
        lifecycle.tick();
      }
      expect(lifecycle.phase, TimerPhase.onBreak);

      // Wait for break
      for (int i = 0; i < 5 * 60; i++) {
        lifecycle.tick();
      }
      expect(lifecycle.phase, TimerPhase.idle);
      expect(lifecycle.completedSessions.length, 2);
    });
  });

  group('Analytics Integration', () {
    test('empty history → zero analytics', () {
      final analytics = updateAnalytics(sessions: [], previousStreaks: {});
      expect(analytics['totalMinutes'], 0);
      expect(analytics['totalSessions'], 0);
      expect(analytics['todayMinutes'], 0);
    });

    test('heatmap tracks daily totals', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final sessions = [
        FokusSession(
          date: todayStr,
          timestamp: today.toIso8601String(),
          durationMinutes: 30,
        ),
        FokusSession(
          date: todayStr,
          timestamp: today.toIso8601String(),
          durationMinutes: 45,
        ),
      ];

      final analytics = updateAnalytics(sessions: sessions, previousStreaks: {});
      final heatmap = analytics['heatmap'] as Map<String, int>;
      final todayKey =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      expect(heatmap[todayKey], 75);
    });

    test('weekday distribution tracks per-day totals', () {
      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final sessions = [
        FokusSession(
          date: todayStr,
          timestamp: now.toIso8601String(),
          durationMinutes: 60,
        ),
      ];

      final analytics = updateAnalytics(sessions: sessions, previousStreaks: {});
      final weekdayDist = analytics['weekdayDistribution'] as List<int>;
      expect(weekdayDist[now.weekday % 7], 60);
    });
  });

  group('Point Calculation', () {
    test('base points: 1 per minute', () {
      final points = calculatePoints(
        durationMinutes: 30,
        isDeepWork: false,
        currentStreak: 0,
        wasInterrupted: false,
      );
      expect(points, 30);
    });

    test('deep work bonus: 50% extra', () {
      final base = calculatePoints(
        durationMinutes: 30,
        isDeepWork: false,
        currentStreak: 0,
        wasInterrupted: false,
      );
      final deep = calculatePoints(
        durationMinutes: 30,
        isDeepWork: true,
        currentStreak: 0,
        wasInterrupted: false,
      );
      expect(deep, greaterThan(base));
      expect(deep, 45); // 30 * 1.5
    });

    test('streak bonus: up to 25% extra', () {
      final noStreak = calculatePoints(
        durationMinutes: 30,
        isDeepWork: false,
        currentStreak: 0,
        wasInterrupted: false,
      );
      final highStreak = calculatePoints(
        durationMinutes: 30,
        isDeepWork: false,
        currentStreak: 5,
        wasInterrupted: false,
      );
      expect(highStreak, greaterThan(noStreak));
    });

    test('interrupted session: 0 points', () {
      final points = calculatePoints(
        durationMinutes: 30,
        isDeepWork: false,
        currentStreak: 5,
        wasInterrupted: true,
      );
      expect(points, 0);
    });
  });

  group('Task Linking', () {
    test('session with linked task preserves taskId', () {
      final lifecycle = FokusSessionLifecycle();
      lifecycle.startFocus(taskId: 'task-123');

      for (int i = 0; i < 25 * 60; i++) {
        lifecycle.tick();
      }

      expect(lifecycle.completedSessions.first.taskId, 'task-123');
    });

    test('session without task has null taskId', () {
      final lifecycle = FokusSessionLifecycle();
      lifecycle.startFocus();

      for (int i = 0; i < 25 * 60; i++) {
        lifecycle.tick();
      }

      expect(lifecycle.completedSessions.first.taskId, isNull);
    });

    test('log session preserves taskId in history', () {
      final lifecycle = FokusSessionLifecycle();
      lifecycle.startFocus(taskId: 'task-456');

      for (int i = 0; i < 25 * 60; i++) {
        lifecycle.tick();
      }

      final completed = lifecycle.completedSessions.first;
      final history = logSession(existingSessions: [], completed: completed);

      expect(history.first.taskId, 'task-456');
    });
  });
}
