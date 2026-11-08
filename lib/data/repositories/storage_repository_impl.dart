import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/repositories/storage_repository.dart';

/// Concrete implementation of [StorageRepository] using SharedPreferences.
///
/// Auto-initializes on first method call by piggy-backing on the
/// already-initialized [SharedPreferences] instance (created by
/// [StorageService.init] earlier in the DI sequence).
class StorageRepositoryImpl implements StorageRepository {
  SharedPreferences? _prefs;

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  @override
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  @override
  Future<String?> getString(String key) async =>
      (await _getPrefs()).getString(key);

  @override
  Future<bool> setString(String key, String value) async =>
      (await _getPrefs()).setString(key, value);

  @override
  Future<bool?> getBool(String key) async =>
      (await _getPrefs()).getBool(key);

  @override
  Future<bool> setBool(String key, bool value) async =>
      (await _getPrefs()).setBool(key, value);

  @override
  Future<int?> getInt(String key) async =>
      (await _getPrefs()).getInt(key);

  @override
  Future<bool> setInt(String key, int value) async =>
      (await _getPrefs()).setInt(key, value);

  @override
  Future<double?> getDouble(String key) async =>
      (await _getPrefs()).getDouble(key);

  @override
  Future<bool> setDouble(String key, double value) async =>
      (await _getPrefs()).setDouble(key, value);

  @override
  Future<bool> remove(String key) async =>
      (await _getPrefs()).remove(key);

  @override
  Future<bool> containsKey(String key) async =>
      (await _getPrefs()).containsKey(key);

  @override
  Future<bool> clear() async =>
      (await _getPrefs()).clear();
}
