import 'package:flutter/foundation.dart';
import 'disposable_state.dart';
import 'equality_checker.dart';
import 'notification_batcher.dart';
import 'observable_state.dart';
import 'state_manager.dart';

/// Performance-optimized state implementation that uses deep equality
/// checking and notification batching to reduce unnecessary rebuilds.
class OptimizedState<T> extends ChangeNotifier with DisposableState implements ObservableState<T> {
  T _value;
  late final String _stateId;
  final Set<String> _tags;
  final Map<String, dynamic> _metadata;
  final EqualityChecker<T> _equalityChecker;
  final NotificationBatcher _notificationBatcher;
  bool _hasScheduledNotification = false;

  OptimizedState(
    this._value, {
    Set<String>? tags,
    Map<String, dynamic>? metadata,
    EqualityChecker<T>? equalityChecker,
    NotificationBatcher? notificationBatcher,
  }) : _tags = tags ?? {},
       _metadata = metadata ?? {},
       _equalityChecker = equalityChecker ?? EqualityChecker<T>(),
       _notificationBatcher = notificationBatcher ?? globalNotificationBatcher {
    _stateId = StateManager.instance.registerState(
      this,
      tags: _tags,
      metadata: _metadata,
    );
  }

  @override
  T get value {
    checkNotDisposed();
    return _value;
  }

  @override
  set value(T newValue) {
    checkNotDisposed();
    if (!equals(newValue)) {
      _value = newValue;
      _scheduleNotification();
    }
  }

  /// Sets the value without triggering notifications.
  /// Useful for batch updates or initialization.
  void setValueSilently(T newValue) {
    checkNotDisposed();
    _value = newValue;
  }

  /// Updates the value using a function and only notifies if changed.
  void updateValue(T Function(T current) updater) {
    checkNotDisposed();
    final newValue = updater(_value);
    value = newValue;
  }

  /// Schedules a notification using the configured batching strategy.
  void _scheduleNotification() {
    if (_hasScheduledNotification) return;
    
    _hasScheduledNotification = true;
    _notificationBatcher.scheduleNotification(() {
      _hasScheduledNotification = false;
      if (!isDisposed) {
        notifyListeners();
      }
    });
  }

  /// Forces immediate notification of listeners.
  void notifyImmediately() {
    checkNotDisposed();
    notifyListeners();
  }

  @override
  bool equals(T other) {
    return _equalityChecker.equals(_value, other);
  }

  @override
  StateSnapshot<T> createSnapshot() {
    checkNotDisposed();
    return StateSnapshot(
      _value,
      timestamp: DateTime.now(),
      metadata: {
        'stateType': runtimeType.toString(),
        'stateId': _stateId,
        'equalityStats': _equalityChecker.getCacheStats(),
        'batchingStats': _notificationBatcher.getStats(),
      },
    );
  }

  @override
  void restoreSnapshot(StateSnapshot<T> snapshot) {
    checkNotDisposed();
    value = snapshot.value;
  }

  /// Gets performance statistics for this state.
  Map<String, dynamic> getPerformanceStats() {
    return {
      'stateId': _stateId,
      'stateType': runtimeType.toString(),
      'hasScheduledNotification': _hasScheduledNotification,
      'equalityStats': _equalityChecker.getCacheStats(),
      'batchingStats': _notificationBatcher.getStats(),
    };
  }

  /// Clears the equality cache for this state.
  void clearEqualityCache() {
    _equalityChecker.clearCache();
  }

  @override
  void dispose() {
    // Cancel any pending notifications
    if (_hasScheduledNotification) {
      _notificationBatcher.cancel();
      _hasScheduledNotification = false;
    }
    
    StateManager.instance.unregisterState(_stateId);
    super.dispose();
  }
}

/// Creates an optimized mutable state with performance enhancements.
/// 
/// [initialValue] - The initial value for the state
/// [tags] - Optional tags for state categorization
/// [metadata] - Optional metadata for the state
/// [customEquals] - Custom equality function for the value type
/// [customHashCode] - Custom hash function for caching optimization
/// [batchingStrategy] - Strategy for batching notifications
/// [enableCaching] - Whether to enable equality caching
OptimizedState<T> optimizedStateOf<T>(
  T initialValue, {
  Set<String>? tags,
  Map<String, dynamic>? metadata,
  EqualityFunction<T>? customEquals,
  HashFunction<T>? customHashCode,
  BatchingStrategy batchingStrategy = BatchingStrategy.frame,
  bool enableCaching = true,
}) {
  final equalityChecker = EqualityChecker<T>(
    customEquals: customEquals,
    customHashCode: customHashCode,
    enableCaching: enableCaching,
  );

  final notificationBatcher = createNotificationBatcher(
    strategy: batchingStrategy,
  );

  return OptimizedState(
    initialValue,
    tags: tags,
    metadata: metadata,
    equalityChecker: equalityChecker,
    notificationBatcher: notificationBatcher,
  );
}

/// Creates an optimized state with immediate notifications (no batching).
OptimizedState<T> immediateStateOf<T>(
  T initialValue, {
  Set<String>? tags,
  Map<String, dynamic>? metadata,
  EqualityFunction<T>? customEquals,
  HashFunction<T>? customHashCode,
}) {
  return optimizedStateOf<T>(
    initialValue,
    tags: tags,
    metadata: metadata,
    customEquals: customEquals,
    customHashCode: customHashCode,
    batchingStrategy: BatchingStrategy.immediate,
  );
}

/// Creates an optimized state with debounced notifications.
OptimizedState<T> debouncedStateOf<T>(
  T initialValue, {
  Set<String>? tags,
  Map<String, dynamic>? metadata,
  EqualityFunction<T>? customEquals,
  HashFunction<T>? customHashCode,
  Duration delay = const Duration(milliseconds: 50),
}) {
  final notificationBatcher = createNotificationBatcher(
    strategy: BatchingStrategy.debounced,
    delay: delay,
  );

  final equalityChecker = EqualityChecker<T>(
    customEquals: customEquals,
    customHashCode: customHashCode,
  );

  return OptimizedState(
    initialValue,
    tags: tags,
    metadata: metadata,
    equalityChecker: equalityChecker,
    notificationBatcher: notificationBatcher,
  );
}