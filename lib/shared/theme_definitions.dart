import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme.dart';

// ──────────────────────────────────────────────
// Theme Token Model
// ──────────────────────────────────────────────

class ThemeTokens extends ThemeExtension<ThemeTokens> {
  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color accent;
  final Color accentSecondary;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color borderSubtle;
  final Color borderMedium;
  final Brightness brightness;

  const ThemeTokens({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.accent,
    required this.accentSecondary,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.borderSubtle,
    required this.borderMedium,
    required this.brightness,
  });

  @override
  ThemeTokens copyWith({
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? accent,
    Color? accentSecondary,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? borderSubtle,
    Color? borderMedium,
    Brightness? brightness,
  }) =>
      ThemeTokens(
        background: background ?? this.background,
        surface: surface ?? this.surface,
        surfaceAlt: surfaceAlt ?? this.surfaceAlt,
        accent: accent ?? this.accent,
        accentSecondary: accentSecondary ?? this.accentSecondary,
        textPrimary: textPrimary ?? this.textPrimary,
        textSecondary: textSecondary ?? this.textSecondary,
        textMuted: textMuted ?? this.textMuted,
        borderSubtle: borderSubtle ?? this.borderSubtle,
        borderMedium: borderMedium ?? this.borderMedium,
        brightness: brightness ?? this.brightness,
      );

  @override
  ThemeTokens lerp(ThemeExtension<ThemeTokens>? other, double t) {
    if (other is! ThemeTokens) return this;
    return ThemeTokens(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSecondary: Color.lerp(accentSecondary, other.accentSecondary, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      borderMedium: Color.lerp(borderMedium, other.borderMedium, t)!,
      brightness: t < 0.5 ? brightness : other.brightness,
    );
  }

  LinearGradient get accentGradient => LinearGradient(
        colors: [accent, accentSecondary],
        stops: const [0.0, 1.0],
      );
}

// ──────────────────────────────────────────────
// Theme Definition
// ──────────────────────────────────────────────

class ThemeDefinition {
  final String id;
  final String name;
  final String category; // 'Dark' or 'Light'
  final IconData icon;
  final ThemeTokens tokens;

  const ThemeDefinition({
    required this.id,
    required this.name,
    required this.category,
    required this.icon,
    required this.tokens,
  });

  bool get isLight => tokens.brightness == Brightness.light;

  ThemeData toThemeData() {
    final textOnAccent = tokens.accent.computeLuminance() > 0.6
        ? const Color(0xFF1E1B4B)
        : Colors.white;

    final baseTheme = ThemeData(brightness: tokens.brightness);
    final baseTextTheme = GoogleFonts.plusJakartaSansTextTheme(baseTheme.textTheme);

    return ThemeData(
      brightness: tokens.brightness,
      scaffoldBackgroundColor: tokens.background,
      colorScheme: ColorScheme(
        brightness: tokens.brightness,
        primary: tokens.accent,
        secondary: tokens.accentSecondary,
        surface: tokens.surface,
        error: const Color(0xFFEF4444),
        onPrimary: textOnAccent,
        onSecondary: textOnAccent,
        onSurface: tokens.textPrimary,
        onError: Colors.white,
      ),
      dividerColor: tokens.borderSubtle,
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: tokens.accent,
        selectionColor: tokens.accent.safeWithOpacity(0.35),
        selectionHandleColor: tokens.accent,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: tokens.textPrimary,
      ),
      textTheme: baseTextTheme.copyWith(
        headlineLarge: GoogleFonts.plusJakartaSans(
          color: tokens.textPrimary,
          fontWeight: FontWeight.w700,
        ),
        headlineMedium: GoogleFonts.plusJakartaSans(
          color: tokens.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: GoogleFonts.plusJakartaSans(color: tokens.textPrimary),
        bodyMedium: GoogleFonts.plusJakartaSans(color: tokens.textSecondary),
        labelLarge: GoogleFonts.plusJakartaSans(color: tokens.textSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: tokens.accent,
          foregroundColor: textOnAccent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: tokens.textSecondary,
          side: BorderSide(color: tokens.borderMedium),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        fillColor: Colors.transparent,
        hintStyle: GoogleFonts.plusJakartaSans(color: tokens.textMuted, fontSize: 14),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
        isDense: true,
      ),
    );
  }
}

// ──────────────────────────────────────────────
// 15 Themes — WCAG AA Compliant
// ──────────────────────────────────────────────

class AppThemes {
  // ═══════════════════════════════════════════
  // DARK MODES
  // ═══════════════════════════════════════════
  //
  // All dark themes use:
  //   textPrimary  = #F8FAFC (near-white, ~20:1 contrast)
  //   textSecondary = #B0B8C4 (light silver-gray, ~12:1 contrast)
  //   textMuted     = #808890 (medium gray, ~7:1 contrast)
  // These solid hex values eliminate the washout caused by
  // the previous alpha-opacity approach on tinted surfaces.
  //
  // Borders use subtle alpha values as they are decorative only.

