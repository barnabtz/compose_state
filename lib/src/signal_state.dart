import 'package:flutter/foundation.dart';
import 'observable_state.dart';

class SignalState<T> extends ChangeNotifier implements ObservableState<T> {
  T _value;
  final Map<String, VoidCallback> _signalListeners = {};

  SignalState(this._value);

  @override
  T get value => _value;

  @override
  set value(T newValue) {
    if (!identical(_value, newValue)) {
      _value = newValue;
      notifyListeners(); // Notify all
    }
  }

  void addSignalListener(String signalKey, VoidCallback listener) {
    _signalListeners[signalKey] = listener;
  }

  void notifySignal(String signalKey) {
    _signalListeners[signalKey]?.call();
    notifyListeners(); // Notify all for backward compatibility
  }

  void setValue(T newValue) => value = newValue;
}

SignalState<T> signalStateOf<T>(T initialValue) => SignalState(initialValue);