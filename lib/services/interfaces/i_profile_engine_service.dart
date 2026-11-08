import '../profile_engine_service.dart' show FocusProfile;

/// Abstraction over focus profile loading, saving, and active profile management.
///
/// Implementations handle persistence of built-in and custom focus profiles,
/// as well as tracking which profile is currently active.
abstract class IProfileEngineService {
  /// Load all profiles (built-in + custom).
  Future<List<FocusProfile>> loadProfiles();

  /// Save a custom profile (or overwrite an existing one).
  Future<void> saveProfile(FocusProfile profile);

  /// Delete a custom profile by [id].
  Future<void> deleteProfile(String id);

  /// Get the active profile ID, or null if none is set.
  Future<String?> getActiveProfileId();

  /// Set the active profile ID, or null to clear.
  Future<void> setActiveProfileId(String? id);
}