  /// Theme 1: Default Cosmic Black (Off-Black, Neon Indigo accent)
  static const cosmicBlack = ThemeDefinition(
    id: 'cosmic_black',
    name: 'Cosmic Black',
    category: 'Dark',
    icon: Icons.dark_mode,
    tokens: ThemeTokens(
      background: Color(0xFF08090C),
      surface: Color(0xEE10121A),
      surfaceAlt: Color(0xFF14161F),
      accent: Color(0xFF6366F1),
      accentSecondary: Color(0xFF8B5CF6),
      textPrimary: Color(0xFFF8FAFC),
      textSecondary: Color(0xFFB0B8C4),
      textMuted: Color(0xFF808890),
      borderSubtle: Color(0x1AFFFFFF),
      borderMedium: Color(0x2AFFFFFF),
      brightness: Brightness.dark,
    ),
  );

  /// Theme 2: Electric Cyberpunk (Ink-black, neon pink/magenta)
  static const cyberpunk = ThemeDefinition(
    id: 'cyberpunk',
    name: 'Cyberpunk',
    category: 'Dark',
    icon: Icons.flash_on,
    tokens: ThemeTokens(
      background: Color(0xFF0A0A0A),
      surface: Color(0xEE120713),
      surfaceAlt: Color(0xFF1A0A14),
      accent: Color(0xFFFF0080),
      accentSecondary: Color(0xFFFF6B35),
      textPrimary: Color(0xFFF8FAFC),
      textSecondary: Color(0xFFB0B8C4),
      textMuted: Color(0xFF808890),
      borderSubtle: Color(0x1AFF0080),
      borderMedium: Color(0x30FF0080),
      brightness: Brightness.dark,
    ),
  );

  /// Theme 3: Midnight Aurora (Deep teal/navy, aurora green-blue accent)
  static const aurora = ThemeDefinition(
    id: 'aurora',
    name: 'Midnight Aurora',
    category: 'Dark',
    icon: Icons.nightlight_round,
    tokens: ThemeTokens(
      background: Color(0xFF0B1215),
      surface: Color(0xEE0B1417),
      surfaceAlt: Color(0xFF0F1E24),
      accent: Color(0xFF2DD4BF),
      accentSecondary: Color(0xFF0EA5E9),
      textPrimary: Color(0xFFF0FDFA),
      textSecondary: Color(0xFFB0BCC6),
      textMuted: Color(0xFF809098),
      borderSubtle: Color(0x1AFFFFFF),
      borderMedium: Color(0x2A2DD4BF),
      brightness: Brightness.dark,
    ),
  );

  /// Theme 4: Monolith Dark (Pure dark gray, subtle slate accents)
  static const monolith = ThemeDefinition(
    id: 'monolith',
    name: 'Monolith Dark',
    category: 'Dark',
    icon: Icons.view_agenda,
    tokens: ThemeTokens(
      background: Color(0xFF0D0D0D),
      surface: Color(0xEE121315),
      surfaceAlt: Color(0xFF1A1C1E),
      accent: Color(0xFF94A3B8),
      accentSecondary: Color(0xFF64748B),
      textPrimary: Color(0xFFF1F5F9),
      textSecondary: Color(0xFFB0B8C4),
      textMuted: Color(0xFF808890),
      borderSubtle: Color(0x1AFFFFFF),
      borderMedium: Color(0x2AFFFFFF),
      brightness: Brightness.dark,
    ),
  );

