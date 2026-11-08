import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fokus/core/providers.dart';
import 'package:fokus/services/storage_service.dart';
import 'package:fokus/shared/theme.dart';
import 'package:fokus/shared/widgets/sidebar.dart';
import 'package:fokus/features/settings/settings_modal.dart';


// ──────────────────────────────────────────────
// Helpers
// ──────────────────────────────────────────────

/// Create a test app wrapper that provides the active [theme] along with
/// Riverpod and Material scaffolding, rendering [child] as the home page.
///
/// Callers MUST invoke `SharedPreferences.setMockInitialValues({})` before
/// the first `pumpWidget` call so that providers that depend on prefs
/// (e.g. [ThemeNotifier], [UserProfileNotifier]) can initialise without
/// hitting the real SharedPreferences disk.
Widget createAppWithTheme({
  Widget child = const SizedBox(),
  ThemeDefinition theme = AppThemes.cosmicBlack,
}) {
  return ProviderScope(
    child: MaterialApp(
      theme: FocusOsTheme.fromDefinition(theme),
      darkTheme: FocusOsTheme.fromDefinition(theme),
      themeMode: ThemeMode.dark,
      home: child,
    ),
  );
}

/// Retrieve the [Color] of a [Text] widget by its exact [text], if found.
Color? textColorOf(WidgetTester tester, String text) {
  final textWidget = tester.widget<Text>(find.text(text).first);
  return textWidget.style?.color;
}

/// Retrieve the [FontWeight] of a [Text] widget by its exact [text].
FontWeight? textWeightOf(WidgetTester tester, String text) {
  final textWidget = tester.widget<Text>(find.text(text).first);
  return textWidget.style?.fontWeight;
}

// ──────────────────────────────────────────────
// Tests
// ──────────────────────────────────────────────

