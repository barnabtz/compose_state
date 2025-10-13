import 'mutable_state.dart';
import 'observable_state.dart';
import 'state_error_handler.dart';
import 'state_exceptions.dart';
import 'equality_checker.dart';

class HistoryState<T> extends MutableState<T> implements ObservableState<T> {
  final List<T> _history = [];
  final List<StateSnapshot<T>> _transactionHistory = [];
  int _historyIndex = -1;
  bool _inSetValue = false; // Prevent recursion
  int? _transactionStartIndex; // Track where transaction started

  HistoryState(
    T initialValue, {
    super.tags,
    super.metadata,
    super.equalityChecker,
    super.errorHandler,
  }) : super(initialValue) {
    _history.add(initialValue);
    _historyIndex = 0;
  }

  /// Gets the error handler from the parent class.
  StateErrorHandler get _errorHandler => super.errorHandler;

  @override
  void setValue(T newValue) {
    if (_inSetValue) return;
    
    _errorHandler.withErrorBoundarySync(
      'set_history_value',
      () {
        _inSetValue = true;
        try {
          // Handle transaction context
          if (isInTransaction) {
            // Mark transaction start if this is the first change in transaction
            _transactionStartIndex ??= _historyIndex;
            setValueInTransaction(newValue);
          } else {
            // Normal history operation
            if (_historyIndex < _history.length - 1) {
              _history.removeRange(_historyIndex + 1, _history.length);
            }
            _history.add(newValue);
            _historyIndex++;
            super.value = newValue;
          }
        } finally {
          _inSetValue = false;
        }
      },
      stateKey: stateId,
      valueType: T,
      metadata: {
        'historyIndex': _historyIndex,
        'historyLength': _history.length,
        'inTransaction': isInTransaction,
      },
    );
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
    _errorHandler.withErrorBoundarySync(
      'undo',
      () {
        checkNotDisposed();
        
        if (isInTransaction) {
          throw StateConsistencyException(
            'Cannot undo while in transaction',
            operation: 'undo',
            involvedStates: [toString()],
          );
        }
        
        if (_historyIndex > 0) {
          _historyIndex--;
          _inSetValue = true;
          try {
            super.value = _history[_historyIndex];
          } finally {
            _inSetValue = false;
          }
        }
      },
      stateKey: stateId,
      valueType: T,
      metadata: {
        'currentIndex': _historyIndex,
        'canUndo': _historyIndex > 0,
      },
    );
  }

  void redo() {
    _errorHandler.withErrorBoundarySync(
      'redo',
      () {
        checkNotDisposed();
        
        if (isInTransaction) {
          throw StateConsistencyException(
            'Cannot redo while in transaction',
            operation: 'redo',
            involvedStates: [toString()],
          );
        }
        
        if (_historyIndex < _history.length - 1) {
          _historyIndex++;
          _inSetValue = true;
          try {
            super.value = _history[_historyIndex];
          } finally {
            _inSetValue = false;
          }
        }
      },
      stateKey: stateId,
      valueType: T,
      metadata: {
        'currentIndex': _historyIndex,
        'canRedo': _historyIndex < _history.length - 1,
      },
    );
  }

  /// Gets whether undo is available.
  bool get canUndo => _historyIndex > 0 && !isInTransaction;

  /// Gets whether redo is available.
  bool get canRedo => _historyIndex < _history.length - 1 && !isInTransaction;

  /// Gets the current history length.
  int get historyLength => _history.length;

  /// Gets the current position in history.
  int get currentHistoryIndex => _historyIndex;

  /// Clears all history and resets to current value.
  void clearHistory() {
    _errorHandler.withErrorBoundarySync(
      'clear_history',
      () {
        checkNotDisposed();
        
        if (isInTransaction) {
          throw StateConsistencyException(
            'Cannot clear history while in transaction',
            operation: 'clear_history',
            involvedStates: [toString()],
          );
        }
        
        final currentValue = value;
        _history.clear();
        _history.add(currentValue);
        _historyIndex = 0;
        _transactionHistory.clear();
      },
      stateKey: stateId,
      valueType: T,
    );
  }

  /// Creates a transaction-aware snapshot that includes history state.
  @override
  StateSnapshot<T> createSnapshot() {
    final baseSnapshot = super.createSnapshot();
    return StateSnapshot(
      baseSnapshot.value,
      timestamp: baseSnapshot.timestamp,
      metadata: {
        ...baseSnapshot.metadata,
        'historyIndex': _historyIndex,
        'historyLength': _history.length,
        'transactionStartIndex': _transactionStartIndex,
        'history': _history.toList(), // Copy of history for rollback
      },
    );
  }

  /// Restores from snapshot with history consistency checks.
  @override
  void restoreSnapshot(StateSnapshot<T> snapshot) {
    _errorHandler.withErrorBoundarySync(
      'restore_snapshot',
      () {
        checkNotDisposed();
        
        final metadata = snapshot.metadata;
        if (metadata.containsKey('history')) {
          // Restore full history state
          final savedHistory = metadata['history'] as List<T>?;
          final savedIndex = metadata['historyIndex'] as int?;
          
          if (savedHistory != null && savedIndex != null) {
            _history.clear();
            _history.addAll(savedHistory);
            _historyIndex = savedIndex;
            
            _inSetValue = true;
            try {
              super.value = _history[_historyIndex];
            } finally {
              _inSetValue = false;
            }
          }
        } else {
          // Fallback to basic restore
          super.restoreSnapshot(snapshot);
        }
      },
      stateKey: stateId,
      valueType: T,
      metadata: snapshot.metadata,
    );
  }


}

HistoryState<T> historyStateOf<T>(
  T initialValue, {
  Set<String>? tags,
  Map<String, dynamic>? metadata,
  EqualityChecker<T>? equalityChecker,
  StateErrorHandler? errorHandler,
}) => HistoryState(
  initialValue,
  tags: tags,
  metadata: metadata,
  equalityChecker: equalityChecker,
  errorHandler: errorHandler,
);