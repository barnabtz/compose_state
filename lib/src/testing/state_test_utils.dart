import 'dart:async';
import '../observable_state.dart';
import '../ui_state.dart';

/// Comprehensive testing utilities for the compose_state package.
/// 
/// This class provides helper methods for testing state behavior,
/// verifying state changes, and creating test scenarios.
class StateTestUtils {
  /// Waits for a state to change from its current value.
  /// 
  /// Returns a Future that completes when the state changes,
  /// or throws a TimeoutException if the timeout is reached.
  static Future<T> waitForStateChange<T>(
    ObservableState<T> state, {
    Duration timeout = const Duration(seconds: 5),
  }) {
    final completer = Completer<T>();
    final currentValue = state.value;
    
    void listener() {
      if (state.value != currentValue) {
        state.removeListener(listener);
        completer.complete(state.value);
      }
    }
    
    state.addListener(listener);
    
    // Set up timeout
    Timer(timeout, () {
      if (!completer.isCompleted) {
        state.removeListener(listener);
        completer.completeError(
          TimeoutException('State did not change within timeout', timeout),
        );
      }
    });
    
    return completer.future;
  }

  /// Waits for a state to reach a specific value.
  /// 
  /// Returns a Future that completes when the state reaches the expected value,
  /// or throws a TimeoutException if the timeout is reached.
  static Future<void> waitForStateValue<T>(
    ObservableState<T> state,
    T expectedValue, {
    Duration timeout = const Duration(seconds: 5),
  }) {
    if (state.value == expectedValue) {
      return Future.value();
    }
    
    final completer = Completer<void>();
    
    void listener() {
      if (state.value == expectedValue) {
        state.removeListener(listener);
        completer.complete();
      }
    }
    
    state.addListener(listener);
    
    // Set up timeout
    Timer(timeout, () {
      if (!completer.isCompleted) {
        state.removeListener(listener);
        completer.completeError(
          TimeoutException('State did not reach expected value within timeout', timeout),
        );
      }
    });
    
    return completer.future;
  }

  /// Records all state changes over a specified duration.
  /// 
  /// Returns a list of all values the state took during the recording period.
  static Future<List<T>> recordStateChanges<T>(
    ObservableState<T> state,
    Duration duration,
  ) {
    final changes = <T>[state.value]; // Include initial value
    
    void listener() {
      changes.add(state.value);
    }
    
    state.addListener(listener);
    
    return Future.delayed(duration).then((_) {
      state.removeListener(listener);
      return changes;
    });
  }

  /// Verifies that a state change sequence matches expected values.
  static void verifyStateSequence<T>(
    List<StateChangeRecord<T>> actualChanges,
    List<T> expectedValues, {
    String? reason,
  }) {
    if (actualChanges.length != expectedValues.length) {
      throw AssertionError(reason ?? 'State change count mismatch: expected ${expectedValues.length}, got ${actualChanges.length}');
    }

    for (int i = 0; i < expectedValues.length; i++) {
      if (actualChanges[i].newValue != expectedValues[i]) {
        throw AssertionError(reason ?? 'State change $i value mismatch: expected ${expectedValues[i]}, got ${actualChanges[i].newValue}');
      }
    }
  }

  /// Verifies that a state operation throws a specific exception.
  static void expectStateThrows<T>(
    void Function() operation,
    Type expectedExceptionType, {
    String? reason,
  }) {
    try {
      operation();
      throw AssertionError(reason ?? 'Expected operation to throw $expectedExceptionType, but it completed normally');
    } catch (e) {
      if (e.runtimeType != expectedExceptionType) {
        throw AssertionError(reason ?? 'Expected $expectedExceptionType, but got ${e.runtimeType}: $e');
      }
    }
  }

