import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import '../observable_state.dart';
import '../ui_state.dart';
import 'mock_state.dart';

/// Comprehensive testing utilities for state management testing.
/// 
/// This class provides helper functions, assertion utilities, and
/// testing patterns for all state types in the compose_state package.
class StateTestUtils {
  StateTestUtils._();

  /// Waits for a state to change to a specific value within a timeout.
  /// 
  /// Returns true if the state changed to the expected value, false if timeout.
  static Future<bool> waitForStateChange<T>(
    ObservableState<T> state,
    T expectedValue, {
    Duration timeout = const Duration(seconds: 5),
    bool Function(T, T)? equals,
  }) async {
    if ((equals?.call(state.value, expectedValue) ?? state.value == expectedValue)) {
      return true;
    }

    final completer = Completer<bool>();
    late VoidCallback listener;
    Timer? timeoutTimer;

    listener = () {
      final currentValue = state.value;
      if (equals?.call(currentValue, expectedValue) ?? currentValue == expectedValue) {
        timeoutTimer?.cancel();
        state.removeListener(listener);
        if (!completer.isCompleted) {
          completer.complete(true);
        }
      }
    };

    timeoutTimer = Timer(timeout, () {
      state.removeListener(listener);
      if (!completer.isCompleted) {
        completer.complete(false);
      }
    });

    state.addListener(listener);
    return completer.future;
  }

  /// Waits for any state change within a timeout.
  static Future<T?> waitForAnyStateChange<T>(
    ObservableState<T> state, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final completer = Completer<T?>();
    late VoidCallback listener;
    Timer? timeoutTimer;

    listener = () {
      timeoutTimer?.cancel();
      state.removeListener(listener);
      if (!completer.isCompleted) {
        completer.complete(state.value);
      }
    };

    timeoutTimer = Timer(timeout, () {
      state.removeListener(listener);
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    });

    state.addListener(listener);
    return completer.future;
  }

  /// Records all state changes for a given duration.
  static Future<List<StateChangeRecord<T>>> recordStateChanges<T>(
    ObservableState<T> state,
    Duration duration,
  ) async {
    final changes = <StateChangeRecord<T>>[];
    T? previousValue = state.value;
    
    late VoidCallback listener;
    listener = () {
      final currentValue = state.value;
      changes.add(StateChangeRecord(
        previousValue: previousValue,
        newValue: currentValue,
        timestamp: DateTime.now(),
      ));
      previousValue = currentValue;
    };

    state.addListener(listener);
    await Future.delayed(duration);
    state.removeListener(listener);

    return changes;
  }

  /// Verifies that a state change sequence matches expected values.
  static void verifyStateSequence<T>(
    List<StateChangeRecord<T>> actualChanges,
    List<T> expectedValues, {
    String? reason,
  }) {
    expect(
      actualChanges.length,
      expectedValues.length,
      reason: reason ?? 'State change count mismatch',
    );

    for (int i = 0; i < expectedValues.length; i++) {
      expect(
        actualChanges[i].newValue,
        expectedValues[i],
        reason: reason ?? 'State change $i value mismatch',
      );
    }
  }

  /// Creates a test listener that tracks calls and values.
  static TestStateListener<T> createTestListener<T>(ObservableState<T> state) {
    return TestStateListener(state);
  }

  /// Verifies that a state operation throws a specific exception.
  static void expectStateThrows<T>(
    void Function() operation,
    Matcher matcher, {
    String? reason,
  }) {
    expect(operation, throwsA(matcher), reason: reason);
  }

  /// Verifies that a state is properly disposed.
  static void expectStateDisposed<T>(
    ObservableState<T> state, {
    String? reason,
  }) {
    expect(
      state.isDisposed,
      isTrue,
      reason: reason ?? 'State should be disposed',
    );
    
    expect(
      () => state.value,
      throwsStateError,
      reason: reason ?? 'Disposed state should throw on value access',
    );
  }

