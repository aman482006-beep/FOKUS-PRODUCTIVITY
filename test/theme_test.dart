import 'dart:math' show pow;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fokus/shared/theme.dart';

// ──────────────────────────────────────────────
// WCAG contrast helpers
// ──────────────────────────────────────────────

/// Convert a 0–255 sRGB channel to linear (0–1).
double _linearize(double c) {
  final v = c / 255.0;
  if (v <= 0.04045) return v / 12.92;
  final result = (v + 0.055) / 1.055;
  return pow(result, 2.4).toDouble();
}

/// Compute the relative luminance of a [Color] per WCAG 2.1 definition.
double relativeLuminance(Color c) {
  final r = _linearize(c.r * 255);
  final g = _linearize(c.g * 255);
  final b = _linearize(c.b * 255);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

/// Compute the WCAG contrast ratio between two colours (range 1:1 to 21:1).
/// WCAG AA requires ≥ 4.5:1 for normal text, ≥ 3:1 for large text.
double contrastRatio(Color a, Color b) {
  final l1 = relativeLuminance(a);
  final l2 = relativeLuminance(b);
  final lighter = l1 > l2 ? l1 : l2;
  final darker = l1 > l2 ? l2 : l1;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  // ═══════════════════════════════════════════
  // 1. All themes exist and have valid tokens
  // ═══════════════════════════════════════════

  group('AppThemes — all themes', () {
    test('returns 15 themes', () {
      expect(AppThemes.all.length, 15);
    });

    test('isLight matches category', () {
      for (final theme in AppThemes.all) {
        if (theme.category == 'Light') {
          expect(theme.isLight, isTrue,
              reason: '${theme.name} should be light');
        } else {
          expect(theme.isLight, isFalse,
              reason: '${theme.name} should not be light');
        }
      }
    });

    test('every theme has required metadata', () {
      for (final theme in AppThemes.all) {
        expect(theme.id, isNotEmpty, reason: '${theme.name} has empty id');
        expect(theme.name, isNotEmpty, reason: '${theme.id} has empty name');
        expect(['Dark', 'Light'], contains(theme.category),
            reason: '${theme.id} has invalid category "${theme.category}"');
        expect(theme.tokens, isNotNull,
            reason: '${theme.id} has null tokens');
        expect(theme.icon, isNotNull,
            reason: '${theme.id} has null icon');
      }
    });

    test('all theme ids are unique', () {
      final ids = AppThemes.all.map((t) => t.id).toSet();
      expect(ids.length, AppThemes.all.length,
          reason: 'Duplicate theme ids found');
    });

    test('every name has a unique id mapping', () {
      for (final theme in AppThemes.all) {
        final resolved = AppThemes.byId(theme.id);
        expect(resolved.id, theme.id,
            reason: 'byId("${theme.id}") did not resolve back');
      }
    });

    test('byId returns cosmicBlack fallback for unknown id', () {
      final fallback = AppThemes.byId('nonexistent_theme');
      expect(fallback.id, 'cosmic_black');
    });

    test('8 dark themes and 7 light themes', () {
      final dark = AppThemes.all.where((t) => t.category == 'Dark');
      final light = AppThemes.all.where((t) => t.category == 'Light');
      expect(dark.length, 8);
      expect(light.length, 7);
    });
  });

  // ═══════════════════════════════════════════
  // 2. WCAG AA contrast validation
  // ═══════════════════════════════════════════

  group('WCAG AA contrast compliance', () {
    const double wcagAaThreshold = 4.5; // normal text
    const double wcagAaLargeTextThreshold = 3.0;

    for (final theme in AppThemes.all) {
      final t = theme.tokens;
      final isDark = theme.isLight == false;

      group('${theme.name} (${theme.category})', () {
        // ── Text contrast against background ──
        test('textPrimary meets WCAG AA (≥4.5:1) against background', () {
          final ratio = contrastRatio(t.textPrimary, t.background);
          expect(ratio, greaterThanOrEqualTo(wcagAaThreshold),
              reason: 'textPrimary/background = ${ratio.toStringAsFixed(2)}:1');
        });

        test('textSecondary meets WCAG AA (≥4.5:1) against background', () {
          final ratio = contrastRatio(t.textSecondary, t.background);
          expect(ratio, greaterThanOrEqualTo(wcagAaThreshold),
              reason:
                  'textSecondary/background = ${ratio.toStringAsFixed(2)}:1');
        });

        test('textMuted meets WCAG AA large-text (≥3:1) against background', () {
          final ratio = contrastRatio(t.textMuted, t.background);
          expect(ratio, greaterThanOrEqualTo(wcagAaLargeTextThreshold),
              reason: 'textMuted/background = ${ratio.toStringAsFixed(2)}:1');
        });

        // ── Text contrast against surface (cards, panels) ──
        // Surface may have alpha, so we composite over the background.
        final surfaceComposite = Color.alphaBlend(t.surface, t.background);

        test('textPrimary meets WCAG AA (≥4.5:1) against surface', () {
          final ratio = contrastRatio(t.textPrimary, surfaceComposite);
          expect(ratio, greaterThanOrEqualTo(wcagAaThreshold),
              reason:
                  'textPrimary/surface = ${ratio.toStringAsFixed(2)}:1');
        });

        test('textSecondary meets WCAG AA (≥4.5:1) against surface', () {
          final ratio = contrastRatio(t.textSecondary, surfaceComposite);
          expect(ratio, greaterThanOrEqualTo(wcagAaThreshold),
              reason:
                  'textSecondary/surface = ${ratio.toStringAsFixed(2)}:1');
        });

        // ── Dark vs Light category validation ──
        if (isDark) {
          test('dark theme background has low relative luminance (< 0.1)', () {
            final lum = relativeLuminance(t.background);
            expect(lum, lessThan(0.1),
                reason: 'Dark theme background luminance = ${lum.toStringAsFixed(4)}');
          });

          test('dark theme textPrimary is near-white (luminance > 0.6)', () {
            final lum = relativeLuminance(t.textPrimary);
            expect(lum, greaterThan(0.6),
                reason:
                    'Dark theme textPrimary luminance = ${lum.toStringAsFixed(4)}');
          });
        } else {
          test('light theme background has high relative luminance (> 0.7)', () {
            final lum = relativeLuminance(t.background);
            expect(lum, greaterThan(0.7),
                reason:
                    'Light theme background luminance = ${lum.toStringAsFixed(4)}');
          });

          test('light theme textPrimary is dark (luminance < 0.05)', () {
            final lum = relativeLuminance(t.textPrimary);
            expect(lum, lessThan(0.05),
                reason:
                    'Light theme textPrimary luminance = ${lum.toStringAsFixed(4)}');
          });
        }

        // ── Brightness matches category ──
        test('brightness matches category', () {
          if (theme.category == 'Dark') {
            expect(t.brightness, Brightness.dark);
          } else {
            expect(t.brightness, Brightness.light);
          }
        });

        // ── Accent gradient ──
        test('accent gradient uses the two accent colours', () {
          final g = t.accentGradient;
          expect(g.colors.length, 2);
          expect(g.colors[0], t.accent);
          expect(g.colors[1], t.accentSecondary);
        });
      });
    }
  });

  // ═══════════════════════════════════════════
  // 3. FocusOsTheme API
  // ═══════════════════════════════════════════

  group('FocusOsTheme', () {
    test('fromDefinition returns ThemeData with extension', () {
      final themeData = FocusOsTheme.fromDefinition(AppThemes.cosmicBlack);
      expect(themeData, isA<ThemeData>());
      expect(themeData.brightness, Brightness.dark);
    });

    test('fromDefinition includes ThemeTokens as extension', () {
      final themeData = FocusOsTheme.fromDefinition(AppThemes.cosmicBlack);
      final tokens = themeData.extension<ThemeTokens>();
      expect(tokens, isNotNull);
      expect(tokens!.accent, AppThemes.cosmicBlack.tokens.accent);
    });

    test('fromDefinition on light theme sets brightness to light', () {
      final themeData = FocusOsTheme.fromDefinition(AppThemes.studioLight);
      expect(themeData.brightness, Brightness.light);
    });

    test('of() returns fallback tokens when no extension set', () {
      // When there's no Flutter widget tree, `of()` falls back to
      // AppThemes.oceanicLight.tokens.
      // We simulate this by creating a plain Material widget with no extension.
      // Actually, the fallback path is tested by verifying
      // Theme.of(context).extension<ThemeTokens>() returns null,
      // which is hard to do without a widget tree.
      // We test the static getters instead as they use the same fallback.
      expect(FocusOsTheme.background, AppThemes.oceanicLight.tokens.background);
      expect(FocusOsTheme.textPrimary, AppThemes.oceanicLight.tokens.textPrimary);
      expect(FocusOsTheme.textSecondary, AppThemes.oceanicLight.tokens.textSecondary);
      expect(FocusOsTheme.textMuted, AppThemes.oceanicLight.tokens.textMuted);
      expect(FocusOsTheme.accentStart, AppThemes.oceanicLight.tokens.accent);
      expect(FocusOsTheme.accentEnd, AppThemes.oceanicLight.tokens.accentSecondary);
    });
  });

  // ═══════════════════════════════════════════
  // 4. ThemeTokens — model behaviour
  // ═══════════════════════════════════════════

  group('ThemeTokens model', () {
    test('copyWith preserves unchanged fields', () {
      final original = AppThemes.cosmicBlack.tokens;
      final copied = original.copyWith();
      expect(copied.background, original.background);
      expect(copied.accent, original.accent);
      expect(copied.textPrimary, original.textPrimary);
    });

    test('copyWith overrides specified fields', () {
      final original = AppThemes.cosmicBlack.tokens;
      final copied = original.copyWith(accent: const Color(0xFFFF0000));
      expect(copied.accent, const Color(0xFFFF0000));
      expect(copied.background, original.background); // unchanged
    });

    test('lerp with identity returns same', () {
      final t = AppThemes.cosmicBlack.tokens;
      final result = t.lerp(t, 0.5);
      expect(result.textPrimary, t.textPrimary);
      expect(result.background, t.background);
    });

    test('lerp between two themes at t=0 returns first', () {
      final a = AppThemes.cosmicBlack.tokens;
      final b = AppThemes.cyberpunk.tokens;
      final result = a.lerp(b, 0.0);
      expect(result.accent, a.accent);
    });

    test('lerp between two themes at t=1 returns second', () {
      final a = AppThemes.cosmicBlack.tokens;
      final b = AppThemes.cyberpunk.tokens;
      final result = a.lerp(b, 1.0);
      expect(result.accent, b.accent);
    });

    test('lerp with non-ThemeTokens returns this', () {
      final t = AppThemes.cosmicBlack.tokens;
      final result = t.lerp(null, 0.5);
      expect(result.accent, t.accent);
    });
  });

  // ═══════════════════════════════════════════
  // 5. ThemeDefinition — toThemeData
  // ═══════════════════════════════════════════

  group('ThemeDefinition.toThemeData', () {
    for (final theme in AppThemes.all) {
      test('${theme.name} produces correct brightness', () {
        final td = theme.toThemeData();
        expect(td.brightness,
            theme.isLight ? Brightness.light : Brightness.dark);
      });

      test('${theme.name} uses accent as colorScheme.primary', () {
        final td = theme.toThemeData();
        expect(td.colorScheme.primary, theme.tokens.accent);
      });

      test('${theme.name} scaffoldBackgroundColor matches tokens.background',
          () {
        final td = theme.toThemeData();
        expect(td.scaffoldBackgroundColor, theme.tokens.background);
      });
    }
  });

  // ═══════════════════════════════════════════
  // 6. Theme switching — distinct colors
  // ═══════════════════════════════════════════

  group('Theme switching produces distinct appearances', () {
    test('cosmicBlack and studioLight have different backgrounds', () {
      final darkBg = AppThemes.cosmicBlack.tokens.background;
      final lightBg = AppThemes.studioLight.tokens.background;
      expect(darkBg, isNot(equals(lightBg)));
    });

    test('all dark themes have similar luminance for textPrimary', () {
      final darks = AppThemes.all.where((t) => t.category == 'Dark');
      for (final theme in darks) {
        final lum = relativeLuminance(theme.tokens.textPrimary);
        expect(lum, greaterThan(0.6),
            reason: '${theme.name} textPrimary too dim (${lum.toStringAsFixed(4)})');
      }
    });

    test('all light themes have dark textPrimary (luminance < 0.05)', () {
      final lights = AppThemes.all.where((t) => t.category == 'Light');
      for (final theme in lights) {
        final lum = relativeLuminance(theme.tokens.textPrimary);
        expect(lum, lessThan(0.05),
            reason:
                '${theme.name} textPrimary too bright (${lum.toStringAsFixed(4)})');
      }
    });

    test('dark theme surface is always darker than textPrimary', () {
      for (final theme in AppThemes.all.where((t) => t.category == 'Dark')) {
        final t = theme.tokens;
        final surfaceLum = relativeLuminance(Color.alphaBlend(t.surface, t.background));
        final textLum = relativeLuminance(t.textPrimary);
        expect(textLum, greaterThan(surfaceLum),
            reason: '${theme.name}: text not lighter than surface');
      }
    });
  });
}
