import 'package:flutter/material.dart';
import 'theme_definitions.dart';
export 'theme_definitions.dart';

/// Provides quick access to the current theme tokens from a BuildContext.
/// Usage: `final tokens = FocusOsTheme.of(context);`
class FocusOsTheme {
  static ThemeTokens of(BuildContext context) {
    // We retrieve the tokens from the theme's extension data.
    final tokens = Theme.of(context).extension<ThemeTokens>();
    return tokens ?? AppThemes.oceanicLight.tokens;
  }

  static Color get background => AppThemes.oceanicLight.tokens.background;
  static Color get surface => AppThemes.oceanicLight.tokens.surface;
  static Color get accentStart => AppThemes.oceanicLight.tokens.accent;
  static Color get accentEnd => AppThemes.oceanicLight.tokens.accentSecondary;
  static Color get textPrimary => AppThemes.oceanicLight.tokens.textPrimary;
  static Color get textSecondary => AppThemes.oceanicLight.tokens.textSecondary;
  static Color get textMuted => AppThemes.oceanicLight.tokens.textMuted;
  static Color get borderSubtle => AppThemes.oceanicLight.tokens.borderSubtle;
  static Color get borderMedium => AppThemes.oceanicLight.tokens.borderMedium;
  static LinearGradient get accentGradient =>
      AppThemes.oceanicLight.tokens.accentGradient;
  static LinearGradient get inputUnderlineGradient =>
      AppThemes.oceanicLight.tokens.accentGradient;

  static BoxDecoration glassDecoration = BoxDecoration(
    color: surface,
    borderRadius: BorderRadius.circular(12),
  );

  static BoxDecoration glassDecorationLarge = BoxDecoration(
    color: surface,
    borderRadius: BorderRadius.circular(16),
  );

  static BoxDecoration blurredGlassDecoration = BoxDecoration(
    color: surface,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: borderSubtle, width: 1),
  );

  /// Build a ThemeData from a ThemeDefinition.
  static ThemeData fromDefinition(ThemeDefinition def) {
    final t = def.tokens;
    final theme = def.toThemeData();
    // Store tokens as an extension so we can retrieve them via FocusOsTheme.of(context)
    return theme.copyWith(
      extensions: [t],
    );
  }
}

extension SafeColor on Color {
  Color safeWithOpacity(double opacity) {
    return Color.fromRGBO(
      (r * 255).round().clamp(0, 255),
      (g * 255).round().clamp(0, 255),
      (b * 255).round().clamp(0, 255),
      opacity,
    );
  }
}


