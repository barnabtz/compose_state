import 'dart:async';
import 'package:flutter/foundation.dart';
import '../observable_state.dart';

/// Comprehensive state change tracking and verification system.
/// 
/// This class provides mechanisms to track, record, and verify state changes
/// across multiple states, enabling complex testing scenarios and debugging.
class StateChangeTracker {
  final Map<String, ObservableState> _trackedStates = {};
  final Map<String, List<StateChangeEntry>> _changeHistory = {};
  final Map<String, VoidCallback> _listeners = {};
  final List<StateChangeVerification> _verifications = [];
  bool _isTracking = false;
  Timer? _verificationTimer;

  /// Start tracking state changes for all registered states.
  void startTracking() {
    if (_isTracking) return;
    
    _isTracking = true;
    for (final entry in _trackedStates.entries) {
      _startTrackingState(entry.key, entry.value);
    }
  }

  /// Stop tracking state changes.
  void stopTracking() {
    if (!_isTracking) return;
    
    _isTracking = false;
    _verificationTimer?.cancel();
    
    for (final entry in _listeners.entries) {
      final state = _trackedStates[entry.key];
      if (state != null && !state.isDisposed) {
        state.removeListener(entry.value);
      }
    }
    _listeners.clear();
  }

  /// Register a state for tracking with an optional identifier.
  void trackState<T>(
    String identifier,
    ObservableState<T> state,
  ) {
    if (_trackedStates.containsKey(identifier)) {
      throw ArgumentError('State with identifier "$identifier" is already being tracked');
    }
    
    _trackedStates[identifier] = state;
    _changeHistory[identifier] = [];
    
    if (_isTracking) {
      _startTrackingState(identifier, state);
    }
  }

  /// Unregister a state from tracking.
  void untrackState(String identifier) {
    final state = _trackedStates[identifier];
    if (state != null && _listeners.containsKey(identifier)) {
      if (!state.isDisposed) {
        state.removeListener(_listeners[identifier]!);
      }
      _listeners.remove(identifier);
    }
    
    _trackedStates.remove(identifier);
    _changeHistory.remove(identifier);
  }

  /// Clear all tracked states.
  void clearTracking() {
    stopTracking();
    _trackedStates.clear();
    _changeHistory.clear();
    _verifications.clear();
  }

  void _startTrackingState<T>(String identifier, ObservableState<T> state) {
    if (_listeners.containsKey(identifier)) return;
    
    // Record initial value
    _recordChange(identifier, null, state.value, 'initial');
    
    void listener() => _recordChange(identifier, null, state.value, 'change');
    _listeners[identifier] = listener;
    state.addListener(listener);
  }

  void _recordChange<T>(
    String identifier,
    T? previousValue,
    T currentValue,
    String changeType,
  ) {
    final entry = StateChangeEntry<T>(
      identifier: identifier,
      previousValue: previousValue,
      currentValue: currentValue,
      timestamp: DateTime.now(),
      changeType: changeType,
    );
    
    _changeHistory[identifier]?.add(entry);
    _checkVerifications(entry);
  }

  /// Get the change history for a specific state.
  List<StateChangeEntry> getChangeHistory(String identifier) {
    return List.unmodifiable(_changeHistory[identifier] ?? []);
  }

  /// Get the complete change history for all states.
  Map<String, List<StateChangeEntry>> getAllChangeHistory() {
    return Map.unmodifiable(
      _changeHistory.map((key, value) => MapEntry(key, List.unmodifiable(value))),
    );
  }

  /// Get the current value of a tracked state.
  T? getCurrentValue<T>(String identifier) {
    final state = _trackedStates[identifier] as ObservableState<T>?;
    return state?.value;
  }

  /// Get the number of changes for a specific state.
  int getChangeCount(String identifier) {
    return _changeHistory[identifier]?.length ?? 0;
  }

  /// Get the last change for a specific state.
  StateChangeEntry? getLastChange(String identifier) {
    final history = _changeHistory[identifier];
    return history?.isEmpty ?? true ? null : history!.last;
  }

