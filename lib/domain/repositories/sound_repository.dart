/// Abstract contract for sound playback.
///
/// Implementations live in `data/repositories/`. ViewModels and Use Cases
/// depend only on this interface, never on concrete services.
abstract class SoundRepository {
  Future<void> playNotification();
  Future<void> playTick();
  Future<void> playFlip();
  Future<void> playComplete();
  void dispose();
}
