import 'package:shared_preferences/shared_preferences.dart';
import '../models/fokus_session.dart';
import '../models/habit.dart';
import '../services/blue_light_service.dart';
import '../services/eye_break_service.dart';
import '../services/fokus_history_service.dart';
import '../services/habit_service.dart';
import '../services/notification_service.dart';
import '../services/profile_engine_service.dart';
import '../services/screen_time_service.dart';
import '../services/share_service.dart';
import '../services/sound_service.dart';
import '../services/storage_service.dart';
import '../services/interfaces/interfaces.dart';

// ──────────────────────────────────────────────
// Adapter classes — delegate from interface to static API
// ──────────────────────────────────────────────
// These adapters exist because the existing codebase calls services
// via static methods (e.g. FokusHistoryService.getDailyStreak()).
// The adapters implement the interfaces and forward to the static API,
// enabling DI without refactoring all existing call sites.

class StorageServiceAdapter implements IStorageService {
  @override
  Future<void> init() => StorageService.init();

  @override
  SharedPreferences get prefs => StorageService.prefsStatic;

  @override
  String? getString(String key) => StorageService.getString(key);

  @override
  Future<bool> setString(String key, String value) =>
      StorageService.setString(key, value);

  @override
  bool? getBool(String key) => StorageService.getBool(key);

  @override
  Future<bool> setBool(String key, bool value) =>
      StorageService.setBool(key, value);

  @override
  int? getInt(String key) => StorageService.getInt(key);

  @override
  Future<bool> setInt(String key, int value) =>
      StorageService.setInt(key, value);

  @override
  double? getDouble(String key) => StorageService.getDouble(key);

  @override
  Future<bool> setDouble(String key, double value) =>
      StorageService.setDouble(key, value);

  @override
  Future<bool> remove(String key) => StorageService.remove(key);

  @override
  bool containsKey(String key) => StorageService.containsKey(key);

  @override
  Future<bool> clear() => StorageService.clear();
}

class NotificationServiceAdapter implements INotificationService {
  @override
  Future<void> init() => NotificationService.init();

  @override
  Future<void> show({int id = 0, String title = 'Fokus', required String body}) =>
      NotificationService.show(id: id, title: title, body: body);

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) => NotificationService.schedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
      );

  @override
  Future<void> cancel(int id) => NotificationService.cancel(id);

  @override
  Future<void> capturePreviousSuppressionState() =>
      NotificationService.capturePreviousSuppressionState();

  @override
  Future<bool> enableOSNotificationSuppression() =>
      NotificationService.enableOSNotificationSuppression();

  @override
  Future<bool> disableOSNotificationSuppression() =>
      NotificationService.disableOSNotificationSuppression();
}

class SoundServiceAdapter implements ISoundService {
  @override
  Future<void> playNotification() => SoundService.playNotification();

  @override
  Future<void> playTick() => SoundService.playTick();

  @override
  Future<void> playFlip() => SoundService.playFlip();

  @override
  Future<void> playComplete() => SoundService.playComplete();

  @override
  void dispose() => SoundService.disposeStatic();
}

class EyeBreakServiceAdapter implements IEyeBreakService {
  @override
  Future<void> init() => EyeBreakService.init();

  @override
  bool get enabled => EyeBreakService.enabled;

  @override
  int get intervalMinutes => EyeBreakService.intervalMinutes;

  @override
  void start() => EyeBreakService.start();

  @override
  void stop() => EyeBreakService.stop();

  @override
  Future<void> setEnabled(bool value) => EyeBreakService.setEnabled(value);

  @override
  Future<void> setInterval(int minutes) => EyeBreakService.setInterval(minutes);

  @override
  void dispose() => EyeBreakService.dispose();
}

class FokusHistoryServiceAdapter implements IFokusHistoryService {
  @override
  List<FokusSession> loadSessions() => FokusHistoryService.loadSessions();

  @override
  Future<void> logFokusSession() => FokusHistoryService.logFokusSession();

