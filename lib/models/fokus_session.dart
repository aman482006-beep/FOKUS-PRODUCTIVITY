/// A single completed or interrupted focus session.
class FokusSession {
  final String date; // ISO date string e.g. "2026-05-21"
  final int durationMinutes;
  final String timestamp; // ISO 8601 timestamp e.g. "2026-05-21T10:30:00.000"
  final String? taskId; // Linked task, if any
  final bool isInterrupted;
  final String sessionType; // 'Pomodoro' | 'Deep Work' | 'Custom Timer' | 'Flow'
  final int? plannedDurationMinutes;
  final int? actualDurationSeconds;
  final String? startTime;
  final String? endTime;
  final bool isBreak;

  const FokusSession({
    required this.date,
    required this.durationMinutes,
    required this.timestamp,
    this.taskId,
    this.isInterrupted = false,
    this.sessionType = 'Pomodoro',
    this.plannedDurationMinutes,
    this.actualDurationSeconds,
    this.startTime,
    this.endTime,
    this.isBreak = false,
  });

  Map<String, dynamic> toJson() => {
        'date': date,
        'durationMinutes': durationMinutes,
        'timestamp': timestamp,
        'taskId': taskId,
        'isInterrupted': isInterrupted,
        'sessionType': sessionType,
        'plannedDurationMinutes': plannedDurationMinutes,
        'actualDurationSeconds': actualDurationSeconds,
        'startTime': startTime,
        'endTime': endTime,
        'isBreak': isBreak,
      };

  factory FokusSession.fromJson(Map<String, dynamic> json) => FokusSession(
        date: json['date'] as String? ?? '',
        durationMinutes: json['durationMinutes'] as int? ?? 25,
        timestamp: json['timestamp'] as String? ?? '',
        taskId: json['taskId'] as String?,
        isInterrupted: json['isInterrupted'] as bool? ?? false,
        sessionType: json['sessionType'] as String? ?? 'Pomodoro',
        plannedDurationMinutes: json['plannedDurationMinutes'] as int?,
        actualDurationSeconds: json['actualDurationSeconds'] as int?,
        startTime: json['startTime'] as String?,
        endTime: json['endTime'] as String?,
        isBreak: json['isBreak'] as bool? ?? false,
      );
}
