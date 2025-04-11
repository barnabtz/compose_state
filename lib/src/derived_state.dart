import 'package:flutter/material.dart';

import 'mutable_state.dart';
import 'state_builder.dart';

class DerivedState<T> implements ObservableState<T> {
  final T Function() _computation;
  final MutableState<T> _state; // Still mutable internally
  final List<ObservableState> _dependencies;

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
  set value(T newValue) => _state.value = newValue; // Allow external updates

  void _update() => _state.value = _computation();

  @override
  void addListener(VoidCallback listener) => _state.addListener(listener);

  @override
  void removeListener(VoidCallback listener) => _state.removeListener(listener);

  @override
  void dispose() {
    for (final dep in _dependencies) {
      dep.removeListener(_update);
    }
    _state.dispose();
  }

  @override
  bool get hasListeners => _state.hasListeners;

  @override
  void notifyListeners() => _state.notifyListeners();
}

DerivedState<T> derivedStateOf<T>(T Function() computation, {List<ObservableState>? dependencies}) {
  return DerivedState(computation, dependencies: dependencies);
}