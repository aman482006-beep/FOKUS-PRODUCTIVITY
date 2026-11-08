/// A timeline goal entity tracked in Fokus.
class TimelineGoal {
  final String id;
  final String title;
  final DateTime targetDate;
  final DateTime createdAt;
  final bool isCompleted;
  final String? notes;
  final String color; // Hex color string, e.g. '#6366F1'

  TimelineGoal({
    required this.id,
    required this.title,
    required this.targetDate,
    DateTime? createdAt,
    this.isCompleted = false,
    this.notes,
    this.color = '#6366F1',
  }) : createdAt = createdAt ?? DateTime.now();

  TimelineGoal copyWith({
    String? id,
    String? title,
    DateTime? targetDate,
    DateTime? createdAt,
    bool? isCompleted,
    String? notes,
    String? color,
  }) =>
      TimelineGoal(
        id: id ?? this.id,
        title: title ?? this.title,
        targetDate: targetDate ?? this.targetDate,
        createdAt: createdAt ?? this.createdAt,
        isCompleted: isCompleted ?? this.isCompleted,
        notes: notes ?? this.notes,
        color: color ?? this.color,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'targetDate': targetDate.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'isCompleted': isCompleted,
        'notes': notes,
        'color': color,
      };

  factory TimelineGoal.fromJson(Map<String, dynamic> json) => TimelineGoal(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        targetDate: json['targetDate'] != null
            ? DateTime.parse(json['targetDate'] as String)
            : DateTime.now(),
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
        isCompleted: json['isCompleted'] as bool? ?? false,
        notes: json['notes'] as String?,
        color: json['color'] as String? ?? '#6366F1',
      );
}
