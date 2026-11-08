import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ──────────────────────────────────────────────
// Centralized Keyboard Shortcut Definitions
// ──────────────────────────────────────────────

/// All global actions that can be triggered via keyboard shortcuts.
enum FocusOsAction {
  startPauseTimer,
  resetTimer,
  quickCapture,
  brainDump,
  openSettings,
  toggleSidebar,
  toggleDnd,
  toggleFullscreen,
  closeOverlay,
  toggleShortcutsCheatSheet,
  navigateFocus,
  navigateTasks,
  navigateAnalytics,
  navigateHealth,
  navigateTools,
  cycleTimerStyle,
  toggleMiniTimer,
  toggleCalculator,
  navigateUp,
  navigateDown,
}

/// A single keyboard shortcut binding.
class FocusOsShortcut {
  final FocusOsAction action;
  final LogicalKeyboardKey key;
  final bool requireCtrl;
  final bool requireShift;

  const FocusOsShortcut({
    required this.action,
    required this.key,
    this.requireCtrl = false,
    this.requireShift = false,
  });

  /// Whether this shortcut uses any modifier key.
  bool get usesModifier => requireCtrl || requireShift;

  /// Check if this shortcut matches the given event and modifier state.
  bool matches(KeyEvent event, bool ctrlPressed, bool shiftPressed) {
    if (event.logicalKey != key) return false;
    if (requireCtrl != ctrlPressed) return false;
    if (requireShift != shiftPressed) return false;
    return true;
  }

  /// Platform-aware modifier label for display.
  static String get modifierLabel {
    try {
      if (Platform.isMacOS) return '⌘';
    } catch (_) {}
    return 'Ctrl';
  }

  /// Human-readable key label for this shortcut.
  String get keyLabel {
    if (key == LogicalKeyboardKey.space) return 'Space';
    if (key == LogicalKeyboardKey.escape) return 'Esc';
    if (key == LogicalKeyboardKey.comma) return ',';
    if (key == LogicalKeyboardKey.backslash) return '\\';
    if (key == LogicalKeyboardKey.slash) return '/';
    if (key == LogicalKeyboardKey.arrowUp) return '↑';
    if (key == LogicalKeyboardKey.arrowDown) return '↓';
    final name = key.keyLabel;
    if (name.isNotEmpty) return name;
    return key.debugName ?? '?';
  }

  /// Display string like "Ctrl+Space" or "⌘⇧R" for the overlay UI.
  String get displayLabel {
    final parts = <String>[];
    try {
      if (Platform.isMacOS) {
        if (requireCtrl) parts.add('⌘');
        if (requireShift) parts.add('⇧');
        parts.add(keyLabel);
        return parts.join('');
      }
    } catch (_) {}

    parts.add('Ctrl');
    if (requireShift) parts.add('Shift');
    parts.add(keyLabel);
    return parts.join('+');
  }

  /// Returns the keys as a display-friendly list (for the _ShortcutRow widget).
  /// On macOS shows ["⌘", "B"], on others shows ["Ctrl", "B"].
  List<String> get displayKeys {
    final keys = <String>[];
    try {
      if (Platform.isMacOS) {
        if (requireCtrl) keys.add('⌘');
        if (requireShift) keys.add('⇧');
        keys.add(keyLabel);
        return keys;
      }
    } catch (_) {}

    if (requireCtrl) keys.add('Ctrl');
    if (requireShift) keys.add('Shift');
    keys.add(keyLabel);
    return keys;
  }
}

// ──────────────────────────────────────────────
// All global shortcut definitions
// ──────────────────────────────────────────────

/// Master list of all global keyboard shortcuts.
final List<FocusOsShortcut> globalShortcuts = [
  // Timer & Focus
  FocusOsShortcut(
    action: FocusOsAction.startPauseTimer,
    key: LogicalKeyboardKey.space,
    requireCtrl: true,
  ),
  FocusOsShortcut(
    action: FocusOsAction.resetTimer,
    key: LogicalKeyboardKey.keyR,
    requireCtrl: true,
  ),
  FocusOsShortcut(
    action: FocusOsAction.toggleDnd,
    key: LogicalKeyboardKey.keyD,
    requireCtrl: true,
  ),
  FocusOsShortcut(
    action: FocusOsAction.toggleFullscreen,
    key: LogicalKeyboardKey.keyF,
    requireCtrl: true,
    requireShift: true,
  ),
  // Quick Tools
  FocusOsShortcut(
    action: FocusOsAction.quickCapture,
    key: LogicalKeyboardKey.keyQ,
    requireCtrl: true,
  ),
  FocusOsShortcut(
    action: FocusOsAction.brainDump,
    key: LogicalKeyboardKey.keyB,
    requireCtrl: true,
  ),
  FocusOsShortcut(
    action: FocusOsAction.openSettings,
    key: LogicalKeyboardKey.comma,
    requireCtrl: true,
  ),
  FocusOsShortcut(
    action: FocusOsAction.toggleSidebar,
    key: LogicalKeyboardKey.backslash,
    requireCtrl: true,
  ),
  // Overlays
  FocusOsShortcut(
    action: FocusOsAction.closeOverlay,
    key: LogicalKeyboardKey.escape,
  ),
  FocusOsShortcut(
    action: FocusOsAction.toggleShortcutsCheatSheet,
    key: LogicalKeyboardKey.slash,
    requireCtrl: true,
  ),
  // Timer Customization
  FocusOsShortcut(
    action: FocusOsAction.cycleTimerStyle,
    key: LogicalKeyboardKey.keyT,
    requireCtrl: true,
  ),
  FocusOsShortcut(
    action: FocusOsAction.toggleMiniTimer,
    key: LogicalKeyboardKey.keyM,
    requireCtrl: true,
  ),
  FocusOsShortcut(
    action: FocusOsAction.toggleCalculator,
    key: LogicalKeyboardKey.keyC,
    requireCtrl: true,
    requireShift: true,
  ),
  // Direct page access
  FocusOsShortcut(
    action: FocusOsAction.navigateFocus,
    key: LogicalKeyboardKey.digit1,
    requireCtrl: true,
  ),
  FocusOsShortcut(
    action: FocusOsAction.navigateTasks,
    key: LogicalKeyboardKey.digit2,
    requireCtrl: true,
  ),
  FocusOsShortcut(
    action: FocusOsAction.navigateAnalytics,
    key: LogicalKeyboardKey.digit3,
    requireCtrl: true,
  ),
  FocusOsShortcut(
    action: FocusOsAction.navigateHealth,
    key: LogicalKeyboardKey.digit4,
    requireCtrl: true,
  ),
  FocusOsShortcut(
    action: FocusOsAction.navigateTools,
    key: LogicalKeyboardKey.digit6,
    requireCtrl: true,
  ),
];

// ──────────────────────────────────────────────
// Helper: check if no text field is focused
// ──────────────────────────────────────────────

/// Returns true when no text-editing widget has focus,
/// meaning non-modifier shortcuts can safely fire.
bool noTextFieldFocused() {
  final focus = FocusManager.instance.primaryFocus;
  if (focus == null) return true;
  final contextWidget = focus.context?.widget;
  if (contextWidget == null) return true;
  return contextWidget is! TextField && contextWidget is! TextFormField && contextWidget is! EditableText;
}
