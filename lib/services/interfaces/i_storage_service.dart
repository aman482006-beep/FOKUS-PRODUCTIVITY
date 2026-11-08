import 'package:shared_preferences/shared_preferences.dart';

/// Abstraction over persistent key-value storage.
///
/// Implementations wrap [SharedPreferences] and optionally Hive.
/// This interface exists to make storage testable and swappable.
abstract class IStorageService {
  /// Initialize the storage backend. Must be called once before any other method.
  Future<void> init();

  /// The underlying [SharedPreferences] instance.
  SharedPreferences get prefs;

  /// Get a string value by [key].
  String? getString(String key);

  /// Set a string value by [key].
  Future<bool> setString(String key, String value);

  /// Get a bool value by [key].
  bool? getBool(String key);

  /// Set a bool value by [key].
  Future<bool> setBool(String key, bool value);

  /// Get an int value by [key].
  int? getInt(String key);

  /// Set an int value by [key].
  Future<bool> setInt(String key, int value);

  /// Get a double value by [key].
  double? getDouble(String key);

  /// Set a double value by [key].
  Future<bool> setDouble(String key, double value);

  /// Remove a value by [key].
  Future<bool> remove(String key);

  /// Check if a [key] exists.
  bool containsKey(String key);

  /// Clear all stored data.
  Future<bool> clear();
}
