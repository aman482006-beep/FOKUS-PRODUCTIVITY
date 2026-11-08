import '../../domain/repositories/sound_repository.dart';
import '../../services/sound_service.dart';

/// Concrete implementation of [SoundRepository] that delegates to
/// the existing [SoundService] static API.
class SoundRepositoryImpl implements SoundRepository {
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
