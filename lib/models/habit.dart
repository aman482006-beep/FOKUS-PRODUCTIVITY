/// A habit entity tracked in Fokus.
class Habit {
  final String id;
  final String name;
  final String icon; // Icon identifier (e.g. material icon name or code point)
  final String color; // Hex color string, e.g. '#6366F1'
  final String frequency; // 'daily' | 'weekdays' | 'weekends' | 'custom' | 'weekly' | 'monthly'
  final int targetCount; // Target completions per period
  final String targetPeriod; // 'day' | 'week' | 'month'
  final List<int>? customWeekdays; // 1 = Monday, 7 = Sunday
  final int streak;
  final int bestStreak;
  final String? reminderTime; // 'HH:mm'
  final DateTime createdAt;
  final bool active;

  Habit({
    required this.id,
    required this.name,
    required this.icon,
    this.color = '#6366F1',
    this.frequency = 'daily',
    this.targetCount = 1,
    this.targetPeriod = 'day',
    this.customWeekdays,
    this.streak = 0,
    this.bestStreak = 0,
    this.reminderTime,
    DateTime? createdAt,
    this.active = true,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Checks if this habit is scheduled to be performed on a specific [date].
  bool isDueOn(DateTime date) {
    if (!active) return false;
    switch (frequency) {
      case 'daily':
        return true;
      case 'weekdays':
        return date.weekday >= DateTime.monday && date.weekday <= DateTime.friday;
      case 'weekends':
        return date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
      case 'custom':
        return customWeekdays?.contains(date.weekday) ?? false;
      case 'weekly':
      case 'monthly':
      default:
        // Weekly and monthly habits are evaluated over their full period,
        // so we treat them as active/due in general.
        return true;
    }
  }

  Habit copyWith({
    String? id,
    String? name,
    String? icon,
    String? color,
    String? frequency,
    int? targetCount,
    String? targetPeriod,
    List<int>? customWeekdays,
    int? streak,
    int? bestStreak,
    String? reminderTime,
    DateTime? createdAt,
    bool? active,
  }) =>
      Habit(
        id: id ?? this.id,
        name: name ?? this.name,
        icon: icon ?? this.icon,
        color: color ?? this.color,
        frequency: frequency ?? this.frequency,
        targetCount: targetCount ?? this.targetCount,
        targetPeriod: targetPeriod ?? this.targetPeriod,
        customWeekdays: customWeekdays ?? this.customWeekdays,
        streak: streak ?? this.streak,
        bestStreak: bestStreak ?? this.bestStreak,
        reminderTime: reminderTime ?? this.reminderTime,
        createdAt: createdAt ?? this.createdAt,
        active: active ?? this.active,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': icon,
        'color': color,
        'frequency': frequency,
        'targetCount': targetCount,
        'targetPeriod': targetPeriod,
        'customWeekdays': customWeekdays,
        'streak': streak,
        'bestStreak': bestStreak,
        'reminderTime': reminderTime,
        'createdAt': createdAt.toIso8601String(),
        'active': active,
      };

  factory Habit.fromJson(Map<String, dynamic> json) => Habit(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        icon: json['icon'] as String? ?? 'check',
        color: json['color'] as String? ?? '#6366F1',
        frequency: json['frequency'] as String? ?? 'daily',
        targetCount: json['targetCount'] as int? ?? 1,
        targetPeriod: json['targetPeriod'] as String? ?? 'day',
        customWeekdays: (json['customWeekdays'] as List?)?.map((e) => e as int).toList(),
        streak: json['streak'] as int? ?? 0,
        bestStreak: json['bestStreak'] as int? ?? 0,
        reminderTime: json['reminderTime'] as String?,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
        active: json['active'] as bool? ?? true,
      );
}

/// A completion record for a specific habit.
class HabitCompletion {
  final String id;
  final String habitId;
  final String date; // 'yyyy-MM-dd' for quick date grouping
  final bool completed;
  final DateTime timestamp;
  final String? notes;

  HabitCompletion({
    required this.id,
    required this.habitId,
    required this.date,
    this.completed = true,
    required this.timestamp,
    this.notes,
  });

  HabitCompletion copyWith({
    String? id,
    String? habitId,
    String? date,
    bool? completed,
    DateTime? timestamp,
    String? notes,
  }) =>
      HabitCompletion(
        id: id ?? this.id,
        habitId: habitId ?? this.habitId,
        date: date ?? this.date,
        completed: completed ?? this.completed,
        timestamp: timestamp ?? this.timestamp,
        notes: notes ?? this.notes,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'habitId': habitId,
        'date': date,
        'completed': completed,
        'timestamp': timestamp.toIso8601String(),
        'notes': notes,
      };

  factory HabitCompletion.fromJson(Map<String, dynamic> json) => HabitCompletion(
        id: json['id'] as String? ?? '',
        habitId: json['habitId'] as String? ?? '',
        date: json['date'] as String? ?? '',
        completed: json['completed'] as bool? ?? true,
        timestamp: json['timestamp'] != null
            ? DateTime.parse(json['timestamp'] as String)
            : DateTime.now(),
        notes: json['notes'] as String?,
      );
}
