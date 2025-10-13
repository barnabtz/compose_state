import 'dart:async';
import 'package:flutter/foundation.dart';
import 'compose_view_model.dart';
import 'disposable_state.dart';
import 'history_state.dart';
import 'mutable_state.dart';
import 'observable_state.dart';
import 'state_manager.dart';
import 'state_error_handler.dart';
import 'state_exceptions.dart';
import 'serialization_validator.dart';
import 'state_transaction.dart';

class PersistableState<T> extends ChangeNotifier 
    with DisposableState 
    implements ObservableState<T> {
  final MutableState<T> _state;
  final String _key;
  final Persistable _persistable;
  final Map<String, Serializable Function(String)>? typeRegistry;
  Timer? _debounceTimer;
  late final String _stateId;
  final StateErrorHandler _errorHandler;
  final SerializationValidator _validator;
  StateTransaction? _currentTransaction;
  static const _debounceDuration = Duration(milliseconds: 500);

  PersistableState(
    T initialValue, {
    required String fieldName,
    required Persistable persistable,
    this.typeRegistry,
    bool enableHistory = false,
    StateErrorHandler? errorHandler,
  })  : _state = enableHistory ? HistoryState(initialValue) : MutableState(initialValue),
        _key = '${persistable.runtimeType}_$fieldName',
        _persistable = persistable,
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
        
        // Validate serialization before setting
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
        'hasTypeRegistry': typeRegistry != null,
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
        if (_state.value is List && typeRegistry != null) {
          final saved = await _persistable.restoreDynamicList(_key, typeRegistry!);
          if (saved.isNotEmpty && !isDisposed) {
            // Validate deserialized data
            _validator.validateDeserialization<T>(saved);
            _state.setValue(saved as T);
          }
        } else {
          final saved = await _persistable.restore<T>(_key);
          if (saved != null && !isDisposed) {
            // Validate deserialized data
            _validator.validateDeserialization<T>(saved);
            _state.setValue(saved);
          }
        }
      },
      stateKey: _stateId,
      valueType: T,
      metadata: {'key': _key, 'operation': 'load'},
    ).catchError((error) async {
      if (error is StateException) {
        // Try to recover from load error
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
        // Validate before persisting
        _validator.validateSerialization<T>(_state.value);
        
        if (_state.value is List && typeRegistry != null) {
          await _persistable.persistDynamicList(_key, _state.value as List<dynamic>);
        } else {
          await _persistable.persist(_key, _state.value);
        }
      },
      stateKey: _stateId,
      valueType: T,
      metadata: {'key': _key, 'operation': 'persist'},
    ).catchError((error) async {
      if (error is StateException) {
        // Try to recover from persist error
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

  /// Whether this state is currently participating in a transaction.
  bool get isInTransaction => _currentTransaction != null;

  /// Sets the value within a transaction context.
  void setValueInTransaction(T newValue, [StateTransaction? transaction]) {
    final txn = transaction ?? _currentTransaction;
    
    if (txn != null) {
      // Record the change in the transaction
      final previousValue = _state.value;
      txn.addState(this);
      
      // Set the new value
      _state.setValue(newValue);
      
      // Record the change for rollback purposes
      txn.recordChange(this, previousValue, newValue);
    } else {
      // No transaction, just set the value normally
      _state.setValue(newValue);
      _debouncePersist();
    }
  }

  /// Joins a transaction.
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
    
    // Add cleanup callback when transaction completes
    transaction.addCommitCallback(() {
      _currentTransaction = null;
    });
    
    transaction.addRollbackCallback(() {
      _currentTransaction = null;
    });
  }

  /// Leaves the current transaction.
  void leaveTransaction() {
    _currentTransaction = null;
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    if (!isDisposed) {
      _persist();
    }
    // Leave any current transaction before disposing
    if (_currentTransaction != null) {
      leaveTransaction();
    }
    _state.removeListener(notifyListeners);
    _state.dispose();
    StateManager.instance.unregisterState(_stateId);
    super.dispose();
  }
}

PersistableState<T> persistableState<T>(
  T initialValue, {
  required String fieldName,
  required Persistable persistable,
  Map<String, Serializable Function(String)>? typeRegistry,
  bool enableHistory = false,
  StateErrorHandler? errorHandler,
}) =>
    PersistableState(
      initialValue,
      fieldName: fieldName,
      persistable: persistable,
      typeRegistry: typeRegistry,
      enableHistory: enableHistory,
      errorHandler: errorHandler,
    );