import 'package:flutter/foundation.dart';
import 'mutable_state.dart';
import 'state_builder.dart';

class HistoryState<T> extends MutableState<T> implements ObservableState<T> {
  final List<T> _history = [];
  int _historyIndex = -1;

  HistoryState(T initialValue) : super(initialValue) {
    _history.add(initialValue);
    _historyIndex = 0;
  }

  @override
  void setValue(T newValue) {
    if (_historyIndex < _history.length - 1) {
      _history.removeRange(_historyIndex + 1, _history.length);
    }
    _history.add(newValue);
    _historyIndex++;
    super.value = newValue; // Directly set value, no recursion
  }

  @override
  set value(T newValue) {
    super.value = newValue; // Delegate to MutableState, no history logic here
  }

  void undo() {
    if (_historyIndex > 0) {
      _historyIndex--;
      super.value = _history[_historyIndex]; // Use super.value to avoid recursion
    }
  }

  void redo() {
    if (_historyIndex < _history.length - 1) {
      _historyIndex++;
      super.value = _history[_historyIndex]; // Use super.value to avoid recursion
    }
  }
}

HistoryState<T> historyStateOf<T>(T initialValue) => HistoryState(initialValue);