  /// Verifies that two state snapshots are equal.
  static void expectSnapshotsEqual<T>(
    StateSnapshot<T> actual,
    StateSnapshot<T> expected, {
    String? reason,
  }) {
    expect(
      actual.value,
      expected.value,
      reason: reason ?? 'Snapshot values should be equal',
    );
    
    expect(
      actual.timestamp,
      expected.timestamp,
      reason: reason ?? 'Snapshot timestamps should be equal',
    );
    
    expect(
      actual.metadata,
      expected.metadata,
      reason: reason ?? 'Snapshot metadata should be equal',
    );
  }

  /// Verifies that a state has specific metadata in its snapshot.
  static void expectSnapshotMetadata<T>(
    StateSnapshot<T> snapshot,
    Map<String, dynamic> expectedMetadata, {
    String? reason,
  }) {
    for (final entry in expectedMetadata.entries) {
      expect(
        snapshot.metadata[entry.key],
        entry.value,
        reason: reason ?? 'Snapshot metadata ${entry.key} mismatch',
      );
    }
  }

  /// Creates a mock state with pre-configured behavior for testing.
  static MockState<T> createMockState<T>(
    T initialValue, {
    bool throwOnGet = false,
    bool throwOnSet = false,
    Duration? setDelay,
    bool Function(T, T)? customEquals,
  }) {
    final mock = MockState(initialValue);
    
    if (throwOnGet) mock.throwOnGet();
    if (throwOnSet) mock.throwOnSet();
    if (setDelay != null) mock.delaySet(setDelay);
    if (customEquals != null) mock.setCustomEquals(customEquals);
    
    return mock;
  }

  /// Verifies API state transitions for success scenarios.
  static void expectApiSuccess<T>(
    ObservableState<UiState<T>> apiState,
    T expectedData, {
    String? reason,
  }) {
    expect(
      apiState.value,
      isA<Success<T>>(),
      reason: reason ?? 'API state should be Success',
    );
    
    final success = apiState.value as Success<T>;
    expect(
      success.data,
      expectedData,
      reason: reason ?? 'API success data mismatch',
    );
  }

  /// Verifies API state transitions for error scenarios.
  static void expectApiError<T>(
    ObservableState<UiState<T>> apiState,
    String expectedError, {
    String? reason,
  }) {
    expect(
      apiState.value,
      isA<Error<T>>(),
      reason: reason ?? 'API state should be Error',
    );
    
    final error = apiState.value as Error<T>;
    expect(
      error.message,
      expectedError,
      reason: reason ?? 'API error message mismatch',
    );
  }

  /// Verifies API state is in loading state.
  static void expectApiLoading<T>(
    ObservableState<UiState<T>> apiState, {
    String? reason,
  }) {
    expect(
      apiState.value,
      isA<Loading<T>>(),
      reason: reason ?? 'API state should be Loading',
    );
  }

  /// Pumps the event loop to allow async operations to complete.
  static Future<void> pumpEventLoop([int times = 1]) async {
    for (int i = 0; i < times; i++) {
      await Future.delayed(Duration.zero);
    }
  }

  /// Creates a test scenario with multiple states for integration testing.
  static TestStateScenario<T> createScenario<T>(
    Map<String, ObservableState<T>> states,
  ) {
    return TestStateScenario(states);
  }
}

/// Records a state change for testing purposes.
class StateChangeRecord<T> {
  final T? previousValue;
  final T newValue;
  final DateTime timestamp;

  const StateChangeRecord({
    required this.previousValue,
    required this.newValue,
    required this.timestamp,
  });

  @override
  String toString() {
    return 'StateChangeRecord(previous: $previousValue, new: $newValue, '
           'timestamp: $timestamp)';
  }
}

/// A test listener that tracks state changes and call counts.
class TestStateListener<T> {
  final ObservableState<T> _state;
  final List<T> _values = [];
  int _callCount = 0;
  bool _isListening = false;

  TestStateListener(this._state);

  /// Start listening to state changes.
  void startListening() {
    if (!_isListening) {
      _state.addListener(_onStateChange);
      _isListening = true;
    }
  }

  /// Stop listening to state changes.
  void stopListening() {
    if (_isListening) {
      _state.removeListener(_onStateChange);
      _isListening = false;
    }
  }

