import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fokus/models/task.dart';
import 'package:fokus/models/fokus_session.dart';
import 'package:fokus/models/habit.dart';
import 'package:fokus/models/portfolio_asset.dart';
import 'package:fokus/models/quick_capture_item.dart';
import 'package:fokus/models/timeline_goal.dart';
import 'package:fokus/models/reminder.dart';

// ════════════════════════════════════════════════════════════════
// Task Model Tests
// ════════════════════════════════════════════════════════════════

void main() {
  group('Task', () {
    test('defaults are correct', () {
      final task = Task(id: '1', title: 'Test');
      expect(task.id, '1');
      expect(task.title, 'Test');
      expect(task.done, false);
      expect(task.archived, false);
      expect(task.totalFocusMinutes, 0);
      expect(task.completedSessions, 0);
      expect(task.interruptedSessions, 0);
      expect(task.priority, 'medium');
      expect(task.estimatedMinutes, 0);
      expect(task.color, isNull);
      expect(task.notes, isNull);
      expect(task.dueDate, isNull);
      expect(task.completedAt, isNull);
      expect(task.lastActiveAt, isNull);
      expect(task.createdAt, isA<DateTime>());
    });

    test('colorValue returns parsed hex', () {
      final task = Task(id: '1', title: 'T', color: '#FF5722');
      expect(task.colorValue, 0xFFFF5722);
    });

    test('colorValue falls back to default indigo', () {
      final task = Task(id: '1', title: 'T');
      expect(task.colorValue, 0xFF6366F1);
    });

    test('formattedFokusTime hours and minutes', () {
      final task = Task(id: '1', title: 'T', totalFocusMinutes: 90);
      expect(task.formattedFocusTime, '1h 30m');
    });

    test('formattedFokusTime minutes only', () {
      final task = Task(id: '1', title: 'T', totalFocusMinutes: 45);
      expect(task.formattedFocusTime, '45m');
    });

    test('formattedFokusTime zero minutes', () {
      final task = Task(id: '1', title: 'T', totalFocusMinutes: 0);
      expect(task.formattedFocusTime, '0m');
    });

    test('formattedTodayTime works', () {
      final task = Task(id: '1', title: 'T', todayFocusMinutes: 125);
      expect(task.formattedTodayTime, '2h 5m');
    });

    test('completionRate with no sessions', () {
      final task = Task(id: '1', title: 'T');
      expect(task.completionRate, 0.0);
    });

    test('completionRate with sessions', () {
      final task = Task(
        id: '1',
        title: 'T',
        completedSessions: 8,
        interruptedSessions: 2,
      );
      expect(task.completionRate, 0.8);
    });

    test('completionRate all completed', () {
      final task = Task(
        id: '1',
        title: 'T',
        completedSessions: 5,
        interruptedSessions: 0,
      );
      expect(task.completionRate, 1.0);
    });

    test('fokusProgress clamps at 1.0', () {
      final task = Task(id: '1', title: 'T', totalFocusMinutes: 200);
      expect(task.fokusProgress, 1.0);
    });

    test('fokusProgress calculates correctly', () {
      final task = Task(id: '1', title: 'T', totalFocusMinutes: 60);
      expect(task.fokusProgress, 0.5);
    });

    test('copyWith preserves unmodified fields', () {
      final task = Task(
        id: '1',
        title: 'Original',
        color: '#FF0000',
        done: true,
        totalFocusMinutes: 30,
        priority: 'high',
      );
      final updated = task.copyWith(title: 'Updated');
      expect(updated.title, 'Updated');
      expect(updated.id, '1');
      expect(updated.color, '#FF0000');
      expect(updated.done, true);
      expect(updated.totalFocusMinutes, 30);
      expect(updated.priority, 'high');
    });

    test('toJson/fromJson roundtrip', () {
      final now = DateTime.now();
      final task = Task(
        id: '42',
        title: 'Write tests',
        color: '#ABCDEF',
        done: true,
        archived: false,
        totalFocusMinutes: 120,
        completedSessions: 4,
        interruptedSessions: 1,
        lastActiveAt: now,
        notes: 'Important notes',
        todayFocusMinutes: 30,
        createdAt: now,
        priority: 'high',
        dueDate: now.add(const Duration(days: 7)),
        completedAt: now,
        estimatedMinutes: 60,
      );
      final json = task.toJson();
      final restored = Task.fromJson(json);
      expect(restored.id, task.id);
      expect(restored.title, task.title);
      expect(restored.color, task.color);
      expect(restored.done, task.done);
      expect(restored.totalFocusMinutes, task.totalFocusMinutes);
      expect(restored.completedSessions, task.completedSessions);
      expect(restored.interruptedSessions, task.interruptedSessions);
      expect(restored.notes, task.notes);
      expect(restored.todayFocusMinutes, task.todayFocusMinutes);
      expect(restored.priority, task.priority);
      expect(restored.estimatedMinutes, task.estimatedMinutes);
    });

    test('fromJson handles missing/null fields gracefully', () {
      final json = <String, dynamic>{'id': '1'};
      final task = Task.fromJson(json);
      expect(task.id, '1');
      expect(task.title, '');
      expect(task.done, false);
      expect(task.priority, 'medium');
      expect(task.totalFocusMinutes, 0);
    });

    test('toJson contains all expected keys', () {
      final task = Task(id: '1', title: 'T');
      final json = task.toJson();
      expect(json.keys, containsAll([
        'id', 'title', 'color', 'done', 'archived',
        'totalFocusMinutes', 'completedSessions', 'interruptedSessions',
        'lastActiveAt', 'notes', 'todayFocusMinutes', 'createdAt',
        'priority', 'dueDate', 'completedAt', 'estimatedMinutes',
      ]));
    });
  });

  // ════════════════════════════════════════════════════════════════
  // FokusSession Model Tests
  // ════════════════════════════════════════════════════════════════

  group('FokusSession', () {
    test('defaults', () {
      const session = FokusSession(date: '2026-01-01', durationMinutes: 25, timestamp: '2026-01-01T10:00:00');
      expect(session.date, '2026-01-01');
      expect(session.durationMinutes, 25);
      expect(session.taskId, isNull);
      expect(session.isInterrupted, false);
      expect(session.sessionType, 'Pomodoro');
      expect(session.isBreak, false);
    });

    test('toJson/fromJson roundtrip', () {
      final session = FokusSession(
        date: '2026-05-21',
        durationMinutes: 50,
        timestamp: '2026-05-21T14:30:00.000',
        taskId: 'task-123',
        isInterrupted: true,
        sessionType: 'Deep Work',
        plannedDurationMinutes: 60,
        actualDurationSeconds: 3000,
        startTime: '2026-05-21T14:00:00',
        endTime: '2026-05-21T14:50:00',
        isBreak: false,
      );
      final json = session.toJson();
      final restored = FokusSession.fromJson(json);
      expect(restored.date, session.date);
      expect(restored.durationMinutes, session.durationMinutes);
      expect(restored.taskId, session.taskId);
      expect(restored.isInterrupted, session.isInterrupted);
      expect(restored.sessionType, session.sessionType);
      expect(restored.plannedDurationMinutes, session.plannedDurationMinutes);
      expect(restored.actualDurationSeconds, session.actualDurationSeconds);
      expect(restored.startTime, session.startTime);
      expect(restored.endTime, session.endTime);
      expect(restored.isBreak, session.isBreak);
    });

    test('fromJson handles missing fields', () {
      final session = FokusSession.fromJson({});
      expect(session.date, '');
      expect(session.durationMinutes, 25);
      expect(session.isBreak, false);
      expect(session.isInterrupted, false);
    });

    test('toJson serialized to JSON string and back', () {
      const session = FokusSession(date: '2026-01-01', durationMinutes: 30, timestamp: '2026-01-01T12:00:00');
      final jsonString = jsonEncode(session.toJson());
      final restored = FokusSession.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
      expect(restored.date, session.date);
      expect(restored.durationMinutes, session.durationMinutes);
    });
  });

  // ════════════════════════════════════════════════════════════════
  // Habit Model Tests
  // ════════════════════════════════════════════════════════════════

  group('Habit', () {
    test('defaults', () {
      final habit = Habit(id: '1', name: 'Meditate', icon: '🧘');
      expect(habit.id, '1');
      expect(habit.name, 'Meditate');
      expect(habit.frequency, 'daily');
      expect(habit.targetCount, 1);
      expect(habit.targetPeriod, 'day');
      expect(habit.streak, 0);
      expect(habit.bestStreak, 0);
      expect(habit.active, true);
    });

    test('isDueOn daily', () {
      final habit = Habit(id: '1', name: 'Read', icon: '📖', frequency: 'daily');
      expect(habit.isDueOn(DateTime(2026, 1, 1)), true); // Friday
      expect(habit.isDueOn(DateTime(2026, 1, 3)), true); // Sunday
    });

    test('isDueOn weekdays', () {
      final habit = Habit(id: '1', name: 'Workout', icon: '💪', frequency: 'weekdays');
      expect(habit.isDueOn(DateTime(2026, 1, 5)), true);  // Monday
      expect(habit.isDueOn(DateTime(2026, 1, 9)), true);  // Friday
      expect(habit.isDueOn(DateTime(2026, 1, 10)), false); // Saturday
      expect(habit.isDueOn(DateTime(2026, 1, 11)), false); // Sunday
    });

    test('isDueOn weekends', () {
      final habit = Habit(id: '1', name: 'Relax', icon: '🏖', frequency: 'weekends');
      expect(habit.isDueOn(DateTime(2026, 1, 10)), true); // Saturday
      expect(habit.isDueOn(DateTime(2026, 1, 11)), true); // Sunday
      expect(habit.isDueOn(DateTime(2026, 1, 5)), false);  // Monday
    });

    test('isDueOn custom weekdays', () {
      final habit = Habit(
        id: '1',
        name: 'Gym',
        icon: '🏋',
        frequency: 'custom',
        customWeekdays: [1, 3, 5], // Mon, Wed, Fri
      );
      expect(habit.isDueOn(DateTime(2026, 1, 5)), true);  // Monday
      expect(habit.isDueOn(DateTime(2026, 1, 7)), true);  // Wednesday
      expect(habit.isDueOn(DateTime(2026, 1, 9)), true);  // Friday
      expect(habit.isDueOn(DateTime(2026, 1, 6)), false); // Tuesday
      expect(habit.isDueOn(DateTime(2026, 1, 8)), false); // Thursday
    });

    test('isDueOn inactive habit returns false', () {
      final habit = Habit(id: '1', name: 'Read', icon: '📖', frequency: 'daily', active: false);
      expect(habit.isDueOn(DateTime.now()), false);
    });

    test('isDueOn weekly/monthly always true', () {
      final weekly = Habit(id: '1', name: 'W', icon: '📝', frequency: 'weekly');
      final monthly = Habit(id: '2', name: 'M', icon: '📋', frequency: 'monthly');
      expect(weekly.isDueOn(DateTime.now()), true);
      expect(monthly.isDueOn(DateTime.now()), true);
    });

    test('toJson/fromJson roundtrip', () {
      final habit = Habit(
        id: 'h1',
        name: 'Meditate',
        icon: '🧘',
        color: '#FF0000',
        frequency: 'custom',
        targetCount: 3,
        targetPeriod: 'week',
        customWeekdays: [1, 3, 5],
        streak: 7,
        bestStreak: 14,
        reminderTime: '08:00',
        active: true,
      );
      final json = habit.toJson();
      final restored = Habit.fromJson(json);
      expect(restored.id, habit.id);
      expect(restored.name, habit.name);
      expect(restored.frequency, habit.frequency);
      expect(restored.targetCount, habit.targetCount);
      expect(restored.customWeekdays, habit.customWeekdays);
      expect(restored.streak, habit.streak);
      expect(restored.bestStreak, habit.bestStreak);
      expect(restored.reminderTime, habit.reminderTime);
    });

    test('copyWith', () {
      final habit = Habit(id: '1', name: 'Old', icon: '📖');
      final updated = habit.copyWith(name: 'New', streak: 5);
      expect(updated.name, 'New');
      expect(updated.streak, 5);
      expect(updated.id, '1');
    });
  });

  group('HabitCompletion', () {
    test('toJson/fromJson roundtrip', () {
      final now = DateTime.now();
      final comp = HabitCompletion(
        id: 'c1',
        habitId: 'h1',
        date: '2026-05-21',
        completed: true,
        timestamp: now,
        notes: 'Felt great',
      );
      final json = comp.toJson();
      final restored = HabitCompletion.fromJson(json);
      expect(restored.id, 'c1');
      expect(restored.habitId, 'h1');
      expect(restored.date, '2026-05-21');
      expect(restored.completed, true);
      expect(restored.notes, 'Felt great');
    });

    test('copyWith', () {
      final comp = HabitCompletion(
        id: 'c1',
        habitId: 'h1',
        date: '2026-01-01',
        timestamp: DateTime.now(),
      );
      final updated = comp.copyWith(notes: 'Updated notes');
      expect(updated.notes, 'Updated notes');
      expect(updated.id, 'c1');
    });
  });

  // ════════════════════════════════════════════════════════════════
  // PortfolioAsset Model Tests
  // ════════════════════════════════════════════════════════════════

  group('PortfolioAsset', () {
    test('active position computations', () {
      final asset = PortfolioAsset(
        id: '1',
        name: 'AAPL',
        category: 'Equity (Stocks)',
        buyPrice: 150,
        quantity: 10,
        currentPrice: 180,
        purchaseDate: DateTime(2025, 1, 1),
      );
      expect(asset.invested, 1500);
      expect(asset.currentValue, 1800);
      expect(asset.profitLoss, 300);
      expect(asset.unrealised, 300);
      expect(asset.realised, 0.0);
      expect(asset.profitLossPercent, closeTo(20.0, 0.01));
    });

    test('sold position computations', () {
      final asset = PortfolioAsset(
        id: '1',
        name: 'TSLA',
        category: 'Equity (Stocks)',
        buyPrice: 200,
        quantity: 5,
        currentPrice: 180,
        purchaseDate: DateTime(2025, 1, 1),
        isSold: true,
        sellPrice: 250,
        sellDate: DateTime(2025, 6, 1),
      );
      expect(asset.invested, 0.0);
      expect(asset.currentValue, 0.0);
      expect(asset.profitLoss, 250); // (250 - 200) * 5
      expect(asset.realised, 250);
      expect(asset.unrealised, 0.0);
    });

    test('loss scenario', () {
      final asset = PortfolioAsset(
        id: '1',
        name: 'XYZ',
        category: 'Equity (Stocks)',
        buyPrice: 100,
        quantity: 20,
        currentPrice: 80,
        purchaseDate: DateTime(2025, 1, 1),
      );
      expect(asset.profitLoss, -400);
      expect(asset.profitLossPercent, closeTo(-20.0, 0.01));
    });

    test('profitLossPercent zero invested returns 0', () {
      final asset = PortfolioAsset(
        id: '1',
        name: 'ZERO',
        category: 'Cash',
        buyPrice: 0,
        quantity: 10,
        currentPrice: 100,
        purchaseDate: DateTime(2025, 1, 1),
      );
      expect(asset.profitLossPercent, 0.0);
    });

    test('toJson/fromJson roundtrip', () {
      final date = DateTime(2025, 3, 15);
      final sellDate = DateTime(2025, 6, 20);
      final asset = PortfolioAsset(
        id: 'a1',
        name: 'Reliance',
        category: 'Equity (Stocks)',
        buyPrice: 2500,
        quantity: 4,
        currentPrice: 2700,
        purchaseDate: date,
        isSold: false,
        sellPrice: 3000,
        sellDate: sellDate,
        notes: 'Long term',
      );
      final json = asset.toJson();
      final restored = PortfolioAsset.fromJson(json);
      expect(restored.id, 'a1');
      expect(restored.name, 'Reliance');
      expect(restored.buyPrice, 2500);
      expect(restored.quantity, 4);
      expect(restored.currentPrice, 2700);
      expect(restored.sellPrice, 3000);
      expect(restored.notes, 'Long term');
    });
  });

  // ════════════════════════════════════════════════════════════════
  // QuickCaptureItem Tests
  // ════════════════════════════════════════════════════════════════

  group('QuickCaptureItem', () {
    test('hasImages and hasLinks', () {
      final item = QuickCaptureItem(
        id: '1',
        text: 'Note',
        timestamp: DateTime.now(),
      );
      expect(item.hasImages, false);
      // Since timestamp is required and const can't be null, test differently
      final item2 = QuickCaptureItem(
        id: '1',
        text: 'Note',
        timestamp: DateTime.now(),
        mediaPaths: ['/path/to/img.png'],
        linkUrls: ['https://example.com'],
      );
      expect(item2.hasImages, true);
      expect(item2.hasLinks, true);
    });

    test('no images or links by default', () {
      final item = QuickCaptureItem(
        id: '1',
        text: 'Plain text',
        timestamp: DateTime.now(),
      );
      expect(item.hasImages, false);
      expect(item.hasLinks, false);
      expect(item.linkUrls, isEmpty);
      expect(item.mediaPaths, isEmpty);
      expect(item.isActioned, false);
    });

    test('toJson/fromJson roundtrip', () {
      final item = QuickCaptureItem(
        id: 'qc1',
        text: 'Remember this',
        timestamp: DateTime(2026, 5, 21, 10, 30),
        linkUrls: ['https://example.com', 'https://google.com'],
        mediaPaths: ['/path/img1.png'],
        isActioned: true,
      );
      final json = item.toJson();
      final restored = QuickCaptureItem.fromJson(json);
      expect(restored.id, 'qc1');
      expect(restored.text, 'Remember this');
      expect(restored.linkUrls, ['https://example.com', 'https://google.com']);
      expect(restored.mediaPaths, ['/path/img1.png']);
      expect(restored.isActioned, true);
    });

    test('fromJson with old single linkUrl format', () {
      final json = {
        'id': '1',
        'text': 'Check this https://old.example.com',
        'timestamp': '2026-01-01T00:00:00',
        'linkUrl': 'https://old.example.com',
      };
      final item = QuickCaptureItem.fromJson(json);
      expect(item.linkUrls, contains('https://old.example.com'));
    });

    test('fromJson auto-detects URLs in text', () {
      final json = {
        'id': '1',
        'text': 'Visit https://auto-detected.com now',
        'timestamp': '2026-01-01T00:00:00',
      };
      final item = QuickCaptureItem.fromJson(json);
      expect(item.linkUrls, contains('https://auto-detected.com'));
    });

    test('copyWith', () {
      final item = QuickCaptureItem(
        id: '1',
        text: 'Original',
        timestamp: DateTime.now(),
      );
      final updated = item.copyWith(text: 'Updated', isActioned: true);
      expect(updated.text, 'Updated');
      expect(updated.isActioned, true);
      expect(updated.id, '1');
    });
  });

  group('extractUrls', () {
    test('extracts multiple URLs', () {
      final urls = extractUrls('Go to https://a.com and http://b.org/path?q=1');
      expect(urls.length, 2);
      expect(urls, contains('https://a.com'));
      expect(urls, contains('http://b.org/path?q=1'));
    });

    test('empty for no URLs', () {
      final urls = extractUrls('No links here');
      expect(urls, isEmpty);
    });
  });

  // ════════════════════════════════════════════════════════════════
  // TimelineGoal Tests
  // ════════════════════════════════════════════════════════════════

  group('TimelineGoal', () {
    test('defaults', () {
      final goal = TimelineGoal(id: 'g1', title: 'Exam', targetDate: DateTime(2026, 8, 1));
      expect(goal.isCompleted, false);
      expect(goal.notes, isNull);
      expect(goal.color, '#6366F1');
      expect(goal.createdAt, isA<DateTime>());
    });

    test('toJson/fromJson roundtrip', () {
      final goal = TimelineGoal(
        id: 'g1',
        title: 'Final Exam',
        targetDate: DateTime(2026, 8, 1),
        isCompleted: true,
        notes: 'Study hard',
        color: '#3B82F6',
      );
      final json = goal.toJson();
      final restored = TimelineGoal.fromJson(json);
      expect(restored.id, 'g1');
      expect(restored.title, 'Final Exam');
      expect(restored.isCompleted, true);
      expect(restored.notes, 'Study hard');
      expect(restored.color, '#3B82F6');
    });

    test('copyWith toggles isCompleted', () {
      final goal = TimelineGoal(id: '1', title: 'T', targetDate: DateTime.now());
      final toggled = goal.copyWith(isCompleted: true);
      expect(toggled.isCompleted, true);
      expect(goal.isCompleted, false); // original unchanged
    });
  });

  // ════════════════════════════════════════════════════════════════
  // Reminder Tests
  // ════════════════════════════════════════════════════════════════

  group('Reminder', () {
    test('defaults', () {
      final r = Reminder(id: 'r1', title: 'Call', description: 'Doctor', dateTime: DateTime(2026, 6, 1, 14));
      expect(r.isTriggered, false);
      expect(r.alarmEnabled, true);
      expect(r.alarmSoundPath, isNull);
    });

    test('toJson/fromJson roundtrip', () {
      final r = Reminder(
        id: 'r1',
        title: 'Meeting',
        description: 'Team standup',
        dateTime: DateTime(2026, 6, 1, 9, 0),
        isTriggered: true,
        alarmEnabled: false,
        alarmSoundPath: '/sounds/alert.wav',
      );
      final json = r.toJson();
      final restored = Reminder.fromJson(json);
      expect(restored.id, 'r1');
      expect(restored.title, 'Meeting');
      expect(restored.description, 'Team standup');
      expect(restored.isTriggered, true);
      expect(restored.alarmEnabled, false);
      expect(restored.alarmSoundPath, '/sounds/alert.wav');
    });

    test('copyWith', () {
      final r = Reminder(id: '1', title: 'Old', description: '', dateTime: DateTime.now());
      final updated = r.copyWith(title: 'New', isTriggered: true);
      expect(updated.title, 'New');
      expect(updated.isTriggered, true);
      expect(updated.id, '1');
    });
  });
}
