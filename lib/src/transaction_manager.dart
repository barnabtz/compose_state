import 'dart:async';
import 'dart:collection';
import 'observable_state.dart';
import 'state_transaction.dart';
import 'state_exceptions.dart';

/// Callback function for transaction events.
typedef TransactionCallback = void Function(StateTransaction transaction);

/// Manages atomic multi-state updates through transactions.
///
/// The TransactionManager ensures that multiple state changes can be
/// applied atomically - either all changes succeed or all are rolled back.
/// It also handles dependency ordering and concurrent update scenarios.
class TransactionManager {
  static final TransactionManager _instance = TransactionManager._internal();

  /// Gets the singleton instance of the TransactionManager.
  factory TransactionManager() => _instance;

  TransactionManager._internal();

  final Map<String, StateTransaction> _activeTransactions = {};
  final Queue<StateTransaction> _transactionQueue = Queue<StateTransaction>();
  final Map<ObservableState, Set<String>> _stateTransactions = {};
  final Map<ObservableState, List<ObservableState>> _dependencies = {};

  bool _isProcessingQueue = false;
  final List<TransactionCallback> _onTransactionStarted = [];
  final List<TransactionCallback> _onTransactionCompleted = [];
  final List<TransactionCallback> _onTransactionFailed = [];

  /// Currently active transactions.
  Map<String, StateTransaction> get activeTransactions =>
      Map.unmodifiable(_activeTransactions);

  /// Number of transactions waiting to be processed.
  int get queueLength => _transactionQueue.length;

  /// Whether the manager is currently processing the transaction queue.
  bool get isProcessingQueue => _isProcessingQueue;

  /// Adds a callback to be called when a transaction starts.
  void onTransactionStarted(TransactionCallback callback) {
    _onTransactionStarted.add(callback);
  }

  /// Adds a callback to be called when a transaction completes successfully.
  void onTransactionCompleted(TransactionCallback callback) {
    _onTransactionCompleted.add(callback);
  }

  /// Adds a callback to be called when a transaction fails.
  void onTransactionFailed(TransactionCallback callback) {
    _onTransactionFailed.add(callback);
  }

  /// Creates a new transaction for atomic state updates.
  ///
  /// The transaction will be in preparing state and needs to be manually
  /// started or used with executeInTransaction.
  StateTransaction createTransaction({
    String? id,
    Map<String, dynamic> metadata = const {},
  }) {
    final transaction = StateTransaction(id: id, metadata: metadata);
    return transaction;
  }

  /// Executes a function within a transaction context.
  ///
  /// The function receives the transaction as a parameter and should
  /// use it to make state changes. The transaction will be automatically
  /// committed if the function completes successfully, or rolled back
  /// if an exception occurs.
  Future<T> executeInTransaction<T>(
    Future<T> Function(StateTransaction transaction) operation, {
    String? transactionId,
    Map<String, dynamic> metadata = const {},
  }) async {
    final transaction = createTransaction(
      id: transactionId,
      metadata: metadata,
    );

    try {
      // Queue and start the transaction
      _queueTransaction(transaction);

      // Wait for the transaction to become active
      await _waitForTransactionToStart(transaction);

      // Execute the operation
      final result = await operation(transaction);

      // Commit the transaction
      final committed = await transaction.commit();
      if (!committed) {
        throw StateConsistencyException(
          'Failed to commit transaction: ${transaction.failureReason}',
          operation: 'execute_in_transaction',
          involvedStates:
              transaction.changes.map((c) => c.state.toString()).toList(),
        );
      }

      return result;
    } catch (error) {
      // Rollback on any error
      await transaction.rollback('Operation failed: $error');
      rethrow;
    }
  }

  /// Defines a dependency relationship between states.
  ///
  /// When [dependent] state changes, [dependency] will be updated first
  /// to maintain consistency.
  void addDependency(ObservableState dependent, ObservableState dependency) {
    _dependencies.putIfAbsent(dependent, () => []).add(dependency);
  }

  /// Removes a dependency relationship between states.
  void removeDependency(ObservableState dependent, ObservableState dependency) {
    _dependencies[dependent]?.remove(dependency);
    if (_dependencies[dependent]?.isEmpty == true) {
      _dependencies.remove(dependent);
    }
  }

  /// Gets all dependencies for a given state.
  List<ObservableState> getDependencies(ObservableState state) {
    return List.unmodifiable(_dependencies[state] ?? []);
  }

  /// Checks if there are any circular dependencies in the dependency graph.
  bool hasCircularDependencies() {
    final visited = <ObservableState>{};
    final recursionStack = <ObservableState>{};

    bool hasCycle(ObservableState state) {
      if (recursionStack.contains(state)) {
        return true; // Circular dependency found
      }
      if (visited.contains(state)) {
        return false; // Already processed
      }

      visited.add(state);
      recursionStack.add(state);

      final dependencies = _dependencies[state] ?? [];
      for (final dependency in dependencies) {
        if (hasCycle(dependency)) {
          return true;
        }
      }

      recursionStack.remove(state);
      return false;
    }

    for (final state in _dependencies.keys) {
      if (hasCycle(state)) {
        return true;
      }
    }

    return false;
  }

