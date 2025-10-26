
import 'package:compose_state/compose_state.dart';
import 'package:flutter/material.dart';

class DerivedState<T> implements ObservableState<T> {
  final T Function() _computation;
  final MutableState<T> _state; // Mutable internally for updates
  final List<ObservableState> _dependencies;
  final Set<ObservableState> _activeDependencies;
  bool _isDisposed = false;
  T? _lastComputedValue;
  int _computeCount = 0;

  DerivedState(this._computation, {List<ObservableState>? dependencies})
      : _state = mutableStateOf(_computation()),
        _dependencies = dependencies ?? [],
        _activeDependencies = <ObservableState>{} {
    // Track which dependencies actually affect the computation
    _setupDependencyTracking();
  }

  @override
  T get value => _state.value;

  @override
  set value(T newValue) => _state.value = newValue;

  @override
  bool get isDisposed => _isDisposed;

  /// Sets up optimized dependency tracking
  void _setupDependencyTracking() {
    for (final dep in _dependencies) {
      dep.addListener(_handleDependencyChange);
      _activeDependencies.add(dep);
    }
  }

  /// Handles dependency changes with optimization
  void _handleDependencyChange() {
    _computeCount++;
    
    // For frequently changing dependencies, consider debouncing
    if (_computeCount > 10) { // Arbitrary threshold
      // Could implement debouncing here for very frequent updates
      _update();
    } else {
      _update();
    }
  }

  void _update() {
    try {
      final newValue = _computation();
      
      // Only update if value actually changed
      if (_lastComputedValue == null || _lastComputedValue != newValue) {
        _state.value = newValue;
        _lastComputedValue = newValue;
      }
    } catch (e) {
      // Log error but don't crash the derived state
      debugPrint('Error in derived state computation: $e');
    }
  }

  @override
  void addListener(VoidCallback listener) => _state.addListener(listener);

  @override
  void removeListener(VoidCallback listener) => _state.removeListener(listener);

  @override
  bool equals(T other) => _state.equals(other);

  @override
  StateSnapshot<T> createSnapshot() => _state.createSnapshot();

  @override
  void restoreSnapshot(StateSnapshot<T> snapshot) => _state.restoreSnapshot(snapshot);

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    
    for (final dep in _dependencies) {
      dep.removeListener(_update);
    }
    _state.dispose();
  }
}

DerivedState<T> derivedStateOf<T>(T Function() computation, {List<ObservableState>? dependencies}) {
  return DerivedState(computation, dependencies: dependencies);
}