  @override
  Future<void> logDetailedSession(int durationMinutes, {String? taskId, bool isInterrupted = false, String? sessionType}) =>
      FokusHistoryService.logDetailedSession(durationMinutes, taskId: taskId, isInterrupted: isInterrupted, sessionType: sessionType);

  @override
  int todayMinutes() => FokusHistoryService.todayMinutes();

  @override
  int todaySessions() => FokusHistoryService.todaySessions();

  @override
  List<int> dailyMinutes({int days = 7}) => FokusHistoryService.dailyMinutes(days: days);

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
  Map<String, dynamic>? get lastSessionInfo => FokusHistoryService.lastSessionInfo;
}

class HabitServiceAdapter implements IHabitService {
  @override
  List<Habit> loadHabits() => HabitService.loadHabits();

  @override
  Future<void> saveHabits(List<Habit> habits) =>
      HabitService.saveHabits(habits);

  @override
  List<HabitCompletion> loadCompletions() =>
      HabitService.loadCompletions();

  @override
  Future<void> saveCompletions(List<HabitCompletion> completions) =>
      HabitService.saveCompletions(completions);

  @override
  Habit recalculateStreaksForHabit(Habit habit, List<HabitCompletion> completions) =>
      HabitService.recalculateStreaksForHabit(habit, completions);
}

class BlueLightServiceAdapter implements IBlueLightService {
  @override
  BlueLightSettings load() => BlueLightService.load();

  @override
  Future<void> save(BlueLightSettings settings) =>
      BlueLightService.save(settings);

  @override
  bool isWithinSchedule(BlueLightSettings s) =>
      BlueLightService.isWithinSchedule(s);

  @override
  int adaptiveTemperature(BlueLightSettings s) =>
      BlueLightService.adaptiveTemperature(s);

  @override
  List<double> warmMatrix(BlueLightSettings s) =>
      BlueLightService.warmMatrix(s);

  @override
  List<double> matrixForSettings(BlueLightSettings s) =>
      BlueLightService.matrixForSettings(s);
}

class ShareServiceAdapter implements IShareService {
  @override
  Future<void> shareSession({
    required String durationLabel,
    required int sessionNumber,
    int? streak,
  }) => ShareService.shareSession(
    durationLabel: durationLabel,
    sessionNumber: sessionNumber,
    streak: streak,
  );

  @override
  Future<void> shareStats() => ShareService.shareStats();
}

class ScreenTimeServiceAdapter implements IScreenTimeService {
  @override
  Future<String> getActiveWindowTitle() =>
      ScreenTimeService.getActiveWindowTitle();

  @override
  Future<String> getActiveProcessName() =>
      ScreenTimeService.getActiveProcessName();

  @override
  void startTracking() => ScreenTimeService.startTracking();

  @override
  void stopTracking() => ScreenTimeService.stopTracking();

  @override
  Future<List<AppUsageEntry>> getTodayUsage() =>
      ScreenTimeService.getTodayUsage();

  @override
  Future<List<AppUsageEntry>> getUsageLastDays(int days) =>
      ScreenTimeService.getUsageLastDays(days);

  @override
  Future<int> getTodayTotalSeconds() =>
      ScreenTimeService.getTodayTotalSeconds();

  @override
  Future<void> clearAll() => ScreenTimeService.clearAll();
}

class ProfileEngineServiceAdapter implements IProfileEngineService {
  @override
  Future<List<FocusProfile>> loadProfiles() =>
      ProfileEngineService.loadProfiles();

  @override
  Future<void> saveProfile(FocusProfile profile) =>
      ProfileEngineService.saveProfile(profile);

  @override
  Future<void> deleteProfile(String id) =>
      ProfileEngineService.deleteProfile(id);

  @override
  Future<String?> getActiveProfileId() =>
      ProfileEngineService.getActiveProfileId();

  @override
  Future<void> setActiveProfileId(String? id) =>
      ProfileEngineService.setActiveProfileId(id);
}
