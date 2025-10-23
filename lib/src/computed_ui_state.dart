import 'package:compose_state/compose_state.dart';
import 'package:flutter/foundation.dart';


/// A computed UI state that derives its value from multiple source states
/// and provides a single UiState representation.
class ComputedUiState<T> implements ObservableState<UiState<T>> {
  final UiState<T> Function() _computation;
  final List<ObservableState> _dependencies;
  final StateErrorHandler _errorHandler;
  late final String _stateId;
  bool _isDisposed = false;
  bool _isUpdating = false;

  // Internal state for the computed UI state
  late final MutableState<UiState<T>> _internalState;

  ComputedUiState(
    this._computation, {
    List<ObservableState>? dependencies,
    StateErrorHandler? errorHandler,
  }) : _dependencies = dependencies ?? [],
       _errorHandler = errorHandler ?? StateErrorHandler() {
    _stateId = StateManager.instance.registerState(this);
    _internalState = MutableState<UiState<T>>(UiState.loading());

    _validateDependencies();
    _setupDependencyListeners();
    _performInitialComputation();
  }

  @override
  UiState<T> get value => _internalState.value;

  @override
  set value(UiState<T> newValue) {
    _internalState.value = newValue;
  }

  @override
  bool get isDisposed => _isDisposed;

  @override
  void addListener(VoidCallback listener) =>
      _internalState.addListener(listener);

  @override
  void removeListener(VoidCallback listener) =>
      _internalState.removeListener(listener);

  @override
  bool equals(UiState<T> other) => _internalState.equals(other);

  @override
  StateSnapshot<UiState<T>> createSnapshot() => _internalState.createSnapshot();

  @override
  void restoreSnapshot(StateSnapshot<UiState<T>> snapshot) =>
      _internalState.restoreSnapshot(snapshot);

  void _validateDependencies() {
    for (final dep in _dependencies) {
      if (dep.isDisposed) {
        throw const StateValidationException(
          'Cannot create computed UI state with disposed dependency',
          violatedRule: 'dependency_validation',
        );
      }
    }
  }

  void _setupDependencyListeners() {
    for (final dep in _dependencies) {
      dep.addListener(_safeUpdate);
    }
  }

  void _performInitialComputation() {
    _safeUpdate();
  }

  void _safeUpdate() {
    if (_isDisposed || _isUpdating) return;

    _isUpdating = true;

    try {
      // Validate dependencies are still valid
      for (final dep in _dependencies) {
        if (dep.isDisposed) {
          throw const StateValidationException(
            'Dependency was disposed during computation',
            violatedRule: 'dependency_disposed',
          );
        }
      }

      final newUiState = _computation();
      _internalState.value = newUiState;
    } catch (error) {
      final errorState = UiState.error(
        error is StateException ? error.message : 'Computation failed: $error',
      );
      _internalState.value = errorState as UiState<T>;

      _errorHandler.handleError<UiState<T>>(
        error is StateException
            ? error
            : StateValidationException(
              'UI state computation failed: $error',
              cause: error,
              violatedRule: 'ui_computation_error',
            ),
        ErrorContext(
          stateKey: _stateId,
          operation: 'ui_state_computation',
          valueType: UiState<T>,
        ),
        lastKnownValue: _internalState.value,
      );
    } finally {
      _isUpdating = false;
    }
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;

    for (final dep in _dependencies) {
      dep.removeListener(_safeUpdate);
    }

    StateManager.instance.unregisterState(_stateId);
    _internalState.dispose();
  }
}

/// Creates a computed UI state that derives from multiple source states.
ComputedUiState<T> computedUiStateOf<T>(
  UiState<T> Function() computation, {
  List<ObservableState>? dependencies,
  StateErrorHandler? errorHandler,
}) {
  return ComputedUiState<T>(
    computation,
    dependencies: dependencies,
    errorHandler: errorHandler,
  );
}

/// Extension methods for creating computed UI states from existing states.
extension ComputedUiStateExtensions on ObservableState {
  /// Creates a computed UI state that maps this state to a UiState.
  ComputedUiState<T> toUiState<T>(UiState<T> Function(dynamic value) mapper) {
    return ComputedUiState<T>(() => mapper(value), dependencies: [this]);
  }

  /// Creates a loading UI state that becomes success when this state has a value.
  ComputedUiState<T> toLoadingUiState<T>() {
    return ComputedUiState<T>(() {
      if (value == null) {
        return UiState.loading();
      }
      return UiState.success(value as T);
    }, dependencies: [this]);
  }
}

/// Extension for creating computed UI states from multiple states.
extension MultiStateUiStateExtensions on List<ObservableState> {
  /// Creates a computed UI state from multiple source states.
  ComputedUiState<T> toComputedUiState<T>(
    UiState<T> Function(List<dynamic> values) computation,
  ) {
    return ComputedUiState<T>(
      () => computation(map((state) => state.value).toList()),
      dependencies: this,
    );
  }
}
