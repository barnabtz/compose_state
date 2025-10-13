import 'observable_state.dart';
import 'state_transaction.dart';
import 'transaction_manager.dart';
import 'state_exceptions.dart';

/// Mixin that adds transaction support to state implementations.
/// 
/// This mixin provides methods for participating in transactions
/// and ensures that state changes are properly tracked and can be
/// rolled back if needed.
mixin TransactionalStateMixin<T> on ObservableState<T> {
  StateTransaction? _currentTransaction;
  final TransactionManager _transactionManager = TransactionManager();

  /// The current transaction this state is participating in, if any.
  StateTransaction? get currentTransaction => _currentTransaction;

  /// Whether this state is currently participating in a transaction.
  bool get isInTransaction => _currentTransaction != null;

  /// Sets the value within a transaction context.
  /// 
  /// If the state is currently in a transaction, the change will be
  /// recorded for potential rollback. Otherwise, it behaves like a
  /// normal value assignment.
  void setValueInTransaction(T newValue, [StateTransaction? transaction]) {
    final txn = transaction ?? _currentTransaction;
    
    if (txn != null) {
      // Record the change in the transaction
      final previousValue = value;
      txn.addState(this);
      
      // Set the new value
      value = newValue;
      
      // Record the change for rollback purposes
      txn.recordChange(this, previousValue, newValue);
    } else {
      // No transaction, just set the value normally
      value = newValue;
    }
  }

  /// Joins a transaction, allowing this state to participate in atomic updates.
  /// 
  /// Once joined, all value changes should use [setValueInTransaction]
  /// to ensure they can be rolled back if the transaction fails.
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
  /// 
  /// This should typically only be called when a transaction is being
  /// rolled back or when the state is being disposed.
  void leaveTransaction() {
    _currentTransaction = null;
  }

  /// Creates a transactional update that can be committed or rolled back.
  /// 
  /// This is a convenience method that creates a transaction, applies
  /// the update function, and returns the transaction for manual control.
  StateTransaction createTransactionalUpdate(void Function() updateFunction) {
    final transaction = _transactionManager.createTransaction();
    
    // Wait for transaction to become active, then apply updates
    transaction.completion.then((_) {
      if (transaction.isActive) {
        joinTransaction(transaction);
        updateFunction();
      }
    });
    
    return transaction;
  }

  /// Executes multiple state changes atomically.
  /// 
  /// All changes within the [updates] function will be applied together
  /// or rolled back together if any error occurs.
  Future<void> executeAtomicUpdate(void Function() updates) async {
    await _transactionManager.executeInTransaction((transaction) async {
      joinTransaction(transaction);
      updates();
    });
  }

  /// Adds a dependency relationship with another state.
  /// 
  /// When this state changes, the [dependency] will be updated first
  /// to maintain consistency.
  void addDependency(ObservableState dependency) {
    _transactionManager.addDependency(this, dependency);
  }

  /// Removes a dependency relationship with another state.
  void removeDependency(ObservableState dependency) {
    _transactionManager.removeDependency(this, dependency);
  }

  /// Gets all states that this state depends on.
  List<ObservableState> getDependencies() {
    return _transactionManager.getDependencies(this);
  }

  /// Override this method in your state implementation to clean up transactions.
  /// Call this method from your dispose() implementation.
  void disposeTransactional() {
    // Leave any current transaction before disposing
    if (_currentTransaction != null) {
      leaveTransaction();
    }
  }
}

/// Extension methods for working with transactions on any ObservableState.
extension TransactionalStateExtension<T> on ObservableState<T> {
  /// Executes a state update within a transaction.
  /// 
  /// This creates a new transaction, applies the update, and commits it.
  /// If any error occurs, the transaction is automatically rolled back.
  Future<void> updateInTransaction(void Function() update) async {
    final manager = TransactionManager();
    await manager.executeInTransaction((transaction) async {
      if (this is TransactionalStateMixin<T>) {
        (this as TransactionalStateMixin<T>).joinTransaction(transaction);
      } else {
        transaction.addState(this);
      }
      update();
    });
  }

  /// Creates a snapshot of the current state for transaction purposes.
  /// 
  /// This is used internally by the transaction system but can also
  /// be used for manual state management.
  StateSnapshot<T> snapshotForTransaction() {
    return createSnapshot();
  }

  /// Restores state from a snapshot within a transaction context.
  /// 
  /// This is typically called during transaction rollback.
  void restoreFromTransaction(StateSnapshot<T> snapshot) {
    restoreSnapshot(snapshot);
  }
}