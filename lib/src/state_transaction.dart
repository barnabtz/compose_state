import 'dart:async';
import 'package:flutter/foundation.dart';
import 'observable_state.dart';
import 'state_exceptions.dart';

/// Represents the current status of a transaction.
enum TransactionStatus {
  /// Transaction is being prepared but not yet started.
  preparing,
  
  /// Transaction is currently active and changes can be made.
  active,
  
  /// Transaction has been committed successfully.
  committed,
  
  /// Transaction has been rolled back due to failure or explicit rollback.
  rolledBack,
  
  /// Transaction failed during commit or rollback.
  failed,
}

/// Represents a single state change within a transaction.
class StateChange<T> {
  final ObservableState<T> state;
  final T previousValue;
  final T newValue;
  final DateTime timestamp;

  const StateChange({
    required this.state,
    required this.previousValue,
    required this.newValue,
    required this.timestamp,
  });
}

/// Encapsulates multiple state changes that should be applied atomically.
/// 
/// A transaction ensures that either all state changes are applied successfully,
/// or none of them are applied (rollback). This maintains consistency across
/// multiple related states.
class StateTransaction {
  final String id;
  final DateTime createdAt;
  final Map<String, dynamic> metadata;
  
  TransactionStatus _status = TransactionStatus.preparing;
  final List<StateChange> _changes = [];
  final Map<ObservableState, StateSnapshot> _snapshots = {};
  final List<VoidCallback> _rollbackCallbacks = [];
  final List<VoidCallback> _commitCallbacks = [];
  
  Completer<void>? _completionCompleter;
  String? _failureReason;

  StateTransaction({
    String? id,
    this.metadata = const {},
  }) : id = id ?? _generateTransactionId(),
       createdAt = DateTime.now();

  /// Current status of the transaction.
  TransactionStatus get status => _status;

  /// Whether the transaction is currently active and can accept changes.
  bool get isActive => _status == TransactionStatus.active;

  /// Whether the transaction has been completed (committed or rolled back).
  bool get isCompleted => _status == TransactionStatus.committed || 
                         _status == TransactionStatus.rolledBack ||
                         _status == TransactionStatus.failed;

  /// List of all state changes in this transaction.
  List<StateChange> get changes => List.unmodifiable(_changes);

  /// Reason for failure if the transaction failed.
  String? get failureReason => _failureReason;

  /// Future that completes when the transaction is finished.
  Future<void> get completion => _completionCompleter?.future ?? Future.value();

  /// Begins the transaction, making it active for state changes.
  void begin() {
    if (_status != TransactionStatus.preparing) {
      throw StateConsistencyException(
        'Cannot begin transaction in status: $_status',
        operation: 'begin_transaction',
        involvedStates: _snapshots.keys.map((s) => s.toString()).toList(),
      );
    }
    
    _status = TransactionStatus.active;
    _completionCompleter = Completer<void>();
  }

  /// Adds a state to the transaction and creates a snapshot of its current value.
  /// 
  /// This must be called before making any changes to the state.
  void addState<T>(ObservableState<T> state) {
    if (!isActive) {
      throw StateConsistencyException(
        'Cannot add state to inactive transaction',
        operation: 'add_state',
        involvedStates: [state.toString()],
      );
    }

    if (_snapshots.containsKey(state)) {
      return; // State already added
    }

    _snapshots[state] = state.createSnapshot();
  }

  /// Records a state change within this transaction.
  /// 
  /// The state must have been added to the transaction first.
  void recordChange<T>(ObservableState<T> state, T previousValue, T newValue) {
    if (!isActive) {
      throw StateConsistencyException(
        'Cannot record change in inactive transaction',
        operation: 'record_change',
        involvedStates: [state.toString()],
      );
    }

    if (!_snapshots.containsKey(state)) {
      throw StateConsistencyException(
        'State not added to transaction',
        operation: 'record_change',
        involvedStates: [state.toString()],
      );
    }

    _changes.add(StateChange<T>(
      state: state,
      previousValue: previousValue,
      newValue: newValue,
      timestamp: DateTime.now(),
    ));
  }

  /// Adds a callback to be executed during rollback.
  void addRollbackCallback(VoidCallback callback) {
    _rollbackCallbacks.add(callback);
  }

  /// Adds a callback to be executed after successful commit.
  void addCommitCallback(VoidCallback callback) {
    _commitCallbacks.add(callback);
  }

  /// Commits the transaction, making all changes permanent.
  /// 
  /// Returns true if the commit was successful, false otherwise.
  Future<bool> commit() async {
    if (!isActive) {
      throw StateConsistencyException(
        'Cannot commit transaction in status: $_status',
        operation: 'commit_transaction',
        involvedStates: _snapshots.keys.map((s) => s.toString()).toList(),
      );
    }

    try {
      // Execute commit callbacks
      for (final callback in _commitCallbacks) {
        callback();
      }

      _status = TransactionStatus.committed;
      _completionCompleter?.complete();
      return true;
    } catch (error, stackTrace) {
      _failureReason = error.toString();
      _status = TransactionStatus.failed;
      _completionCompleter?.completeError(
        StateConsistencyException(
          'Transaction commit failed: $error',
          operation: 'commit_transaction',
          involvedStates: _snapshots.keys.map((s) => s.toString()).toList(),
        ),
        stackTrace,
      );
      return false;
    }
  }

  /// Rolls back the transaction, reverting all state changes.
  /// 
  /// Returns true if the rollback was successful, false otherwise.
  Future<bool> rollback([String? reason]) async {
    if (isCompleted && _status != TransactionStatus.failed) {
      throw StateConsistencyException(
        'Cannot rollback completed transaction',
        operation: 'rollback_transaction',
        involvedStates: _snapshots.keys.map((s) => s.toString()).toList(),
      );
    }

    try {
      // Restore all states to their original values
      for (final entry in _snapshots.entries) {
        final state = entry.key;
        final snapshot = entry.value;
        state.restoreSnapshot(snapshot);
      }

      // Execute rollback callbacks
      for (final callback in _rollbackCallbacks) {
        callback();
      }

      _failureReason = reason;
      _status = TransactionStatus.rolledBack;
      _completionCompleter?.complete();
      return true;
    } catch (error, stackTrace) {
      _failureReason = 'Rollback failed: $error';
      _status = TransactionStatus.failed;
      _completionCompleter?.completeError(
        StateConsistencyException(
          'Transaction rollback failed: $error',
          operation: 'rollback_transaction',
          involvedStates: _snapshots.keys.map((s) => s.toString()).toList(),
        ),
        stackTrace,
      );
      return false;
    }
  }

  /// Generates a unique transaction ID.
  static String _generateTransactionId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp * 31) % 1000000;
    return 'txn_${timestamp}_$random';
  }

  @override
  String toString() {
    return 'StateTransaction(id: $id, status: $_status, changes: ${_changes.length})';
  }
}