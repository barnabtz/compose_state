import 'mutable_state.dart';

class DerivedState<T> {
  final T Function() _computation;
  final MutableState<T> _state;
  final List<MutableState> _dependencies;

  DerivedState(this._computation, {List<MutableState>? dependencies})
      : _state = mutableStateOf(_computation()),
        _dependencies = dependencies ?? [] {
    for (final dep in _dependencies) {
      dep.addListener(_update);
    }
  }

  T get value => _state.value;

  void _update() => _state.value = _computation();

  void dispose() {
    for (final dep in _dependencies) {
      dep.removeListener(_update);
    }
    _state.dispose();
  }
}

DerivedState<T> derivedStateOf<T>(T Function() computation, {List<MutableState>? dependencies}) {
  return DerivedState(computation, dependencies: dependencies);
}