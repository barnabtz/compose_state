import 'package:flutter/foundation.dart';
import 'state_builder.dart';

class MutableState<T> extends ChangeNotifier implements ObservableState<T> {
  T _value;

  MutableState(this._value);

  @override
  T get value => _value;

  @override
  set value(T newValue) {
    if (!identical(_value, newValue)) {
      _value = newValue;
      notifyListeners();
    }
  }

  void setValue(T newValue) => value = newValue;
}

MutableState<T> mutableStateOf<T>(T initialValue) => MutableState(initialValue);