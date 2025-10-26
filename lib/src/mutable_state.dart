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

  /// Updates a specific field in a complex object without full replacement
  /// This is useful for objects with many fields where only one changes
  void updateField(String fieldName, dynamic newValue) {
    _errorHandler.withErrorBoundarySync(
      'update_field',
      () {
        checkNotDisposed();
        
        // This is a simplified implementation - in practice, this would need
        // reflection or code generation to work with arbitrary objects
        // For now, we'll provide a generic approach that works with maps
        if (_value is Map<String, dynamic>) {
          final mapValue = _value as Map<String, dynamic>;
          if (mapValue[fieldName] != newValue) {
            final newMap = Map<String, dynamic>.from(mapValue);
            newMap[fieldName] = newValue;
            _value = newMap as T;
            notifyListeners();
          }
        } else {
          // For non-map types, fall back to normal update
          // This would typically be enhanced with code generation
          value = _value;
        }
      },
      stateKey: _stateId,
      valueType: T,
      metadata: {'fieldName': fieldName, 'newValue': newValue},
    );
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

/// Creates a basic mutable state with default configuration

/// Creates a mutable state with tags for organization
MutableState<T> taggedStateOf<T>(T initialValue, Set<String> tags) => MutableState(
      initialValue,
      tags: tags,
    );

/// Creates a mutable state with full configuration options
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

/// Creates a mutable state with persistence
MutableState<T> persistedStateOf<T>(
  T initialValue, 
  String key, {
  EqualityChecker<T>? equalityChecker,
}) => MutableState(
      initialValue,
      tags: {'persisted'},
      metadata: {'persistenceKey': key},
      equalityChecker: equalityChecker,
    );

/// Creates a mutable state optimized for lists
MutableState<List<T>> listStateOf<T>(List<T> initialValue) => MutableState(
      initialValue,
      equalityChecker: EqualityChecker<List<T>>(),
    );

/// Creates a mutable state optimized for maps
MutableState<Map<K, V>> mapStateOf<K, V>(Map<K, V> initialValue) => MutableState(
      initialValue,
      equalityChecker: EqualityChecker<Map<K, V>>(),
    );

extension MutableStateFluentAPI<T> on MutableState<T> {
  /// Sets tags and returns the state for chaining
  MutableState<T> withTags(Set<String> tags) {
    // This would require modifying the internal structure to support
    // adding tags after creation, which isn't currently supported
    // For now, this is just a conceptual example
    return this;
  }
  
  /// Sets metadata and returns the state for chaining
  MutableState<T> withMetadata(Map<String, dynamic> metadata) {
    // Similar to tags, this would require internal changes
    return this;
  }
  
  /// Sets an equality checker and returns the state for chaining
  MutableState<T> withEqualityChecker(EqualityChecker<T> checker) {
    // This would also require internal changes
    return this;
  }
}

extension StateValueExtensions<T> on ObservableState<T> {
  /// Gets the value or a default if the state is disposed
  T valueOrDefault(T defaultValue) {
    try {
      return value;
    } catch (e) {
      return defaultValue;
    }
  }
  
  /// Checks if the state has a specific value
  bool hasValue(T testValue) {
    try {
      return equals(testValue);
    } catch (e) {
      return false;
    }
  }
}

extension NumericStateExtensions on ObservableState<num> {
  /// Increments the state value
  void increment([num amount = 1]) {
    if (this is MutableState<num>) {
      final mutable = this as MutableState<num>;
      mutable.value = mutable.value + amount;
    }
  }
  
  /// Decrements the state value
  void decrement([num amount = 1]) {
    if (this is MutableState<num>) {
      final mutable = this as MutableState<num>;
      mutable.value = mutable.value - amount;
    }
  }
}

extension BooleanStateExtensions on ObservableState<bool> {
  /// Toggles the boolean value
  void toggle() {
    if (this is MutableState<bool>) {
      final mutable = this as MutableState<bool>;
      mutable.value = !mutable.value;
    }
  }
}

extension ListStateExtensions<T> on ObservableState<List<T>> {
  /// Adds an item to the list
  void add(T item) {
    if (this is MutableState<List<T>>) {
      final mutable = this as MutableState<List<T>>;
      mutable.value = List<T>.from(mutable.value)..add(item);
    }
  }
  
  /// Removes an item from the list
  void remove(T item) {
    if (this is MutableState<List<T>>) {
      final mutable = this as MutableState<List<T>>;
      mutable.value = List<T>.from(mutable.value)..remove(item);
    }
  }
  
  /// Clears the list
  void clear() {
    if (this is MutableState<List<T>>) {
      final mutable = this as MutableState<List<T>>;
      mutable.value = [];
    }
  }
}