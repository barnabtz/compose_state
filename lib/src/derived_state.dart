import 'mutable_state.dart';
import 'state_builder.dart';

class DerivedState<T> {
  final T Function() _computation;
  final ObservableState<T> _state; // Changed from MutableState<T>
  final List<ObservableState> _dependencies; // Changed from MutableState

  DerivedState(this._computation, {List<ObservableState>? dependencies})
      : _state = mutableStateOf(_computation()),
        _dependencies = dependencies ?? [] {
    for (final dep in _dependencies) {
      dep.addListener(_update);
    }
  }

  T get value => _state.value;

  void _update() => ( _state as MutableState<T>).value = _computation(); // Cast to MutableState for setter

  void dispose() {
    for (final dep in _dependencies) {
      dep.removeListener(_update);
    }
    _state.dispose();
  }
}

DerivedState<T> derivedStateOf<T>(T Function() computation, {List<ObservableState>? dependencies}) {
  return DerivedState(computation, dependencies: dependencies);
}