import 'package:flutter/foundation.dart';
import 'compose_view_model.dart';
import 'mutable_state.dart';

class PersistableState<T> extends ChangeNotifier {
  final MutableState<T> _state;
  final String _key;
  final Persistable _persistable;
  final Map<String, Serializable Function(String)>? typeRegistry;

  PersistableState(
    T initialValue, {
    required String fieldName,
    required Persistable persistable,
    this.typeRegistry,
  })  : _state = MutableState(initialValue),
        _key = '${persistable.runtimeType}_$fieldName',
        _persistable = persistable {
    _state.addListener(notifyListeners); // Forward _state changes
    _load();
  }

  T get value => _state.value;

  set value(T newValue) {
    _state.setValue(newValue);
    _persist();
  }

  Future<void> _load() async {
    if (_isListOfSerializable() && typeRegistry != null) {
      final saved = await _persistable.restoreDynamicList(_key, typeRegistry!);
      if (saved.isNotEmpty) _state.setValue(saved as T);
    } else {
      final saved = await _persistable.restore<T>(_key);
      if (saved != null) _state.setValue(saved);
    }
  }

  Future<void> _persist() async {
    if (_isListOfSerializable() && typeRegistry != null) {
      await _persistable.persistDynamicList(_key, _state.value as List<dynamic>);
    } else {
      await _persistable.persist(_key, _state.value);
    }
  }

  bool _isListOfSerializable() {
    return _state.value is List && (_state.value as List).every((item) => item is Serializable);
  }

  @override
  void dispose() {
    _state.removeListener(notifyListeners);
    _state.dispose();
    super.dispose();
  }
}

PersistableState<T> persistableState<T>(
  T initialValue, {
  required String fieldName,
  required Persistable persistable,
  Map<String, Serializable Function(String)>? typeRegistry,
}) =>
    PersistableState(
      initialValue,
      fieldName: fieldName,
      persistable: persistable,
      typeRegistry: typeRegistry,
    );