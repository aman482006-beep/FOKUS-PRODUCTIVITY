/// Abstract contract for key-value storage.
///
/// Implementations live in `data/repositories/`. ViewModels and Use Cases
/// depend only on this interface, never on concrete services.
abstract class StorageRepository {
  Future<void> init();
  Future<String?> getString(String key);
  Future<bool> setString(String key, String value);
  Future<bool?> getBool(String key);
  Future<bool> setBool(String key, bool value);
  Future<int?> getInt(String key);
  Future<bool> setInt(String key, int value);
  Future<double?> getDouble(String key);
  Future<bool> setDouble(String key, double value);
  Future<bool> remove(String key);
  Future<bool> containsKey(String key);
  Future<bool> clear();
}
