import '../../domain/repositories/fokus_history_repository.dart';
import '../../models/fokus_session.dart';
import '../../services/fokus_history_service.dart';

/// Concrete implementation of [FokusHistoryRepository] that delegates to
/// the existing [FokusHistoryService] static API.
///
/// This adapter bridges the clean architecture domain layer with the
/// existing service layer. Over time, the static services can be
/// replaced with instance-based implementations.
class FokusHistoryRepositoryImpl implements FokusHistoryRepository {
  @override
  List<FokusSession> loadSessions() => FokusHistoryService.loadSessions();

  @override
  Future<void> logFokusSession() => FokusHistoryService.logFokusSession();

  @override
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
  }) =>
      FokusHistoryService.logDetailedSession(
        durationMinutes,
        taskId: taskId,
        isInterrupted: isInterrupted,
        sessionType: sessionType,
        plannedDurationMinutes: plannedDurationMinutes,
        actualDurationSeconds: actualDurationSeconds,
        startTime: startTime,
        endTime: endTime,
        isBreak: isBreak,
      );

  @override
  int todayMinutes() => FokusHistoryService.todayMinutes();

  @override
  int todaySessions() => FokusHistoryService.todaySessions();

  @override
  List<int> dailyMinutes({int days = 7}) =>
      FokusHistoryService.dailyMinutes(days: days);

  @override
  int totalMinutes() => FokusHistoryService.totalMinutes();

  @override
  int totalSessionsCount() => FokusHistoryService.totalSessionsCount();

  @override
  double averageMinutes() => FokusHistoryService.averageMinutes();

  @override
  List<FokusSession> recentSessions({int limit = 20}) =>
      FokusHistoryService.recentSessions(limit: limit);

  @override
  int taskMinutes(String taskId) => FokusHistoryService.taskMinutes(taskId);

  @override
  int bestStreak() => FokusHistoryService.bestStreak();

  @override
  int getDailyStreak() => FokusHistoryService.getDailyStreak();

  @override
  List<int> getDailyCounts({int days = 28}) =>
      FokusHistoryService.getDailyCounts(days: days);

  @override
  void recordLastSession(String durationLabel, int sessionNumber) =>
      FokusHistoryService.recordLastSession(durationLabel, sessionNumber);

  @override
  Map<String, dynamic>? get lastSessionInfo =>
      FokusHistoryService.lastSessionInfo;
}
