import '../../models/fokus_session.dart';

/// Abstraction over focus session history storage and queries.
///
/// Implementations handle persisting completed focus sessions,
/// computing streaks, daily counts, and per-task statistics.
abstract class IFokusHistoryService {
  /// Load all stored sessions.
  List<FokusSession> loadSessions();

  /// Record a focus session for today (deduplicates by date).
  Future<void> logFokusSession();

  /// Record a session with full details (duration, task, interruption, type).
  Future<void> logDetailedSession(
    int durationMinutes, {
    String? taskId,
    bool isInterrupted,
    String? sessionType,
  });

  /// Total focus minutes for today.
  int todayMinutes();

  /// Total sessions today.
  int todaySessions();

  /// Daily focus minutes for the last [days] days.
  List<int> dailyMinutes({int days});

  /// Total focus minutes all-time.
  int totalMinutes();

  /// Total number of completed sessions all-time.
  int totalSessionsCount();

  /// Average session duration in minutes.
  double averageMinutes();

  /// Most recent [limit] sessions, newest first.
  List<FokusSession> recentSessions({int limit});

  /// Total focus minutes for a specific task.
  int taskMinutes(String taskId);

  /// Best streak on record (days with at least one session).
  int bestStreak();

  /// Number of consecutive days ending today with at least one focus session.
  int getDailyStreak();

  /// Daily counts for the last [days] days.
  List<int> getDailyCounts({int days});

  /// Call when a focus session finishes to record it for sharing.
  void recordLastSession(String durationLabel, int sessionNumber);

  /// Info about the most recently completed focus session, or null.
  Map<String, dynamic>? get lastSessionInfo;
}
