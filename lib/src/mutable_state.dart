import 'package:flutter/foundation.dart';
import 'disposable_state.dart';
import 'equality_checker.dart';
import 'observable_state.dart';
import 'state_manager.dart';
import 'state_error_handler.dart';
import 'state_exceptions.dart';
import 'state_transaction.dart';

class MutableState<T> extends ChangeNotifier 
    with DisposableState 
    implements ObservableState<T> {
  T _value;
  late final String _stateId;
  final Set<String> _tags;
  final Map<String, dynamic> _metadata;
  final EqualityChecker<T> _equalityChecker;
  final StateErrorHandler _errorHandler;
  StateTransaction? _currentTransaction;

  MutableState(
    this._value, {
    Set<String>? tags,
    Map<String, dynamic>? metadata,
    EqualityChecker<T>? equalityChecker,
    StateErrorHandler? errorHandler,
  }) : _tags = tags ?? {},
       _metadata = metadata ?? {},
       _equalityChecker = equalityChecker ?? EqualityChecker<T>(),
       _errorHandler = errorHandler ?? StateErrorHandler() {
    _stateId = StateManager.instance.registerState(
      this,
      tags: _tags,
      metadata: _metadata,
    );
  }

  @override
  T get value {
    return _errorHandler.withErrorBoundarySync(
      'get_value',
      () {
        checkNotDisposed();
        return _value;
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
        if (!equals(newValue)) {
          if (isInTransaction) {
            setValueInTransaction(newValue);
          } else {
            _value = newValue;
            notifyListeners();
          }
        }
      },
      stateKey: _stateId,
      valueType: T,
      metadata: {'newValue': newValue},
    );
  }

  void setValue(T newValue) {
    if (isInTransaction) {
      setValueInTransaction(newValue);
    } else {
      value = newValue;
    }
  }

  /// Whether this state is currently participating in a transaction.
  bool get isInTransaction => _currentTransaction != null;

  /// Sets the value within a transaction context.
  void setValueInTransaction(T newValue, [StateTransaction? transaction]) {
    final txn = transaction ?? _currentTransaction;
    
    if (txn != null) {
      // Record the change in the transaction
      final previousValue = _value;
      txn.addState(this);
      
      // Set the new value
      _value = newValue;
      notifyListeners();
      
      // Record the change for rollback purposes
      txn.recordChange(this, previousValue, newValue);
    } else {
      // No transaction, just set the value normally
      _value = newValue;
      notifyListeners();
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

  /// Gets the state ID for error handling and debugging.
  String get stateId => _stateId;

  /// Gets the error handler for subclasses.
  @protected
  StateErrorHandler get errorHandler => _errorHandler;

  @override
  bool equals(T other) {
    return _equalityChecker.equals(_value, other);
  }

  @override
  StateSnapshot<T> createSnapshot() {
    return _errorHandler.withErrorBoundarySync(
      'create_snapshot',
      () {
        checkNotDisposed();
        return StateSnapshot(
          _value,
          timestamp: DateTime.now(),
          metadata: {
            'stateType': runtimeType.toString(),
            'stateId': _stateId,
          },
        );
      },
      stateKey: _stateId,
      valueType: T,
    );
  }

  @override
  void restoreSnapshot(StateSnapshot<T> snapshot) {
    _errorHandler.withErrorBoundarySync(
      'restore_snapshot',
      () {
        checkNotDisposed();
        value = snapshot.value;
      },
      stateKey: _stateId,
      valueType: T,
      metadata: {'snapshot': snapshot.metadata},
    );
  }

  @override
  void dispose() {
    // Leave any current transaction before disposing
    if (_currentTransaction != null) {
      leaveTransaction();
    }
    StateManager.instance.unregisterState(_stateId);
    super.dispose();
  }
}

MutableState<T> mutableStateOf<T>(
  T initialValue, {
  Set<String>? tags,
  Map<String, dynamic>? metadata,
  EqualityChecker<T>? equalityChecker,
  StateErrorHandler? errorHandler,
}) => MutableState(
  initialValue,
  tags: tags,
  metadata: metadata,
  equalityChecker: equalityChecker,
  errorHandler: errorHandler,
);