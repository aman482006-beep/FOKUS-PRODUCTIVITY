import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/services.dart' show MethodChannel, MissingPluginException;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Shows system-level toast notifications when timer phases complete,
/// so alerts reach the user even when the app is minimized / behind other windows.
/// Also handles system-level notification suppression/DND controls.
class NotificationService {
  static FlutterLocalNotificationsPlugin? _plugin;
  static bool _initialized = false;

  static const _windowsAppName = 'Fokus';
  static const _windowsAppUserModelId = 'com.example.fokus';
  static const _windowsGuid = '0f8fad5b-d9cb-469f-a165-70867728950e';

  // State capture variables
  static dynamic _previousOSNotificationState;
  static bool _hasCapturedState = false;

  // Platform Channel (Windows native DND integration)
  static const _dndChannel = MethodChannel('com.example.fokus/dnd');

  /// Initialize the notification service
  static Future<void> init() async {
    if (_initialized) return;
    if (kIsWeb) {
      _initialized = true;
      return;
    }

    _plugin = FlutterLocalNotificationsPlugin();
    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings();
    const windowsSettings = WindowsInitializationSettings(
      appName: _windowsAppName,
      appUserModelId: _windowsAppUserModelId,
      guid: _windowsGuid,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
      windows: windowsSettings,
    );

    await _plugin!.initialize(settings: settings);
    _initialized = true;
  }

  /// Show a notification
  static Future<void> show({
    int id = 0,
    String title = 'Fokus',
    required String body,
  }) async {
    if (!_initialized) return;

    const androidDetails = AndroidNotificationDetails(
      'fokus_timer_channel',
      'Timer Alerts',
      importance: Importance.max,
      priority: Priority.high,
    );

    const darwinDetails = DarwinNotificationDetails();
    const windowsDetails = WindowsNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
      windows: windowsDetails,
    );

