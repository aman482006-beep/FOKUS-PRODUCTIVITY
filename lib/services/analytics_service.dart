import 'package:flutter/material.dart';
import '../models/habit.dart';
import '../models/fokus_session.dart';
import '../models/task.dart';

class AnalyticsState {
  // Overview Tab Metrics
  final double todayFocusMinutes;
  final double habitCompletionTodayPercent;
  final int currentFocusStreak;
  final int currentHabitStreak;
  final double weeklyFocusMinutes;
  final double weeklyHabitConsistencyPercent;

  // Focus Analytics Tab Metrics
  final List<int> dailyFocusTrend7D;
  final List<int> dailyFocusTrend30D;
  final List<int> dailyFocusTrend90D;
  final List<DateTime> dailyFocusTrendDates7D;
  final List<DateTime> dailyFocusTrendDates30D;
  final List<DateTime> dailyFocusTrendDates90D;

  final Map<String, int> focusHeatmapData; // yyyy-MM-dd -> focus minutes
  final Map<String, double> habitHeatmapData; // yyyy-MM-dd -> completion rate (0.0 to 1.0)
  
  // Focus Tab Details
  final double averageSessionDuration;
  final int completedSessionsCount;
  final int fokusStreak;
  final String bestFocusDay; // Weekday name
  final List<int> weekdayFocusDistribution; // 7 entries: Mon-Sun minutes
  final int monthlyFocusTotalMinutes;

  // Habits Tab Details
  final int totalHabitsCount;
  final int completedHabitsCountToday;
  final double habitTrendTodayPercent;
  final List<Map<String, dynamic>> individualHabitsProgress; // name, icon, completedToday (bool), streak, weeklyConsistencyPercent, color, id
  final Map<String, List<String>> habitCalendarHeatmap; // habitId -> list of completed dates
  final double thisWeekHabitPercent;
  final double thisMonthHabitPercent;
  final int bestHabitStreak;
  final List<double> habitTrend7D;
  final List<double> habitTrend30D;
  final List<double> habitTrend90D;
  final List<DateTime> habitTrendDates7D;
  final List<DateTime> habitTrendDates30D;
  final List<DateTime> habitTrendDates90D;

  // Tasks Tab Metrics
  final int todayTasksCompletedCount;
  final int overdueTasksCount;
  final List<int> tasksCompletionTrend7D;
  final List<int> tasksCompletionTrend30D;
  final List<int> tasksCompletionTrend90D;
  final double averageTaskCompletionTimeMinutes;

  AnalyticsState({
    required this.todayFocusMinutes,
    required this.habitCompletionTodayPercent,
    required this.currentFocusStreak,
    required this.currentHabitStreak,
    required this.weeklyFocusMinutes,
    required this.weeklyHabitConsistencyPercent,
    required this.dailyFocusTrend7D,
    required this.dailyFocusTrend30D,
    required this.dailyFocusTrend90D,
    required this.dailyFocusTrendDates7D,
    required this.dailyFocusTrendDates30D,
    required this.dailyFocusTrendDates90D,
    required this.focusHeatmapData,
    required this.habitHeatmapData,
    required this.averageSessionDuration,
    required this.completedSessionsCount,
    required this.fokusStreak,
    required this.bestFocusDay,
    required this.weekdayFocusDistribution,
    required this.monthlyFocusTotalMinutes,
    required this.totalHabitsCount,
    required this.completedHabitsCountToday,
    required this.habitTrendTodayPercent,
    required this.individualHabitsProgress,
    required this.habitCalendarHeatmap,
    required this.thisWeekHabitPercent,
    required this.thisMonthHabitPercent,
    required this.bestHabitStreak,
    required this.habitTrend7D,
    required this.habitTrend30D,
    required this.habitTrend90D,
    required this.habitTrendDates7D,
    required this.habitTrendDates30D,
    required this.habitTrendDates90D,
    required this.todayTasksCompletedCount,
    required this.overdueTasksCount,
    required this.tasksCompletionTrend7D,
    required this.tasksCompletionTrend30D,
    required this.tasksCompletionTrend90D,
    required this.averageTaskCompletionTimeMinutes,
  });
}

class AnalyticsService {
  
