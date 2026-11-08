/// Abstraction over sound playback for timer events.
///
/// Implementations handle audio resource lifecycle (play, stop, dispose)
/// for notification sounds, tick sounds, flip sounds, and session complete sounds.
abstract class ISoundService {
  /// Plays a soft chime notification.
  Future<void> playNotification();

  /// Plays a tick sound (once per second during active timer).
  Future<void> playTick();

  /// Plays a mechanical flip sound.
  Future<void> playFlip();

  /// Plays the session complete sound.
  Future<void> playComplete();

  /// Releases all audio player resources. Call when the app disposes.
  void dispose();
}
