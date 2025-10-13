import 'package:flutter/foundation.dart';
import 'disposable_state.dart';
import 'observable_state.dart';
import 'state_manager.dart';

class SignalState<T> extends ChangeNotifier
    with DisposableState
    implements ObservableState<T> {
  T _value;
  final Map<String, VoidCallback> _signalListeners = {};
  late final String _stateId;

  SignalState(this._value) {
    _stateId = StateManager.instance.registerState(this);
  }

  @override
  T get value {
    checkNotDisposed();
    return _value;
  }

  @override
  set value(T newValue) {
    checkNotDisposed();
    if (!equals(newValue)) {
      _value = newValue;
      notifyListeners(); // Notify all
    }
  }

  void addSignalListener(String signalKey, VoidCallback listener) {
    checkNotDisposed();
    _signalListeners[signalKey] = listener;
  }

  void notifySignal(String signalKey) {
    checkNotDisposed();
    _signalListeners[signalKey]?.call();
    notifyListeners(); // Notify all for backward compatibility
  }

  void setValue(T newValue) => value = newValue;

  @override
  bool equals(T other) {
    return identical(_value, other) || _value == other;
  }

  @override
  StateSnapshot<T> createSnapshot() {
    checkNotDisposed();
    return StateSnapshot(
      _value,
      timestamp: DateTime.now(),
      metadata: {
        'stateType': runtimeType.toString(),
        'stateId': _stateId,
        'signalListeners': _signalListeners.keys.toList(),
      },
    );
  }

  @override
  void restoreSnapshot(StateSnapshot<T> snapshot) {
    checkNotDisposed();
    value = snapshot.value;
  }

  @override
  void dispose() {
    _signalListeners.clear();
    StateManager.instance.unregisterState(_stateId);
    super.dispose();
  }
}

SignalState<T> signalStateOf<T>(T initialValue) => SignalState(initialValue);
