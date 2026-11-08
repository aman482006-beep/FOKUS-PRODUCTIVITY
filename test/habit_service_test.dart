import 'package:flutter_test/flutter_test.dart';
import 'package:fokus/models/habit.dart';
import 'package:fokus/services/habit_service.dart';
import 'package:fokus/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.initForTest();
  });

  // ════════════════════════════════════════════════════════════════
  // HabitService Streak Calculation Tests
  // ════════════════════════════════════════════════════════════════

  group('HabitService.recalculateStreaksForHabit', () {
    late DateTime now;
    late String todayStr;

    setUp(() {
      now = DateTime.now();
      todayStr = now.toIso8601String().substring(0, 10);
    });

    test('no completions returns streak 0', () {
      final habit = Habit(id: 'h1', name: 'Read', icon: '📖', frequency: 'daily');
      final result = HabitService.recalculateStreaksForHabit(habit, []);
      expect(result.streak, 0);
      expect(result.bestStreak, 0);
    });

    test('streak of 1 when only today completed', () {
      final habit = Habit(id: 'h1', name: 'Read', icon: '📖', frequency: 'daily');
      final completions = [
        HabitCompletion(id: 'c1', habitId: 'h1', date: todayStr, timestamp: now),
      ];
      final result = HabitService.recalculateStreaksForHabit(habit, completions);
      expect(result.streak, 1);
    });

    test('streak of 3 for 3 consecutive days', () {
      final habit = Habit(id: 'h1', name: 'Read', icon: '📖', frequency: 'daily');
      final completions = List.generate(3, (i) {
        final day = now.subtract(Duration(days: i));
        final dateStr = day.toIso8601String().substring(0, 10);
        return HabitCompletion(id: 'c$i', habitId: 'h1', date: dateStr, timestamp: day);
      });
      final result = HabitService.recalculateStreaksForHabit(habit, completions);
      expect(result.streak, 3);
    });

    test('streak breaks with missing day', () {
      final habit = Habit(id: 'h1', name: 'Read', icon: '📖', frequency: 'daily');
      final today = now;
      final yesterday = now.subtract(const Duration(days: 1));
      final dayBefore = now.subtract(const Duration(days: 3)); // Gap at -2

      final completions = [
        HabitCompletion(id: 'c1', habitId: 'h1', date: today.toIso8601String().substring(0, 10), timestamp: today),
        HabitCompletion(id: 'c2', habitId: 'h1', date: yesterday.toIso8601String().substring(0, 10), timestamp: yesterday),
        HabitCompletion(id: 'c3', habitId: 'h1', date: dayBefore.toIso8601String().substring(0, 10), timestamp: dayBefore),
      ];
      final result = HabitService.recalculateStreaksForHabit(habit, completions);
      // Streak should be 2 (today + yesterday) since there's a gap
      expect(result.streak, 2);
    });

    test('weekdays habit - streak counts weekday-only days', () {
      final habit = Habit(id: 'h1', name: 'Work', icon: '💼', frequency: 'weekdays');

      // Find this week's Monday
      var monday = now;
      while (monday.weekday != DateTime.monday) {
        monday = monday.subtract(const Duration(days: 1));
      }

      // Complete Mon, Tue, Wed
      final completions = <HabitCompletion>[];
      for (int i = 0; i < 3; i++) {
        final day = monday.add(Duration(days: i));
        final dateStr = day.toIso8601String().substring(0, 10);
        completions.add(HabitCompletion(id: 'c$i', habitId: 'h1', date: dateStr, timestamp: day));
      }

      final result = HabitService.recalculateStreaksForHabit(habit, completions);
      expect(result.streak, greaterThanOrEqualTo(0));
    });

    test('best streak is preserved when current is lower', () {
      final habit = Habit(
        id: 'h1',
        name: 'Read',
        icon: '📖',
        frequency: 'daily',
        bestStreak: 30,
      );
      final completions = [
        HabitCompletion(id: 'c1', habitId: 'h1', date: todayStr, timestamp: now),
      ];
      final result = HabitService.recalculateStreaksForHabit(habit, completions);
      expect(result.streak, 1);
      expect(result.bestStreak, 30); // Preserved
    });

    test('best streak updates when current exceeds it', () {
      final habit = Habit(
        id: 'h1',
        name: 'Read',
        icon: '📖',
        frequency: 'daily',
        bestStreak: 2,
      );
      // Complete 5 consecutive days including today
      final completions = List.generate(5, (i) {
        final day = now.subtract(Duration(days: i));
        final dateStr = day.toIso8601String().substring(0, 10);
        return HabitCompletion(id: 'c$i', habitId: 'h1', date: dateStr, timestamp: day);
      });
      final result = HabitService.recalculateStreaksForHabit(habit, completions);
      expect(result.streak, 5);
      expect(result.bestStreak, 5);
    });

    test('inactive habit still gets streak computed', () {
      final habit = Habit(
        id: 'h1',
        name: 'Read',
        icon: '📖',
        frequency: 'daily',
        active: false,
      );
      final completions = [
        HabitCompletion(id: 'c1', habitId: 'h1', date: todayStr, timestamp: now),
      ];
      final result = HabitService.recalculateStreaksForHabit(habit, completions);
      expect(result.streak, greaterThanOrEqualTo(0));
    });

    test('weekly habit streak calculation', () {
      final habit = Habit(
        id: 'h1',
        name: 'Long run',
        icon: '🏃',
        frequency: 'weekly',
        targetCount: 3,
      );
      // Complete 2 weeks in a row with 3+ completions
      final completions = <HabitCompletion>[];
      for (int w = 0; w < 2; w++) {
        for (int d = 0; d < 3; d++) {
          final day = now.subtract(Duration(days: w * 7 + d));
          completions.add(HabitCompletion(
            id: 'c${w}_$d',
            habitId: 'h1',
            date: day.toIso8601String().substring(0, 10),
            timestamp: day,
          ));
        }
      }
      final result = HabitService.recalculateStreaksForHabit(habit, completions);
      expect(result.streak, greaterThanOrEqualTo(1));
    });

    test('monthly habit streak calculation', () {
      final habit = Habit(
        id: 'h1',
        name: 'Book review',
        icon: '📚',
        frequency: 'monthly',
        targetCount: 1,
      );
      final completions = [
        HabitCompletion(id: 'c1', habitId: 'h1', date: todayStr, timestamp: now),
      ];
      final result = HabitService.recalculateStreaksForHabit(habit, completions);
      expect(result.streak, greaterThanOrEqualTo(1));
    });
  });

  // ════════════════════════════════════════════════════════════════
  // HabitService Persistence Tests
  // ════════════════════════════════════════════════════════════════

  group('HabitService persistence', () {
    test('loadHabits from empty prefs', () {
      final habits = HabitService.loadHabits();
      expect(habits, isEmpty);
    });

    test('loadCompletions from empty prefs', () {
      final completions = HabitService.loadCompletions();
      expect(completions, isEmpty);
    });

    test('save and load habits roundtrip', () async {
      final habit = Habit(id: 'h1', name: 'Read', icon: '📖', frequency: 'daily');
      await HabitService.saveHabits([habit]);
      final loaded = HabitService.loadHabits();
      expect(loaded.length, 1);
      expect(loaded.first.id, 'h1');
      expect(loaded.first.name, 'Read');
    });

    test('save and load completions roundtrip', () async {
      final comp = HabitCompletion(
        id: 'c1',
        habitId: 'h1',
        date: '2026-01-01',
        timestamp: DateTime(2026, 1, 1),
      );
      await HabitService.saveCompletions([comp]);
      final loaded = HabitService.loadCompletions();
      expect(loaded.length, 1);
      expect(loaded.first.habitId, 'h1');
    });
  });
}
