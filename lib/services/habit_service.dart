import 'dart:convert';
import 'storage_service.dart';
import '../models/habit.dart';

/// Manages habit persistence and streak calculation.
///
/// This is a purely static service. For DI-aware access, use [HabitServiceAdapter].
class HabitService {
  HabitService._();

  static const _habitsKey = 'habits_list';
  static const _completionsKey = 'habit_completions_list';

  // ── Static API ──

  static List<Habit> loadHabits() {
    final raw = StorageService.prefsStatic.getString(_habitsKey) ?? '[]';
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => Habit.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveHabits(List<Habit> habits) async {
    await StorageService.prefsStatic.setString(
      _habitsKey,
      jsonEncode(habits.map((h) => h.toJson()).toList()),
    );
  }

  static List<HabitCompletion> loadCompletions() {
    final raw = StorageService.prefsStatic.getString(_completionsKey) ?? '[]';
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => HabitCompletion.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveCompletions(List<HabitCompletion> completions) async {
    await StorageService.prefsStatic.setString(
      _completionsKey,
      jsonEncode(completions.map((c) => c.toJson()).toList()),
    );
  }

  static Habit recalculateStreaksForHabit(Habit habit, List<HabitCompletion> completions) {
    final myCompletions = completions.where((c) => c.habitId == habit.id).toList();
    if (myCompletions.isEmpty) {
      return habit.copyWith(streak: 0, bestStreak: habit.bestStreak);
    }

    final today = DateTime.now();
    final todayStr = today.toIso8601String().substring(0, 10);
    final completedDates = myCompletions.map((c) => c.date).toSet().toList()..sort();

    int currentStreak = 0;
    int bestStreak = habit.bestStreak;

    if (habit.frequency == 'weekly' || habit.frequency == 'monthly') {
      final isWeekly = habit.frequency == 'weekly';

      String getPeriodKey(DateTime date) {
        if (isWeekly) {
          // ISO 8601 week number calculation (using UTC to prevent DST issues):
          final thursdayLocal = date.add(Duration(days: 4 - date.weekday));
          final thursday = DateTime.utc(thursdayLocal.year, thursdayLocal.month, thursdayLocal.day);
          final jan1 = DateTime.utc(thursday.year, 1, 1);
          final weekNumber = (thursday.difference(jan1).inDays / 7).floor() + 1;
          return '${thursday.year}-W${weekNumber.toString().padLeft(2, '0')}';
        } else {
          return '${date.year}-${date.month.toString().padLeft(2, '0')}';
        }
      }

      final completionsByPeriod = <String, int>{};
      for (final comp in myCompletions) {
        final key = getPeriodKey(comp.timestamp);
        completionsByPeriod[key] = (completionsByPeriod[key] ?? 0) + 1;
      }

      int consecutive = 0;
      bool currentPeriodValid = true;
      final currentKey = getPeriodKey(today);
      final currentCount = completionsByPeriod[currentKey] ?? 0;
      if (currentCount >= habit.targetCount) {
        consecutive++;
      } else {
        currentPeriodValid = false;
      }

      DateTime prevCursor = isWeekly
          ? today.subtract(const Duration(days: 7))
          : DateTime(today.year, today.month - 1, 15);

      bool broke = false;
      int safety = 0;
      while (safety < 104) {
        safety++;
        final key = getPeriodKey(prevCursor);
        final count = completionsByPeriod[key] ?? 0;
        if (count >= habit.targetCount) {
          consecutive++;
        } else {
          if (safety == 1 && !currentPeriodValid) broke = true;
          break;
        }
        prevCursor = isWeekly
            ? prevCursor.subtract(const Duration(days: 7))
            : DateTime(prevCursor.year, prevCursor.month - 1, 15);
      }

      currentStreak = broke ? 0 : consecutive;
      if (currentStreak > bestStreak) bestStreak = currentStreak;
    } else {
      final completedDatesSet = completedDates.toSet();
      bool completedToday = completedDatesSet.contains(todayStr);
      DateTime cursor = today;

      if (!completedToday && habit.isDueOn(today)) {
        DateTime prevDue = today.subtract(const Duration(days: 1));
        while (!habit.isDueOn(prevDue)) prevDue = prevDue.subtract(const Duration(days: 1));
        final prevDueStr = prevDue.toIso8601String().substring(0, 10);
        if (!completedDatesSet.contains(prevDueStr)) {
          currentStreak = 0;
        } else {
          cursor = prevDue;
        }
      } else if (!completedToday && !habit.isDueOn(today)) {
        DateTime prevDue = today.subtract(const Duration(days: 1));
        while (!habit.isDueOn(prevDue)) prevDue = prevDue.subtract(const Duration(days: 1));
        final prevDueStr = prevDue.toIso8601String().substring(0, 10);
        if (!completedDatesSet.contains(prevDueStr)) {
          currentStreak = 0;
        } else {
          cursor = prevDue;
        }
      }

      if (currentStreak != 0 || completedToday || !habit.isDueOn(today)) {
        int streakCount = 0;
        int safety = 0;
        while (safety < 365) {
          safety++;
          final cursorStr = cursor.toIso8601String().substring(0, 10);
          if (habit.isDueOn(cursor)) {
            if (completedDatesSet.contains(cursorStr)) {
              streakCount++;
            } else {
              break;
            }
          }
          cursor = cursor.subtract(const Duration(days: 1));
        }
        currentStreak = streakCount;
      }

      int maxStreak = 0;
      if (completedDates.isNotEmpty) {
        int tempStreak = 0;
        DateTime? lastDueDay;
        for (final dateStr in completedDates) {
          final currentDay = DateTime.parse(dateStr);
          if (lastDueDay == null) {
            tempStreak = 1;
            lastDueDay = currentDay;
          } else {
            DateTime check = lastDueDay.add(const Duration(days: 1));
            int dueDaysBetween = 0;
            while (check.isBefore(currentDay)) {
              if (habit.isDueOn(check)) dueDaysBetween++;
              check = check.add(const Duration(days: 1));
            }
            if (dueDaysBetween == 0) {
              tempStreak++;
            } else {
              if (tempStreak > maxStreak) maxStreak = tempStreak;
              tempStreak = 1;
            }
            lastDueDay = currentDay;
          }
        }
        if (tempStreak > maxStreak) maxStreak = tempStreak;
        bestStreak = maxStreak > habit.bestStreak ? maxStreak : habit.bestStreak;
      }
    }

    return habit.copyWith(streak: currentStreak, bestStreak: bestStreak);
  }
}