  /// Theme 5: Solarized Amber (Warm dark, amber/gold accents)
  static const amberDark = ThemeDefinition(
    id: 'amber_dark',
    name: 'Solarized Amber',
    category: 'Dark',
    icon: Icons.wb_sunny,
    tokens: ThemeTokens(
      background: Color(0xFF1A1610),
      surface: Color(0xEE1A130C),
      surfaceAlt: Color(0xFF2A2015),
      accent: Color(0xFFF59E0B),
      accentSecondary: Color(0xFFD97706),
      textPrimary: Color(0xFFFFFCF0),
      textSecondary: Color(0xFFC4BCB0),
      textMuted: Color(0xFF9E9488),
      borderSubtle: Color(0x1AFFFBEA),
      borderMedium: Color(0x2AFFFBEA),
      brightness: Brightness.dark,
    ),
  );

  /// Theme 6: Forest Night (Deep green-black, pine/emerald accents)
  static const forestNight = ThemeDefinition(
    id: 'forest_night',
    name: 'Forest Night',
    category: 'Dark',
    icon: Icons.forest,
    tokens: ThemeTokens(
      background: Color(0xFF0A120E),
      surface: Color(0xEE08100C),
      surfaceAlt: Color(0xFF0F1E16),
      accent: Color(0xFF22C55E),
      accentSecondary: Color(0xFF16A34A),
      textPrimary: Color(0xFFF0FFF4),
      textSecondary: Color(0xFFB0C4B8),
      textMuted: Color(0xFF809888),
      borderSubtle: Color(0x1AFFFFFF),
      borderMedium: Color(0x2AFFFFFF),
      brightness: Brightness.dark,
    ),
  );

  /// Theme 7: Royal Velvet (Deep purple, gold accents)
  static const royalVelvet = ThemeDefinition(
    id: 'royal_velvet',
    name: 'Royal Velvet',
    category: 'Dark',
    icon: Icons.diamond,
    tokens: ThemeTokens(
      background: Color(0xFF0E0A14),
      surface: Color(0xEE0E0916),
      surfaceAlt: Color(0xFF1A1024),
      accent: Color(0xFFA855F7),
      accentSecondary: Color(0xFFEAB308),
      textPrimary: Color(0xFFF8F0FF),
      textSecondary: Color(0xFFB8B0C8),
      textMuted: Color(0xFF8A8098),
      borderSubtle: Color(0x1AFFFFFF),
      borderMedium: Color(0x2AA855F7),
      brightness: Brightness.dark,
    ),
  );

  /// Theme 8: Nocturnal Cobalt (Deep navy, electric blue accents)
  static const cobaltNocturne = ThemeDefinition(
    id: 'cobalt_nocturne',
    name: 'Cobalt Nocturne',
    category: 'Dark',
    icon: Icons.nights_stay,
    tokens: ThemeTokens(
      background: Color(0xFF0A0E1A),
      surface: Color(0xEE080C16),
      surfaceAlt: Color(0xFF0F1A2E),
      accent: Color(0xFF3B82F6),
      accentSecondary: Color(0xFF60A5FA),
      textPrimary: Color(0xFFF0F4FF),
      textSecondary: Color(0xFFB0B8CC),
      textMuted: Color(0xFF80889E),
      borderSubtle: Color(0x1AFFFFFF),
      borderMedium: Color(0x2AFFFFFF),
      brightness: Brightness.dark,
    ),
  );

