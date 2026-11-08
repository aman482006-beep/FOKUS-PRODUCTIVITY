/// A simple Result type for error handling without exceptions.
///
/// Encapsulates either a successful [value] or a [failure] with details.
/// Use this in service methods instead of throwing exceptions to make
/// error handling explicit at the call site.
sealed class Result<T> {
  const Result();

  /// Whether this result represents a successful outcome.
  bool get isSuccess => this is Success<T>;

  /// Whether this result represents a failure.
  bool get isFailure => this is Failure<T>;

  /// Unwraps the value or throws if this is a Failure.
  T get requireValue {
    return switch (this) {
      Success<T>(:final value) => value,
      Failure<T>(:final error) => throw error,
    };
  }

  /// Returns the value if success, or [orElse] if failure.
  T valueOr(T orElse) => switch (this) {
        Success<T>(:final value) => value,
        Failure<T>() => orElse,
      };

  /// Maps the success value using [transform].
  Result<U> map<U>(U Function(T value) transform) => switch (this) {
        Success<T>(:final value) => Success(transform(value)),
        Failure<T>(:final error, :final stackTrace) => Failure(error, stackTrace),
      };

  /// Maps the success value using [transform], or handles the error with [onError].
  U fold<U>(U Function(T value) transform, U Function(ResultError error) onError) =>
      switch (this) {
        Success<T>(:final value) => transform(value),
        Failure<T>(:final error) => onError(error),
      };

  /// Runs [action] if this is a Success.
  void onSuccess(void Function(T value) action) {
    if (this is Success<T>) action((this as Success<T>).value);
  }

  /// Runs [action] if this is a Failure.
  void onFailure(void Function(ResultError error) action) {
    if (this is Failure<T>) action((this as Failure<T>).error);
  }
}

final class Success<T> extends Result<T> {
  final T value;
  const Success(this.value);
}

final class Failure<T> extends Result<T> {
  final ResultError error;
  final StackTrace? stackTrace;
  const Failure(this.error, [this.stackTrace]);
}

/// Describes a failure with a message, optional code, and optional inner error.
class ResultError {
  final String message;
  final String? code;
  final Object? innerError;

  const ResultError(this.message, {this.code, this.innerError});

  @override
  String toString() => 'ResultError($code): $message${innerError != null ? ' (inner: $innerError)' : ''}';
}

/// Utility for constructing Results from operations that may throw.
///
/// Usage:
///   ```dart
///   final result = ResultCatcher.guard(() => riskyOperation());
///   ```
class ResultCatcher {
  static Result<T> guard<T>(T Function() fn, {String? errorMessage}) {
    try {
      return Success(fn());
    } catch (e, stack) {
      return Failure(
        ResultError(
          errorMessage ?? e.toString(),
          innerError: e,
        ),
        stack,
      );
    }
  }

  static Future<Result<T>> guardAsync<T>(Future<T> Function() fn, {String? errorMessage}) async {
    try {
      final value = await fn();
      return Success(value);
    } catch (e, stack) {
      return Failure(
        ResultError(
          errorMessage ?? e.toString(),
          innerError: e,
        ),
        stack,
      );
    }
  }
}
