import 'package:flutter/foundation.dart';

class MutableState<T> {
  T _value;
  final _listeners = <VoidCallback>[];

  MutableState(this._value);

  T get value => _value;

  set value(T newValue) {
    if (!identical(_value, newValue)) {
      _value = newValue;
      for (final listener in _listeners) listener();
    }
  }

  // Added: Explicit setter for hoisting
  void setValue(T newValue) => value = newValue;

  void addListener(VoidCallback listener) => _listeners.add(listener);
  void removeListener(VoidCallback listener) => _listeners.remove(listener);
  void dispose() => _listeners.clear();
}

MutableState<T> mutableStateOf<T>(T initialValue) => MutableState(initialValue);