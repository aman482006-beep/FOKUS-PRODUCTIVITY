import 'package:get_it/get_it.dart';
import '../services/interfaces/interfaces.dart';
import '../domain/repositories/repositories.dart';
import '../data/repositories/repositories.dart' as repo_impl;
import 'service_adapters.dart';

/// Global service locator.
///
/// Use [serviceLocator] to access registered services throughout the app.
/// Services are registered in [configureDependencies] which is called from `main()`.
///
/// Example:
/// ```dart
/// final storage = serviceLocator<IStorageService>();
/// await storage.setString('key', 'value');
/// ```
final GetIt serviceLocator = GetIt.instance;

/// Result of DI initialization, capturing which services succeeded and which failed.
class DiInitResult {
  final List<String> initialized;
  final List<DiInitError> errors;

  const DiInitResult({
    this.initialized = const [],
    this.errors = const [],
  });

  bool get hasErrors => errors.isNotEmpty;
  bool get allSucceeded => errors.isEmpty;

  DiInitResult copyWith({List<String>? initialized, List<DiInitError>? errors}) =>
      DiInitResult(
        initialized: initialized ?? this.initialized,
        errors: errors ?? this.errors,
      );
}

class DiInitError {
  final String serviceName;
  final String message;
  final Object? innerError;
  final StackTrace? stackTrace;

  const DiInitError({
    required this.serviceName,
    required this.message,
    this.innerError,
    this.stackTrace,
  });
}

/// Register all services with the DI container and attempt to initialize them.
///
/// Each service init is individually caught so that a single failure
/// (e.g. flutter_local_notifications on web) does not prevent the app from loading.
///
/// Returns a [DiInitResult] with the list of successfully initialized services
/// and any errors that occurred. Callers can inspect [DiInitResult.errors]
/// to log or display initialization failures without crashing.
Future<DiInitResult> configureDependencies() async {
  final initialized = <String>[];
  final errors = <DiInitError>[];

  // ── 1. Register non-async singletons ──

  serviceLocator.registerLazySingleton<ISoundService>(() => SoundServiceAdapter());

  // ── 2. Initialize async services with individual error handling ──

  // StorageService
  try {
    final storage = StorageServiceAdapter();
    await storage.init();
    serviceLocator.registerLazySingleton<IStorageService>(() => storage);
    initialized.add('StorageService');
  } catch (e, stack) {
    errors.add(DiInitError(
      serviceName: 'StorageService',
      message: e.toString(),
      innerError: e,
      stackTrace: stack,
    ));
  }

  // NotificationService
  try {
    final notifications = NotificationServiceAdapter();
    await notifications.init();
    serviceLocator.registerLazySingleton<INotificationService>(() => notifications);
    initialized.add('NotificationService');
  } catch (e, stack) {
    errors.add(DiInitError(
      serviceName: 'NotificationService',
      message: e.toString(),
      innerError: e,
      stackTrace: stack,
    ));
  }

  // EyeBreakService
  try {
    final eyeBreak = EyeBreakServiceAdapter();
    await eyeBreak.init();
    serviceLocator.registerLazySingleton<IEyeBreakService>(() => eyeBreak);
    initialized.add('EyeBreakService');
  } catch (e, stack) {
    errors.add(DiInitError(
      serviceName: 'EyeBreakService',
      message: e.toString(),
      innerError: e,
      stackTrace: stack,
    ));
  }

  // FokusHistoryService (no async init — but we still register)
  serviceLocator
      .registerLazySingleton<IFokusHistoryService>(() => FokusHistoryServiceAdapter());
  initialized.add('FokusHistoryService');

  // HabitService (no async init)
  serviceLocator.registerLazySingleton<IHabitService>(() => HabitServiceAdapter());
  initialized.add('HabitService');

  // BlueLightService (no async init — it's stateless/pure)
  serviceLocator
      .registerLazySingleton<IBlueLightService>(() => BlueLightServiceAdapter());
  initialized.add('BlueLightService');


  // ShareService (no async init)
  serviceLocator.registerLazySingleton<IShareService>(() => ShareServiceAdapter());
  initialized.add('ShareService');

  // ProfileEngineService (no async init)
  serviceLocator
      .registerLazySingleton<IProfileEngineService>(() => ProfileEngineServiceAdapter());
  initialized.add('ProfileEngineService');

  // ScreenTimeService (no async init)
  serviceLocator
      .registerLazySingleton<IScreenTimeService>(() => ScreenTimeServiceAdapter());
  initialized.add('ScreenTimeService');

  // ── 3. Register clean architecture repositories ──
  // These implement the domain repository interfaces and delegate to
  // the existing service layer. New code should depend on these
  // interfaces instead of calling static services directly.

  serviceLocator.registerLazySingleton<FokusHistoryRepository>(
      () => repo_impl.FokusHistoryRepositoryImpl());
  initialized.add('FokusHistoryRepository');

  serviceLocator.registerLazySingleton<HabitRepository>(
      () => repo_impl.HabitRepositoryImpl());
  initialized.add('HabitRepository');

  serviceLocator.registerLazySingleton<StorageRepository>(
      () => repo_impl.StorageRepositoryImpl());
  // Auto-initializes via SharedPreferences.getInstance() on first method call.
  initialized.add('StorageRepository');

  serviceLocator.registerLazySingleton<SoundRepository>(
      () => repo_impl.SoundRepositoryImpl());
  initialized.add('SoundRepository');

  return DiInitResult(initialized: initialized, errors: errors);
}