  void _onStateChange() {
    _callCount++;
    _values.add(_state.value);
  }

  /// Get the number of times the listener was called.
  int get callCount => _callCount;

  /// Get all values that were recorded.
  List<T> get values => List.unmodifiable(_values);

  /// Get the last recorded value.
  T? get lastValue => _values.isEmpty ? null : _values.last;

  /// Clear the recorded data.
  void clear() {
    _callCount = 0;
    _values.clear();
  }

  /// Verify that the listener was called a specific number of times.
  void expectCallCount(int expected, {String? reason}) {
    expect(
      _callCount,
      expected,
      reason: reason ?? 'Listener call count mismatch',
    );
  }

  /// Verify that specific values were recorded.
  void expectValues(List<T> expected, {String? reason}) {
    expect(
      _values,
      expected,
      reason: reason ?? 'Listener recorded values mismatch',
    );
  }

  /// Dispose the listener.
  void dispose() {
    stopListening();
    clear();
  }
}

/// A test scenario for integration testing with multiple states.
class TestStateScenario<T> {
  final Map<String, ObservableState<T>> _states;
  final Map<String, TestStateListener<T>> _listeners = {};

  TestStateScenario(this._states);

  /// Get a state by name.
  ObservableState<T> state(String name) {
    final state = _states[name];
    if (state == null) {
      throw ArgumentError('State "$name" not found in scenario');
    }
    return state;
  }

  /// Get a listener for a state by name.
  TestStateListener<T> listener(String name) {
    return _listeners.putIfAbsent(
      name,
      () => TestStateListener(state(name)),
    );
  }

  /// Start listening to all states.
  void startListening() {
    for (final name in _states.keys) {
      listener(name).startListening();
    }
  }

  /// Stop listening to all states.
  void stopListening() {
    for (final listener in _listeners.values) {
      listener.stopListening();
    }
  }

  /// Clear all recorded data.
  void clear() {
    for (final listener in _listeners.values) {
      listener.clear();
    }
  }

  /// Dispose all listeners and states.
  void dispose() {
    stopListening();
    for (final listener in _listeners.values) {
      listener.dispose();
    }
    for (final state in _states.values) {
      if (!state.isDisposed) {
        state.dispose();
      }
    }
    _listeners.clear();
  }
}

/// Custom matchers for state testing.
class StateMatchers {
  /// Matcher for disposed states.
  static Matcher get isDisposed => _IsDisposedMatcher();
  
  /// Matcher for loading UI states.
  static Matcher get isLoading => isA<Loading>();
  
  /// Matcher for success UI states.
  static Matcher isSuccess<T>([T? data]) => _IsSuccessMatcher<T>(data);
  
  /// Matcher for error UI states.
  static Matcher isError<T>([String? message]) => _IsErrorMatcher<T>(message);
}

class _IsDisposedMatcher extends Matcher {
  @override
  bool matches(dynamic item, Map matchState) {
    return item is ObservableState && item.isDisposed;
  }

  @override
  Description describe(Description description) {
    return description.add('a disposed state');
  }
}

class _IsSuccessMatcher<T> extends Matcher {
  final T? expectedData;

  _IsSuccessMatcher(this.expectedData);

  @override
  bool matches(dynamic item, Map matchState) {
    if (item is! Success<T>) return false;
    if (expectedData == null) return true;
    return item.data == expectedData;
  }

  @override
  Description describe(Description description) {
    if (expectedData != null) {
      return description.add('a Success state with data $expectedData');
    }
    return description.add('a Success state');
  }
}

class _IsErrorMatcher<T> extends Matcher {
  final String? expectedMessage;

  _IsErrorMatcher(this.expectedMessage);

  @override
  bool matches(dynamic item, Map matchState) {
    if (item is! Error<T>) return false;
    if (expectedMessage == null) return true;
    return item.message == expectedMessage;
  }

  @override
  Description describe(Description description) {
    if (expectedMessage != null) {
      return description.add('an Error state with message "$expectedMessage"');
    }
    return description.add('an Error state');
  }
}