import 'mutable_state.dart';

class HistoryState<T> extends MutableState<T> {
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
    super.setValue(newValue);
  }

  void undo() {
    if (_historyIndex > 0) {
      _historyIndex--;
      super.setValue(_history[_historyIndex]);
    }
  }

  void redo() {
    if (_historyIndex < _history.length - 1) {
      _historyIndex++;
      super.setValue(_history[_historyIndex]);
    }
  }
}

HistoryState<T> historyStateOf<T>(T initialValue) => HistoryState(initialValue);