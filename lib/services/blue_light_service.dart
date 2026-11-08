import 'dart:convert';
import 'dart:math';
import '../services/storage_service.dart';

// ──────────────────────────────────────────────
// Color Science Engine
// ──────────────────────────────────────────────
// Implements the Tanner Helland algorithm for converting
// color temperature (Kelvin) → CIE XYZ → linear RGB.
// This is the same math f.lux and similar tools use.

class ColorTemperature {
  /// Converts a color temperature in Kelvin to an RGB color (0.0 – 1.0).
  ///
  /// Range: 1000 K (candlelight) → 10000 K (blue sky).
  /// Standard daylight D65 is 6504 K.
  /// Typical night-mode targets: 3400 K (warm) – 5000 K (mild).
  static (double r, double g, double b) kelvinToRgb(int kelvin) {
    final t = kelvin.toDouble() / 100.0;

    double red, green, blue;

    // ── Red channel ──
    if (t <= 66) {
      red = 255.0;
    } else {
      red = 329.698727446 * pow(t - 60, -0.1332047592);
      red = red.clamp(0, 255);
    }

    // ── Green channel ──
    if (t <= 66) {
      green = 99.4708025861 * log(t) - 161.1195681661;
      green = green.clamp(0, 255);
    } else {
      green = 288.1221695283 * pow(t - 60, -0.0755148492);
      green = green.clamp(0, 255);
    }

    // ── Blue channel ──
    if (t >= 66) {
      blue = 255.0;
    } else if (t <= 19) {
      blue = 0.0;
    } else {
      blue = 138.5177312231 * log(t - 10) - 305.0447927307;
      blue = blue.clamp(0, 255);
    }

    return (red / 255.0, green / 255.0, blue / 255.0);
  }

  /// Builds a perceptually-tuned color matrix for the blue-light range.
  ///
  /// Uses the Tanner Helland Kelvin→RGB to determine the target color,
  /// then blends from identity (daylight) toward that target using an
  /// ease-out curve with luminance compensation to prevent darkening.
  /// This gives a scientifically-grounded result that's visually comfortable.
  static List<double> buildMatrix(double intensity) {
    final t = intensity.clamp(0.0, 1.0);

    // Compute target RGB at the associated Kelvin via Tanner Helland
    final targetKelvin = intensityToKelvin(t);
    final (targetR, targetG, targetB) = kelvinToRgb(targetKelvin);

    // Ease-out curve for smoother feel
    final eased = 1.0 - pow(1.0 - t, 1.8).toDouble();

    // Apply the target color as a multiplicative filter
    // At intensity 0 (6500K): no change (1.0, 1.0, 1.0)
    // At intensity 1 (3400K): full warm filter (targetR, targetG, targetB)
    final r = 1.0 - (1.0 - targetR) * eased;
    final g = 1.0 - (1.0 - targetG) * eased;
    final b = 1.0 - (1.0 - targetB) * eased;

    // Perceptual luminance weights
    final luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b;
    final comp = luminance < 0.80 ? 0.80 / luminance : 1.0;

    return [
      (r * comp).clamp(0.0, 1.3), 0, 0, 0, 0,
      0, (g * comp).clamp(0.0, 1.3), 0, 0, 0,
      0, 0, (b * comp).clamp(0.0, 1.3), 0, 0,
      0, 0, 0, 1, 0,
    ];
  }

  /// Kelvin → perceptually mapped intensity 0..1 for the UI slider.
  static double kelvinToIntensity(int kelvin) =>
      ((6500 - kelvin) / (6500 - 3400)).clamp(0.0, 1.0);

  static int intensityToKelvin(double intensity) =>
      (6500 - (intensity * (6500 - 3400))).round().clamp(3400, 6500);
}

// ──────────────────────────────────────────────
// Persistent settings model
// ──────────────────────────────────────────────

class BlueLightSettings {
  final bool enabled;
  final int temperature; // Kelvin 3400–6500
  final bool autoMode;
  final int scheduledStartHour; // 0–23
  final int scheduledStartMinute;
  final int scheduledEndHour;
  final int scheduledEndMinute;
  final bool sessionLinked;
  final bool grayscale;
  final String? activePreset;

  const BlueLightSettings({
    this.enabled = false,
    this.temperature = 3400,
    this.autoMode = false,
    this.scheduledStartHour = 20, // 8 PM
    this.scheduledStartMinute = 0,
    this.scheduledEndHour = 7, // 7 AM
    this.scheduledEndMinute = 0,
    this.sessionLinked = false,
    this.grayscale = false,
    this.activePreset,
  });

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'temperature': temperature,
        'autoMode': autoMode,
        'scheduledStartHour': scheduledStartHour,
        'scheduledStartMinute': scheduledStartMinute,
        'scheduledEndHour': scheduledEndHour,
        'scheduledEndMinute': scheduledEndMinute,
        'sessionLinked': sessionLinked,
        'grayscale': grayscale,
        'activePreset': activePreset,
      };

  factory BlueLightSettings.fromJson(Map<String, dynamic> json) =>
      BlueLightSettings(
        enabled: json['enabled'] as bool? ?? false,
        temperature: json['temperature'] as int? ?? 3400,
        autoMode: json['autoMode'] as bool? ?? false,
        scheduledStartHour: json['scheduledStartHour'] as int? ?? 20,
        scheduledStartMinute: json['scheduledStartMinute'] as int? ?? 0,
        scheduledEndHour: json['scheduledEndHour'] as int? ?? 7,
        scheduledEndMinute: json['scheduledEndMinute'] as int? ?? 0,
        sessionLinked: json['sessionLinked'] as bool? ?? false,
        grayscale: json['grayscale'] as bool? ?? false,
        activePreset: json['activePreset'] as String?,
      );
}

