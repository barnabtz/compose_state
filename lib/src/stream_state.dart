import 'dart:async';
import 'mutable_state.dart';
import 'state_builder.dart';

class StreamState<T> extends MutableState<T> implements ObservableState<T> {
  StreamSubscription<T>? _subscription;

  StreamState(super.initialValue);

  // Removed unnecessary override
  // @override
  // set value(T newValue) => super.value = newValue;

  void bind(Stream<T> stream) {
    _subscription?.cancel();
    _subscription = stream.listen((value) => this.value = value);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

StreamState<T> streamStateOf<T>(Stream<T> stream, T initialValue) {
  final state = StreamState(initialValue);
  state.bind(stream);
  return state;
}