  static AnalyticsState calculateAnalytics({
    required List<Habit> habits,
    required List<HabitCompletion> completions,
    required List<FokusSession> sessions,
    required Map<String, double> goals,
    required List<Task> tasks,
  }) {
    final now = DateTime.now();
    final todayStr = now.toIso8601String().substring(0, 10);
    final yesterdayStr = now.subtract(const Duration(days: 1)).toIso8601String().substring(0, 10);

    // ── 1. Focus Timer Calculations ──
    final completedSessions = sessions.where((s) => !s.isBreak && s.durationMinutes > 0).toList();
    
    // Today's focus minutes
    final todayFocusMinutes = completedSessions
        .where((s) => s.date == todayStr)
        .fold<double>(0.0, (sum, s) => sum + s.durationMinutes);

    // Weekly focus minutes (last 7 rolling days)
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final weeklyFocusMinutes = completedSessions
        .where((s) {
          try {
            final date = DateTime.parse(s.timestamp);
            return date.isAfter(sevenDaysAgo);
          } catch (_) {
            return false;
          }
        })
        .fold<double>(0.0, (sum, s) => sum + s.durationMinutes);

    // Monthly Focus Total (current calendar month)
    final monthlyFocusTotalMinutes = completedSessions
        .where((s) {
          try {
            final date = DateTime.parse(s.timestamp);
            return date.year == now.year && date.month == now.month;
          } catch (_) {
            return false;
          }
        })
        .fold<int>(0, (sum, s) => sum + s.durationMinutes);

    // Focus Streak
    final completedSessionDates = completedSessions.map((s) => s.date).toSet().toList()..sort();
    int currentFocusStreak = 0;
    int bestFocusStreak = 0;
    if (completedSessionDates.isNotEmpty) {
      bool activeStreak = completedSessionDates.contains(todayStr) || completedSessionDates.contains(yesterdayStr);
      if (activeStreak) {
        int count = 0;
        DateTime checkDate = completedSessionDates.contains(todayStr) ? now : now.subtract(const Duration(days: 1));
        while (true) {
          final checkStr = checkDate.toIso8601String().substring(0, 10);
          if (completedSessionDates.contains(checkStr)) {
            count++;
            checkDate = checkDate.subtract(const Duration(days: 1));
          } else {
            break;
          }
        }
        currentFocusStreak = count;
      }

      int temp = 0;
      DateTime? prev;
      for (final dateStr in completedSessionDates) {
        final d = DateTime.parse(dateStr);
        if (prev == null) {
          temp = 1;
        } else {
          final diff = d.difference(prev).inDays;
          if (diff == 1) {
            temp++;
          } else if (diff > 1) {
            if (temp > bestFocusStreak) bestFocusStreak = temp;
            temp = 1;
          }
        }
        prev = d;
      }
      if (temp > bestFocusStreak) bestFocusStreak = temp;
    }

    final double averageSessionDuration = completedSessions.isEmpty
        ? 0.0
        : (completedSessions.fold<int>(0, (sum, s) => sum + s.durationMinutes) / completedSessions.length);

    // Focus Trend lines (7D, 30D, 90D)
    List<int> getTrend(int days) {
      return List.generate(days, (i) {
        final date = now.subtract(Duration(days: days - 1 - i));
        final key = date.toIso8601String().substring(0, 10);
        return completedSessions
            .where((s) => s.date == key)
            .fold<int>(0, (sum, s) => sum + s.durationMinutes);
      });
    }
    List<DateTime> getTrendDates(int days) {
      return List.generate(days, (i) => now.subtract(Duration(days: days - 1 - i)));
    }

    final dailyFocusTrend7D = getTrend(7);
    final dailyFocusTrend30D = getTrend(30);
    final dailyFocusTrend90D = getTrend(90);
    final dailyFocusTrendDates7D = getTrendDates(7);
    final dailyFocusTrendDates30D = getTrendDates(30);
    final dailyFocusTrendDates90D = getTrendDates(90);

    // Weekday distribution Mon-Sun
    final weekdayFocusDistribution = List<int>.filled(7, 0);
    for (final s in completedSessions) {
      try {
        final date = DateTime.parse(s.timestamp);
        weekdayFocusDistribution[date.weekday - 1] += s.durationMinutes;
      } catch (_) {}
    }

    // Best Focus day of week
    int maxMins = -1;
    int bestDayIndex = -1;
    for (int i = 0; i < 7; i++) {
      if (weekdayFocusDistribution[i] > maxMins) {
        maxMins = weekdayFocusDistribution[i];
        bestDayIndex = i;
      }
    }
    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final bestFocusDay = maxMins > 0 && bestDayIndex != -1 ? weekdays[bestDayIndex] : 'None';


    // ── 2. Habit Calculations ──
    final activeHabits = habits.where((h) => h.active).toList();
    final todayHabits = activeHabits.where((h) => h.isDueOn(now)).toList();
    final todayCompletions = completions.where((c) => c.date == todayStr && c.completed).toList();

    int habitsCompletedToday = 0;
    for (final h in todayHabits) {
      final isDone = todayCompletions.any((c) => c.habitId == h.id);
      if (isDone) habitsCompletedToday++;
    }

    final habitCompletionTodayPercent = todayHabits.isEmpty
        ? 0.0
        : (habitsCompletedToday / todayHabits.length) * 100;

    // Current Habit Streak (Max streak of active habits)
    int currentHabitStreak = 0;
    int bestHabitStreak = 0;
    for (final h in activeHabits) {
      if (h.streak > currentHabitStreak) {
        currentHabitStreak = h.streak;
      }
      if (h.bestStreak > bestHabitStreak) {
        bestHabitStreak = h.bestStreak;
      }
    }

    // Weekly habit consistency % (rolling 7 days: completed due days / total due days)
    double getHabitPeriodConsistency(int days) {
      int totalDue = 0;
      int completedCount = 0;
      for (int i = 0; i < days; i++) {
        final d = now.subtract(Duration(days: i));
        final dStr = d.toIso8601String().substring(0, 10);
        final dayComps = completions.where((c) => c.date == dStr && c.completed).map((c) => c.habitId).toSet();
        for (final h in activeHabits) {
          if (h.isDueOn(d)) {
            totalDue++;
            if (dayComps.contains(h.id)) {
              completedCount++;
            }
          }
        }
      }
      return totalDue == 0 ? 0.0 : (completedCount / totalDue) * 100;
    }

    final weeklyHabitConsistencyPercent = getHabitPeriodConsistency(7);
    final thisWeekHabitPercent = getHabitPeriodConsistency(7);
    final thisMonthHabitPercent = getHabitPeriodConsistency(30);

    // Habit Trend completion rate per day over time
    List<double> getHabitTrendRate(int days) {
      return List.generate(days, (i) {
        final d = now.subtract(Duration(days: days - 1 - i));
        final dStr = d.toIso8601String().substring(0, 10);
        final dayComps = completions.where((c) => c.date == dStr && c.completed).map((c) => c.habitId).toSet();
        int due = 0;
        int completed = 0;
        for (final h in activeHabits) {
          if (h.isDueOn(d)) {
            due++;
            if (dayComps.contains(h.id)) {
              completed++;
            }
          }
        }
        return due == 0 ? 0.0 : (completed / due) * 100;
      });
    }

    final habitTrend7D = getHabitTrendRate(7);
    final habitTrend30D = getHabitTrendRate(30);
    final habitTrend90D = getHabitTrendRate(90);
    final habitTrendDates7D = getTrendDates(7);
    final habitTrendDates30D = getTrendDates(30);
    final habitTrendDates90D = getTrendDates(90);

    // Individual habits progress
    final List<Map<String, dynamic>> individualHabitsProgress = habits.map((h) {
      final isDone = completions.any((c) => c.habitId == h.id && c.date == todayStr && c.completed);
      
      // Weekly consistency percentage for this habit
      int dueCount = 0;
      int compCount = 0;
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      for (int i = 0; i < 7; i++) {
        final d = startOfWeek.add(Duration(days: i));
        if (h.isDueOn(d)) {
          dueCount++;
          final dStr = d.toIso8601String().substring(0, 10);
          if (completions.any((c) => c.habitId == h.id && c.date == dStr && c.completed)) {
            compCount++;
          }
        }
      }
      final double weeklyConsistency = dueCount == 0 ? 0.0 : (compCount / dueCount) * 100;

      return {
        'id': h.id,
        'name': h.name,
        'icon': h.icon,
        'color': Color(int.parse(h.color.replaceFirst('#', '0xFF'))),
        'completedToday': isDone,
        'streak': h.streak,
        'weeklyConsistencyPercent': weeklyConsistency,
      };
    }).toList();

    // Habit completion calendars (habitId -> dates completed)
    final habitCalendarHeatmap = <String, List<String>>{};
    for (final h in habits) {
      habitCalendarHeatmap[h.id] = completions
          .where((c) => c.habitId == h.id && c.completed)
          .map((c) => c.date)
          .toList();
    }


    // ── 3. Heatmaps ──
    // Focus Heatmap (past 84 days)
    final focusHeatmapData = <String, int>{};
    // Habit Heatmap (past 84 days)
    final habitHeatmapData = <String, double>{};

    for (int i = 0; i < 84; i++) {
      final d = now.subtract(Duration(days: 83 - i));
      final dStr = d.toIso8601String().substring(0, 10);
      
      // Focus
      final focusMins = completedSessions
          .where((s) => s.date == dStr)
          .fold<int>(0, (sum, s) => sum + s.durationMinutes);
      focusHeatmapData[dStr] = focusMins;

      // Habits
      final dayComps = completions.where((c) => c.date == dStr && c.completed).map((c) => c.habitId).toSet();
      int due = 0;
      int completed = 0;
      for (final h in activeHabits) {
        if (h.isDueOn(d)) {
          due++;
          if (dayComps.contains(h.id)) {
            completed++;
          }
        }
      }
      habitHeatmapData[dStr] = due == 0 ? 0.0 : (completed / due);
    }

    // ── 4. Task Calculations ──
    final todayTasksCompletedCount = tasks.where((t) {
      if (!t.done || t.completedAt == null) return false;
      final compDateStr = t.completedAt!.toIso8601String().substring(0, 10);
      return compDateStr == todayStr;
    }).length;

    final overdueTasksCount = tasks.where((t) {
      if (t.done || t.dueDate == null) return false;
      return t.dueDate!.isBefore(now) && t.dueDate!.toIso8601String().substring(0, 10) != todayStr;
    }).length;

    List<int> getTaskTrend(int days) {
      return List.generate(days, (i) {
        final date = now.subtract(Duration(days: days - 1 - i));
        final key = date.toIso8601String().substring(0, 10);
        return tasks.where((t) {
          if (!t.done || t.completedAt == null) return false;
          final compDateStr = t.completedAt!.toIso8601String().substring(0, 10);
          return compDateStr == key;
        }).length;
      });
    }

    final tasksCompletionTrend7D = getTaskTrend(7);
    final tasksCompletionTrend30D = getTaskTrend(30);
    final tasksCompletionTrend90D = getTaskTrend(90);

    final completedTasks = tasks.where((t) => t.done && t.completedAt != null).toList();
    double averageTaskCompletionTimeMinutes = 0.0;
    if (completedTasks.isNotEmpty) {
      final totalDiff = completedTasks.fold<int>(0, (sum, t) {
        final diff = t.completedAt!.difference(t.createdAt).inMinutes;
        return sum + (diff > 0 ? diff : 0);
      });
      averageTaskCompletionTimeMinutes = totalDiff / completedTasks.length;
    }

    return AnalyticsState(
      todayFocusMinutes: todayFocusMinutes,
      habitCompletionTodayPercent: habitCompletionTodayPercent,
      currentFocusStreak: currentFocusStreak,
      currentHabitStreak: currentHabitStreak,
      weeklyFocusMinutes: weeklyFocusMinutes,
      weeklyHabitConsistencyPercent: weeklyHabitConsistencyPercent,
      dailyFocusTrend7D: dailyFocusTrend7D,
      dailyFocusTrend30D: dailyFocusTrend30D,
      dailyFocusTrend90D: dailyFocusTrend90D,
      dailyFocusTrendDates7D: dailyFocusTrendDates7D,
      dailyFocusTrendDates30D: dailyFocusTrendDates30D,
      dailyFocusTrendDates90D: dailyFocusTrendDates90D,
      focusHeatmapData: focusHeatmapData,
      habitHeatmapData: habitHeatmapData,
      averageSessionDuration: averageSessionDuration,
      completedSessionsCount: completedSessions.length,
      fokusStreak: currentFocusStreak,
      bestFocusDay: bestFocusDay,
      weekdayFocusDistribution: weekdayFocusDistribution,
      monthlyFocusTotalMinutes: monthlyFocusTotalMinutes,
      totalHabitsCount: todayHabits.length,
      completedHabitsCountToday: habitsCompletedToday,
      habitTrendTodayPercent: habitCompletionTodayPercent,
      individualHabitsProgress: individualHabitsProgress,
      habitCalendarHeatmap: habitCalendarHeatmap,
      thisWeekHabitPercent: thisWeekHabitPercent,
      thisMonthHabitPercent: thisMonthHabitPercent,
      bestHabitStreak: bestHabitStreak,
      habitTrend7D: habitTrend7D,
      habitTrend30D: habitTrend30D,
      habitTrend90D: habitTrend90D,
      habitTrendDates7D: habitTrendDates7D,
      habitTrendDates30D: habitTrendDates30D,
      habitTrendDates90D: habitTrendDates90D,
      todayTasksCompletedCount: todayTasksCompletedCount,
      overdueTasksCount: overdueTasksCount,
      tasksCompletionTrend7D: tasksCompletionTrend7D,
      tasksCompletionTrend30D: tasksCompletionTrend30D,
      tasksCompletionTrend90D: tasksCompletionTrend90D,
      averageTaskCompletionTimeMinutes: averageTaskCompletionTimeMinutes,
    );
  }
}
