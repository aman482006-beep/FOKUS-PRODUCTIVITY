import '../../models/habit.dart';

/// Abstraction over habit persistence and streak calculation.
///
/// Implementations handle loading/saving habits and their completions,
/// as well as recalculating current and best streaks.
abstract class IHabitService {
  /// Load all habits from storage.
  List<Habit> loadHabits();

  /// Save all habits to storage.
  Future<void> saveHabits(List<Habit> habits);

  /// Load all habit completions from storage.
  List<HabitCompletion> loadCompletions();

  /// Save all completions to storage.
  Future<void> saveCompletions(List<HabitCompletion> completions);

  /// Recalculate current and best streaks for a single habit.
  Habit recalculateStreaksForHabit(Habit habit, List<HabitCompletion> completions);
}
