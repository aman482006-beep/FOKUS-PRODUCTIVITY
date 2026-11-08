/// A reminder entity in Fokus.
class Reminder {
  final String id;
  final String title;
  final String description;
  final DateTime dateTime;
  final DateTime createdAt;
  final bool isTriggered;
  final bool alarmEnabled;
  final String? alarmSoundPath;

  Reminder({
    required this.id,
    required this.title,
    required this.description,
    required this.dateTime,
    DateTime? createdAt,
    this.isTriggered = false,
    this.alarmEnabled = true,
    this.alarmSoundPath,
  }) : createdAt = createdAt ?? DateTime.now();

  Reminder copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? dateTime,
    DateTime? createdAt,
    bool? isTriggered,
    bool? alarmEnabled,
    String? alarmSoundPath,
  }) =>
      Reminder(
        id: id ?? this.id,
        title: title ?? this.title,
        description: description ?? this.description,
        dateTime: dateTime ?? this.dateTime,
        createdAt: createdAt ?? this.createdAt,
        isTriggered: isTriggered ?? this.isTriggered,
        alarmEnabled: alarmEnabled ?? this.alarmEnabled,
        alarmSoundPath: alarmSoundPath ?? this.alarmSoundPath,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'dateTime': dateTime.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'isTriggered': isTriggered,
        'alarmEnabled': alarmEnabled,
        'alarmSoundPath': alarmSoundPath,
      };

  factory Reminder.fromJson(Map<String, dynamic> json) => Reminder(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        dateTime: json['dateTime'] != null
            ? DateTime.parse(json['dateTime'] as String)
            : DateTime.now(),
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
        isTriggered: json['isTriggered'] as bool? ?? false,
        alarmEnabled: json['alarmEnabled'] as bool? ?? true,
        alarmSoundPath: json['alarmSoundPath'] as String?,
      );
}

