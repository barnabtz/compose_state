import 'package:flutter/foundation.dart';

class MutableState<T> extends ChangeNotifier {
  T _value;

  MutableState(this._value);

  T get value => _value;

  set value(T newValue) {
    if (!identical(_value, newValue)) {
      _value = newValue;
      notifyListeners();
    }
  }

  void setValue(T newValue) => value = newValue;

  @override
  void dispose() => super.dispose();
}

MutableState<T> mutableStateOf<T>(T initialValue) => MutableState(initialValue);