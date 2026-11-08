import 'package:just_audio/just_audio.dart';

/// Plays notification sounds when timer phases complete.
///
/// This is a purely static service. For DI-aware access, use [SoundServiceAdapter].
class SoundService {
  SoundService._();

  static final AudioPlayer _player = AudioPlayer();
  static final AudioPlayer _tickPlayer = AudioPlayer();
  static final AudioPlayer _flipPlayer = AudioPlayer();

  static bool _initialized = false;

  static Future<void> _ensureInitialized() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await _player.setAudioSource(
        AudioSource.asset('sounds/notification.wav'),
        preload: true,
      );
      await _tickPlayer.setAudioSource(
        AudioSource.asset('sounds/tick.wav'),
        preload: true,
      );
      await _flipPlayer.setAudioSource(
        AudioSource.asset('sounds/flip.wav'),
        preload: true,
      );
    } catch (_) {}
  }

  // ── Static API ──

  static Future<void> playNotification() async {
    try {
      await _ensureInitialized();
      await _player.stop();
      await _player.seek(Duration.zero);
      await _player.play();
    } catch (_) {}
  }

  static Future<void> playTick() async {
    try {
      await _ensureInitialized();
      await _tickPlayer.stop();
      await _tickPlayer.seek(Duration.zero);
      await _tickPlayer.play();
    } catch (_) {}
  }

  static void stopTick() {
    try {
      _tickPlayer.stop();
    } catch (_) {}
  }

  static Future<void> playFlip() async {
    try {
      await _ensureInitialized();
      await _flipPlayer.stop();
      await _flipPlayer.seek(Duration.zero);
      await _flipPlayer.play();
    } catch (_) {}
  }

  static Future<void> playComplete() async {
    await playNotification();
  }

  static void disposeStatic() {
    _player.dispose();
    _tickPlayer.dispose();
    _flipPlayer.dispose();
    _initialized = false;
  }
}
