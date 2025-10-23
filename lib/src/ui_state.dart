/// Base class for UI state representation.
///
/// This provides a type-safe way to represent different UI states
/// (loading, error, success) in a single state object.
abstract class UiState<T> {
  const UiState();

  /// Creates a loading state.
  factory UiState.loading() = LoadingState<T>;

  /// Creates an error state with the given error message.
  factory UiState.error(String error) = ErrorState<T>;

  /// Creates a success state with the given data.
  factory UiState.success(T data) = SuccessState<T>;

  /// Creates an empty state (no data, no error).
  factory UiState.empty() = EmptyState<T>;

  /// Pattern matching for UI states.
  R when<R>({
    required R Function() loading,
    required R Function(String error) error,
    required R Function(T data) success,
    R Function()? empty,
  }) {
    if (this is LoadingState<T>) {
      return loading();
    } else if (this is ErrorState<T>) {
      return error((this as ErrorState<T>).error);
    } else if (this is SuccessState<T>) {
      return success((this as SuccessState<T>).data);
    } else if (this is EmptyState<T>) {
      return empty?.call() ?? loading();
    }
    throw StateError('Unknown UI state: $this');
  }

  /// Pattern matching with default values.
  R maybeWhen<R>({
    R Function()? loading,
    R Function(String error)? error,
    R Function(T data)? success,
    R Function()? empty,
    required R Function() orElse,
  }) {
    if (this is LoadingState<T>) {
      return loading?.call() ?? orElse();
    } else if (this is ErrorState<T>) {
      return error?.call((this as ErrorState<T>).error) ?? orElse();
    } else if (this is SuccessState<T>) {
      return success?.call((this as SuccessState<T>).data) ?? orElse();
    } else if (this is EmptyState<T>) {
      return empty?.call() ?? orElse();
    }
    return orElse();
  }

  /// Checks if the state is loading.
  bool get isLoading => this is LoadingState<T>;

  /// Checks if the state is an error.
  bool get isError => this is ErrorState<T>;

  /// Checks if the state is success.
  bool get isSuccess => this is SuccessState<T>;

  /// Checks if the state is empty.
  bool get isEmpty => this is EmptyState<T>;

  /// Gets the data if the state is success, null otherwise.
  T? get data =>
      this is SuccessState<T> ? (this as SuccessState<T>).data : null;

  /// Gets the error message if the state is error, null otherwise.
  String? get error =>
      this is ErrorState<T> ? (this as ErrorState<T>).error : null;
}

/// Loading state indicating that data is being fetched.
class LoadingState<T> extends UiState<T> {
  const LoadingState();

  @override
  String toString() => 'LoadingState<$T>()';

  @override
  bool operator ==(Object other) => other is LoadingState<T>;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// Error state containing an error message.
class ErrorState<T> extends UiState<T> {
  @override
  final String error;

  const ErrorState(this.error);

  @override
  String toString() => 'ErrorState<$T>(error: $error)';

  @override
  bool operator ==(Object other) =>
      other is ErrorState<T> && error == other.error;

  @override
  int get hashCode => Object.hash(runtimeType, error);
}

/// Success state containing the data.
class SuccessState<T> extends UiState<T> {
  @override
  final T data;

  const SuccessState(this.data);

  @override
  String toString() => 'SuccessState<$T>(data: $data)';

  @override
  bool operator ==(Object other) =>
      other is SuccessState<T> && data == other.data;

  @override
  int get hashCode => Object.hash(runtimeType, data);
}

/// Empty state indicating no data and no error.
class EmptyState<T> extends UiState<T> {
  const EmptyState();

  @override
  String toString() => 'EmptyState<$T>()';

  @override
  bool operator ==(Object other) => other is EmptyState<T>;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// Extension methods for UiState to provide convenient operations.
extension UiStateExtensions<T> on UiState<T> {
  /// Maps the data if the state is success.
  UiState<R> map<R>(R Function(T data) mapper) {
    if (this is SuccessState<T>) {
      return UiState.success(mapper((this as SuccessState<T>).data));
    } else if (this is LoadingState<T>) {
      return UiState.loading();
    } else if (this is ErrorState<T>) {
      return UiState.error((this as ErrorState<T>).error);
    } else if (this is EmptyState<T>) {
      return UiState.empty();
    }
    throw StateError('Unknown UI state: $this');
  }

  /// Chains another operation if the state is success.
  UiState<R> flatMap<R>(UiState<R> Function(T data) mapper) {
    if (this is SuccessState<T>) {
      return mapper((this as SuccessState<T>).data);
    } else if (this is LoadingState<T>) {
      return UiState.loading();
    } else if (this is ErrorState<T>) {
      return UiState.error((this as ErrorState<T>).error);
    } else if (this is EmptyState<T>) {
      return UiState.empty();
    }
    throw StateError('Unknown UI state: $this');
  }

  /// Gets the data or returns a default value.
  T getOrElse(T defaultValue) {
    return data ?? defaultValue;
  }

  /// Gets the data or throws an exception if not success.
  T getOrThrow() {
    if (this is SuccessState<T>) {
      return (this as SuccessState<T>).data;
    }
    throw StateError('Cannot get data from $this');
  }
}
