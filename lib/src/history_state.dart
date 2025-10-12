import 'mutable_state.dart';
import 'observable_state.dart';

class HistoryState<T> extends MutableState<T> implements ObservableState<T> {
  final List<T> _history = [];
  int _historyIndex = -1;
  bool _inSetValue = false; // Prevent recursion

  HistoryState(T initialValue) : super(initialValue) {
    _history.add(initialValue);
    _historyIndex = 0;
  }

  @override
  void setValue(T newValue) {
    if (_inSetValue) return;
    _inSetValue = true;
    try {
      if (_historyIndex < _history.length - 1) {
        _history.removeRange(_historyIndex + 1, _history.length);
      }
      _history.add(newValue);
      _historyIndex++;
      super.value = newValue;
    } finally {
      _inSetValue = false;
    }
  }

  @override
  set value(T newValue) {
    if (_inSetValue) {
      super.value = newValue;
    } else {
      setValue(newValue);
    }
  }

  void undo() {
    if (_historyIndex > 0) {
      _historyIndex--;
      super.value = _history[_historyIndex];
    }
  }

  void redo() {
    if (_historyIndex < _history.length - 1) {
      _historyIndex++;
      super.value = _history[_historyIndex];
    }
  }
}

HistoryState<T> historyStateOf<T>(T initialValue) => HistoryState(initialValue);