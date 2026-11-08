import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fokus/features/fokus_timer/fokus_timer_page.dart';
import 'package:fokus/services/storage_service.dart';
import 'package:fokus/shared/motion.dart';
import 'package:fokus/shared/theme.dart';
import 'package:fokus/core/providers.dart';

void main() {
  setUp(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    StorageService.prefs = await SharedPreferences.getInstance();
  });

  group('FokusTimerPage — timer text reflects active theme', () {
    testWidgets('dark theme: timer digits use textPrimary (near-white)',
        (tester) async {
      final tokens = AppThemes.cosmicBlack.tokens;

      // Use a larger surface to avoid layout overflow
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          theme: FocusOsTheme.fromDefinition(AppThemes.cosmicBlack),
          darkTheme: FocusOsTheme.fromDefinition(AppThemes.cosmicBlack),
          themeMode: ThemeMode.dark,
          home: const Scaffold(body: FokusTimerPage()),
        ),
      ));
      // Use pump (not pumpAndSettle) since animations never settle
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final digitFinder = find.byType(AnimatedDigit);
      expect(digitFinder, findsAtLeast(1));
      final timerDigit = tester.widget<AnimatedDigit>(digitFinder.first);
      expect(timerDigit.style?.color, tokens.textPrimary,
          reason: 'Timer digits should use textPrimary from dark theme');
      expect(timerDigit.style?.color!.computeLuminance(), greaterThan(0.9),
          reason: 'Dark theme timer text should be near-white');
    });

    testWidgets('light theme: timer digits use textPrimary (near-black)',
        (tester) async {
      final tokens = AppThemes.studioLight.tokens;

      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          theme: FocusOsTheme.fromDefinition(AppThemes.studioLight),
          darkTheme: FocusOsTheme.fromDefinition(AppThemes.studioLight),
          themeMode: ThemeMode.dark,
          home: const Scaffold(body: FokusTimerPage()),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final digitFinder = find.byType(AnimatedDigit);
      expect(digitFinder, findsAtLeast(1));
      final timerDigit = tester.widget<AnimatedDigit>(digitFinder.first);
      expect(timerDigit.style?.color, tokens.textPrimary,
          reason: 'Timer digits should use textPrimary from light theme');
      expect(timerDigit.style?.color!.computeLuminance(), lessThan(0.1),
          reason: 'Light theme timer text should be near-black');
    });

    testWidgets('text colour switches when theme changes from dark to light',
        (tester) async {
      final darkTokens = AppThemes.cosmicBlack.tokens;

      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Pump with dark theme
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          theme: FocusOsTheme.fromDefinition(AppThemes.cosmicBlack),
          darkTheme: FocusOsTheme.fromDefinition(AppThemes.cosmicBlack),
          themeMode: ThemeMode.dark,
          home: const Scaffold(body: FokusTimerPage()),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify dark theme
      final darkDigitFinder = find.byType(AnimatedDigit);
      expect(darkDigitFinder, findsAtLeast(1));
      expect(
        tester.widget<AnimatedDigit>(darkDigitFinder.first).style?.color,
        darkTokens.textPrimary,
      );

      // Rebuild with light theme
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          theme: FocusOsTheme.fromDefinition(AppThemes.studioLight),
          darkTheme: FocusOsTheme.fromDefinition(AppThemes.studioLight),
          themeMode: ThemeMode.dark,
          home: const Scaffold(body: FokusTimerPage()),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify light theme — color changed from dark theme textPrimary
      final lightDigitFinder = find.byType(AnimatedDigit);
      expect(lightDigitFinder, findsAtLeast(1));
      final lightColor =
          tester.widget<AnimatedDigit>(lightDigitFinder.first).style?.color;
      expect(lightColor, isNot(darkTokens.textPrimary),
          reason: 'Timer digits should change when theme switches');
    });
  });

  group('fokusSceneProvider tests', () {
    test('default fokus scene is none', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final activeScene = container.read(fokusSceneProvider);
      expect(activeScene.id, 'none');
    });

    test('setScene changes the active fokus scene and persists it', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(fokusSceneProvider.notifier).setScene('rain');
      expect(container.read(fokusSceneProvider).id, 'rain');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('active_scene_id'), 'rain');
    });
  });
}
