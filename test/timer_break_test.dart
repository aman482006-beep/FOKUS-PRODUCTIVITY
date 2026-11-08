import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fokus/core/providers.dart';
import 'package:fokus/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    StorageService.prefs = await SharedPreferences.getInstance();

    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.allMessagesHandler = (String channel, Future<ByteData?>? Function(ByteData?)? handler, ByteData? message) async {
      if (channel.startsWith('com.ryanheise.just_audio.methods')) {
        try {
          final methodCall = const StandardMethodCodec().decodeMethodCall(message);
          if (methodCall.method == 'init') {
            return const StandardMethodCodec().encodeSuccessEnvelope({'handle': 'test_handle'});
          }
          return const StandardMethodCodec().encodeSuccessEnvelope({});
        } catch (_) {
          return const StandardMethodCodec().encodeSuccessEnvelope({});
        }
      }
      if (channel == 'com.ryanheise.audio_session') {
        return const StandardMethodCodec().encodeSuccessEnvelope({});
      }
      if (handler != null) {
        return handler(message);
      }
      return null;
    };
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.allMessagesHandler = null;
  });

  group('TimerNotifier Break Mode Tests', () {
    test('Initial break values are default/false', () {
      final container = ProviderContainer();
      try {
        final timerState = container.read(timerProvider);

        expect(timerState.isBreak, false);
        expect(timerState.breakDuration, 0);
        expect(timerState.breakElapsed, 0);
      } finally {
        container.dispose();
      }
    });

    test('startBreak sets duration, isBreak=true, and running=true', () {
      final container = ProviderContainer();
      try {
        final notifier = container.read(timerProvider.notifier);

        notifier.startBreak(300); // 5 minutes

        final timerState = container.read(timerProvider);
        expect(timerState.isBreak, true);
        expect(timerState.breakDuration, 300);
        expect(timerState.breakElapsed, 0);
        expect(timerState.running, true);

        // Clean up timer
        notifier.cancelBreak();
      } finally {
        container.dispose();
      }
    });

    test('resumeFokus cancels break and transitions back to fokus timer start', () {
      final container = ProviderContainer();
      try {
        final notifier = container.read(timerProvider.notifier);

        notifier.startBreak(300);
        notifier.resumeFocus();

        final timerState = container.read(timerProvider);
        expect(timerState.isBreak, false);
        expect(timerState.breakDuration, 0);
        expect(timerState.breakElapsed, 0);
        expect(timerState.running, true); // start() makes running=true

        // Clean up timer
        notifier.pause();
      } finally {
        container.dispose();
      }
    });

    test('cancelBreak stops break and leaves running=false', () {
      final container = ProviderContainer();
      try {
        final notifier = container.read(timerProvider.notifier);

        notifier.startBreak(300);
        notifier.cancelBreak();

        final timerState = container.read(timerProvider);
        expect(timerState.isBreak, false);
        expect(timerState.breakDuration, 0);
        expect(timerState.breakElapsed, 0);
        expect(timerState.running, false);
      } finally {
        container.dispose();
      }
    });
  });
}