  /// Verifies that a state is properly disposed.
  static void expectStateDisposed<T>(
    ObservableState<T> state, {
    String? reason,
  }) {
    if (!state.isDisposed) {
      throw AssertionError(reason ?? 'State should be disposed');
    }
    
    try {
      state.value;
      throw AssertionError(reason ?? 'Disposed state should throw on value access');
    } catch (e) {
      // Expected to throw
    }
  }

  /// Verifies that two snapshots are equivalent.
  static void expectSnapshotEquals<T>(
    StateSnapshot<T> actual,
    StateSnapshot<T> expected, {
    String? reason,
  }) {
    if (actual.value != expected.value) {
      throw AssertionError(reason ?? 'Snapshot values should match: expected ${expected.value}, got ${actual.value}');
    }
    
    if (actual.timestamp != expected.timestamp) {
      throw AssertionError(reason ?? 'Snapshot timestamps should match: expected ${expected.timestamp}, got ${actual.timestamp}');
    }
    
    if (actual.metadata.toString() != expected.metadata.toString()) {
      throw AssertionError(reason ?? 'Snapshot metadata should match: expected ${expected.metadata}, got ${actual.metadata}');
    }
  }

  /// Verifies that a snapshot contains expected metadata.
  static void expectSnapshotMetadata<T>(
    StateSnapshot<T> snapshot,
    Map<String, dynamic> expectedMetadata, {
    String? reason,
  }) {
    for (final entry in expectedMetadata.entries) {
      if (snapshot.metadata[entry.key] != entry.value) {
        throw AssertionError(reason ?? 'Snapshot metadata mismatch for key ${entry.key}: expected ${entry.value}, got ${snapshot.metadata[entry.key]}');
      }
    }
  }

  /// Creates a test snapshot with specified properties.
  static StateSnapshot<T> createSnapshot<T>(
    T value, {
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
  }) {
    return StateSnapshot<T>(
      value,
      timestamp: timestamp ?? DateTime.now(),
      metadata: metadata ?? {},
    );
  }

  /// Verifies that an API state is in success state with expected data.
  static void expectApiSuccess<T>(
    UiState<T> apiState,
    T expectedData, {
    String? reason,
  }) {
    if (apiState is! Success<T>) {
      throw AssertionError(reason ?? 'Expected Success state, got ${apiState.runtimeType}');
    }
    
    if ((apiState).data != expectedData) {
      throw AssertionError(reason ?? 'Success data mismatch: expected $expectedData, got ${(apiState).data}');
    }
  }

  /// Verifies that an API state is in error state with expected error.
  static void expectApiError<T>(
    UiState<T> apiState,
    String expectedError, {
    String? reason,
  }) {
    if (apiState is! Error<T>) {
      throw AssertionError(reason ?? 'Expected Error state, got ${apiState.runtimeType}');
    }
    
    if ((apiState).message != expectedError) {
      throw AssertionError(reason ?? 'Error message mismatch: expected $expectedError, got ${(apiState).message}');
    }
  }

  /// Verifies that an API state is in loading state.
  static void expectApiLoading<T>(
    UiState<T> apiState, {
    String? reason,
  }) {
    if (apiState is! Loading<T>) {
      throw AssertionError(reason ?? 'Expected Loading state, got ${apiState.runtimeType}');
    }
  }

  /// Creates a test scenario with multiple states for integration testing.
  static TestStateScenario createScenario() {
    return TestStateScenario({});
  }

  /// Creates a test listener for a state.
  static TestStateListener<T> createTestListener<T>() {
    return TestStateListener<T>();
  }
}

/// Records a state change for testing purposes.
class StateChangeRecord<T> {
  final T? oldValue;
  final T newValue;
  final DateTime timestamp;
  final String changeType;

  StateChangeRecord({
    required this.oldValue,
    required this.newValue,
    required this.timestamp,
    required this.changeType,
  });

  @override
  String toString() {
    return 'StateChangeRecord(oldValue: $oldValue, newValue: $newValue, '
           'changeType: $changeType, timestamp: $timestamp)';
  }
}

