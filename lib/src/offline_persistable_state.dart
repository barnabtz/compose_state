import 'dart:collection';
import 'package:compose_state/compose_state.dart';


class OfflinePersistableState<T> extends PersistableState<T> {
  final Queue<T> _queue = Queue<T>(); // Offline queue
  bool _isOnline = true;

  OfflinePersistableState(
    super.initialValue, {
    required super.fieldName,
    required super.persistable,
    super.typeRegistry,
    super.enableHistory = false,
  });

  @override
  set value(T newValue) {
    super.value = newValue;
    if (!_isOnline) {
      _queue.add(newValue); // Queue offline
    }
  }

  void syncOffline() async {
    while (_queue.isNotEmpty) {
      final queued = _queue.removeFirst();
      // Set the value to trigger persistence in the parent class
      super.value = queued;
    }
  }

  void setOnline(bool online) {
    _isOnline = online;
    if (online) syncOffline();
  }
}