  /// Clear the change history for a specific state.
  void clearHistory(String identifier) {
    _changeHistory[identifier]?.clear();
  }

  /// Clear the change history for all states.
  void clearAllHistory() {
    for (final history in _changeHistory.values) {
      history.clear();
    }
  }

  /// Add a verification rule that will be checked on each state change.
  void addVerification(StateChangeVerification verification) {
    _verifications.add(verification);
  }

  /// Remove a verification rule.
  void removeVerification(StateChangeVerification verification) {
    _verifications.remove(verification);
  }

  /// Clear all verification rules.
  void clearVerifications() {
    _verifications.clear();
  }

  void _checkVerifications(StateChangeEntry entry) {
    for (final verification in _verifications) {
      try {
        verification.verify(entry, this);
      } catch (e) {
        // Verification failed - could log or handle as needed
        debugPrint('State verification failed: $e');
      }
    }
  }

  /// Wait for a specific state to change to an expected value.
  Future<bool> waitForStateValue<T>(
    String identifier,
    T expectedValue, {
    Duration timeout = const Duration(seconds: 5),
    bool Function(T, T)? equals,
  }) async {
    final state = _trackedStates[identifier] as ObservableState<T>?;
    if (state == null) {
      throw ArgumentError('State "$identifier" is not being tracked');
    }

    final equalityCheck = equals ?? (a, b) => a == b;
    if (equalityCheck(state.value, expectedValue)) {
      return true;
    }

    final completer = Completer<bool>();
    late VoidCallback listener;
    Timer? timeoutTimer;

    listener = () {
      if (equalityCheck(state.value, expectedValue)) {
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

  /// Wait for any change in a specific state.
  Future<T?> waitForStateChange<T>(
    String identifier, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final state = _trackedStates[identifier] as ObservableState<T>?;
    if (state == null) {
      throw ArgumentError('State "$identifier" is not being tracked');
    }

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

  /// Create a snapshot of all tracked states.
  Map<String, StateSnapshot> createSnapshot() {
    final snapshot = <String, StateSnapshot>{};
    
    for (final entry in _trackedStates.entries) {
      final state = entry.value;
      if (!state.isDisposed) {
        snapshot[entry.key] = state.createSnapshot();
      }
    }
    
    return snapshot;
  }

  /// Restore all tracked states from a snapshot.
  void restoreSnapshot(Map<String, StateSnapshot> snapshot) {
    for (final entry in snapshot.entries) {
      final state = _trackedStates[entry.key];
      if (state != null && !state.isDisposed) {
        state.restoreSnapshot(entry.value);
      }
    }
  }

  /// Get statistics about tracked states.
  StateTrackingStatistics getStatistics() {
    final totalChanges = _changeHistory.values
        .fold<int>(0, (sum, history) => sum + history.length);
    
    final stateStats = <String, StateStatistics>{};
    for (final entry in _changeHistory.entries) {
      final history = entry.value;
      stateStats[entry.key] = StateStatistics(
        changeCount: history.length,
        firstChange: history.isEmpty ? null : history.first.timestamp,
        lastChange: history.isEmpty ? null : history.last.timestamp,
      );
    }
    
    return StateTrackingStatistics(
      trackedStateCount: _trackedStates.length,
      totalChangeCount: totalChanges,
      isTracking: _isTracking,
      stateStatistics: stateStats,
    );
  }

  /// Dispose the tracker and clean up resources.
  void dispose() {
    stopTracking();
    clearTracking();
  }
}

/// Represents a single state change entry.
class StateChangeEntry<T> {
  final String identifier;
  final T? previousValue;
  final T currentValue;
  final DateTime timestamp;
  final String changeType;

  const StateChangeEntry({
    required this.identifier,
    required this.previousValue,
    required this.currentValue,
    required this.timestamp,
    required this.changeType,
  });

  @override
  String toString() {
    return 'StateChangeEntry(id: $identifier, previous: $previousValue, '
           'current: $currentValue, type: $changeType, time: $timestamp)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StateChangeEntry<T> &&
          runtimeType == other.runtimeType &&
          identifier == other.identifier &&
          previousValue == other.previousValue &&
          currentValue == other.currentValue &&
          timestamp == other.timestamp &&
          changeType == other.changeType;

  @override
  int get hashCode => Object.hash(
        identifier,
        previousValue,
        currentValue,
        timestamp,
        changeType,
      );
}

/// Abstract base class for state change verifications.
abstract class StateChangeVerification {
  /// Verify a state change entry against this verification rule.
  void verify(StateChangeEntry entry, StateChangeTracker tracker);
}

/// Verification that checks if a state value matches an expected value.
class ValueVerification<T> extends StateChangeVerification {
  final String stateIdentifier;
  final T expectedValue;
  final bool Function(T, T)? equals;
  final String? description;

  ValueVerification({
    required this.stateIdentifier,
    required this.expectedValue,
    this.equals,
    this.description,
  });

  @override
  void verify(StateChangeEntry entry, StateChangeTracker tracker) {
    if (entry.identifier != stateIdentifier) return;
    
    final equalityCheck = equals ?? (a, b) => a == b;
    if (!equalityCheck(entry.currentValue as T, expectedValue)) {
      throw StateError(
        description ?? 
        'State "$stateIdentifier" value ${entry.currentValue} does not match expected $expectedValue'
      );
    }
  }
}

/// Verification that checks the sequence of state changes.
class SequenceVerification<T> extends StateChangeVerification {
  final String stateIdentifier;
  final List<T> expectedSequence;
  final List<T> _actualSequence = [];
  final bool Function(T, T)? equals;
  final String? description;

  SequenceVerification({
    required this.stateIdentifier,
    required this.expectedSequence,
    this.equals,
    this.description,
  });

  @override
  void verify(StateChangeEntry entry, StateChangeTracker tracker) {
    if (entry.identifier != stateIdentifier) return;
    
    _actualSequence.add(entry.currentValue as T);
    
    if (_actualSequence.length > expectedSequence.length) {
      throw StateError(
        description ?? 
        'State "$stateIdentifier" has more changes than expected sequence'
      );
    }
    
    final equalityCheck = equals ?? (a, b) => a == b;
    final index = _actualSequence.length - 1;
    if (!equalityCheck(_actualSequence[index], expectedSequence[index])) {
      throw StateError(
        description ?? 
        'State "$stateIdentifier" sequence mismatch at index $index: '
        'expected ${expectedSequence[index]}, got ${_actualSequence[index]}'
      );
    }
  }

  /// Reset the verification to start checking the sequence again.
  void reset() {
    _actualSequence.clear();
  }
}

/// Statistics about state tracking.
class StateTrackingStatistics {
  final int trackedStateCount;
  final int totalChangeCount;
  final bool isTracking;
  final Map<String, StateStatistics> stateStatistics;

  const StateTrackingStatistics({
    required this.trackedStateCount,
    required this.totalChangeCount,
    required this.isTracking,
    required this.stateStatistics,
  });

  @override
  String toString() {
    return 'StateTrackingStatistics(states: $trackedStateCount, '
           'changes: $totalChangeCount, tracking: $isTracking)';
  }
}

/// Statistics for an individual state.
class StateStatistics {
  final int changeCount;
  final DateTime? firstChange;
  final DateTime? lastChange;

  const StateStatistics({
    required this.changeCount,
    this.firstChange,
    this.lastChange,
  });

  Duration? get trackingDuration {
    if (firstChange == null || lastChange == null) return null;
    return lastChange!.difference(firstChange!);
  }

  @override
  String toString() {
    return 'StateStatistics(changes: $changeCount, '
           'duration: ${trackingDuration?.inMilliseconds}ms)';
  }
}

/// Factory function for creating a state change tracker.
StateChangeTracker createStateTracker() => StateChangeTracker();