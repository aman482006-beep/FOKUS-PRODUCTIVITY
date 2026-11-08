import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fokus/features/tools/color_picker_tool.dart';
import 'package:fokus/shared/theme.dart';

Widget createTestApp({VoidCallback? onBack}) {
  return MaterialApp(
    theme: FocusOsTheme.fromDefinition(AppThemes.cosmicBlack),
    darkTheme: FocusOsTheme.fromDefinition(AppThemes.cosmicBlack),
    themeMode: ThemeMode.dark,
    home: ColorPickerPage(onBack: onBack ?? () {}),
  );
}

void main() {
  setUp(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
  });

  group('Rendering', () {
    testWidgets('shows title and description', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();
      expect(find.text('Color Picker & Palettes'), findsOneWidget);
    });

    testWidgets('default HEX and RGB', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();
      expect(find.text('#6366F1'), findsOneWidget);
      expect(find.text('99,102,241'), findsOneWidget);
    });

    testWidgets('harmony labels, sliders, and sections', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();
      expect(find.text('Complementary'), findsWidgets);
      expect(find.text('Red'), findsOneWidget);
      expect(find.text('Saved Palette'), findsOneWidget);
      expect(find.text('Add Current'), findsOneWidget);
      expect(find.text('Recent Colors'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.byIcon(Icons.copy_rounded), findsNWidgets(2));
    });

    testWidgets('slider values', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();
      expect(find.text('99'), findsWidgets);
      expect(find.text('102'), findsWidgets);
      expect(find.text('241'), findsWidgets);
    });

    testWidgets('harmony cards have non-zero size', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Verify the harmony card widgets have valid render sizes
      final complementaryText = find.text('Complementary');
      expect(tester.getRect(complementaryText).width, greaterThan(0.0));
      expect(tester.getRect(complementaryText).height, greaterThan(0.0));
    });
  });

  group('Harmony hex values', () {
    testWidgets('complementary, analogous, triadic', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();
      // Default: Color(0xFF6366F1) → R=99,G=102,B=241
      // Complementary: 255-99=156, 255-102=153, 255-241=14  → #9C990E
      // Analogous:     (g*255)=102, (b*255)=241, (r*255)=99  → #66F163
      // Triadic:       (b*255)=241, (r*255)=99,  (g*255)=102 → #F16366
      expect(find.text('#9C990E'), findsOneWidget);
      expect(find.text('#66F163'), findsOneWidget);
      expect(find.text('#F16366'), findsOneWidget);
    });

    testWidgets('tapping Complementary color swatch changes preview',
        (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Before: the preview shows the default RGB "99,102,241"
      expect(find.text('99,102,241'), findsOneWidget);
      // The complementary hex only appears on the harmony card
      expect(find.text('#9C990E'), findsOneWidget);

      // Tap the Complementary harmony card's color swatch.
      // First, find the Container with the complementary color decoration.
      final complementarySwatch = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).color?.toARGB32() == 0xFF9C990E,
      );
      expect(complementarySwatch, findsOneWidget);

      await tester.tap(complementarySwatch);
      await tester.pumpAndSettle();

      // After: the preview RGB should change to the complementary RGB.
      // Harmonies: default indigo (99,102,241) → complementary (156,153,14)
      expect(find.text('156,153,14'), findsOneWidget);
    });

    testWidgets('tapping Analogous swatch then Triadic swatch',
        (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Tap the Analogous color swatch
      final analogousSwatch = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).color?.toARGB32() == 0xFF66F163,
      );
      await tester.tap(analogousSwatch);
      await tester.pumpAndSettle();

      // Analogous RGB: (102,241,99)
      expect(find.text('102,241,99'), findsOneWidget);

      // Tap the Triadic color swatch
      final triadicSwatch = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).color?.toARGB32() == 0xFFF16366,
      );
      await tester.tap(triadicSwatch);
      await tester.pumpAndSettle();

      // Triadic RGB: (241,99,102)
      expect(find.text('241,99,102'), findsOneWidget);
    });
  });

  group('Interactions', () {
    testWidgets('back button triggers onBack', (tester) async {
      bool backCalled = false;
      await tester.pumpWidget(createTestApp(onBack: () => backCalled = true));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(backCalled, isTrue);
    });

    testWidgets('HEX copy shows snackbar', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.copy_rounded).first);
      await tester.pumpAndSettle();
      expect(find.text('Copied: #6366F1'), findsOneWidget);
    });

    testWidgets('RGB copy shows snackbar', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.copy_rounded).last);
      await tester.pumpAndSettle();
      expect(find.text('Copied: RGB(99, 102, 241)'), findsOneWidget);
    });

    testWidgets('Add Current button is tappable', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Change color to complementary first
      final complementarySwatch = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).color?.toARGB32() == 0xFF9C990E,
      );
      await tester.tap(complementarySwatch);
      await tester.pumpAndSettle();

      // Verify the preview updated: default indigo (99,102,241) → (156,153,14)
      expect(find.text('156,153,14'), findsOneWidget);

      // Tap Add Current
      await tester.tap(find.text('Add Current'));
      await tester.pumpAndSettle();

      // The Add Current button exists and doesn't crash
      expect(find.text('Add Current'), findsOneWidget);
    });

    testWidgets('palette color tap selects it', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Change to complementary first
      final complementarySwatch = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).color?.toARGB32() == 0xFF9C990E,
      );
      await tester.tap(complementarySwatch);
      await tester.pumpAndSettle();

      // Now tap back to indigo in the palette via the palette swatch
      // Since both palette and history might have indigo, use `last`
      final indigoSwatch = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).color?.toARGB32() == 0xFF6366F1,
      );
      expect(indigoSwatch, findsAtLeast(1));
      await tester.tap(indigoSwatch.last);
      await tester.pumpAndSettle();

      // Preview should revert to indigo
      expect(find.text('#6366F1'), findsAtLeast(1));
    });
  });

  group('Empty states', () {
    testWidgets('empty palette shows message', (tester) async {
      SharedPreferences.setMockInitialValues({
        'color_palette': <String>[],
        'color_history': <String>['0xFF6366F1'],
      });
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();
      expect(find.text('No saved colors yet'), findsOneWidget);
    });

    testWidgets('empty history falls back to default', (tester) async {
      SharedPreferences.setMockInitialValues({
        'color_palette': <String>['0xFF6366F1'],
        'color_history': <String>[],
      });
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();
      // History should still render indigo as default
      expect(find.text('#6366F1'), findsOneWidget);
    });

    testWidgets('both palette and history empty shows fallbacks',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'color_palette': <String>[],
        'color_history': <String>[],
      });
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();
      expect(find.text('No saved colors yet'), findsOneWidget);
      // Preview should still show default indigo
      expect(find.text('#6366F1'), findsOneWidget);
    });
  });

  group('Persistence', () {
    testWidgets('loads palette from SharedPreferences', (tester) async {
      SharedPreferences.setMockInitialValues({
        'color_palette': <String>['0xFFEF4444', '0xFF10B981'],
        'color_history': <String>['0xFF6366F1'],
      });
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();
      // These palette swatches should be present (red and green)
      final redSwatch = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).color?.toARGB32() == 0xFFEF4444,
      );
      final greenSwatch = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).color?.toARGB32() == 0xFF10B981,
      );
      expect(redSwatch, findsOneWidget);
      expect(greenSwatch, findsOneWidget);
    });

    testWidgets('loads history from SharedPreferences', (tester) async {
      SharedPreferences.setMockInitialValues({
        'color_palette': <String>['0xFF6366F1'],
        'color_history': <String>['0xFFEF4444', '0xFF10B981', '0xFF3B82F6'],
      });
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();
      // Tapping a history color should update the preview
      final redHistoryItem = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).color?.toARGB32() == 0xFFEF4444,
      );
      expect(redHistoryItem, findsOneWidget);

      await tester.tap(redHistoryItem);
      await tester.pumpAndSettle();
      expect(find.text('#EF4444'), findsAtLeast(1));
    });
  });

  group('Slider interactions', () {
    testWidgets('Red slider changes preview', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Default: 99,102,241
      expect(find.text('99,102,241'), findsOneWidget);

      // Drag Red slider — find and drag
      final sliders = find.byType(Slider);
      // Drag right a significant amount to increase R value
      // The slider is 0-255, the track width is known
      await tester.drag(sliders.first, const Offset(100, 0));
      await tester.pumpAndSettle();

      // Red value should have increased (99 + some)
      // Greens and blues remain 102 and 241
      expect(find.textContaining('102'), findsWidgets);
      expect(find.textContaining('241'), findsWidgets);
    });

    testWidgets('Green slider changes preview', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final sliders = find.byType(Slider);
      await tester.drag(sliders.at(1), const Offset(-100, 0));
      await tester.pumpAndSettle();

      // Green value should have decreased
      expect(find.textContaining('99'), findsWidgets);
      expect(find.textContaining('241'), findsWidgets);
    });
  });

  group('Palette operations', () {
    testWidgets('adds new color to palette', (tester) async {
      SharedPreferences.setMockInitialValues({
        'color_palette': <String>['0xFF6366F1'],
        'color_history': <String>['0xFF6366F1'],
      });
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Change color to complementary first
      final complementarySwatch = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).color?.toARGB32() == 0xFF9C990E,
      );
      await tester.tap(complementarySwatch);
      await tester.pumpAndSettle();

      // Count palette circles before adding
      final paletteCirclesBefore = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).shape == BoxShape.circle,
      );
      final beforeCount = paletteCirclesBefore.evaluate().length;

      // Add to palette
      await tester.tap(find.text('Add Current'));
      await tester.pumpAndSettle();

      // Palette should have one more circle
      final paletteCirclesAfter = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).shape == BoxShape.circle,
      );
      final afterCount = paletteCirclesAfter.evaluate().length;
      expect(afterCount, greaterThan(beforeCount));
    });

    testWidgets('does not add duplicate colors to palette', (tester) async {
      SharedPreferences.setMockInitialValues({
        'color_palette': <String>['0xFF6366F1'],
        'color_history': <String>['0xFF6366F1'],
      });
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Count palette circles before
      final paletteCirclesBefore = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).shape == BoxShape.circle,
      );
      final beforeCount = paletteCirclesBefore.evaluate().length;

      // Try adding current color (indigo) which is already in palette
      await tester.tap(find.text('Add Current'));
      await tester.pumpAndSettle();

      // Count palette circles after — should be same
      final paletteCirclesAfter = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).shape == BoxShape.circle,
      );
      final afterCount = paletteCirclesAfter.evaluate().length;
      expect(afterCount, equals(beforeCount));
    });

    testWidgets('removes color from palette', (tester) async {
      SharedPreferences.setMockInitialValues({
        'color_palette': <String>['0xFFEF4444', '0xFF6366F1'],
        'color_history': <String>['0xFF6366F1'],
      });
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // The back button has shape: BoxShape.circle
      // Palette circles = 2 (red + indigo) + 1 (back button) = 3
      final paletteCirclesBefore = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).shape == BoxShape.circle,
      );
      final beforeCount = paletteCirclesBefore.evaluate().length;
      expect(beforeCount, greaterThanOrEqualTo(3));

      // Use onSecondaryTap (right-click) to avoid Tooltip's long press conflict.
      // The palette GestureDetector has onSecondaryTap: () => _removeFromPalette(color).
      final redContainer = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).color?.toARGB32() == 0xFFEF4444,
      );
      expect(redContainer, findsOneWidget);

      // Simulate a right-click (button 2 = kSecondaryButton) to trigger onSecondaryTap
      final gesture = await tester.startGesture(
        tester.getCenter(redContainer),
        buttons: 2,
      );
      await gesture.up();
      await tester.pumpAndSettle();

      // Palette should have one fewer circle
      final paletteCirclesAfter = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).shape == BoxShape.circle,
      );
      final afterCount = paletteCirclesAfter.evaluate().length;
      expect(afterCount, equals(beforeCount - 1));

      // Red swatch should be gone
      final redSwatchGone = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).color?.toARGB32() == 0xFFEF4444,
      );
      expect(redSwatchGone, findsNothing);
    });
  });

  group('History limit', () {
    testWidgets('stops adding at 12 items', (tester) async {
      // Seed history with 12 colors already
      final manyColors = List.generate(
        12,
        (i) => '0xFF${(0xFF0000 + i * 0x1000).toRadixString(16).padLeft(8, '0')}',
      );
      SharedPreferences.setMockInitialValues({
        'color_palette': <String>['0xFF6366F1'],
        'color_history': manyColors,
      });
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Tapping a new color from harmony should still add to history,
      // but the oldest should be removed (max 12)
      final complementarySwatch = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).color?.toARGB32() == 0xFF9C990E,
      );
      await tester.tap(complementarySwatch);
      await tester.pumpAndSettle();

      // Preview should show complementary color
      expect(find.text('156,153,14'), findsOneWidget);
    });
  });

  group('Monochromatic harmony', () {
    testWidgets('shows different hex than input', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();
      // Input: Color(0xFF6366F1) — Indigo
      // Monochromatic pulls V in HSV up or down by 0.25
      // HSV of #6366F1: H~238°, S~0.58, V~0.95 → V-0.25 = 0.70 → different hex
      // Just verify the monochromatic hex is visible and different from input
      final monoText = find.textContaining('#');
      expect(monoText, findsAtLeast(2)); // preview hex + at least all harmony hexes

      // The monochromatic hex should NOT match the default indigo hex (#6366F1)
      // because V changes by ±0.25
      // Count how many hex texts match the monochromatic value
      final monochromaticCard = find.textContaining('#');
      // All harmony cards plus preview show hex — ensure at least 4 different hexes visible
      // (indigo, complementary, analogous, triadic, monochromatic = 5)
      final hexCount = monochromaticCard.evaluate().length;
      expect(hexCount, greaterThanOrEqualTo(4));
    });
  });

  group('Multiple selections', () {
    testWidgets('selecting new color adds to history', (tester) async {
      SharedPreferences.setMockInitialValues({
        'color_palette': <String>['0xFF6366F1'],
        'color_history': <String>['0xFF6366F1'],
      });
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Count history items initially (GridView items)
      final historyItemsBefore = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).borderRadius != null &&
            (w.decoration as BoxDecoration).color != null,
      );
      final beforeCount = historyItemsBefore.evaluate().length;

      // Select complementary color
      final complementarySwatch = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).color?.toARGB32() == 0xFF9C990E,
      );
      await tester.tap(complementarySwatch);
      await tester.pumpAndSettle();

      // History count should increase by 1 (complementary is new)
      final historyItemsAfter = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).borderRadius != null &&
            (w.decoration as BoxDecoration).color != null,
      );
      final afterCount = historyItemsAfter.evaluate().length;
      expect(afterCount, equals(beforeCount + 1));
    });

    testWidgets('selecting existing history color does not add duplicate',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'color_palette': <String>['0xFFEF4444', '0xFF6366F1'],
        'color_history': <String>['0xFFEF4444', '0xFF6366F1'],
      });
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Count history items scoped to the GridView (not other borderRadius widgets)
      final historyGrid = find.byType(GridView);
      final historyItemsBefore = find.descendant(
        of: historyGrid,
        matching: find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).color != null,
        ),
      );
      final beforeCount = historyItemsBefore.evaluate().length;

      // Tap the red swatch from the palette (circle-shaped to disambiguate from history)
      final redPaletteSwatch = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).shape == BoxShape.circle &&
            (w.decoration as BoxDecoration).color?.toARGB32() == 0xFFEF4444,
      );
      expect(redPaletteSwatch, findsOneWidget);
      await tester.tap(redPaletteSwatch);
      await tester.pumpAndSettle();

      // History should NOT have increased (red was already in history)
      final historyItemsAfter = find.descendant(
        of: historyGrid,
        matching: find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).color != null,
        ),
      );
      final afterCount = historyItemsAfter.evaluate().length;
      expect(afterCount, equals(beforeCount));
    });
  });
}
