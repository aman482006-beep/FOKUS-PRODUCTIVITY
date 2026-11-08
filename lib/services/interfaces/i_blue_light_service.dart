import '../blue_light_service.dart';

/// Abstraction over blue-light filtering persistence and color science.
///
/// Implementations handle saving/loading blue light settings and
/// computing color temperature matrices for the screen overlay.
abstract class IBlueLightService {
  /// Load saved blue light settings.
  BlueLightSettings load();

  /// Persist blue light settings.
  Future<void> save(BlueLightSettings settings);

  /// Returns `true` if the current time falls within the scheduled window.
  bool isWithinSchedule(BlueLightSettings s);

  /// Returns the appropriate Kelvin for the current time in auto mode.
  int adaptiveTemperature(BlueLightSettings s);

  /// Returns the warm-blue-light color matrix for the given settings.
  List<double> warmMatrix(BlueLightSettings s);

  /// Returns the appropriate matrix based on blue light + grayscale state.
  List<double> matrixForSettings(BlueLightSettings s);
}
