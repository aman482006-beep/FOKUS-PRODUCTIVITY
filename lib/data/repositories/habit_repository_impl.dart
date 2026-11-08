import '../../domain/repositories/habit_repository.dart';
import '../../models/habit.dart';
import '../../services/habit_service.dart';

/// Concrete implementation of [HabitRepository] that delegates to
/// the existing [HabitService] static API.
class HabitRepositoryImpl implements HabitRepository {
  @override
  List<Habit> loadHabits() => HabitService.loadHabits();

  @override
  Future<void> saveHabits(List<Habit> habits) =>
      HabitService.saveHabits(habits);

  @override
  List<HabitCompletion> loadCompletions() => HabitService.loadCompletions();

  @override
  Future<void> saveCompletions(List<HabitCompletion> completions) =>
      HabitService.saveCompletions(completions);

  @override
  Habit recalculateStreaksForHabit(
          Habit habit, List<HabitCompletion> completions) =>
      HabitService.recalculateStreaksForHabit(habit, completions);
}
