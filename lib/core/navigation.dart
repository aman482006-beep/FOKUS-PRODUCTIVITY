import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Navigation destinations for the premium sidebar.
/// Maps to the main product areas: Focus, Tasks, Analytics, Health, Tools, Settings.
enum NavDestination {
  focus(Icons.radar, 'Fokus'),
  tasks(Icons.check_circle_outline, 'Tasks'),
  reminders(Icons.alarm_rounded, 'Reminders'),
  analytics(Icons.bar_chart_rounded, 'Analytics'),
  screenTime(Icons.visibility_outlined, 'Your Reality'),
  health(Icons.favorite_outline, 'Health'),
  tools(Icons.grid_view_rounded, 'Tools'),
  support(Icons.favorite_rounded, 'Support'),
  settings(Icons.tune_rounded, 'Settings');


  final IconData icon;
  final String label;

  const NavDestination(this.icon, this.label);
}

/// Current navigation state — the active destination.
final navigationProvider = StateProvider<NavDestination>((ref) => NavDestination.focus);

/// Whether the sidebar is expanded (pinned open) or collapsed (icon-only).
final sidebarExpandedProvider = StateProvider<bool>((ref) => true);

/// Whether the app is in immersive deep work mode.
final deepWorkModeProvider = StateProvider<bool>((ref) => false);

/// Whether the quick capture popover is open.
final quickCaptureOpenProvider = StateProvider<bool>((ref) => false);

/// Whether the settings modal is open.
final settingsModalOpenProvider = StateProvider<bool>((ref) => false);

/// Whether the profile overlay is open.
final profileOverlayOpenProvider = StateProvider<bool>((ref) => false);

/// Whether the keyboard shortcuts cheat sheet overlay is open.
final keyboardShortcutsOpenProvider = StateProvider<bool>((ref) => false);

/// Whether the calculator overlay is open.
final calculatorOpenProvider = StateProvider<bool>((ref) => false);

/// Settings sidebar section identifiers matching the settings modal.
enum SettingsSection {
  account(Icons.person_outline, 'Account'),
  general(Icons.tune_rounded, 'General'),
  fokusTimer(Icons.timer_outlined, 'Fokus Timer'),
  tasks(Icons.check_circle_outline, 'Tasks / Projects'),
  ambientSounds(Icons.headphones, 'Ambient Sounds'),
  fokusScenes(Icons.landscape, 'Fokus Scenes'),
  analytics(Icons.bar_chart_rounded, 'Analytics'),
  health(Icons.favorite_outline, 'Health'),
  appearance(Icons.palette_outlined, 'Appearance'),
  keyboardShortcuts(Icons.keyboard_outlined, 'Keyboard Shortcuts'),
  about(Icons.info_outline, 'About');

  final IconData icon;
  final String label;
  const SettingsSection(this.icon, this.label);
}

/// The currently active settings section.
final activeSettingsSectionProvider = StateProvider<SettingsSection>((ref) => SettingsSection.general);

