import 'package:flutter/widgets.dart';
import '../observable_state.dart';
import '../equality_checker.dart';
import '../state_exceptions.dart';

import 'state_change_tracker.dart';

/// Test-friendly version of StateBuilder with enhanced tracking and control capabilities.
///
/// This builder provides additional features for testing:
/// - Synchronous state updates for predictable testing
/// - Comprehensive change tracking and verification
/// - Manual control over rebuild timing
/// - Error injection and testing capabilities
/// - Performance metrics collection
class TestStateBuilder<T> extends StatefulWidget {
  /// The state to observe and build from.
  final ObservableState<T> state;

  /// The builder function that creates the widget tree.
  final Widget Function(BuildContext, T) builder;

  /// Optional error builder for testing error scenarios.
  final Widget Function(BuildContext, StateException)? errorBuilder;

  /// Custom equality checker for testing equality behavior.
  final EqualityChecker<T>? equalityChecker;

  /// Whether to enable automatic rebuilds (false for manual control in tests).
  final bool enableAutoRebuild;

  /// Whether to track all state changes for verification.
  final bool enableChangeTracking;

  /// Key for identifying this builder in tests.
  final String? testKey;

  /// Optional change tracker for external tracking.
  final StateChangeTracker? changeTracker;

  const TestStateBuilder({
    super.key,
    required this.state,
    required this.builder,
    this.errorBuilder,
    this.equalityChecker,
    this.enableAutoRebuild = true,
    this.enableChangeTracking = true,
    this.testKey,
    this.changeTracker,
  });

  @override
  State<TestStateBuilder<T>> createState() => TestStateBuilderState<T>();
}

class TestStateBuilderState<T> extends State<TestStateBuilder<T>> {
  late T _currentValue;
  late EqualityChecker<T> _equalityChecker;
  StateException? _injectedError;
  bool _isManualRebuildPending = false;

  // Tracking data
  final List<TestStateChangeEvent<T>> _changeHistory = [];
  final List<BuildEvent> _buildHistory = [];
  int _buildCount = 0;
  int _skippedBuilds = 0;
  DateTime? _lastBuildTime;
  Duration? _lastBuildDuration;

  // Test control
  bool _shouldThrowOnBuild = false;
  StateException? _buildException;
  bool _shouldSkipNextBuild = false;

  @override
  void initState() {
    super.initState();

    _equalityChecker = widget.equalityChecker ?? EqualityChecker<T>();
    _currentValue = widget.state.value;

    // Record initial state
    if (widget.enableChangeTracking) {
      _recordStateChange(null, _currentValue, 'initial');
    }

    widget.state.addListener(_onStateChanged);

    // Register with external tracker if provided
    if (widget.changeTracker != null && widget.testKey != null) {
      widget.changeTracker!.trackState(widget.testKey!, widget.state);
    }
  }

  @override
  void didUpdateWidget(TestStateBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.state != widget.state) {
      oldWidget.state.removeListener(_onStateChanged);
      widget.state.addListener(_onStateChanged);

      // Update external tracker
      if (widget.changeTracker != null && widget.testKey != null) {
        if (oldWidget.testKey != null) {
          widget.changeTracker!.untrackState(oldWidget.testKey!);
        }
        widget.changeTracker!.trackState(widget.testKey!, widget.state);
      }

      final oldValue = _currentValue;
      _currentValue = widget.state.value;

      if (widget.enableChangeTracking) {
        _recordStateChange(oldValue, _currentValue, 'stateChanged');
      }
    }