  // ═══════════════════════════════════════════
  // LIGHT MODES
  // ═══════════════════════════════════════════
  //
  // All light themes use:
  //   textPrimary  = near-black/deep charcoal (varies per theme)
  //   textSecondary = dark tone (~#4A4A52 range, ~8:1 contrast)
  //   textMuted     = medium dark gray (~#6E6E78 range, ~5:1 contrast)
  //
  // These pass WCAG AA on all light/off-white backgrounds.

  /// Theme 9: Pure Studio Light (Crisp white, light slate, rich charcoal)
  static const studioLight = ThemeDefinition(
    id: 'studio_light',
    name: 'Studio Light',
    category: 'Light',
    icon: Icons.light_mode,
    tokens: ThemeTokens(
      background: Color(0xFFF8F9FA),
      surface: Color(0xE6FFFFFF),
      surfaceAlt: Color(0xFFF1F3F5),
      accent: Color(0xFF6366F1),
      accentSecondary: Color(0xFF8B5CF6),
      textPrimary: Color(0xFF1A1A2E),
      textSecondary: Color(0xFF4A4A5A),
      textMuted: Color(0xFF6E6E7E),
      borderSubtle: Color(0x1A000000),
      borderMedium: Color(0x2A000000),
      brightness: Brightness.light,
    ),
  );

  /// Theme 10: Oceanic Light (Pale ice-blue, white cards, deep navy text)
  static const oceanicLight = ThemeDefinition(
    id: 'oceanic_light',
    name: 'Oceanic Light',
    category: 'Light',
    icon: Icons.water_drop,
    tokens: ThemeTokens(
      background: Color(0xFFE8F4FD),
      surface: Color(0xE6FFFFFF),
      surfaceAlt: Color(0xFFD6ECF8),
      accent: Color(0xFF0EA5E9),
      accentSecondary: Color(0xFF3B82F6),
      textPrimary: Color(0xFF0F172A),
      textSecondary: Color(0xFF3A4A5A),
      textMuted: Color(0xFF5A6A7A),
      borderSubtle: Color(0x1A0F172A),
      borderMedium: Color(0x2A0F172A),
      brightness: Brightness.light,
    ),
  );

  /// Theme 11: Alpine Mist (Soft gray-white, deep pine-green accents)
  static const alpineMist = ThemeDefinition(
    id: 'alpine_mist',
    name: 'Alpine Mist',
    category: 'Light',
    icon: Icons.terrain,
    tokens: ThemeTokens(
      background: Color(0xFFF4F5F0),
      surface: Color(0xE6FFFFFF),
      surfaceAlt: Color(0xFFE8EAE0),
      accent: Color(0xFF166534),
      accentSecondary: Color(0xFF22C55E),
      textPrimary: Color(0xFF1C2A1E),
      textSecondary: Color(0xFF4A544A),
      textMuted: Color(0xFF6E786E),
      borderSubtle: Color(0x1A000000),
      borderMedium: Color(0x2A000000),
      brightness: Brightness.light,
    ),
  );

  /// Theme 12: Rose Garden (Soft pink, rose accents)
  static const roseGarden = ThemeDefinition(
    id: 'rose_garden',
    name: 'Rose Garden',
    category: 'Light',
    icon: Icons.local_florist,
    tokens: ThemeTokens(
      background: Color(0xFFFDF2F4),
      surface: Color(0xE6FFFFFF),
      surfaceAlt: Color(0xFFFCE4E8),
      accent: Color(0xFFE11D48),
      accentSecondary: Color(0xFFFB7185),
      textPrimary: Color(0xFF2D1B1E),
      textSecondary: Color(0xFF5A4A4E),
      textMuted: Color(0xFF7A6E72),
      borderSubtle: Color(0x1A000000),
      borderMedium: Color(0x2A000000),
      brightness: Brightness.light,
    ),
  );

