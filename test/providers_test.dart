import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fokus/core/providers.dart';
import 'package:fokus/models/task.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ════════════════════════════════════════════════════════════════
  // TasksNotifier Tests
  // ════════════════════════════════════════════════════════════════

  group('TasksNotifier', () {
    test('starts with empty list', () {
      final container = ProviderContainer();
      final tasks = container.read(tasksProvider);
      expect(tasks, isEmpty);
    });

    test('addTask creates task with correct fields', () async {
      final container = ProviderContainer();
      await Future.delayed(Duration.zero);
      final notifier = container.read(tasksProvider.notifier);
      final task = notifier.addTask(
        'Write tests',
        color: '#FF0000',
        priority: 'high',
        estimatedMinutes: 60,
      );
      final tasks = container.read(tasksProvider);
      expect(tasks.length, 1);
      expect(tasks.first.title, 'Write tests');
      expect(tasks.first.color, '#FF0000');
      expect(tasks.first.priority, 'high');
      expect(tasks.first.estimatedMinutes, 60);
      expect(tasks.first.id, isNotEmpty);
    });

    test('addTask with minimal fields', () async {
      final container = ProviderContainer();
      await Future.delayed(Duration.zero);
      final notifier = container.read(tasksProvider.notifier);
      final task = notifier.addTask('Simple task');
      expect(task.title, 'Simple task');
      expect(task.priority, 'medium');
      expect(task.estimatedMinutes, 0);
    });

    test('toggleTask flips done state', () async {
      final container = ProviderContainer();
      await Future.delayed(Duration.zero);
      final notifier = container.read(tasksProvider.notifier);
      final task = notifier.addTask('Toggle me');
      expect(task.done, false);

      notifier.toggleTask(task.id);
      expect(container.read(tasksProvider).first.done, true);

      notifier.toggleTask(task.id);
      expect(container.read(tasksProvider).first.done, false);
    });

    test('removeTask deletes the task', () async {
      final container = ProviderContainer();
      await Future.delayed(Duration.zero);
      final notifier = container.read(tasksProvider.notifier);
      final task = notifier.addTask('Delete me');
      expect(container.read(tasksProvider).length, 1);

      notifier.removeTask(task.id);
      expect(container.read(tasksProvider), isEmpty);
    });

    test('updateTask changes title', () async {
      final container = ProviderContainer();
      await Future.delayed(Duration.zero);
      final notifier = container.read(tasksProvider.notifier);
      final task = notifier.addTask('Old title');

      notifier.updateTask(task.id, 'New title');
      expect(container.read(tasksProvider).first.title, 'New title');
    });

    test('updateTaskColor changes color', () async {
      final container = ProviderContainer();
      await Future.delayed(Duration.zero);
      final notifier = container.read(tasksProvider.notifier);
      final task = notifier.addTask('Color task');

      notifier.updateTaskColor(task.id, '#00FF00');
      expect(container.read(tasksProvider).first.color, '#00FF00');
    });

    test('attributeFokusTime increments fokus minutes and sessions', () async {
      final container = ProviderContainer();
      await Future.delayed(Duration.zero);
      final notifier = container.read(tasksProvider.notifier);
      final task = notifier.addTask('Fokus task');

      notifier.attributeFocusTime(task.id, 25);
      final updated = container.read(tasksProvider).first;
      expect(updated.totalFocusMinutes, 25);
      expect(updated.completedSessions, 1);
      expect(updated.lastActiveAt, isNotNull);

      notifier.attributeFocusTime(task.id, 30);
      final updated2 = container.read(tasksProvider).first;
      expect(updated2.totalFocusMinutes, 55);
      expect(updated2.completedSessions, 2);
    });

    test('attributeInterruption increments interrupted sessions', () async {
      final container = ProviderContainer();
      await Future.delayed(Duration.zero);
      final notifier = container.read(tasksProvider.notifier);
      final task = notifier.addTask('Interrupted task');

      notifier.attributeInterruption(task.id, 10);
      final updated = container.read(tasksProvider).first;
      expect(updated.interruptedSessions, 1);
      expect(updated.totalFocusMinutes, 10);
    });

    test('archiveTask sets archived flag', () async {
      final container = ProviderContainer();
      await Future.delayed(Duration.zero);
      final notifier = container.read(tasksProvider.notifier);
      final task = notifier.addTask('Archive me');

      notifier.archiveTask(task.id);
      expect(container.read(tasksProvider).first.archived, true);
    });

    test('duplicateTask creates a copy', () async {
      final container = ProviderContainer();
      await Future.delayed(Duration.zero);
      final notifier = container.read(tasksProvider.notifier);
      final task = notifier.addTask('Original', color: '#FF0000');

      notifier.duplicateTask(task.id);
      final tasks = container.read(tasksProvider);
      expect(tasks.length, 2);
      final dup = tasks.firstWhere((t) => t.title == 'Original (copy)');
      expect(dup.color, '#FF0000');
    });

    test('clearCompleted removes only done tasks', () async {
      final container = ProviderContainer();
      await Future.delayed(Duration.zero);
      final notifier = container.read(tasksProvider.notifier);
      final t1 = notifier.addTask('Done task');
      await Future.delayed(const Duration(milliseconds: 5));
      final t2 = notifier.addTask('Pending task');
      notifier.toggleTask(t1.id);

      notifier.clearCompleted();
      final tasks = container.read(tasksProvider);
      expect(tasks.length, 1);
      expect(tasks.first.id, t2.id);
    });
  });

  // ════════════════════════════════════════════════════════════════
  // TimerCustomizationNotifier Tests
  // ════════════════════════════════════════════════════════════════

  group('TimerCustomizationState', () {
    test('default values', () {
      const state = TimerCustomizationState();
      expect(state.fontStyle, 'minimal');
      expect(state.size, 'large');
      expect(state.colorTheme, 'auto');
      expect(state.backgroundMode, 'glassmorphism');
      expect(state.showSeconds, true);
      expect(state.showMilliseconds, false);
      expect(state.showProgressRing, true);
      expect(state.enableAnimations, true);
      expect(state.reducedMotion, false);
      expect(state.flipSpeed, 1.0);
      expect(state.isMuted, false);
      expect(state.autoSwitchStyle, false);
      expect(state.transitionEffect, 'fade');
    });

    test('copyWith preserves unmodified fields', () {
      const original = TimerCustomizationState(
        fontStyle: 'futuristic',
        size: 'xl',
        colorTheme: 'red',
        showSeconds: false,
      );
      final updated = original.copyWith(fontStyle: 'elegant');
      expect(updated.fontStyle, 'elegant');
      expect(updated.size, 'xl');
      expect(updated.colorTheme, 'red');
      expect(updated.showSeconds, false);
    });

    test('toJson/fromJson roundtrip', () {
      const state = TimerCustomizationState(
        fontStyle: 'elegant',
        size: 'medium',
        colorTheme: 'blue',
        showSeconds: false,
        flipSpeed: 1.5,
        isMuted: true,
        activePresetName: 'My Preset',
      );
      final json = state.toJson();
      final restored = TimerCustomizationState.fromJson(json);
      expect(restored.fontStyle, 'elegant');
      expect(restored.size, 'medium');
      expect(restored.colorTheme, 'blue');
      expect(restored.showSeconds, false);
      expect(restored.flipSpeed, 1.5);
      expect(restored.isMuted, true);
      expect(restored.activePresetName, 'My Preset');
    });

    test('fromJson handles missing fields', () {
      final state = TimerCustomizationState.fromJson({});
      expect(state.fontStyle, 'minimal');
      expect(state.size, 'large');
      expect(state.showSeconds, true);
      expect(state.flipSpeed, 1.0);
    });

    test('fromJson parses all boolean fields', () {
      final json = {
        'showSeconds': false,
        'showMilliseconds': true,
        'showSessionLabel': false,
        'showTaskName': false,
        'showProgressRing': false,
        'enableAnimations': false,
        'reducedMotion': true,
        'tickSoundEnabled': true,
        'flipSoundEnabled': true,
        'completeSoundEnabled': false,
        'isMuted': true,
        'autoSwitchStyle': true,
      };
      final state = TimerCustomizationState.fromJson(json);
      expect(state.showSeconds, false);
      expect(state.showMilliseconds, true);
      expect(state.showSessionLabel, false);
      expect(state.showTaskName, false);
      expect(state.showProgressRing, false);
      expect(state.enableAnimations, false);
      expect(state.reducedMotion, true);
      expect(state.tickSoundEnabled, true);
      expect(state.flipSoundEnabled, true);
      expect(state.completeSoundEnabled, false);
      expect(state.isMuted, true);
      expect(state.autoSwitchStyle, true);
    });
  });

  // ════════════════════════════════════════════════════════════════
  // UserProfile Tests
  // ════════════════════════════════════════════════════════════════

  group('UserProfile', () {
    test('defaults', () {
      const profile = UserProfile();
      expect(profile.name, 'User');
      expect(profile.email, 'user@fokus.app');
      expect(profile.avatarBase64, '');
      expect(profile.lifetimeFocusTasks, 0);
      expect(profile.status, 'Fokus operative');
    });

    test('copyWith', () {
      const profile = UserProfile(name: 'Alice', email: 'alice@test.com');
      final updated = profile.copyWith(name: 'Bob', lifetimeFocusTasks: 5);
      expect(updated.name, 'Bob');
      expect(updated.email, 'alice@test.com');
      expect(updated.lifetimeFocusTasks, 5);
    });

    test('toJson/fromJson roundtrip', () {
      const profile = UserProfile(
        name: 'Test User',
        email: 'test@example.com',
        avatarBase64: 'base64data',
        lifetimeFocusTasks: 42,
        status: 'Fokus master',
      );
      final json = profile.toJson();
      final restored = UserProfile.fromJson(json);
      expect(restored.name, 'Test User');
      expect(restored.email, 'test@example.com');
      expect(restored.avatarBase64, 'base64data');
      expect(restored.lifetimeFocusTasks, 42);
      expect(restored.status, 'Fokus master');
    });

    test('fromJson handles missing fields', () {
      final profile = UserProfile.fromJson({});
      expect(profile.name, 'User');
      expect(profile.email, 'user@fokus.app');
      expect(profile.lifetimeFocusTasks, 0);
    });
  });

  // ════════════════════════════════════════════════════════════════
  // UserProfileNotifier Tests
  // ════════════════════════════════════════════════════════════════

  group('UserProfileNotifier', () {
    test('updateName changes name', () async {
      final container = ProviderContainer();
      await Future.delayed(Duration.zero);
      container.read(userProfileProvider.notifier).updateName('Alice');
      expect(container.read(userProfileProvider).name, 'Alice');
    });

    test('updateEmail changes email', () async {
      final container = ProviderContainer();
      await Future.delayed(Duration.zero);
      container.read(userProfileProvider.notifier).updateEmail('new@test.com');
      expect(container.read(userProfileProvider).email, 'new@test.com');
    });

    test('incrementLifetimeTasks increments count', () async {
      final container = ProviderContainer();
      await Future.delayed(Duration.zero);
      container.read(userProfileProvider.notifier).incrementLifetimeTasks();
      container.read(userProfileProvider.notifier).incrementLifetimeTasks();
      container.read(userProfileProvider.notifier).incrementLifetimeTasks();
      expect(container.read(userProfileProvider).lifetimeFocusTasks, 3);
    });

    test('updateStatus changes status', () async {
      final container = ProviderContainer();
      await Future.delayed(Duration.zero);
      container.read(userProfileProvider.notifier).updateStatus('Fokus master');
      expect(container.read(userProfileProvider).status, 'Fokus master');
    });
  });

  // ════════════════════════════════════════════════════════════════
  // GoalsNotifier Tests
  // ════════════════════════════════════════════════════════════════

  group('GoalsNotifier', () {
    test('starts with default goals', () async {
      final container = ProviderContainer();
      await Future.delayed(Duration.zero);
      final goals = container.read(goalsProvider);
      expect(goals['dailyFocusMinutes'], 120.0);
      expect(goals['weeklyFocusMinutes'], 600.0);
      expect(goals['dailyTasksCount'], 3.0);
      expect(goals['dailyHabitCompletionPercent'], 80.0);
    });

    test('updateGoal changes a specific goal', () async {
      final container = ProviderContainer();
      await Future.delayed(Duration.zero);
      container.read(goalsProvider.notifier).updateGoal('dailyFocusMinutes', 180.0);
      expect(container.read(goalsProvider)['dailyFocusMinutes'], 180.0);
      expect(container.read(goalsProvider)['weeklyFocusMinutes'], 600.0);
    });

    test('reset restores defaults', () async {
      final container = ProviderContainer();
      await Future.delayed(Duration.zero);
      container.read(goalsProvider.notifier).updateGoal('dailyFocusMinutes', 999.0);
      container.read(goalsProvider.notifier).reset();
      expect(container.read(goalsProvider)['dailyFocusMinutes'], 120.0);
    });
  });

  // ════════════════════════════════════════════════════════════════
  // BlueLightState Tests
  // ════════════════════════════════════════════════════════════════

  group('BlueLightState', () {
    test('default values', () {
      const state = BlueLightState();
      expect(state.enabled, false);
      expect(state.temperature, 4500);
      expect(state.autoMode, false);
      expect(state.grayscale, false);
      expect(state.isLoading, true);
    });

    test('copyWith', () {
      const state = BlueLightState(temperature: 4500);
      final updated = state.copyWith(temperature: 3400, enabled: true);
      expect(updated.temperature, 3400);
      expect(updated.enabled, true);
    });

    test('toSettings and fromSettings roundtrip', () {
      const state = BlueLightState(
        enabled: true,
        temperature: 3400,
        autoMode: true,
        grayscale: true,
        scheduledStartHour: 22,
        scheduledEndHour: 6,
        sessionLinked: true,
      );
      final settings = state.toSettings();
      final restored = BlueLightState.fromSettings(settings);
      expect(restored.enabled, true);
      expect(restored.temperature, 3400);
      expect(restored.autoMode, true);
      expect(restored.grayscale, true);
      expect(restored.scheduledStartHour, 22);
      expect(restored.sessionLinked, true);
    });
  });

  // ════════════════════════════════════════════════════════════════
  // HardcoreLockState Tests
  // ════════════════════════════════════════════════════════════════

  group('HardcoreLockState', () {
    test('defaults', () {
      const state = HardcoreLockState();
      expect(state.enabled, false);
      expect(state.passwordHash, isNull);
      expect(state.locked, false);
      expect(state.penaltySeconds, 30);
    });

    test('copyWith', () {
      const state = HardcoreLockState();
      final updated = state.copyWith(enabled: true, penaltySeconds: 60);
      expect(updated.enabled, true);
      expect(updated.penaltySeconds, 60);
      expect(updated.locked, false);
    });
  });

  // ════════════════════════════════════════════════════════════════
  // EyeBreakState Tests
  // ════════════════════════════════════════════════════════════════

  group('EyeBreakState', () {
    test('defaults', () {
      const state = EyeBreakState();
      expect(state.twentyTwentyEnabled, false);
      expect(state.blinkReminders, false);
      expect(state.breakReminders, false);
      expect(state.postureReminders, false);
      expect(state.hydrationReminders, false);
    });

    test('copyWith', () {
      const state = EyeBreakState();
      final updated = state.copyWith(
        twentyTwentyEnabled: true,
        blinkReminders: true,
        hydrationReminders: true,
      );
      expect(updated.twentyTwentyEnabled, true);
      expect(updated.blinkReminders, true);
      expect(updated.breakReminders, false); // unchanged
      expect(updated.hydrationReminders, true);
    });
  });

  // ════════════════════════════════════════════════════════════════
  // WallpaperState Tests
  // ════════════════════════════════════════════════════════════════

  group('WallpaperState', () {
    test('defaults', () {
      const state = WallpaperState();
      expect(state.imagePath, isNull);
      expect(state.rememberForFuture, false);
    });

    test('copyWith', () {
      const state = WallpaperState();
      final updated = state.copyWith(imagePath: '/path/img.png', rememberForFuture: true);
      expect(updated.imagePath, '/path/img.png');
      expect(updated.rememberForFuture, true);
    });
  });

  // ════════════════════════════════════════════════════════════════
  // RecoverableSession Tests
  // ════════════════════════════════════════════════════════════════

  group('RecoverableSession', () {
    test('toJson/fromJson roundtrip', () {
      final session = RecoverableSession(
        sessionId: 'session_123',
        elapsedSeconds: 300,
        totalSeconds: 1500,
        taskId: 'task-1',
        taskName: 'Write tests',
        taskColor: const Color(0xFF6366F1),
        timestamp: DateTime(2026, 5, 21, 10, 30),
      );
      final json = session.toJson();
      final restored = RecoverableSession.fromJson(json);
      expect(restored.sessionId, 'session_123');
      expect(restored.elapsedSeconds, 300);
      expect(restored.totalSeconds, 1500);
      expect(restored.taskId, 'task-1');
      expect(restored.taskName, 'Write tests');
      expect(restored.taskColor, const Color(0xFF6366F1));
    });

    test('fromJson handles missing fields', () {
      final session = RecoverableSession.fromJson({});
      expect(session.sessionId, '');
      expect(session.elapsedSeconds, 0);
      expect(session.totalSeconds, 1500);
      expect(session.taskId, isNull);
      expect(session.taskColor, isNull);
    });
  });
}
