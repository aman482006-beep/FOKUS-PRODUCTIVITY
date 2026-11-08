/// Abstraction over system-level notifications and DND control.
///
/// Implementations handle platform-specific notification display
/// and OS-level Do-Not-Disturb / focus assist toggling.
abstract class INotificationService {
  /// Initialize the notification plugin. Must be called once before any other method.
  Future<void> init();

  /// Show a system notification with [title] and [body].
  Future<void> show({int id, String title, required String body});

  /// Schedule a notification to trigger in the future.
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  });

  /// Cancel a scheduled notification.
  Future<void> cancel(int id);

  /// Capture the current OS notification/DND state so it can be restored later.
  Future<void> capturePreviousSuppressionState();

  /// Enable OS-level notification suppression (DND / Focus Assist).
  Future<bool> enableOSNotificationSuppression();

  /// Disable OS-level notification suppression, restoring previous state.
  Future<bool> disableOSNotificationSuppression();
}
