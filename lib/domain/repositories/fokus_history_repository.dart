import '../../models/fokus_session.dart';

/// Abstract contract for focus history data access.
///
/// Implementations live in `data/repositories/`. ViewModels and Use Cases
/// depend only on this interface, never on concrete services.
abstract class FokusHistoryRepository {
  List<FokusSession> loadSessions();
  Future<void> logFokusSession();
  Future<void> logDetailedSession(
    int durationMinutes, {
    String? taskId,
    bool isInterrupted = false,
    String? sessionType,
    int? plannedDurationMinutes,
    int? actualDurationSeconds,
    String? startTime,
    String? endTime,
    bool isBreak = false,
  });
  int todayMinutes();
  int todaySessions();
  List<int> dailyMinutes({int days = 7});
  int totalMinutes();
  int totalSessionsCount();
  double averageMinutes();
  List<FokusSession> recentSessions({int limit = 20});
  int taskMinutes(String taskId);
  int bestStreak();
  int getDailyStreak();
  List<int> getDailyCounts({int days = 28});
  void recordLastSession(String durationLabel, int sessionNumber);
  Map<String, dynamic>? get lastSessionInfo;
}
