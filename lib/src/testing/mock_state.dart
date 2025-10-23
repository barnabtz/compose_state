import 'dart:async';
import 'package:flutter/foundation.dart';
import '../observable_state.dart';
import '../ui_state.dart';

/// A mock implementation of [ObservableState] for testing purposes.
/// 
/// This class provides controllable behavior for all state operations,
/// allowing tests to simulate various scenarios including errors,
/// delays, and custom behaviors.
class MockState<T> implements ObservableState<T> {
  T _value;
  bool _isDisposed = false;
  final List<VoidCallback> _listeners = [];
  final List<StateChangeEvent<T>> _changeHistory = [];
  
  // Controllable behavior flags
  bool _shouldThrowOnGet = false;
  bool _shouldThrowOnSet = false;
  bool _shouldThrowOnDispose = false;
  bool _shouldThrowOnEquals = false;
  bool _shouldThrowOnSnapshot = false;
  bool _shouldThrowOnRestore = false;
  
  Duration? _setDelay;
  Duration? _getDelay;
  Exception? _customException;
  bool Function(T, T)? _customEquals;
  bool _notifyOnSameValue = false;
  
  MockState(this._value);

  @override
  T get value {
    if (_isDisposed) throw StateError('MockState has been disposed');
    if (_shouldThrowOnGet) {
      throw _customException ?? Exception('Mock get error');
    }
    
    if (_getDelay != null) {
      // In a real async scenario, this would be handled differently
      // For testing, we simulate the delay effect
      Future.delayed(_getDelay!);
    }
    
    return _value;
  }

  @override
  set value(T newValue) {
    if (_isDisposed) throw StateError('MockState has been disposed');
    if (_shouldThrowOnSet) {
      throw _customException ?? Exception('Mock set error');
    }

    final oldValue = _value;
    
    if (_setDelay != null) {
      Future.delayed(_setDelay!, () => _setValue(newValue, oldValue));
    } else {
      _setValue(newValue, oldValue);
    }
  }

  void _setValue(T newValue, T oldValue) {
    if (_isDisposed) return;
    
    final shouldNotify = _notifyOnSameValue || !equals(newValue);
    _value = newValue;
    
    // Record the change
    _changeHistory.add(StateChangeEvent(
      previousValue: oldValue,
      newValue: newValue,
      timestamp: DateTime.now(),
      source: 'MockState.setValue',
    ));
    
    if (shouldNotify) {
      _notifyListeners();
    }
  }

  @override
  bool get isDisposed => _isDisposed;

  @override
  void dispose() {
    if (_shouldThrowOnDispose) {
      throw _customException ?? Exception('Mock dispose error');
    }
    
    _isDisposed = true;
    _listeners.clear();
  }

