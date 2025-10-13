
import 'package:compose_state/compose_state.dart';
import 'package:flutter/material.dart';

class DerivedState<T> implements ObservableState<T> {
  final T Function() _computation;
  final MutableState<T> _state; // Mutable internally for updates
  final List<ObservableState> _dependencies;
  bool _isDisposed = false;

  DerivedState(this._computation, {List<ObservableState>? dependencies})
      : _state = mutableStateOf(_computation()),
        _dependencies = dependencies ?? [] {
    for (final dep in _dependencies) {
      dep.addListener(_update);
    }
  }

  @override
  T get value => _state.value;

  @override
  set value(T newValue) => _state.value = newValue;

  @override
  bool get isDisposed => _isDisposed;

  void _update() => _state.value = _computation();

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