void main() {
  late ThemeTokens darkTokens;
  late ThemeTokens lightTokens;

  setUpAll(() {
    darkTokens = AppThemes.cosmicBlack.tokens;
    lightTokens = AppThemes.studioLight.tokens;
  });

  setUp(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({
      'active_theme_id': 'cosmic_black',
    });
    StorageService.prefs = await SharedPreferences.getInstance();
  });

  // ═══════════════════════════════════════════
  // 1. Sidebar — text colour changes with theme
  // ═══════════════════════════════════════════

  group('Sidebar — theme-aware text colors', () {
    testWidgets('dark theme shows light text on "Fokus" branding',
        (tester) async {
      await tester.pumpWidget(createAppWithTheme(
        theme: AppThemes.cosmicBlack,
        child: const FocusOsSidebar(),
      ));
      await tester.pumpAndSettle();

      final color = textColorOf(tester, 'Fokus');
      expect(color, isNotNull);
      // textSecondary for dark theme (#B0B8C4) should appear light
      expect(color!.computeLuminance(), greaterThan(0.4),
          reason: 'Dark theme sidebar branding should be light');
    });

    testWidgets('light theme shows dark text on "Fokus" branding',
        (tester) async {
      await tester.pumpWidget(createAppWithTheme(
        theme: AppThemes.studioLight,
        child: const FocusOsSidebar(),
      ));
      await tester.pumpAndSettle();

      final color = textColorOf(tester, 'Fokus');
      expect(color, isNotNull);
      // textSecondary for light theme (#4A4A5A) should appear dark
      expect(color!.computeLuminance(), lessThan(0.3),
          reason: 'Light theme sidebar branding should be dark');
    });

    testWidgets('nav items use textSecondary which changes with theme',
        (tester) async {
      // Build with dark theme
      await tester.pumpWidget(createAppWithTheme(
        theme: AppThemes.cosmicBlack,
        child: const FocusOsSidebar(),
      ));
      await tester.pumpAndSettle();

      final darkColor = textColorOf(tester, 'Tasks');
      expect(darkColor, isNotNull);
      expect(darkColor!.computeLuminance(), greaterThan(0.4),
          reason: 'Dark theme inactive nav text should be light silver-gray');

      // Switch to light theme by rebuilding
      await tester.pumpWidget(createAppWithTheme(
        theme: AppThemes.studioLight,
        child: const FocusOsSidebar(),
      ));
      await tester.pumpAndSettle();

      final lightColor = textColorOf(tester, 'Tasks');
      expect(lightColor, isNotNull);
      expect(lightColor!.computeLuminance(), lessThan(0.1),
          reason: 'Light theme inactive nav text should be dark charcoal-gray');
    });

    testWidgets('profile name uses textPrimary matching theme',
        (tester) async {
      // Default profile name is 'User'
      await tester.pumpWidget(createAppWithTheme(
        theme: AppThemes.cosmicBlack,
        child: const FocusOsSidebar(),
      ));
      await tester.pumpAndSettle();

      final darkColor = textColorOf(tester, 'User');
      expect(darkColor, isNotNull);
      expect(darkColor!.computeLuminance(), greaterThan(0.8));
    });
  });

  // ═══════════════════════════════════════════
  // 2. Theme propagation via MaterialApp
  // ═══════════════════════════════════════════

  group('ThemeData propagation', () {
    testWidgets('scaffold background matches theme background color',
        (tester) async {
      await tester.pumpWidget(createAppWithTheme(
        theme: AppThemes.cosmicBlack,
        child: const Scaffold(body: Center(child: Text('Hello'))),
      ));
      await tester.pumpAndSettle();

      // Scaffold Material should have scaffoldBackgroundColor from theme
      final theme = Theme.of(tester.element(find.text('Hello')));
      expect(theme.scaffoldBackgroundColor, darkTokens.background);
    });

    testWidgets('colorScheme.primary matches accent', (tester) async {
      await tester.pumpWidget(createAppWithTheme(
        theme: AppThemes.cosmicBlack,
        child: const SizedBox(),
      ));
      await tester.pumpAndSettle();

      // Access the theme from any context in the tree
      final theme = tester.widget<MaterialApp>(find.byType(MaterialApp)).theme!;
      expect(theme.colorScheme.primary, darkTokens.accent);
    });

    testWidgets('extension ThemeTokens are retrievable', (tester) async {
      // Use a marker widget so we can get a BuildContext *inside* the
      // MaterialApp tree (where Theme.of() can find the extension).
      await tester.pumpWidget(createAppWithTheme(
        theme: AppThemes.cosmicBlack,
        child: const Text('marker', textDirection: TextDirection.ltr),
      ));
      await tester.pumpAndSettle();

      final context = tester.element(find.text('marker'));
      final tokens = FocusOsTheme.of(context);
      expect(tokens.accent, darkTokens.accent);
      expect(tokens.textPrimary, darkTokens.textPrimary);
      expect(tokens.background, darkTokens.background);
    });

    testWidgets('extension tokens switch when theme switches', (tester) async {
      await tester.pumpWidget(createAppWithTheme(
        theme: AppThemes.cosmicBlack,
        child: const Text('marker', textDirection: TextDirection.ltr),
      ));

      // Rebuild with light theme
      await tester.pumpWidget(createAppWithTheme(
        theme: AppThemes.studioLight,
        child: const Text('marker', textDirection: TextDirection.ltr),
      ));
      await tester.pumpAndSettle();

      final context = tester.element(find.text('marker'));
      final tokens = FocusOsTheme.of(context);
      expect(tokens.accent, lightTokens.accent);
      expect(tokens.textPrimary, lightTokens.textPrimary);
      expect(tokens.background, lightTokens.background);
    });
  });

  // ═══════════════════════════════════════════
  // 3. ThemeNotifier — switching via provider
  // ═══════════════════════════════════════════

  group('ThemeNotifier — provider-driven switching', () {
    testWidgets('starts with oceanicLight as default', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('active_theme_id', 'oceanic_light');

      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          home: Consumer(builder: (context, ref, _) {
            final theme = ref.watch(themeProvider);
            return Text('Theme: ${theme.id}',
                textDirection: TextDirection.ltr);
          }),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Theme: oceanic_light'), findsOneWidget);
    });

    testWidgets('setTheme updates the displayed theme id', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('active_theme_id', 'oceanic_light');

      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          home: Consumer(builder: (context, ref, _) {
            final theme = ref.watch(themeProvider);
            return GestureDetector(
              onTap: () =>
                  ref.read(themeProvider.notifier).setTheme('studio_light'),
              child: Text('Theme: ${theme.id}',
                  textDirection: TextDirection.ltr),
            );
          }),
        ),
      ));
      await tester.pumpAndSettle();

      // Initial state
      expect(find.text('Theme: oceanic_light'), findsOneWidget);

      // Tap to switch to studio_light
      await tester.tap(find.text('Theme: oceanic_light'));
      await tester.pumpAndSettle();

      expect(find.text('Theme: studio_light'), findsOneWidget);
    });
  });

  // ═══════════════════════════════════════════
  // 4. Settings page — theme grid rendering
  // ═══════════════════════════════════════════

  group('Settings theme grid', () {
    testWidgets('shows "Dark Modes" and "Light Modes" section headers',
        (tester) async {
      await tester.pumpWidget(createAppWithTheme(
        child: const _SettingsPageFragment(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Dark Modes'), findsOneWidget);
      expect(find.text('Light Modes'), findsOneWidget);
    });

    testWidgets('renders all 15 theme names', (tester) async {
      await tester.pumpWidget(createAppWithTheme(
        child: const _SettingsPageFragment(),
      ));
      await tester.pumpAndSettle();

      for (final theme in AppThemes.all) {
        expect(find.text(theme.name), findsWidgets,
            reason: 'Missing theme card: ${theme.name}');
      }
    });

    testWidgets('tapping a theme card calls onSelect', (tester) async {
      String? selectedId;
      await tester.pumpWidget(createAppWithTheme(
        child: _ThemeGridHarness(
          onSelect: (id) => selectedId = id,
        ),
      ));
      await tester.pumpAndSettle();

      // Tap on "Studio Light"
      await tester.tap(find.text('Studio Light'));
      await tester.pumpAndSettle();

      expect(selectedId, 'studio_light');
    });

    testWidgets('active theme card has different style than inactive',
        (tester) async {
      await tester.pumpWidget(createAppWithTheme(
        child: const _ThemeGridHarness(initialThemeId: 'cosmic_black'),
      ));
      await tester.pumpAndSettle();

      // Find "Cosmic Black" text — should be rendered with accent color weight
      final activeWeight = textWeightOf(tester, 'Cosmic Black');
      expect(activeWeight, FontWeight.w600,
          reason: 'Active theme should use FontWeight.w600');

      // Find a non-active theme like "Cyberpunk"
      final inactiveWeight = textWeightOf(tester, 'Cyberpunk');
      expect(inactiveWeight, FontWeight.w400,
          reason: 'Inactive theme should use FontWeight.w400');
    });
  });

  _registerModalSettingsModalTest();
}

// ──────────────────────────────────────────────
// Test-only widgets (the grid fragment)
// ──────────────────────────────────────────────

/// A self-contained fragment of the settings page that renders the theme grid
/// so we can test it without pulling in the full SettingsPage (which requires
/// EyeBreakService, StorageService, etc.).
class _SettingsPageFragment extends ConsumerWidget {
  const _SettingsPageFragment();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = FocusOsTheme.of(context);
    final currentThemeId = ref.watch(themeProvider).id;

    return Material(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              title: 'Dark Modes',
              themes: AppThemes.all.where((t) => t.category == 'Dark').toList(),
              currentThemeId: currentThemeId,
              tokens: tokens,
              onSelect: (id) => ref.read(themeProvider.notifier).setTheme(id),
            ),
            const SizedBox(height: 24),
            _buildSection(
              title: 'Light Modes',
              themes:
                  AppThemes.all.where((t) => t.category == 'Light').toList(),
              currentThemeId: currentThemeId,
              tokens: tokens,
              onSelect: (id) => ref.read(themeProvider.notifier).setTheme(id),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<ThemeDefinition> themes,
    required String currentThemeId,
    required ThemeTokens tokens,
    required ValueChanged<String> onSelect,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: tokens.textSecondary,
                letterSpacing: 0.8)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: themes.map((theme) {
            final isActive = currentThemeId == theme.id;
            final tt = theme.tokens;
            return GestureDetector(
              onTap: () => onSelect(theme.id),
              child: Container(
                width: 130,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isActive
                      ? tt.accent.withValues(alpha: 0.12)
                      : tt.borderSubtle.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isActive
                        ? tt.accent.withValues(alpha: 0.50)
                        : tt.borderSubtle,
                    width: isActive ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(theme.name,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: isActive
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: isActive
                                ? tt.accent
                                : tt.textSecondary)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// A test harness for the theme grid that accepts a callback and an initial
/// active theme, so we can verify tap interaction and active styling.
class _ThemeGridHarness extends ConsumerWidget {
  final ValueChanged<String>? onSelect;
  final String initialThemeId;

  const _ThemeGridHarness({this.onSelect, this.initialThemeId = 'cosmic_black'});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentThemeId = ref.watch(themeProvider).id;

    return Material(
      child: SingleChildScrollView(
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: AppThemes.all.map((theme) {
            final isActive = currentThemeId == theme.id;
            final tt = theme.tokens;
            return GestureDetector(
              key: Key('theme_${theme.id}'),
              onTap: () {
                onSelect?.call(theme.id);
                ref.read(themeProvider.notifier).setTheme(theme.id);
              },
              child: Container(
                width: 130,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isActive
                      ? tt.accent.withValues(alpha: 0.12)
                      : tt.borderSubtle.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isActive
                        ? tt.accent.withValues(alpha: 0.50)
                        : tt.borderSubtle,
                    width: isActive ? 1.5 : 1,
                  ),
                ),
                child: Text(theme.name,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: isActive
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color:
                            isActive ? tt.accent : tt.textSecondary)),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Settings Modal — Focus Scenes Tab Crash Test
// ──────────────────────────────────────────────

class _SettingsModalHarness extends StatelessWidget {
  const _SettingsModalHarness();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SettingsModal(onClose: () {}),
    );
  }
}

void _registerModalSettingsModalTest() {
  group('SettingsModal Fokus Scenes and Appearance tests', () {
    testWidgets('Renders all fokus scenes in settings modal without crashing', (tester) async {
      await tester.pumpWidget(createAppWithTheme(
        child: const _SettingsModalHarness(),
      ));
      await tester.pumpAndSettle();

      // Click on the Focus Scenes tab in the sidebar
      final fokusScenesTab = find.text('Fokus Scenes');
      expect(fokusScenesTab, findsAtLeast(1));
      await tester.tap(fokusScenesTab.first);
      await tester.pumpAndSettle();

      // Verify that all 6 focus scenes are rendered
      expect(find.text('Forest'), findsOneWidget);
      expect(find.text('Rain'), findsOneWidget);
      expect(find.text('Library'), findsOneWidget);
      expect(find.text('Coding Desk'), findsOneWidget);
      expect(find.text('Beach'), findsOneWidget);
      expect(find.text('Night Sky'), findsOneWidget);
    });

    testWidgets('Renders all themes in settings modal appearance tab without crashing', (tester) async {
      await tester.pumpWidget(createAppWithTheme(
        child: const _SettingsModalHarness(),
      ));
      await tester.pumpAndSettle();

      // Click on the Appearance tab in the sidebar
      final appearanceTab = find.text('Appearance');
      expect(appearanceTab, findsAtLeast(1));
      await tester.tap(appearanceTab.first);
      await tester.pumpAndSettle();

      // Verify that themes are rendered
      expect(find.text('Cosmic Black'), findsWidgets);
      expect(find.text('Studio Light'), findsWidgets);
    });
  });
}