class BlueLightPreset {
  final String id;
  final String label;
  final int temperature;
  final String icon;
  final String description;

  const BlueLightPreset({
    required this.id,
    required this.label,
    required this.temperature,
    required this.icon,
    required this.description,
  });

  static const presets = [
    BlueLightPreset(
      id: 'daylight',
      label: 'Standard',
      temperature: 6500,
      icon: 'wb_sunny',
      description: 'Clear daylight spectrum — standard rendering.',
    ),
    BlueLightPreset(
      id: 'sunset',
      label: 'Warm Sunset',
      temperature: 4500,
      icon: 'brightness_5',
      description: 'Soft amber tint — relaxing for evening reading.',
    ),
    BlueLightPreset(
      id: 'night',
      label: 'Deep Night',
      temperature: 3400,
      icon: 'bedtime',
      description: 'Maximum warmth — circadian-friendly before sleep.',
    ),
  ];
}

// ──────────────────────────────────────────────
// Service
// ──────────────────────────────────────────────

class BlueLightService {
  static const _key = 'blue_light_settings';

  // ── Persistence ─────────────────────────────

  static BlueLightSettings load() {
    try {
      final raw = StorageService.prefsStatic.getString(_key);
      if (raw == null) return const BlueLightSettings();
      return BlueLightSettings.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const BlueLightSettings();
    }
  }

  static Future<void> save(BlueLightSettings settings) async {
    try {
      await StorageService.prefsStatic.setString(_key, jsonEncode(settings.toJson()));
    } catch (_) {}
  }

  // ── Scheduling ──────────────────────────────

  /// Returns `true` if the current local time falls within the scheduled window.
  ///
  /// Handles overnight windows (e.g. 8 PM → 7 AM the next day).
  static bool isWithinSchedule(BlueLightSettings s) {
    final now = DateTime.now();
    final minutes = now.hour * 60 + now.minute;

    final start = s.scheduledStartHour * 60 + s.scheduledStartMinute;
    final end = s.scheduledEndHour * 60 + s.scheduledEndMinute;

    if (start <= end) {
      // Normal window (e.g. 07:00 – 20:00)
      return minutes >= start && minutes < end;
    } else {
      // Overnight window (e.g. 20:00 – 07:00)
      return minutes >= start || minutes < end;
    }
  }

  /// Returns the appropriate Kelvin for the current time in auto mode.
  /// Gradual warming as the evening progresses.
  static int adaptiveTemperature(BlueLightSettings s) {
    final now = DateTime.now();
    final minutesSinceMidnight = now.hour * 60 + now.minute;

    // Start warming 2 hours before the scheduled start.
    final start = s.scheduledStartHour * 60 + s.scheduledStartMinute;
    final rampUpMinutes = 120; // 2-hour gradual ramp

    final phaseInStart = start - rampUpMinutes;

    if (!_isInAdaptiveRange(minutesSinceMidnight, phaseInStart, start)) {
      return 6500; // daylight
    }

    final progress = ((minutesSinceMidnight - phaseInStart) / rampUpMinutes)
        .clamp(0.0, 1.0);
    final target = s.temperature.toDouble();
    return (6500 - (6500 - target) * progress).round();
  }

  static bool _isInAdaptiveRange(int now, int phaseStart, int scheduleStart) {
    if (phaseStart <= scheduleStart) {
      return now >= phaseStart && now < scheduleStart;
    }
    // Overnight edge case
    return false;
  }

  // ── Color matrix for current state ──────────

  /// Returns the warm-blue-light color matrix.
  static List<double> warmMatrix(BlueLightSettings s) {
    if (!s.enabled) {
      return [
        1.0, 0.0, 0.0, 0.0, 0.0,
        0.0, 1.0, 0.0, 0.0, 0.0,
        0.0, 0.0, 1.0, 0.0, 0.0,
        0.0, 0.0, 0.0, 1.0, 0.0,
      ];
    }
    final intensity = ColorTemperature.kelvinToIntensity(s.temperature);
    return ColorTemperature.buildMatrix(intensity);
  }

  /// Standard luminance-based grayscale matrix.
  static List<double> get grayscaleMatrix => [
        0.2126, 0.7152, 0.0722, 0, 0,
        0.2126, 0.7152, 0.0722, 0, 0,
        0.2126, 0.7152, 0.0722, 0, 0,
        0,      0,      0,      1, 0,
      ];

  /// Returns the appropriate matrix based on whether blue light, grayscale, or both are active.
  static List<double> matrixForSettings(BlueLightSettings s) {
    final warm = warmMatrix(s);

    if (!s.grayscale) return warm;

    final wR = warm[0];
    final wG = warm[6];
    final wB = warm[12];

    return [
      wR * 0.2126, wR * 0.7152, wR * 0.0722, 0, 0,
      wG * 0.2126, wG * 0.7152, wG * 0.0722, 0, 0,
      wB * 0.2126, wB * 0.7152, wB * 0.0722, 0, 0,
      0,           0,           0,           1, 0,
    ];
  }
}
