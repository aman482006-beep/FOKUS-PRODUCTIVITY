import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fokus/models/task.dart';
import 'package:fokus/models/fokus_session.dart';
import 'package:fokus/services/storage_service.dart';
import 'package:fokus/services/fokus_history_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    StorageService.prefs = await SharedPreferences.getInstance();
  });

  group('Task Fokus Estimation', () {
    test('Task model has estimatedMinutes field and supports JSON serialization', () {
      final task = Task(
        id: 'test-task-1',
        title: 'Learn Flutter Widget Testing',
        estimatedMinutes: 90,
        totalFocusMinutes: 45,
      );

      expect(task.estimatedMinutes, 90);
      expect(task.totalFocusMinutes, 45);

      final json = task.toJson();
      expect(json['estimatedMinutes'], 90);

      final decoded = Task.fromJson(json);
      expect(decoded.id, 'test-task-1');
      expect(decoded.estimatedMinutes, 90);
    });

    test('Task supports copyWith with estimatedMinutes', () {
      final task = Task(
        id: 'test-task-2',
        title: 'Write Docs',
        estimatedMinutes: 60,
      );

      final updated = task.copyWith(estimatedMinutes: 120);
      expect(updated.estimatedMinutes, 120);
      expect(updated.title, 'Write Docs');
    });
  });

  group('FokusSession Detailed Tracking', () {
    test('FokusSession supports detailed tracking fields and JSON serialization', () {
      final session = FokusSession(
        date: '2026-05-26',
        durationMinutes: 25,
        timestamp: '2026-05-26T10:00:00.000',
        taskId: 'test-task-1',
        isInterrupted: false,
        sessionType: 'Deep Work',
        plannedDurationMinutes: 25,
        actualDurationSeconds: 1500,
        startTime: '2026-05-26T10:00:00.000',
        endTime: '2026-05-26T10:25:00.000',
        isBreak: false,
      );

      expect(session.plannedDurationMinutes, 25);
      expect(session.actualDurationSeconds, 1500);
      expect(session.startTime, '2026-05-26T10:00:00.000');
      expect(session.endTime, '2026-05-26T10:25:00.000');
      expect(session.isBreak, false);

      final json = session.toJson();
      expect(json['plannedDurationMinutes'], 25);
      expect(json['actualDurationSeconds'], 1500);
      expect(json['startTime'], '2026-05-26T10:00:00.000');
      expect(json['endTime'], '2026-05-26T10:25:00.000');
      expect(json['isBreak'], false);

      final decoded = FokusSession.fromJson(json);
      expect(decoded.taskId, 'test-task-1');
      expect(decoded.plannedDurationMinutes, 25);
      expect(decoded.actualDurationSeconds, 1500);
      expect(decoded.startTime, '2026-05-26T10:00:00.000');
      expect(decoded.endTime, '2026-05-26T10:25:00.000');
      expect(decoded.isBreak, false);
    });
  });

  group('FokusHistoryService logging', () {
    test('logDetailedSession logs fokus session with detailed tracking data', () async {
      await FokusHistoryService.logDetailedSession(
        25,
        taskId: 'test-task-1',
        isInterrupted: false,
        sessionType: 'Pomodoro',
        plannedDurationMinutes: 25,
        actualDurationSeconds: 1500,
        startTime: '2026-05-26T10:00:00.000',
        endTime: '2026-05-26T10:25:00.000',
        isBreak: false,
      );

      final sessions = FokusHistoryService.loadSessions();
      expect(sessions.length, 1);
      final logged = sessions.first;
      expect(logged.durationMinutes, 25);
      expect(logged.taskId, 'test-task-1');
      expect(logged.sessionType, 'Pomodoro');
      expect(logged.plannedDurationMinutes, 25);
      expect(logged.actualDurationSeconds, 1500);
      expect(logged.isBreak, false);
    });
  });
}
