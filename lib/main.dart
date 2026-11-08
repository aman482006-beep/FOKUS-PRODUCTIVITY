import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'core/di.dart';
import 'core/app.dart';
import 'services/deep_link_service.dart';
import 'services/storage_service.dart';

Future<void> main() async {
  // Catch uncaught async errors and ensure bindings are initialized
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Log uncaught Flutter errors
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      // ignore: avoid_print
      debugPrint('FLUTTER ERROR: ${details.exceptionAsString()}\n${details.stack}');
    };

    // ── Initialize all services via DI container ──
    // configureDependencies individually catches each service init
    // so a single failure (e.g. flutter_local_notifications on web)
    // does not prevent the app from loading.
    final diResult = await configureDependencies();

    if (diResult.hasErrors) {
      for (final err in diResult.errors) {
        debugPrint('DI INIT ERROR [${err.serviceName}]: ${err.message}');
      }
    }
    debugPrint('DI initialized ${diResult.initialized.length} services.');

    // ── Also initialize legacy static services for backward compatibility ──
    // These delegate to the same internal implementations used by DI.
    try {
      await StorageService.init();
    } catch (e, stack) {
      debugPrint('StorageService.init (legacy) error: $e\n$stack');
    }


    // Initialize window_manager for fullscreen support (desktop only)
    if (!kIsWeb) {
      try {
        await windowManager.ensureInitialized();
        // Read saved fullscreen preference from StorageService (already initialized)
        final startFullscreen = StorageService.prefs.getBool('fullscreen_enabled') ?? false;
        if (startFullscreen) {
          await windowManager.setFullScreen(true);
        }
        await windowManager.setTitle('Fokus');
        await windowManager.setPreventClose(true);
      } catch (e) {
        debugPrint('window_manager init error (non-fatal): $e');
      }
    }

    // ── Initialize deep link service for OAuth callback handling ──
    try {
      await DeepLinkService().initialize();
      debugPrint('DeepLinkService initialized.');
    } catch (e, stack) {
      debugPrint('DeepLinkService init error (non-fatal): $e\n$stack');
    }

    runApp(const ProviderScope(child: FocusApp()));
  }, (error, stack) {
    // ignore: avoid_print
    debugPrint('UNCAUGHT ERROR: $error\n$stack');
  });
}