  /// Orders states based on their dependencies.
  ///
  /// Returns a list of states in the order they should be updated
  /// to respect dependency constraints.
  List<ObservableState> orderStatesByDependencies(
    List<ObservableState> states,
  ) {
    final result = <ObservableState>[];
    final visited = <ObservableState>{};
    final visiting = <ObservableState>{};

    void visit(ObservableState state) {
      if (visiting.contains(state)) {
        throw StateConsistencyException(
          'Circular dependency detected',
          operation: 'order_states',
          involvedStates: [state.toString()],
        );
      }
      if (visited.contains(state)) {
        return;
      }

      visiting.add(state);

      // Visit dependencies first
      final dependencies = _dependencies[state] ?? [];
      for (final dependency in dependencies) {
        if (states.contains(dependency)) {
          visit(dependency);
        }
      }

      visiting.remove(state);
      visited.add(state);
      result.add(state);
    }

    for (final state in states) {
      visit(state);
    }

    return result;
  }

  /// Queues a transaction for execution.
  void _queueTransaction(StateTransaction transaction) {
    _transactionQueue.add(transaction);
    _processQueue();
  }

  /// Processes the transaction queue.
  Future<void> _processQueue() async {
    if (_isProcessingQueue || _transactionQueue.isEmpty) {
      return;
    }

    _isProcessingQueue = true;

    try {
      while (_transactionQueue.isNotEmpty) {
        final transaction = _transactionQueue.removeFirst();
        await _executeTransaction(transaction);
      }
    } finally {
      _isProcessingQueue = false;
    }
  }

  /// Executes a single transaction.
  Future<void> _executeTransaction(StateTransaction transaction) async {
    try {
      // Check for conflicts with active transactions
      if (_hasConflicts(transaction)) {
        // Wait for conflicting transactions to complete
        await _waitForConflictingTransactions(transaction);
      }

      // Start the transaction
      _activeTransactions[transaction.id] = transaction;
      transaction.begin();

      // Notify listeners
      for (final callback in _onTransactionStarted) {
        callback(transaction);
      }

      // Wait for the transaction to complete
      await transaction.completion;

      // Handle completion
      if (transaction.status == TransactionStatus.committed) {
        for (final callback in _onTransactionCompleted) {
          callback(transaction);
        }
      } else {
        for (final callback in _onTransactionFailed) {
          callback(transaction);
        }
      }
    } catch (error) {
      // Ensure transaction is rolled back on error
      if (transaction.isActive) {
        await transaction.rollback('Transaction execution failed: $error');
      }

      for (final callback in _onTransactionFailed) {
        callback(transaction);
      }
    } finally {
      // Clean up
      _activeTransactions.remove(transaction.id);
      _cleanupStateTransactions(transaction);
    }
  }

  /// Checks if a transaction has conflicts with currently active transactions.
  bool _hasConflicts(StateTransaction transaction) {
    // For now, we consider any overlapping states as conflicts
    // This is a conservative approach that ensures consistency
    for (final activeTransaction in _activeTransactions.values) {
      final activeStates =
          activeTransaction.changes.map((c) => c.state).toSet();
      final newStates = transaction.changes.map((c) => c.state).toSet();

      if (activeStates.intersection(newStates).isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  /// Waits for conflicting transactions to complete.
  Future<void> _waitForConflictingTransactions(
    StateTransaction transaction,
  ) async {
    final conflictingTransactions = <StateTransaction>[];

    for (final activeTransaction in _activeTransactions.values) {
      final activeStates =
          activeTransaction.changes.map((c) => c.state).toSet();
      final newStates = transaction.changes.map((c) => c.state).toSet();

      if (activeStates.intersection(newStates).isNotEmpty) {
        conflictingTransactions.add(activeTransaction);
      }
    }

    // Wait for all conflicting transactions to complete
    await Future.wait(conflictingTransactions.map((t) => t.completion));
  }

  /// Waits for a transaction to start (become active).
  Future<void> _waitForTransactionToStart(StateTransaction transaction) async {
    while (!transaction.isActive && !transaction.isCompleted) {
      await Future.delayed(const Duration(milliseconds: 1));
    }
  }

  /// Cleans up state-transaction mappings after transaction completion.
  void _cleanupStateTransactions(StateTransaction transaction) {
    for (final change in transaction.changes) {
      final stateTransactions = _stateTransactions[change.state];
      stateTransactions?.remove(transaction.id);
      if (stateTransactions?.isEmpty == true) {
        _stateTransactions.remove(change.state);
      }
    }
  }

  /// Clears all transactions and resets the manager state.
  ///
  /// This should only be used for testing or cleanup purposes.
  void clear() {
    _activeTransactions.clear();
    _transactionQueue.clear();
    _stateTransactions.clear();
    _dependencies.clear();
    _isProcessingQueue = false;
  }
}
