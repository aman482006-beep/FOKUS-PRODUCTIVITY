import 'package:share_plus/share_plus.dart';

import 'fokus_history_service.dart';

/// Shares focus session updates and stats via the OS share sheet.
///
/// This is a purely static service. For DI-aware access, use [ShareServiceAdapter].
class ShareService {
  ShareService._();

  /// Share a completed focus session.
  static Future<void> shareSession({
    required String durationLabel,
    required int sessionNumber,
    int? streak,
  }) async {
    final streakPart =
        streak != null && streak > 0 ? ' 🔥 $streak-day streak' : '';
    final text =
        '🎯 I just completed a $durationLabel Fokus session on Fokus!'
        '$streakPart'
        '\n\n#Fokus #Pomodoro #Productivity';
    try {
      await SharePlus.instance.share(ShareParams(text: text));
    } catch (_) {
      // Sharing is non-critical — silently ignore errors.
    }
  }

  /// Share aggregate focus statistics.
  static Future<void> shareStats() async {
    try {
      final streak = FokusHistoryService.getDailyStreak();
      final dates = FokusHistoryService.getDailyCounts(days: 28);
      final totalSessions = dates.fold(0, (a, b) => a + b);
      final activeDays = dates.where((c) => c > 0).length;

      final streakPart =
          streak > 0 ? '🔥 $streak-day streak' : 'No active streak';
      final text =
          '📊 My Fokus stats:\n'
          '$streakPart\n'
          '🎯 $totalSessions total focus sessions\n'
          '📅 $activeDays active days in the last 28\n'
          '\nBuilt with #Fokus #Productivity';
      await SharePlus.instance.share(ShareParams(text: text));
    } catch (_) {
      // Sharing is non-critical — silently ignore errors.
    }
  }
}
