import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fokus/features/fokus_timer/fokus_timer_page.dart';
import 'package:fokus/features/fokus_timer/widgets/fokus_timer_display.dart';
import 'package:fokus/features/fokus_timer/widgets/fokus_timer_presets.dart';
import 'package:fokus/features/fokus_timer/widgets/ambient_sound_mini_player.dart';
import 'package:fokus/features/fokus_timer/widgets/task_selector_panel.dart';
import 'package:fokus/services/storage_service.dart';
import 'package:fokus/shared/theme.dart';
import 'package:fokus/core/providers.dart';
import 'package:fokus/core/navigation.dart';

/// Wraps a widget in [ProviderScope] + [MaterialApp] with a dark theme
/// so that `FocusOsTheme.of(context)` works and the app's visual structure
/// is present (Scaffold, etc.).
Widget _buildTestWidget(Widget child, {List<Override>? overrides}) {
  return ProviderScope(
    overrides: overrides ?? [],
    child: MaterialApp(
      theme: FocusOsTheme.fromDefinition(AppThemes.cosmicBlack),
      darkTheme: FocusOsTheme.fromDefinition(AppThemes.cosmicBlack),
      themeMode: ThemeMode.dark,
      home: Scaffold(body: child),
    ),
  );
}

/// Sets a desktop-like viewport size. Must be called from within testWidgets.
void _setViewport(WidgetTester tester, {double width = 1400, double height = 1000}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

/// Provider override that forces the timer into a specific [TimerState]
/// without starting any real timers.  This avoids the Timer.periodic /
/// DateTime.now() mismatch that prevents real timers from ticking in widget tests.
Override _timerState(TimerState s) {
  return timerProvider.overrideWith((ref) => _StaticTimerNotifier(ref)..state = s);
}

/// A [TimerNotifier] that holds whatever state you set — no real timers,
/// no audio calls.  Safe for widget tests.
class _StaticTimerNotifier extends TimerNotifier {
  _StaticTimerNotifier(super.ref);
}

void main() {
  setUp(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    StorageService.prefs = await SharedPreferences.getInstance();
  });

  // ──────────────────────────────────────────────
  // Widget tests — initial state
  // ──────────────────────────────────────────────

  group('FokusTimerPage — initial state', () {
    testWidgets('renders timer display and status label "READY"',
        (WidgetTester tester) async {
      _setViewport(tester);

      await tester.pumpWidget(_buildTestWidget(const FokusTimerPage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(FocusTimerDisplay), findsOneWidget);
      expect(find.text('READY'), findsOneWidget);
    });

    testWidgets('shows "Start Fokus" primary CTA when idle',
        (WidgetTester tester) async {
      _setViewport(tester);

      await tester.pumpWidget(_buildTestWidget(const FokusTimerPage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Start Fokus'), findsOneWidget);
    });

    testWidgets('shows "Today:" stats chip when idle and not running',
        (WidgetTester tester) async {
      _setViewport(tester);

      await tester.pumpWidget(_buildTestWidget(const FokusTimerPage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.textContaining('Today:'), findsOneWidget);
    });

    testWidgets('renders top bar buttons (wallpaper, fullscreen, theme)',
        (WidgetTester tester) async {
      _setViewport(tester);

      await tester.pumpWidget(_buildTestWidget(const FokusTimerPage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final tooltips = tester.widgetList<Tooltip>(
        find.descendant(
          of: find.byType(FokusTimerPage),
          matching: find.byType(Tooltip),
        ),
      );
      final tooltipMessages = tooltips.map((t) => t.message).toList();
      expect(
        tooltipMessages,
        containsAll([
          'Set background wallpaper',
          'Fullscreen',
          'Change theme',
        ]),
      );
    });

    testWidgets('renders ambient sound mini player',
        (WidgetTester tester) async {
      _setViewport(tester);

      await tester.pumpWidget(_buildTestWidget(const FokusTimerPage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(AmbientSoundMiniPlayer), findsOneWidget);
    });
  });

  // ──────────────────────────────────────────────
  // Widget tests — timer UI states via provider overrides
  // ──────────────────────────────────────────────

  group('FokusTimerPage — timer UI states', () {
    testWidgets('running timer shows FOKUSING status and Pause CTA',
        (WidgetTester tester) async {
      _setViewport(tester);

      await tester.pumpWidget(_buildTestWidget(
        const FokusTimerPage(),
        overrides: [
          _timerState(const TimerState(
            elapsed: 30,
            totalSeconds: 1500,
            running: true,
            isCountdown: true,
          )),
        ],
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('FOCUSING'), findsOneWidget);
      expect(find.text('Pause'), findsOneWidget);
    });

    testWidgets('paused timer with elapsed shows PAUSED and Resume',
        (WidgetTester tester) async {
      _setViewport(tester);

      await tester.pumpWidget(_buildTestWidget(
        const FokusTimerPage(),
        overrides: [
          _timerState(const TimerState(
            elapsed: 60,
            totalSeconds: 1500,
            running: false,
            isCountdown: true,
          )),
        ],
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('PAUSED'), findsOneWidget);
      expect(find.text('Resume'), findsOneWidget);
      expect(find.byTooltip('End session'), findsOneWidget);
      expect(find.byTooltip('Reset'), findsOneWidget);
    });

    testWidgets('paused timer shows break options card',
        (WidgetTester tester) async {
      _setViewport(tester);

      await tester.pumpWidget(_buildTestWidget(
        const FokusTimerPage(),
        overrides: [
          _timerState(const TimerState(
            elapsed: 120,
            totalSeconds: 1500,
            running: false,
            isCountdown: true,
          )),
        ],
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Take a Break?'), findsOneWidget);
      expect(find.text('5m'), findsOneWidget);
      expect(find.text('10m'), findsOneWidget);
      expect(find.text('15m'), findsWidgets);
    });

    testWidgets('break mode shows "Skip Break" CTA',
        (WidgetTester tester) async {
      _setViewport(tester);

      await tester.pumpWidget(_buildTestWidget(
        const FokusTimerPage(),
        overrides: [
          _timerState(const TimerState(
            elapsed: 120,
            totalSeconds: 1500,
            running: true,
            isCountdown: true,
            isBreak: true,
            breakDuration: 300,
            breakElapsed: 60,
          )),
        ],
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Skip Break'), findsOneWidget);
      expect(find.text('Take a Break?'), findsNothing);
    });

    testWidgets('custom break input field present when paused',
        (WidgetTester tester) async {
      _setViewport(tester);

      await tester.pumpWidget(_buildTestWidget(
        const FokusTimerPage(),
        overrides: [
          _timerState(const TimerState(
            elapsed: 60,
            totalSeconds: 1500,
            running: false,
            isCountdown: true,
          )),
        ],
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('stop and reset buttons hidden when timer is idle',
        (WidgetTester tester) async {
      _setViewport(tester);

      await tester.pumpWidget(_buildTestWidget(
        const FokusTimerPage(),
        overrides: [
          _timerState(const TimerState()),
        ],
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byTooltip('End session'), findsNothing);
      expect(find.byTooltip('Reset'), findsNothing);
    });

    testWidgets('running timer hides Today stats chip',
        (WidgetTester tester) async {
      _setViewport(tester);

      await tester.pumpWidget(_buildTestWidget(
        const FokusTimerPage(),
        overrides: [
          _timerState(const TimerState(
            elapsed: 30,
            totalSeconds: 1500,
            running: true,
            isCountdown: true,
          )),
        ],
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.textContaining('Today:'), findsNothing);
    });
  });

  // ──────────────────────────────────────────────
  // Widget tests — deep work mode
  // ──────────────────────────────────────────────

  group('FokusTimerPage — deep work mode', () {
    testWidgets('hides status label, CTA, and ambient player',
        (WidgetTester tester) async {
      _setViewport(tester);

      await tester.pumpWidget(
        _buildTestWidget(const FokusTimerPage(), overrides: [
          deepWorkModeProvider.overrideWith((ref) => true),
        ]),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('READY'), findsNothing);
      expect(find.text('Start Fokus'), findsNothing);
      expect(find.byType(AmbientSoundMiniPlayer), findsNothing);
    });
  });

  // ──────────────────────────────────────────────
  // Widget tests — task indicator
  // ──────────────────────────────────────────────

  group('FokusTimerPage — task indicator', () {
    testWidgets('shows fokused task indicator when a task is linked',
        (WidgetTester tester) async {
      _setViewport(tester);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('tasks_list', '''[
        {"id":"task-1","title":"Write Widget Tests","color":"#3B82F6","done":false,"totalFokusMinutes":30,"completedSessions":2,"interruptedSessions":0,"priority":"high","estimatedMinutes":90}
      ]''');

      await tester.pumpWidget(
        _buildTestWidget(const FokusTimerPage(), overrides: [
          focusedTaskProvider.overrideWith((ref) => 'task-1'),
        ]),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Task title may appear in the task indicator chip and/or timer display subtitle.
      expect(find.text('Write Widget Tests'), findsWidgets);
    });
  });

  // ──────────────────────────────────────────────
  // Widget tests — layout structure
  // ──────────────────────────────────────────────

  group('FokusTimerPage — layout structure', () {
    testWidgets('contains Stack layout layers',
        (WidgetTester tester) async {
      _setViewport(tester);

      await tester.pumpWidget(_buildTestWidget(const FokusTimerPage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(Stack), findsWidgets);
    });

    testWidgets('renders in a scroll-capable layout',
        (WidgetTester tester) async {
      _setViewport(tester);

      await tester.pumpWidget(_buildTestWidget(const FokusTimerPage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(SingleChildScrollView), findsWidgets);
    });

    testWidgets('task selector panel shown on wide screens (> 960px)',
        (WidgetTester tester) async {
      _setViewport(tester, width: 1400, height: 1000);

      await tester.pumpWidget(_buildTestWidget(const FokusTimerPage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(FocusTimerTaskSelectorPanel), findsWidgets);
    });

    testWidgets('presets button is always visible',
        (WidgetTester tester) async {
      _setViewport(tester);

      await tester.pumpWidget(_buildTestWidget(const FokusTimerPage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(FocusTimerPresets), findsOneWidget);
    });
  });
}
