import '../screen_time_service.dart' show AppUsageEntry;

/// Abstraction over screen-time tracking and active window monitoring.
///
/// Implementations handle polling the active window on desktop,
/// recording per-app usage, and providing aggregated reports.
abstract class IScreenTimeService {
  /// Get the currently active/focused window title (Windows).
  Future<String> getActiveWindowTitle();

  /// Get the active process name (e.g. 'chrome.exe').
  Future<String> getActiveProcessName();

  /// Start tracking active window usage.
  void startTracking();

  /// Stop tracking active window usage.
  void stopTracking();

  /// Get today's usage entries, sorted by most used first.
  Future<List<AppUsageEntry>> getTodayUsage();

  /// Get usage for the past [days] days, aggregated and sorted.
  Future<List<AppUsageEntry>> getUsageLastDays(int days);

  /// Get total tracked time today in seconds.
  Future<int> getTodayTotalSeconds();

  /// Clear all screen time data.
  Future<void> clearAll();
}
