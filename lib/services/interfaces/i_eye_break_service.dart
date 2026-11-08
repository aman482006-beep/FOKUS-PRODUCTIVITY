/// Abstraction over the 20-20-20 eye break reminder system.
///
/// Implementations manage a periodic timer that reminds the user
/// to look away from the screen to reduce digital eye strain.
abstract class IEyeBreakService {
  /// Load saved settings and start the timer if previously enabled.
  Future<void> init();

  /// Start the eye break timer.
  void start();

  /// Stop the eye break timer.
  void stop();

  /// Toggle on/off, persisting the new state.
  Future<void> setEnabled(bool value);

  /// Update the interval in minutes, persisting and restarting.
  Future<void> setInterval(int minutes);

  /// Whether reminders are currently enabled.
  bool get enabled;

  /// Interval in minutes between reminders.
  int get intervalMinutes;

  /// Release all resources (timer). Call from app dispose.
  void dispose();
}
