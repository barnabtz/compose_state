import 'dart:async';
import 'package:flutter/foundation.dart';

import 'disposable_state.dart';
import 'history_state.dart';
import 'mutable_state.dart';
import 'observable_state.dart';
import 'state_manager.dart';
import 'state_error_handler.dart';
import 'state_exceptions.dart';
import 'serialization_validator.dart';
import 'state_transaction.dart';
import 'storage.dart';

class PersistableState<T> extends ChangeNotifier 
    with DisposableState 
    implements ObservableState<T> {
  final MutableState<T> _state;
  final String _key;
  final Storage _storage;
  Timer? _debounceTimer;
  late final String _stateId;
  final StateErrorHandler _errorHandler;
  final SerializationValidator _validator;
  StateTransaction? _currentTransaction;
  static const _debounceDuration = Duration(milliseconds: 500);

  PersistableState(
    T initialValue, {
    required String key,
    required Storage storage,
    bool enableHistory = false,
    StateErrorHandler? errorHandler,
  })  : _state = enableHistory ? HistoryState(initialValue) : MutableState(initialValue),
        _key = key,
        _storage = storage,
        _errorHandler = errorHandler ?? StateErrorHandler(),
        _validator = SerializationValidator.instance {
    _stateId = StateManager.instance.registerState(this);
    _state.addListener(notifyListeners);
    _load();
  }

  @override
  T get value {
    return _errorHandler.withErrorBoundarySync(
      'get_value',
      () {
        checkNotDisposed();
        return _state.value;
      },
      stateKey: _stateId,
      valueType: T,
    );
  }

  @override
  set value(T newValue) {
    _errorHandler.withErrorBoundarySync(
      'set_value',
      () {
        checkNotDisposed();
        
        _validator.validateSerialization<T>(newValue);
        
        if (isInTransaction) {
          setValueInTransaction(newValue);
        } else {
          _state.setValue(newValue);
          _debouncePersist();
        }
      },
      stateKey: _stateId,
      valueType: T,
      metadata: {'key': _key, 'newValue': newValue},
    );
  }

  void undo() {
    checkNotDisposed();
    if (_state is HistoryState<T>) _state.undo();
  }

  void redo() {
    checkNotDisposed();
    if (_state is HistoryState<T>) _state.redo();
  }

  @override
  bool equals(T other) => _state.equals(other);

  @override
  StateSnapshot<T> createSnapshot() {
    checkNotDisposed();
    final baseSnapshot = _state.createSnapshot();
    return StateSnapshot(
      baseSnapshot.value,
      timestamp: baseSnapshot.timestamp,
      metadata: {
        ...baseSnapshot.metadata,
        'persistenceKey': _key,
      },
    );
  }

  @override
  void restoreSnapshot(StateSnapshot<T> snapshot) {
    checkNotDisposed();
    _state.restoreSnapshot(snapshot);
    _debouncePersist();
  }

  Future<void> _load() async {
    if (isDisposed) return;
    
    await _errorHandler.withErrorBoundary(
      'load_state',
      () async {
        final saved = await _storage.read<T>(_key);
        if (saved != null && !isDisposed) {
          _validator.validateDeserialization<T>(saved);
          _state.setValue(saved);
        }
      },
      stateKey: _stateId,
      valueType: T,
      metadata: {'key': _key, 'operation': 'load'},
    ).catchError((error) async {
      if (error is StateException) {
        final recovered = await _errorHandler.handleError<T>(
          error,
          ErrorContext(
            stateKey: _stateId,
            operation: 'load_state',
            valueType: T,
            metadata: {'key': _key},
          ),
          lastKnownValue: _state.value,
        );
        if (!isDisposed) {
          _state.setValue(recovered);
        }
      }
    });
  }

  Future<void> _persist() async {
    if (isDisposed) return;
    
    await _errorHandler.withErrorBoundary(
      'persist_state',
      () async {
        _validator.validateSerialization<T>(_state.value);
        await _storage.write<T>(_key, _state.value);
      },
      stateKey: _stateId,
      valueType: T,
      metadata: {'key': _key, 'operation': 'persist'},
    ).catchError((error) async {
      if (error is StateException) {
        await _errorHandler.handleError<void>(
          error,
          ErrorContext(
            stateKey: _stateId,
            operation: 'persist_state',
            valueType: T,
            metadata: {'key': _key, 'value': _state.value},
          ),
        );
      }
    });
  }

  void _debouncePersist() {
    if (isDisposed) return;
    
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, _persist);
  }

  bool get isInTransaction => _currentTransaction != null;

  void setValueInTransaction(T newValue, [StateTransaction? transaction]) {
    final txn = transaction ?? _currentTransaction;
    
    if (txn != null) {
      final previousValue = _state.value;
      txn.addState(this);
      
      _state.setValue(newValue);
      
      txn.recordChange(this, previousValue, newValue);
    } else {
      _state.setValue(newValue);
      _debouncePersist();
    }
  }

  void joinTransaction(StateTransaction transaction) {
    if (_currentTransaction != null && _currentTransaction != transaction) {
      throw StateConsistencyException(
        'State is already participating in another transaction',
        operation: 'join_transaction',
        involvedStates: [toString()],
      );
    }

    _currentTransaction = transaction;
    transaction.addState(this);
    
    transaction.addCommitCallback(() {
      _currentTransaction = null;
    });
    
    transaction.addRollbackCallback(() {
      _currentTransaction = null;
    });
  }

  void leaveTransaction() {
    _currentTransaction = null;
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    if (!isDisposed) {
      _persist();
    }
    if (_currentTransaction != null) {
      leaveTransaction();
    }
    _state.removeListener(notifyListeners);
    _state.dispose();
    StateManager.instance.unregisterState(_stateId);
    super.dispose();
  }
}

PersistableState<T> persistableStateOf<T>(
  String key,
  T initialValue, {
  Storage? storage,
  bool enableHistory = false,
  StateErrorHandler? errorHandler,
}) =>
    PersistableState(
      initialValue,
      key: key,
      storage: storage ?? SharedPreferencesStorage(),
      enableHistory: enableHistory,
      errorHandler: errorHandler,
    );
