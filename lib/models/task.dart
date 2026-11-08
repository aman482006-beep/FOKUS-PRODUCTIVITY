/// A task entity with full focus-tracking metadata.
///
/// Tasks are first-class entities in Fokus — they link to focus
/// sessions, accumulate stats, and feed the analytics system.
class Task {
  final String id;
  final String title;
  final String? color;
  final bool done;
  final bool archived;
  final int totalFocusMinutes;
  final int completedSessions;
  final int interruptedSessions;
  final DateTime? lastActiveAt;
  final String? notes;
  final DateTime createdAt;
  final int todayFocusMinutes; // Cached today's focus minutes for quick display
  final String priority; // 'low' | 'medium' | 'high'
  final DateTime? dueDate;
  final DateTime? completedAt;
  final int estimatedMinutes;

  Task({
    required this.id,
    required this.title,
    this.color,
    this.done = false,
    this.archived = false,
    this.totalFocusMinutes = 0,
    this.completedSessions = 0,
    this.interruptedSessions = 0,
    this.lastActiveAt,
    this.notes,
    this.todayFocusMinutes = 0,
    DateTime? createdAt,
    this.priority = 'medium',
    this.dueDate,
    this.completedAt,
    this.estimatedMinutes = 0,
  }) : createdAt = createdAt ?? DateTime.now();

  /// The display color as a Color from the stored hex string.
  /// Falls back to the default indigo accent.
  int get colorValue {
    final hex = color ?? '#6366F1';
    return int.parse(hex.replaceFirst('#', '0xFF'));
  }

  String get formattedFocusTime {
    final hours = totalFocusMinutes ~/ 60;
    final mins = totalFocusMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${mins}m';
    }
    return '${mins}m';
  }

  String get formattedTodayTime {
    final hours = todayFocusMinutes ~/ 60;
    final mins = todayFocusMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${mins}m';
    }
    return '${mins}m';
  }

  /// Session completion rate 0.0 - 1.0
  double get completionRate {
    final total = completedSessions + interruptedSessions;
    if (total == 0) return 0;
    return completedSessions / total;
  }

  /// Focus progress for mini display (capped at 2 hours = 120 mins)
  double get fokusProgress => (totalFocusMinutes / 120.0).clamp(0.0, 1.0);

  Task copyWith({
    String? id,
    String? title,
    String? color,
    bool? done,
    bool? archived,
    int? totalFocusMinutes,
    int? completedSessions,
    int? interruptedSessions,
    DateTime? lastActiveAt,
    String? notes,
    int? todayFocusMinutes,
    DateTime? createdAt,
    String? priority,
    DateTime? dueDate,
    DateTime? completedAt,
    int? estimatedMinutes,
  }) =>
      Task(
        id: id ?? this.id,
        title: title ?? this.title,
        color: color ?? this.color,
        done: done ?? this.done,
        archived: archived ?? this.archived,
        totalFocusMinutes: totalFocusMinutes ?? this.totalFocusMinutes,
        completedSessions: completedSessions ?? this.completedSessions,
        interruptedSessions: interruptedSessions ?? this.interruptedSessions,
        lastActiveAt: lastActiveAt ?? this.lastActiveAt,
        notes: notes ?? this.notes,
        todayFocusMinutes: todayFocusMinutes ?? this.todayFocusMinutes,
        createdAt: createdAt ?? this.createdAt,
        priority: priority ?? this.priority,
        dueDate: dueDate ?? this.dueDate,
        completedAt: completedAt ?? this.completedAt,
        estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'color': color,
        'done': done,
        'archived': archived,
        'totalFocusMinutes': totalFocusMinutes,
        'completedSessions': completedSessions,
        'interruptedSessions': interruptedSessions,
        'lastActiveAt': lastActiveAt?.toIso8601String(),
        'notes': notes,
        'todayFocusMinutes': todayFocusMinutes,
        'createdAt': createdAt.toIso8601String(),
        'priority': priority,
        'dueDate': dueDate?.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'estimatedMinutes': estimatedMinutes,
      };

  factory Task.fromJson(Map<String, dynamic> json) => Task(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        color: json['color'] as String?,
        done: json['done'] as bool? ?? false,
        archived: json['archived'] as bool? ?? false,
        totalFocusMinutes: json['totalFocusMinutes'] as int? ?? 0,
        completedSessions: json['completedSessions'] as int? ?? 0,
        interruptedSessions: json['interruptedSessions'] as int? ?? 0,
        lastActiveAt: json['lastActiveAt'] != null
            ? DateTime.tryParse(json['lastActiveAt'] as String)
            : null,
        notes: json['notes'] as String?,
        todayFocusMinutes: json['todayFocusMinutes'] as int? ?? 0,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
        priority: json['priority'] as String? ?? 'medium',
        dueDate: json['dueDate'] != null
            ? DateTime.tryParse(json['dueDate'] as String)
            : null,
        completedAt: json['completedAt'] != null
            ? DateTime.tryParse(json['completedAt'] as String)
            : null,
        estimatedMinutes: json['estimatedMinutes'] as int? ?? 0,
      );
}
