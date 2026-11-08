import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../shared/theme.dart';
import 'notification_service.dart';

/// Handles focus lifecycle trigger — manages Windows Do Not Disturb.
class FokusModeService {
  /// Enables focus mode and shows a confirmation toast.
  static Future<void> enableFocusMode(BuildContext context, WidgetRef ref) async {
    if (context.mounted) {
      final theme = FocusOsTheme.of(context);
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.do_not_disturb_alt, color: theme.accent, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Fokus mode enabled.',
                  style: TextStyle(color: theme.textPrimary, fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: theme.surfaceAlt,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// Disables focus mode and shows a confirmation toast.
  static Future<void> disableFocusMode(BuildContext context, WidgetRef ref) async {
    if (context.mounted) {
      final theme = FocusOsTheme.of(context);
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.settings_backup_restore_rounded, color: theme.accent, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Fokus mode disabled.',
                  style: TextStyle(color: theme.textPrimary, fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: theme.surfaceAlt,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // Older methods preserved with deprecated annotations for backward compatibility
  @Deprecated('Use enableFokusMode instead')
  static Future<bool> enableDND() async {
    return NotificationService.enableOSNotificationSuppression();
  }

  @Deprecated('Use disableFokusMode instead')
  static Future<bool> disableDND() async {
    return NotificationService.disableOSNotificationSuppression();
  }
}