/// A test listener that tracks state changes and call counts.
class TestStateListener<T> {
  final List<T> _values = [];
  int _callCount = 0;

  /// The number of times the listener was called.
  int get callCount => _callCount;

  /// All values that were recorded.
  List<T> get values => List.unmodifiable(_values);

  /// The most recent value recorded.
  T? get lastValue => _values.isNotEmpty ? _values.last : null;

  /// Creates a listener function that can be added to a state.
  void Function() createListener(ObservableState<T> state) {
    return () {
      _callCount++;
      _values.add(state.value);
    };
  }

  /// Verify that the listener was called a specific number of times.
  void expectCallCount(int expected, {String? reason}) {
    if (_callCount != expected) {
      throw AssertionError(reason ?? 'Expected $expected calls, got $_callCount');
    }
  }

  /// Verify that specific values were recorded.
  void expectValues(List<T> expected, {String? reason}) {
    if (_values.length != expected.length) {
      throw AssertionError(reason ?? 'Expected ${expected.length} values, got ${_values.length}');
    }
    
    for (int i = 0; i < expected.length; i++) {
      if (_values[i] != expected[i]) {
        throw AssertionError(reason ?? 'Value $i mismatch: expected ${expected[i]}, got ${_values[i]}');
      }
    }
  }

  /// Clear all recorded data.
  void clear() {
    _values.clear();
    _callCount = 0;
  }

  /// Reset the listener for reuse.
  void reset() {
    clear();
  }

  /// Start listening (compatibility method - listener is active when created).
  void startListening() {
    // This method is for compatibility - listeners are active when added to states
  }

  /// Dispose the listener (compatibility method).
  void dispose() {
    clear();
  }
}

/// A test scenario for integration testing with multiple states.
class TestStateScenario {
  final Map<String, ObservableState> _states;
  final Map<String, TestStateListener> _listeners = {};

  TestStateScenario(this._states);

  /// Add a state to the scenario.
  void addState<T>(String name, ObservableState<T> state) {
    _states[name] = state;
  }

  /// Get a state by name.
  ObservableState<T>? getState<T>(String name) {
    return _states[name] as ObservableState<T>?;
  }

  /// Add a listener to a state.
  void addListener<T>(String stateName, String listenerName) {
    final state = getState<T>(stateName);
    if (state == null) return;

    final listener = TestStateListener<T>();
    _listeners[listenerName] = listener;
    state.addListener(listener.createListener(state));
  }

  /// Get a listener by name.
  TestStateListener<T>? getListener<T>(String name) {
    return _listeners[name] as TestStateListener<T>?;
  }

  /// Start listening to all added states.
  void startListening() {
    // This method is for compatibility - listeners are added when addListener is called
  }

  /// Get a state by name (alternative method name for compatibility).
  ObservableState<T>? state<T>(String name) {
    return getState<T>(name);
  }

  /// Get a listener by name (alternative method name for compatibility).
  TestStateListener<T>? listener<T>(String name) {
    return getListener<T>(name);
  }

  /// Clean up all listeners and states.
  void dispose() {
    for (final state in _states.values) {
      if (!state.isDisposed) {
        state.dispose();
      }
    }
    _states.clear();
    _listeners.clear();
  }
}

/// Utility functions for testing state properties.
class StateMatchers {
  /// Checks if a state is disposed.
  static bool isDisposed(ObservableState state) => state.isDisposed;
  
  /// Checks if a UI state is loading.
  static bool isLoading(dynamic state) => state is Loading;
  
  /// Checks if a UI state is success with optional data check.
  static bool isSuccess<T>(dynamic state, [T? expectedData]) {
    if (state is! Success<T>) return false;
    if (expectedData == null) return true;
    return state.data == expectedData;
  }
  
  /// Checks if a UI state is error with optional message check.
  static bool isError<T>(dynamic state, [String? expectedMessage]) {
    if (state is! Error<T>) return false;
    if (expectedMessage == null) return true;
    return state.message == expectedMessage;
  }
}