    try {
      await _plugin?.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
      );
    } catch (_) {
      // Notifications are non-critical
    }
  }

  /// Schedule a notification to trigger in the future
  static Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    if (!_initialized || kIsWeb) return;

    final androidDetails = AndroidNotificationDetails(
      'fokus_timer_channel',
      'Timer Alerts',
      importance: Importance.max,
      priority: Priority.high,
    );

    const darwinDetails = DarwinNotificationDetails();
    const windowsDetails = WindowsNotificationDetails();

    final details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
      windows: windowsDetails,
    );

    try {
      final scheduledTZDate = tz.TZDateTime.from(scheduledDate, tz.local);
      await _plugin?.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledTZDate,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      debugPrint('NotificationService: Scheduled notification $id for $scheduledDate');
    } catch (e) {
      debugPrint('NotificationService: Failed to schedule notification: $e');
    }
  }

  /// Cancel a scheduled notification
  static Future<void> cancel(int id) async {
    if (!_initialized || kIsWeb) return;
    try {
      await _plugin?.cancel(id: id);
      debugPrint('NotificationService: Cancelled notification $id');
    } catch (e) {
      debugPrint('NotificationService: Failed to cancel notification: $e');
    }
  }

  /// Capture the current OS notification/DND state
  static Future<void> capturePreviousSuppressionState() async {
    if (kIsWeb) return;
    try {
      if (Platform.isWindows) {
        final state = await getNotificationState();
        _previousOSNotificationState = state ?? 0;
        _hasCapturedState = true;
      } else if (Platform.isMacOS) {
        final result = await Process.run('defaults', [
          'read',
          'com.apple.controlcenter',
          'NSStatusItem Visible FocusModes',
        ]);
        final val = result.stdout.toString().trim();
        _previousOSNotificationState = (val == '1' || val.toLowerCase() == 'true');
        _hasCapturedState = true;
      } else if (Platform.isLinux) {
        final result = await Process.run('gsettings', [
          'get',
          'org.gnome.desktop.notifications',
          'show-banners',
        ]);
        final val = result.stdout.toString().trim();
        _previousOSNotificationState = (val.trim() == 'true');
        _hasCapturedState = true;
      }
    } catch (e) {
      debugPrint('NotificationService: Failed to capture OS state: $e');
    }
  }

  /// Enable OS-level notification suppression (DND)
  static Future<bool> enableOSNotificationSuppression() async {
    if (kIsWeb) return false;
    if (!_hasCapturedState) {
      await capturePreviousSuppressionState();
    }
    try {
      if (Platform.isWindows) {
        return await enableDoNotDisturb();
      } else if (Platform.isMacOS) {
        await Process.run('shortcuts', ['run', 'Turn Do Not Disturb On']);
        return true;
      } else if (Platform.isLinux) {
        final result = await Process.run('gsettings', [
          'set',
          'org.gnome.desktop.notifications',
          'show-banners',
          'false',
        ]);
        return result.exitCode == 0;
      }
    } catch (e) {
      debugPrint('NotificationService: Failed to enable DND: $e');
    }
    return false;
  }

  /// Disable OS-level notification suppression (restore previous state)
  static Future<bool> disableOSNotificationSuppression() async {
    if (kIsWeb) return false;
    final stateToRestore = _hasCapturedState ? _previousOSNotificationState : null;
    _hasCapturedState = false;
    try {
      if (Platform.isWindows) {
        return await disableDoNotDisturb(stateToRestore);
      } else if (Platform.isMacOS) {
        await Process.run('shortcuts', ['run', 'Turn Do Not Disturb Off']);
        return true;
      } else if (Platform.isLinux) {
        final bool showBanners = (stateToRestore is bool) ? stateToRestore : true;
        final result = await Process.run('gsettings', [
          'set',
          'org.gnome.desktop.notifications',
          'show-banners',
          showBanners ? 'true' : 'false',
        ]);
        return result.exitCode == 0;
      }
    } catch (e) {
      debugPrint('NotificationService: Failed to disable DND: $e');
    }
    return false;
  }

  /// Enable Windows Do Not Disturb
  static Future<bool> enableDoNotDisturb() async {
    if (kIsWeb) return false;
    try {
      final result = await _dndChannel.invokeMethod<bool>('enableDoNotDisturb');
      if (result != null) return result;
    } on MissingPluginException {
      // Fall through to PowerShell
    } catch (e) {
      debugPrint('DND channel error: $e');
    }
    try {
      if (Platform.isWindows) {
        final result = await Process.run('powershell', [
          '-NoProfile',
          '-Command',
          'Set-ItemProperty -Path "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Notifications\\Settings" -Name QuietHoursEnabled -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue',
        ]);
        return result.exitCode == 0;
      }
    } catch (e) {
      debugPrint('DND PowerShell error: $e');
    }
    return false;
  }

  /// Disable Windows Do Not Disturb
  static Future<bool> disableDoNotDisturb(dynamic stateToRestore) async {
    if (kIsWeb) return false;
    try {
      final result = await _dndChannel.invokeMethod<bool>('disableDoNotDisturb');
      if (result != null) return result;
    } on MissingPluginException {
      // Fall through to PowerShell
    } catch (e) {
      debugPrint('DND channel error: $e');
    }
    try {
      if (Platform.isWindows) {
        final int value = (stateToRestore is int) ? stateToRestore : 0;
        final result = await Process.run('powershell', [
          '-NoProfile',
          '-Command',
          'Set-ItemProperty -Path "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Notifications\\Settings" -Name QuietHoursEnabled -Value $value -Type DWord -Force -ErrorAction SilentlyContinue',
        ]);
        return result.exitCode == 0;
      }
    } catch (e) {
      debugPrint('DND PowerShell error: $e');
    }
    return false;
  }

  /// Get the current notification state
  static Future<int?> getNotificationState() async {
    if (kIsWeb) return null;
    try {
      final result = await _dndChannel.invokeMethod<int>('getNotificationState');
      if (result != null) return result;
    } on MissingPluginException {
      // Fall through to PowerShell
    } catch (e) {
      debugPrint('DND channel error: $e');
    }
    try {
      if (Platform.isWindows) {
        final result = await Process.run('powershell', [
          '-NoProfile',
          '-Command',
          '(Get-ItemProperty -Path "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Notifications\\Settings" -ErrorAction SilentlyContinue).QuietHoursEnabled',
        ]);
        final val = result.stdout.toString().trim();
        return int.tryParse(val);
      }
    } catch (e) {
      debugPrint('DND PowerShell error: $e');
    }
    return null;
  }

  /// Check if per-app notification exceptions are supported
  static bool isPerAppNotificationExceptionSupported() {
    return false;
  }
}
