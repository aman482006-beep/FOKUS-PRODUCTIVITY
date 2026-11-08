import 'package:shared_preferences/shared_preferences.dart';

/// Persistent key-value storage using SharedPreferences.
///
/// This is a purely static service. For DI-aware access, use [StorageServiceAdapter].
class StorageService {
  static late SharedPreferences _prefs;

  /// The underlying [SharedPreferences] instance, accessible for direct use.
  static SharedPreferences get prefs => _prefs;
  static set prefs(SharedPreferences value) => _prefs = value;
  static SharedPreferences get prefsStatic => _prefs;

  // ── Initialization ──

  /// Initialize storage. Called from main().
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Initialize for testing.
  static Future<void> initForTest() async {
    await init();
  }

  // ── Static API ──

  static String? getString(String key) => _prefs.getString(key);

  static Future<bool> setString(String key, String value) =>
      _prefs.setString(key, value);

  static bool? getBool(String key) => _prefs.getBool(key);

  static Future<bool> setBool(String key, bool value) =>
      _prefs.setBool(key, value);

  static int? getInt(String key) => _prefs.getInt(key);

  static Future<bool> setInt(String key, int value) =>
      _prefs.setInt(key, value);

  static double? getDouble(String key) => _prefs.getDouble(key);

  static Future<bool> setDouble(String key, double value) =>
      _prefs.setDouble(key, value);

  static Future<bool> remove(String key) => _prefs.remove(key);

  static bool containsKey(String key) => _prefs.containsKey(key);

  static Future<bool> clear() => _prefs.clear();
}