    if (oldWidget.equalityChecker != widget.equalityChecker) {
      _equalityChecker = widget.equalityChecker ?? EqualityChecker<T>();
    }
  }

  @override
  void dispose() {
    widget.state.removeListener(_onStateChanged);

    // Unregister from external tracker
    if (widget.changeTracker != null && widget.testKey != null) {
      widget.changeTracker!.untrackState(widget.testKey!);
    }

    super.dispose();
  }

  void _onStateChanged() {
    if (!mounted) return;

    final newValue = widget.state.value;
    final oldValue = _currentValue;

    // Check if we should skip this build
    if (_shouldSkipNextBuild) {
      _shouldSkipNextBuild = false;
      _skippedBuilds++;
      return;
    }

    // Use equality checker to determine if rebuild is needed
    if (_equalityChecker.equals(_currentValue, newValue)) {
      _skippedBuilds++;
      if (widget.enableChangeTracking) {
        _recordStateChange(oldValue, newValue, 'skipped');
      }
      return;
    }

    if (widget.enableChangeTracking) {
      _recordStateChange(oldValue, newValue, 'changed');
    }

    if (widget.enableAutoRebuild) {
      _performRebuild(newValue);
    } else {
      _currentValue = newValue;
      _isManualRebuildPending = true;
    }
  }

  void _performRebuild(T newValue) {
    setState(() {
      _currentValue = newValue;
      // Build count is incremented in build method, not here
    });
  }

  void _recordStateChange(T? oldValue, T newValue, String reason) {
    final event = TestStateChangeEvent<T>(
      previousValue: oldValue,
      newValue: newValue,
      timestamp: DateTime.now(),
      source: reason,
    );

    _changeHistory.add(event);

    // Limit history size to prevent memory issues in long-running tests
    if (_changeHistory.length > 1000) {
      _changeHistory.removeAt(0);
    }
  }

  void _recordBuildEvent(String phase, {Duration? duration, Object? error}) {
    final event = BuildEvent(
      phase: phase,
      timestamp: DateTime.now(),
      buildCount: _buildCount,
      duration: duration,
      error: error,
      currentValue: _currentValue,
    );

    _buildHistory.add(event);

    // Limit history size
    if (_buildHistory.length > 500) {
      _buildHistory.removeAt(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final buildStart = DateTime.now();
    _buildCount++; // Increment build count for every build
    _recordBuildEvent('buildStart');

    try {
      // Handle injected errors
      if (_injectedError != null) {
        final error = _injectedError!;
        _injectedError = null; // Clear after use
        throw error;
      }

      // Handle test-controlled build exceptions
      if (_shouldThrowOnBuild) {
        _shouldThrowOnBuild = false;
        throw _buildException ??
            StateValidationException('Test build exception');
      }

      Widget result;

      try {
        result = widget.builder(context, _currentValue);
        _lastBuildTime = DateTime.now();
        _lastBuildDuration = _lastBuildTime!.difference(buildStart);

        _recordBuildEvent('buildSuccess', duration: _lastBuildDuration);

        return result;
      } catch (error) {
        _recordBuildEvent('buildError', error: error);

        final stateError =
            error is StateException
                ? error
                : StateValidationException(
                  'Builder function failed: $error',
                  cause: error,
                  violatedRule: 'builder_execution',
                );

        if (widget.errorBuilder != null) {
          return widget.errorBuilder!(context, stateError);
        } else {
          return _buildDefaultErrorWidget(context, stateError);
        }
      }
    } catch (error) {
      _recordBuildEvent('buildCriticalError', error: error);

      final stateError =
          error is StateException
              ? error
              : StateValidationException(
                'Critical build error: $error',
                cause: error,
                violatedRule: 'critical_build_error',
              );

      if (widget.errorBuilder != null) {
        return widget.errorBuilder!(context, stateError);
      } else {
        return _buildDefaultErrorWidget(context, stateError);
      }
    }
  }

  Widget _buildDefaultErrorWidget(BuildContext context, StateException error) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        border: Border.all(color: const Color(0xFFE57373)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Test Error',
            style: TextStyle(
              color: Color(0xFFD32F2F),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          Text(
            error.message,
            style: const TextStyle(color: Color(0xFFD32F2F), fontSize: 10),
          ),
        ],
      ),
    );
  }

  // Test Control Methods

  /// Manually triggers a rebuild (useful when auto-rebuild is disabled).
  void manualRebuild() {
    if (mounted) {
      _performRebuild(_currentValue);
      _isManualRebuildPending = false;
    }
  }

  /// Injects an error that will be thrown on the next build.
  void injectError(StateException error) {
    _injectedError = error;
    if (widget.enableAutoRebuild && mounted) {
      setState(() {});
    }
  }

  /// Makes the next build throw an exception.
  void throwOnNextBuild([StateException? error]) {
    _shouldThrowOnBuild = true;
    _buildException = error;
  }

  /// Skips the next rebuild (useful for testing optimization behavior).
  void skipNextBuild() {
    _shouldSkipNextBuild = true;
  }

  /// Forces a state change notification without changing the actual value.
  void forceStateNotification() {
    if (mounted) {
      _onStateChanged();
    }
  }

  // Verification Methods

  /// Gets the complete change history for verification.
  List<TestStateChangeEvent<T>> get changeHistory =>
      List.unmodifiable(_changeHistory);

  /// Gets the complete build history for verification.
  List<BuildEvent> get buildHistory => List.unmodifiable(_buildHistory);

  /// Gets the current state value.
  T get currentValue => _currentValue;

  /// Checks if a manual rebuild is pending.
  bool get isManualRebuildPending => _isManualRebuildPending;

  /// Gets comprehensive performance statistics.
  TestBuilderStats get stats => TestBuilderStats(
    buildCount: _buildCount,
    skippedBuilds: _skippedBuilds,
    changeCount: _changeHistory.length,
    lastBuildTime: _lastBuildTime,
    lastBuildDuration: _lastBuildDuration,
    enableAutoRebuild: widget.enableAutoRebuild,
    enableChangeTracking: widget.enableChangeTracking,
    equalityStats: _equalityChecker.getCacheStats(),
  );

  /// Verifies that the expected number of builds occurred.
  bool verifyBuildCount(int expectedCount) {
    return _buildCount == expectedCount;
  }

  /// Verifies that the expected number of builds were skipped.
  bool verifySkippedBuilds(int expectedCount) {
    return _skippedBuilds == expectedCount;
  }

  /// Verifies that a specific state change occurred.
  bool verifyStateChange(T? expectedOldValue, T expectedNewValue) {
    return _changeHistory.any(
      (event) =>
          (expectedOldValue == null
              ? event.previousValue == null
              : _equalityChecker.equals(
                event.previousValue ?? expectedOldValue,
                expectedOldValue,
              )) &&
          _equalityChecker.equals(event.newValue, expectedNewValue),
    );
  }

  /// Verifies that no builds occurred within a time period.
  bool verifyNoBuildsDuring(Duration period) {
    final cutoff = DateTime.now().subtract(period);
    return !_buildHistory.any((event) => event.timestamp.isAfter(cutoff));
  }

  /// Clears all tracking history (useful for test cleanup).
  void clearHistory() {
    _changeHistory.clear();
    _buildHistory.clear();
    _buildCount = 0;
    _skippedBuilds = 0;
  }
}