  /// Theme 13: Warm Sand (Beige background, warm terra cotta accent)
  static const warmSand = ThemeDefinition(
    id: 'warm_sand',
    name: 'Warm Sand',
    category: 'Light',
    icon: Icons.beach_access,
    tokens: ThemeTokens(
      background: Color(0xFFFDF8F0),
      surface: Color(0xE6FFFFFF),
      surfaceAlt: Color(0xFFF5EDE0),
      accent: Color(0xFFC2410C),
      accentSecondary: Color(0xFFEA580C),
      textPrimary: Color(0xFF29241E),
      textSecondary: Color(0xFF544C44),
      textMuted: Color(0xFF786E66),
      borderSubtle: Color(0x1A000000),
      borderMedium: Color(0x2A000000),
      brightness: Brightness.light,
    ),
  );

  /// Theme 14: Lavender Haze (Soft purple pastel, violet accents)
  static const lavenderHaze = ThemeDefinition(
    id: 'lavender_haze',
    name: 'Lavender Haze',
    category: 'Light',
    icon: Icons.auto_awesome,
    tokens: ThemeTokens(
      background: Color(0xFFF5F3FF),
      surface: Color(0xE6FFFFFF),
      surfaceAlt: Color(0xFFEDE9FE),
      accent: Color(0xFF7C3AED),
      accentSecondary: Color(0xFFA78BFA),
      textPrimary: Color(0xFF1E1B4B),
      textSecondary: Color(0xFF4A4868),
      textMuted: Color(0xFF6E6C84),
      borderSubtle: Color(0x1A000000),
      borderMedium: Color(0x2A000000),
      brightness: Brightness.light,
    ),
  );

  /// Theme 15: Mint Dew (Pale green-white, mint/seafoam accents)
  static const mintDew = ThemeDefinition(
    id: 'mint_dew',
    name: 'Mint Dew',
    category: 'Light',
    icon: Icons.spa,
    tokens: ThemeTokens(
      background: Color(0xFFF0FDF4),
      surface: Color(0xE6FFFFFF),
      surfaceAlt: Color(0xFFDCFCE7),
      accent: Color(0xFF059669),
      accentSecondary: Color(0xFF34D399),
      textPrimary: Color(0xFF022C22),
      textSecondary: Color(0xFF2A4A3E),
      textMuted: Color(0xFF4A6A5E),
      borderSubtle: Color(0x1A000000),
      borderMedium: Color(0x2A000000),
      brightness: Brightness.light,
    ),
  );

  /// All themes in display order
  static const all = [
    // Dark modes
    cosmicBlack,
    cyberpunk,
    aurora,
    monolith,
    amberDark,
    forestNight,
    royalVelvet,
    cobaltNocturne,
    // Light modes
    studioLight,
    oceanicLight,
    alpineMist,
    roseGarden,
    warmSand,
    lavenderHaze,
    mintDew,
  ];

  static ThemeDefinition byId(String id) =>
      all.firstWhere((t) => t.id == id, orElse: () => cosmicBlack);
}

// ──────────────────────────────────────────────
// Focus Scenes — Visual environments
// ──────────────────────────────────────────────

class FocusSceneVariant {
  final String id;
  final String name;
  final String imagePath;

  const FocusSceneVariant({
    required this.id,
    required this.name,
    required this.imagePath,
  });
}

class FocusScene {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final List<Color> gradientColors;
  final String imagePath;
  final List<FocusSceneVariant> variants;

  const FocusScene({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.gradientColors,
    required this.imagePath,
    this.variants = const [],
  });

  FocusScene copyWith({String? imagePath}) {
    return FocusScene(
      id: id,
      name: name,
      description: description,
      icon: icon,
      gradientColors: gradientColors,
      imagePath: imagePath ?? this.imagePath,
      variants: variants,
    );
  }
}

class AppScenes {
  static const none = FocusScene(
    id: 'none',
    name: 'Default',
    description: 'Standard styling',
    icon: Icons.image_not_supported_outlined,
    gradientColors: [Color(0xFF0F172A), Color(0xFF1E293B)],
    imagePath: '',
    variants: [],
  );

