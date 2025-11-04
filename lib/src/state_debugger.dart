import 'package:flutter/foundation.dart';
import 'observable_state.dart';

class StateDebugger<T> implements ObservableState<T> {
  final ObservableState<T> _wrapped;
  final String _name;

  StateDebugger(this._wrapped, this._name);

  @override
  T get value {
    debugPrint('[${DateTime.now()}] [$_name] Get value: ${_wrapped.value}');
    return _wrapped.value;
  }

  @override
  set value(T newValue) {
    debugPrint('[${DateTime.now()}] [$_name] Set value: $newValue');
    _wrapped.value = newValue;
  }

  @override
  bool get isDisposed => _wrapped.isDisposed;

  @override
  void addListener(VoidCallback listener) => _wrapped.addListener(listener);

  @override
  void removeListener(VoidCallback listener) => _wrapped.removeListener(listener);

  @override
  bool equals(T other) {
    debugPrint('[${DateTime.now()}] [$_name] Equals check: ${_wrapped.value} == $other');
    return _wrapped.equals(other);
  }

  @override
  StateSnapshot<T> createSnapshot() {
    debugPrint('[${DateTime.now()}] [$_name] Creating snapshot');
    return _wrapped.createSnapshot();
  }

  @override
  void restoreSnapshot(StateSnapshot<T> snapshot) {
    debugPrint('[${DateTime.now()}] [$_name] Restoring snapshot: ${snapshot.value}');
    _wrapped.restoreSnapshot(snapshot);
  }

  @override
  void dispose() {
    debugPrint('[${DateTime.now()}] [$_name] Disposing state');
    _wrapped.dispose();
  }
}

StateDebugger<T> debuggerStateOf<T>(ObservableState<T> state, String name) => StateDebugger(state, name);