  @override
  void addListener(VoidCallback listener) {
    if (_isDisposed) throw StateError('MockState has been disposed');
    _listeners.add(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    if (_isDisposed) throw StateError('MockState has been disposed');
    _listeners.remove(listener);
  }

  void _notifyListeners() {
    if (_isDisposed) return;
    for (final listener in List.from(_listeners)) {
      try {
        listener();
      } catch (e) {
        // Ignore listener errors in mock
      }
    }
  }

  @override
  bool equals(T other) {
    if (_shouldThrowOnEquals) {
      throw _customException ?? Exception('Mock equals error');
    }
    
    if (_customEquals != null) {
      return _customEquals!(_value, other);
    }
    
    return _value == other;
  }

  @override
  StateSnapshot<T> createSnapshot() {
    if (_isDisposed) throw StateError('MockState has been disposed');
    if (_shouldThrowOnSnapshot) {
      throw _customException ?? Exception('Mock snapshot error');
    }
    
    return StateSnapshot(
      _value,
      timestamp: DateTime.now(),
      metadata: {
        'mockState': true,
        'changeCount': _changeHistory.length,
        'listenerCount': _listeners.length,
      },
    );
  }

  @override
  void restoreSnapshot(StateSnapshot<T> snapshot) {
    if (_isDisposed) throw StateError('MockState has been disposed');
    if (_shouldThrowOnRestore) {
      throw _customException ?? Exception('Mock restore error');
    }
    
    final oldValue = _value;
    _value = snapshot.value;
    
    _changeHistory.add(StateChangeEvent(
      previousValue: oldValue,
      newValue: snapshot.value,
      timestamp: DateTime.now(),
      source: 'MockState.restoreSnapshot',
    ));
    
    _notifyListeners();
  }

  // Mock control methods
  
  /// Configure the mock to throw an exception on get operations
  void throwOnGet([Exception? exception]) {
    _shouldThrowOnGet = true;
    _customException = exception;
  }

  /// Configure the mock to throw an exception on set operations
  void throwOnSet([Exception? exception]) {
    _shouldThrowOnSet = true;
    _customException = exception;
  }

  /// Configure the mock to throw an exception on dispose
  void throwOnDispose([Exception? exception]) {
    _shouldThrowOnDispose = true;
    _customException = exception;
  }

  /// Configure the mock to throw an exception on equals operations
  void throwOnEquals([Exception? exception]) {
    _shouldThrowOnEquals = true;
    _customException = exception;
  }

  /// Configure the mock to throw an exception on snapshot operations
  void throwOnSnapshot([Exception? exception]) {
    _shouldThrowOnSnapshot = true;
    _customException = exception;
  }

  /// Configure the mock to throw an exception on restore operations
  void throwOnRestore([Exception? exception]) {
    _shouldThrowOnRestore = true;
    _customException = exception;
  }

  /// Add delay to set operations
  void delaySet(Duration delay) {
    _setDelay = delay;
  }

  /// Add delay to get operations
  void delayGet(Duration delay) {
    _getDelay = delay;
  }

  /// Set custom equality function
  void setCustomEquals(bool Function(T, T) equals) {
    _customEquals = equals;
  }

  /// Configure whether to notify listeners even when value is the same
  void notifyOnSameValue(bool notify) {
    _notifyOnSameValue = notify;
  }

  /// Reset all mock configurations to default
  void resetMockBehavior() {
    _shouldThrowOnGet = false;
    _shouldThrowOnSet = false;
    _shouldThrowOnDispose = false;
    _shouldThrowOnEquals = false;
    _shouldThrowOnSnapshot = false;
    _shouldThrowOnRestore = false;
    _setDelay = null;
    _getDelay = null;
    _customException = null;
    _customEquals = null;
    _notifyOnSameValue = false;
  }

  // Testing utilities
  
  /// Get the complete change history
  List<StateChangeEvent<T>> get changeHistory => List.unmodifiable(_changeHistory);

  /// Get the number of listeners
  int get listenerCount => _listeners.length;

  /// Clear the change history
  void clearHistory() {
    _changeHistory.clear();
  }

  /// Get the last change event
  StateChangeEvent<T>? get lastChange => 
      _changeHistory.isEmpty ? null : _changeHistory.last;

  /// Check if a specific value was ever set
  bool wasValueSet(T value) {
    return _changeHistory.any((event) => event.newValue == value);
  }

  /// Get the number of times a specific value was set
  int getValueSetCount(T value) {
    return _changeHistory.where((event) => event.newValue == value).length;
  }
}

/// Represents a state change event for testing purposes
class StateChangeEvent<T> {
  final T previousValue;
  final T newValue;
  final DateTime timestamp;
  final String source;

  const StateChangeEvent({
    required this.previousValue,
    required this.newValue,
    required this.timestamp,
    required this.source,
  });

  @override
  String toString() {
    return 'StateChangeEvent(previous: $previousValue, new: $newValue, '
           'timestamp: $timestamp, source: $source)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StateChangeEvent<T> &&
          runtimeType == other.runtimeType &&
          previousValue == other.previousValue &&
          newValue == other.newValue &&
          timestamp == other.timestamp &&
          source == other.source;

  @override
  int get hashCode => Object.hash(previousValue, newValue, timestamp, source);
}

/// Mock implementation for API states
class MockApiState<T> extends MockState<UiState<T>> {
  MockApiState() : super(const LoadingState());

  /// Simulate a successful API call
  void simulateSuccess(T data) {
    value = SuccessState(data);
  }

  /// Simulate an API error
  void simulateError(String error) {
    value = ErrorState(error);
  }

  /// Simulate loading state
  void simulateLoading() {
    value = const LoadingState();
  }

  /// Simulate an API call with delay
  Future<void> simulateAsyncCall(
    Future<T> Function() call, {
    Duration delay = const Duration(milliseconds: 100),
  }) async {
    simulateLoading();
    await Future.delayed(delay);
    
    try {
      final result = await call();
      simulateSuccess(result);
    } catch (e) {
      simulateError(e.toString());
    }
  }
}

/// Factory functions for creating mock states
MockState<T> mockStateOf<T>(T initialValue) => MockState(initialValue);
MockApiState<T> mockApiStateOf<T>() => MockApiState<T>();