  static const forest = FocusScene(
    id: 'forest',
    name: 'Forest',
    description: 'Forest ambiance',
    icon: Icons.forest,
    gradientColors: [Color(0xFF166534), Color(0xFF22C55E)],
    imagePath: 'assets/scenes/forest/day_forest.jpg',
    variants: [
      FocusSceneVariant(id: 'day_forest', name: 'Day Forest', imagePath: 'assets/scenes/forest/day_forest.jpg'),
      FocusSceneVariant(id: 'night_forest', name: 'Night Forest', imagePath: 'assets/scenes/forest/night_forest.jpg'),
    ],
  );

  static const rain = FocusScene(
    id: 'rain',
    name: 'Rain',
    description: 'Calming rainfall',
    icon: Icons.water_drop,
    gradientColors: [Color(0xFF1E3A5F), Color(0xFF3B82F6)],
    imagePath: 'assets/scenes/rain/evening_rain.png',
    variants: [
      FocusSceneVariant(id: 'evening_rain', name: 'Evening Rain', imagePath: 'assets/scenes/rain/evening_rain.png'),
    ],
  );

  static const library = FocusScene(
    id: 'library',
    name: 'Library',
    description: 'Quiet study',
    icon: Icons.local_library,
    gradientColors: [Color(0xFF5C4033), Color(0xFFB8860B)],
    imagePath: 'assets/scenes/library/day_library.jpg',
    variants: [
      FocusSceneVariant(id: 'day_library', name: 'Day Library', imagePath: 'assets/scenes/library/day_library.jpg'),
      FocusSceneVariant(id: 'night_library', name: 'Night Library', imagePath: 'assets/scenes/library/night_library.jpg'),
    ],
  );

  static const codingDesk = FocusScene(
    id: 'coding_desk',
    name: 'Coding Desk',
    description: 'Developer setup',
    icon: Icons.desktop_windows,
    gradientColors: [Color(0xFF1A1A2E), Color(0xFF6366F1)],
    imagePath: 'assets/scenes/coding/bro_code.jpg',
    variants: [
      FocusSceneVariant(id: 'bro_code', name: 'Bro Code', imagePath: 'assets/scenes/coding/bro_code.jpg'),
      FocusSceneVariant(id: 'morgan_codes', name: 'Morgan Codes', imagePath: 'assets/scenes/coding/morgan_codes.jpg'),
      FocusSceneVariant(id: 'slash_code', name: 'Slash Code', imagePath: 'assets/scenes/coding/slash_code.jpg'),
    ],
  );

  static const beach = FocusScene(
    id: 'beach',
    name: 'Beach',
    description: 'Coastal calm',
    icon: Icons.beach_access,
    gradientColors: [Color(0xFF0EA5E9), Color(0xFFF59E0B)],
    imagePath: 'assets/scenes/beach/morning_beach.jpg',
    variants: [
      FocusSceneVariant(id: 'morning_beach', name: 'Morning Beach', imagePath: 'assets/scenes/beach/morning_beach.jpg'),
      FocusSceneVariant(id: 'afternoon_beach', name: 'Afternoon Beach', imagePath: 'assets/scenes/beach/afternoon_beach.jpg'),
      FocusSceneVariant(id: 'night_beach', name: 'Night Beach', imagePath: 'assets/scenes/beach/night_beach.jpg'),
    ],
  );

  static const nightSky = FocusScene(
    id: 'night_sky',
    name: 'Night Sky',
    description: 'Starlit background',
    icon: Icons.nights_stay,
    gradientColors: [Color(0xFF0F0A1E), Color(0xFF7C3AED)],
    imagePath: 'assets/scenes/sky/night_sky.jpg',
    variants: [
      FocusSceneVariant(id: 'night_sky', name: 'Night Sky', imagePath: 'assets/scenes/sky/night_sky.jpg'),
      FocusSceneVariant(id: 'day_sky', name: 'Day Sky', imagePath: 'assets/scenes/sky/day_sky.jpg'),
    ],
  );

  static const all = [
    none,
    forest,
    rain,
    library,
    codingDesk,
    beach,
    nightSky,
  ];

  static FocusScene byId(String id) =>
      all.firstWhere((s) => s.id == id, orElse: () => none);
}
