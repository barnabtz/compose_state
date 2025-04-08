import 'package:flutter/foundation.dart';
import 'compose_view_model.dart';
import 'mutable_state.dart';

class PersistableState<T> extends ChangeNotifier {
  final MutableState<T> _state;
  final String _key;
  final Persistable _persistable;

  PersistableState(
    T initialValue, {
    required String fieldName,
    required Persistable persistable,
  })  : _state = MutableState(initialValue),
        _key = '${persistable.runtimeType}_$fieldName',
        _persistable = persistable {
    _load();
  }

  T get value => _state.value;

  set value(T newValue) {
    _state.setValue(newValue);
    _persist();
  }

  Future<void> _load() async {
    final saved = await _persistable.restore<T>(_key);
    if (saved != null) _state.setValue(saved);
  }

  Future<void> _persist() async => await _persistable.persist(_key, _state.value);

  @override
  void addListener(VoidCallback listener) => _state.addListener(listener);
  
  @override
  void removeListener(VoidCallback listener) => _state.removeListener(listener);

  @override
  void dispose() {
    super.dispose();
    return _state.dispose();
  }
}

PersistableState<T> persistableState<T>(
  T initialValue, {
  required String fieldName,
  required Persistable persistable,
}) =>
    PersistableState(initialValue, fieldName: fieldName, persistable: persistable);