import 'package:flutter_test/flutter_test.dart';
import 'package:fokus/models/habit.dart';
import 'package:fokus/models/fokus_session.dart';
import 'package:fokus/models/task.dart';
import 'package:fokus/services/analytics_service.dart';

void main() {
  group('AnalyticsService', () {
    late DateTime now;
    late String todayStr;

    setUp(() {
      now = DateTime.now();
      todayStr = now.toIso8601String().substring(0, 10);
    });

    test('empty data returns zeroed state', () {
      final state = AnalyticsService.calculateAnalytics(
        habits: [],
        completions: [],
        sessions: [],
        goals: {},
        tasks: [],
      );
      expect(state.todayFocusMinutes, 0.0);
      expect(state.completedSessionsCount, 0);
      expect(state.averageSessionDuration, 0.0);
      expect(state.currentFocusStreak, 0);
      expect(state.todayTasksCompletedCount, 0);
      expect(state.overdueTasksCount, 0);
      expect(state.bestFocusDay, 'None');
    });

    test('today fokus minutes calculated correctly', () {
      final sessions = [
        FokusSession(date: todayStr, durationMinutes: 25, timestamp: '${todayStr}T10:00:00'),
        FokusSession(date: todayStr, durationMinutes: 25, timestamp: '${todayStr}T11:00:00'),
        FokusSession(date: '2020-01-01', durationMinutes: 30, timestamp: '2020-01-01T10:00:00'),
      ];
      final state = AnalyticsService.calculateAnalytics(
        habits: [],
        completions: [],
        sessions: sessions,
        goals: {},
        tasks: [],
      );
      expect(state.todayFocusMinutes, 50.0);
      expect(state.completedSessionsCount, 3);
    });

    test('break sessions excluded from fokus minutes', () {
      final sessions = [
        FokusSession(date: todayStr, durationMinutes: 25, timestamp: '${todayStr}T10:00:00'),
        FokusSession(date: todayStr, durationMinutes: 5, timestamp: '${todayStr}T10:25:00', isBreak: true),
      ];
      final state = AnalyticsService.calculateAnalytics(
        habits: [],
        completions: [],
        sessions: sessions,
        goals: {},
        tasks: [],
      );
      expect(state.todayFocusMinutes, 25.0);
      expect(state.completedSessionsCount, 1);
    });

    test('average session duration', () {
      final sessions = [
        FokusSession(date: todayStr, durationMinutes: 20, timestamp: '${todayStr}T10:00:00'),
        FokusSession(date: todayStr, durationMinutes: 40, timestamp: '${todayStr}T11:00:00'),
      ];
      final state = AnalyticsService.calculateAnalytics(
        habits: [],
        completions: [],
        sessions: sessions,
        goals: {},
        tasks: [],
      );
      expect(state.averageSessionDuration, 30.0);
    });

    test('fokus streak counts consecutive days', () {
      final today = DateTime.now();
      final sessions = <FokusSession>[];
      for (int i = 0; i < 3; i++) {
        final day = today.subtract(Duration(days: i));
        final dateStr = day.toIso8601String().substring(0, 10);
        sessions.add(FokusSession(date: dateStr, durationMinutes: 25, timestamp: '${dateStr}T10:00:00'));
      }
      final state = AnalyticsService.calculateAnalytics(
        habits: [],
        completions: [],
        sessions: sessions,
        goals: {},
        tasks: [],
      );
      expect(state.currentFocusStreak, greaterThanOrEqualTo(3));
    });

    test('fokus streak is 0 when today and yesterday have no sessions', () {
      final sessions = [
        FokusSession(
          date: '2020-01-01',
          durationMinutes: 25,
          timestamp: '2020-01-01T10:00:00',
        ),
      ];
      final state = AnalyticsService.calculateAnalytics(
        habits: [],
        completions: [],
        sessions: sessions,
        goals: {},
        tasks: [],
      );
      expect(state.currentFocusStreak, 0);
    });

    test('best fokus day of week', () {
      final today = DateTime.now();
      // Create 5 sessions on a Wednesday
      final sessions = <FokusSession>[];
      // Find a past Wednesday
      var wednesday = today;
      while (wednesday.weekday != DateTime.wednesday) {
        wednesday = wednesday.subtract(const Duration(days: 1));
      }
      final wedStr = wednesday.toIso8601String().substring(0, 10);
      for (int i = 0; i < 5; i++) {
        sessions.add(FokusSession(date: wedStr, durationMinutes: 30, timestamp: '${wedStr}T${10 + i}:00:00'));
      }
      final state = AnalyticsService.calculateAnalytics(
        habits: [],
        completions: [],
        sessions: sessions,
        goals: {},
        tasks: [],
      );
      expect(state.bestFocusDay, 'Wednesday');
    });

    test('habit completion percentage', () {
      final habit = Habit(id: 'h1', name: 'Read', icon: '📖', frequency: 'daily');
      final completion = HabitCompletion(
        id: 'c1',
        habitId: 'h1',
        date: todayStr,
        completed: true,
        timestamp: now,
      );
      final state = AnalyticsService.calculateAnalytics(
        habits: [habit],
        completions: [completion],
        sessions: [],
        goals: {},
        tasks: [],
      );
      expect(state.habitCompletionTodayPercent, 100.0);
      expect(state.completedHabitsCountToday, 1);
      expect(state.totalHabitsCount, 1);
    });

    test('habit not completed today shows 0%', () {
      final habit = Habit(id: 'h1', name: 'Read', icon: '📖', frequency: 'daily');
      final state = AnalyticsService.calculateAnalytics(
        habits: [habit],
        completions: [],
        sessions: [],
        goals: {},
        tasks: [],
      );
      expect(state.habitCompletionTodayPercent, 0.0);
      expect(state.completedHabitsCountToday, 0);
    });

    test('inactive habits excluded from today count', () {
      final active = Habit(id: 'h1', name: 'Read', icon: '📖', frequency: 'daily', active: true);
      final inactive = Habit(id: 'h2', name: 'Gym', icon: '💪', frequency: 'daily', active: false);
      final state = AnalyticsService.calculateAnalytics(
        habits: [active, inactive],
        completions: [],
        sessions: [],
        goals: {},
        tasks: [],
      );
      expect(state.totalHabitsCount, 1); // only active daily habits
    });

    test('weekend habits not due on weekdays', () {
      final weekend = Habit(id: 'h1', name: 'Sleep in', icon: '😴', frequency: 'weekends');
      final state = AnalyticsService.calculateAnalytics(
        habits: [weekend],
        completions: [],
        sessions: [],
        goals: {},
        tasks: [],
      );
      // If today is a weekday, this habit shouldn't be counted
      if (now.weekday >= DateTime.monday && now.weekday <= DateTime.friday) {
        expect(state.totalHabitsCount, 0);
      }
    });

    test('today tasks completed count', () {
      final tasks = [
        Task(
          id: '1',
          title: 'Done today',
          done: true,
          completedAt: now,
          createdAt: now.subtract(const Duration(hours: 1)),
        ),
        Task(
          id: '2',
          title: 'Done yesterday',
          done: true,
          completedAt: now.subtract(const Duration(days: 1)),
          createdAt: now.subtract(const Duration(days: 2)),
        ),
        Task(id: '3', title: 'Not done', done: false),
      ];
      final state = AnalyticsService.calculateAnalytics(
        habits: [],
        completions: [],
        sessions: [],
        goals: {},
        tasks: tasks,
      );
      expect(state.todayTasksCompletedCount, 1);
    });

    test('overdue tasks count', () {
      final tasks = [
        Task(
          id: '1',
          title: 'Overdue',
          done: false,
          dueDate: now.subtract(const Duration(days: 2)),
        ),
        Task(
          id: '2',
          title: 'Not overdue yet',
          done: false,
          dueDate: now.add(const Duration(days: 2)),
        ),
        Task(
          id: '3',
          title: 'Done overdue',
          done: true,
          dueDate: now.subtract(const Duration(days: 1)),
          completedAt: now,
        ),
        Task(id: '4', title: 'No due date', done: false),
      ];
      final state = AnalyticsService.calculateAnalytics(
        habits: [],
        completions: [],
        sessions: [],
        goals: {},
        tasks: tasks,
      );
      expect(state.overdueTasksCount, 1);
    });

    test('weekday fokus distribution', () {
      final today = DateTime.now();
      // Find this Monday
      var monday = today;
      while (monday.weekday != DateTime.monday) {
        monday = monday.subtract(const Duration(days: 1));
      }
      final monStr = monday.toIso8601String().substring(0, 10);
      final sessions = [
        FokusSession(date: monStr, durationMinutes: 60, timestamp: '${monStr}T10:00:00'),
        FokusSession(date: monStr, durationMinutes: 30, timestamp: '${monStr}T11:00:00'),
      ];
      final state = AnalyticsService.calculateAnalytics(
        habits: [],
        completions: [],
        sessions: sessions,
        goals: {},
        tasks: [],
      );
      expect(state.weekdayFocusDistribution[0], 90); // Monday index = 0
    });

    test('individual habits progress includes all habits', () {
      final habits = [
        Habit(id: 'h1', name: 'Read', icon: '📖', frequency: 'daily'),
        Habit(id: 'h2', name: 'Exercise', icon: '💪', frequency: 'daily'),
      ];
      final state = AnalyticsService.calculateAnalytics(
        habits: habits,
        completions: [],
        sessions: [],
        goals: {},
        tasks: [],
      );
      expect(state.individualHabitsProgress.length, 2);
      expect(state.individualHabitsProgress[0]['name'], 'Read');
      expect(state.individualHabitsProgress[1]['name'], 'Exercise');
    });

    test('habit calendar heatmap contains completed dates', () {
      final habit = Habit(id: 'h1', name: 'Read', icon: '📖', frequency: 'daily');
      final completions = [
        HabitCompletion(id: 'c1', habitId: 'h1', date: '2026-01-01', timestamp: DateTime(2026, 1, 1)),
        HabitCompletion(id: 'c2', habitId: 'h1', date: '2026-01-02', timestamp: DateTime(2026, 1, 2)),
      ];
      final state = AnalyticsService.calculateAnalytics(
        habits: [habit],
        completions: completions,
        sessions: [],
        goals: {},
        tasks: [],
      );
      expect(state.habitCalendarHeatmap['h1'], contains('2026-01-01'));
      expect(state.habitCalendarHeatmap['h1'], contains('2026-01-02'));
    });

    test('heatmap data covers past 84 days', () {
      final state = AnalyticsService.calculateAnalytics(
        habits: [],
        completions: [],
        sessions: [],
        goals: {},
        tasks: [],
      );
      expect(state.focusHeatmapData.length, 84);
      expect(state.habitHeatmapData.length, 84);
    });

    test('monthly fokus total', () {
      final sessions = [
        FokusSession(date: todayStr, durationMinutes: 25, timestamp: '${todayStr}T10:00:00'),
        FokusSession(
          date: todayStr,
          durationMinutes: 35,
          timestamp: '${todayStr}T11:00:00',
        ),
      ];
      final state = AnalyticsService.calculateAnalytics(
        habits: [],
        completions: [],
        sessions: sessions,
        goals: {},
        tasks: [],
      );
      expect(state.monthlyFocusTotalMinutes, 60);
    });

    test('completed task average completion time', () {
      final tasks = [
        Task(
          id: '1',
          title: 'Fast task',
          done: true,
          createdAt: DateTime(2026, 1, 1, 8, 0),
          completedAt: DateTime(2026, 1, 1, 8, 30), // 30 min
        ),
        Task(
          id: '2',
          title: 'Slow task',
          done: true,
          createdAt: DateTime(2026, 1, 2, 8, 0),
          completedAt: DateTime(2026, 1, 2, 12, 0), // 240 min
        ),
      ];
      final state = AnalyticsService.calculateAnalytics(
        habits: [],
        completions: [],
        sessions: [],
        goals: {},
        tasks: tasks,
      );
      expect(state.averageTaskCompletionTimeMinutes, 135.0); // (30+240)/2
    });
  });
}
