import 'dart:async';
import 'package:flutter/foundation.dart';
import 'compose_view_model.dart';
import 'history_state.dart';
import 'mutable_state.dart';
import 'state_builder.dart';

class PersistableState<T> extends ChangeNotifier implements ObservableState<T> {
  final MutableState<T> _state;
  final String _key;
  final Persistable _persistable;
  final Map<String, Serializable Function(String)>? typeRegistry;
  Timer? _debounceTimer;
  static const _debounceDuration = Duration(milliseconds: 500);

  PersistableState(
    T initialValue, {
    required String fieldName,
    required Persistable persistable,
    this.typeRegistry,
    bool enableHistory = false,
  })  : _state = enableHistory ? HistoryState(initialValue) : MutableState(initialValue),
        _key = '${persistable.runtimeType}_$fieldName',
        _persistable = persistable {
    _state.addListener(notifyListeners);
    _load();
  }

  @override
  T get value => _state.value;

  @override // Added annotation
  set value(T newValue) {
    _state.setValue(newValue);
    _debouncePersist();
  }

  void undo() {
    if (_state is HistoryState<T>) (_state).undo();
  }

  void redo() {
    if (_state is HistoryState<T>) (_state).redo();
  }

  Future<void> _load() async {
    if (_state.value is List && typeRegistry != null) {
      final saved = await _persistable.restoreDynamicList(_key, typeRegistry!);
      if (saved.isNotEmpty) _state.setValue(saved as T);
    } else {
      final saved = await _persistable.restore<T>(_key);
      if (saved != null) _state.setValue(saved);
    }
  }

  Future<void> _persist() async {
    if (_state.value is List && typeRegistry != null) {
      await _persistable.persistDynamicList(_key, _state.value as List<dynamic>);
    } else {
      await _persistable.persist(_key, _state.value);
    }
  }

  void _debouncePersist() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, _persist);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _persist();
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
  bool enableHistory = false,
}) =>
    PersistableState(
      initialValue,
      fieldName: fieldName,
      persistable: persistable,
      typeRegistry: typeRegistry,
      enableHistory: enableHistory,
    );