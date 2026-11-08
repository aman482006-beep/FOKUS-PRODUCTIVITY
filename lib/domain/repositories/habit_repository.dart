import '../../models/habit.dart';

/// Abstract contract for habit data access.
///
/// Implementations live in `data/repositories/`. ViewModels and Use Cases
/// depend only on this interface, never on concrete services.
abstract class HabitRepository {
  List<Habit> loadHabits();
  Future<void> saveHabits(List<Habit> habits);
  List<HabitCompletion> loadCompletions();
  Future<void> saveCompletions(List<HabitCompletion> completions);
  Habit recalculateStreaksForHabit(Habit habit, List<HabitCompletion> completions);
}
