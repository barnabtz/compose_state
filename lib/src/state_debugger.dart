import 'package:flutter/foundation.dart';
import 'observable_state.dart';

class StateDebugger<T> implements ObservableState<T> {
  final ObservableState<T> _wrapped;
  final String _name;

  StateDebugger(this._wrapped, this._name);

  @override
  T get value {
    debugPrint('[$_name] Get value: $_wrapped.value');
    return _wrapped.value;
  }

  @override
  set value(T newValue) {
    debugPrint('[$_name] Set value: $newValue');
    _wrapped.value = newValue;
  }

  @override
  void addListener(VoidCallback listener) => _wrapped.addListener(listener);

  @override
  void removeListener(VoidCallback listener) => _wrapped.removeListener(listener);

  void dispose() {
    // Note: ObservableState doesn't define dispose, but wrapped implementations might
    if (_wrapped is ChangeNotifier) {
      (_wrapped as ChangeNotifier).dispose();
    }
  }
}

StateDebugger<T> debuggerStateOf<T>(ObservableState<T> state, String name) => StateDebugger(state, name);