/// Event representing a state change for testing verification.
class TestStateChangeEvent<T> {
  final T? previousValue;
  final T newValue;
  final DateTime timestamp;
  final String source;

  const TestStateChangeEvent({
    required this.previousValue,
    required this.newValue,
    required this.timestamp,
    required this.source,
  });

  @override
  String toString() {
    return 'TestStateChangeEvent(previous: $previousValue, new: $newValue, source: $source, time: $timestamp)';
  }
}

/// Event representing a build operation for testing verification.
class BuildEvent {
  final String phase;
  final DateTime timestamp;
  final int buildCount;
  final Duration? duration;
  final Object? error;
  final dynamic currentValue;

  const BuildEvent({
    required this.phase,
    required this.timestamp,
    required this.buildCount,
    this.duration,
    this.error,
    this.currentValue,
  });

  @override
  String toString() {
    return 'BuildEvent(phase: $phase, count: $buildCount, duration: $duration, error: $error, time: $timestamp)';
  }
}

/// Comprehensive statistics for test verification.
class TestBuilderStats {
  final int buildCount;
  final int skippedBuilds;
  final int changeCount;
  final DateTime? lastBuildTime;
  final Duration? lastBuildDuration;
  final bool enableAutoRebuild;
  final bool enableChangeTracking;
  final Map<String, dynamic> equalityStats;

  const TestBuilderStats({
    required this.buildCount,
    required this.skippedBuilds,
    required this.changeCount,
    this.lastBuildTime,
    this.lastBuildDuration,
    required this.enableAutoRebuild,
    required this.enableChangeTracking,
    required this.equalityStats,
  });

  /// Calculates the rebuild efficiency (builds / total notifications).
  double get rebuildEfficiency {
    final totalNotifications = buildCount + skippedBuilds;
    return totalNotifications > 0 ? buildCount / totalNotifications : 0.0;
  }

  /// Gets average build duration if available.
  Duration? get averageBuildDuration {
    // This would require tracking all build durations, simplified for now
    return lastBuildDuration;
  }

  Map<String, dynamic> toMap() {
    return {
      'buildCount': buildCount,
      'skippedBuilds': skippedBuilds,
      'changeCount': changeCount,
      'rebuildEfficiency': rebuildEfficiency,
      'lastBuildTime': lastBuildTime?.toIso8601String(),
      'lastBuildDuration': lastBuildDuration?.inMicroseconds,
      'enableAutoRebuild': enableAutoRebuild,
      'enableChangeTracking': enableChangeTracking,
      'equalityStats': equalityStats,
    };
  }
}

/// Convenience function to create a TestStateBuilder.
Widget buildTestState<T>(
  ObservableState<T> state,
  Widget Function(BuildContext, T) builder, {
  Widget Function(BuildContext, StateException)? errorBuilder,
  EqualityChecker<T>? equalityChecker,
  bool enableAutoRebuild = true,
  bool enableChangeTracking = true,
  String? testKey,
  StateChangeTracker? changeTracker,
}) {
  return TestStateBuilder<T>(
    state: state,
    builder: builder,
    errorBuilder: errorBuilder,
    equalityChecker: equalityChecker,
    enableAutoRebuild: enableAutoRebuild,
    enableChangeTracking: enableChangeTracking,
    testKey: testKey,
    changeTracker: changeTracker,
  );
}
