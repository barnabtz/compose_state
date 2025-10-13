import 'package:flutter/foundation.dart';
import 'observable_state.dart';
import 'state_registry.dart';
import 'state_lifecycle_manager.dart';

/// Centralized manager for state lifecycle and memory management.
///
/// The StateManager provides a global registry of active states,
/// automatic disposal mechanisms, and memory leak detection.
/// This is the main entry point for state management operations.
class StateManager {
  static StateManager? _instance;

  /// Gets the singleton instance of the StateManager.
  static StateManager get instance => _instance ??= StateManager._();

  StateManager._();

  final Map<String, WeakReference<ObservableState>> _stateRegistry = {};
  final Map<String, DateTime> _creationTimes = {};
  final Set<String> _disposedStates = {};

  bool _isStarted = false;

  /// Starts the state manager with automatic memory management.
  void start() {
    if (_isStarted) return;

    StateRegistry.instance.start();
    _isStarted = true;

    debugPrint('StateManager: Started with automatic memory management');
  }

  /// Stops the state manager and cleanup operations.
  void stop() {
    if (!_isStarted) return;

    StateRegistry.instance.stop();
    _isStarted = false;

    debugPrint('StateManager: Stopped');
  }

  /// Registers a state with the manager for lifecycle tracking.
  ///
  /// Returns a unique identifier for the state that can be used
  /// for later operations.
  String registerState<T>(
    ObservableState<T> state, {
    String? name,
    Set<String>? tags,
    Map<String, dynamic>? metadata,
  }) {
    // Ensure the manager is started
    if (!_isStarted) start();

    final id = StateRegistry.instance.registerState(
      state,
      name: name,
      tags: tags,
      customMetadata: metadata,
    );

    // Keep backward compatibility with legacy registry
    _stateRegistry[id] = WeakReference(state);
    _creationTimes[id] = DateTime.now();

    debugPrint('StateManager: Registered state $id (${state.runtimeType})');

    return id;
  }

  /// Unregisters a state from the manager.
  ///
  /// This should be called when a state is disposed to clean up
  /// the registry and prevent memory leaks.
  void unregisterState(String stateId) {
    StateRegistry.instance.unregisterState(stateId);

    // Keep backward compatibility with legacy registry
    _stateRegistry.remove(stateId);
    _creationTimes.remove(stateId);
    _disposedStates.add(stateId);

    debugPrint('StateManager: Unregistered state $stateId');
  }

  /// Gets a registered state by its ID.
  ///
  /// Returns null if the state is not found or has been garbage collected.
  ObservableState<T>? getState<T>(String stateId) {
    // Use the new registry first
    final state = StateRegistry.instance.getState<T>(stateId);
    if (state != null) return state;

    // Fallback to legacy registry for backward compatibility
    final weakRef = _stateRegistry[stateId];
    if (weakRef == null) return null;

    final legacyState = weakRef.target;
    if (legacyState == null) {
      // State was garbage collected, clean up the registry
      _cleanupDeadReference(stateId);
      return null;
    }

    return legacyState as ObservableState<T>?;
  }

  /// Gets all currently active (non-disposed, non-garbage-collected) states.
  List<ObservableState> getActiveStates() {
    // Use the new registry
    return StateRegistry.instance.getAllActiveStates();
  }

  /// Disposes all registered states.
  ///
  /// This is useful for cleanup during app shutdown or testing.
  void disposeAllStates() {
    final activeStates = getActiveStates();

    for (final state in activeStates) {
      try {
        if (!state.isDisposed) {
          state.dispose();
        }
      } catch (e, stackTrace) {
        debugPrint('StateManager: Error disposing state: $e');
        debugPrint('Stack trace: $stackTrace');
      }
    }

    // Clear both registries
    StateRegistry.instance.performCleanup();
    _stateRegistry.clear();
    _creationTimes.clear();
    _disposedStates.clear();

    debugPrint('StateManager: Disposed all states');
  }

  /// Performs garbage collection of dead state references.
  ///
  /// This removes entries from the registry where the state
  /// has been garbage collected.
  void performGarbageCollection() {
    // Use the new registry's cleanup
    StateRegistry.instance.performCleanup();

    // Also clean up legacy registry
    final deadReferences = <String>[];

    for (final entry in _stateRegistry.entries) {
      if (entry.value.target == null) {
        deadReferences.add(entry.key);
      }
    }

    for (final deadRef in deadReferences) {
      _cleanupDeadReference(deadRef);
    }

    if (deadReferences.isNotEmpty) {
      debugPrint(
        'StateManager: Cleaned up ${deadReferences.length} dead references',
      );
    }
  }

  /// Gets memory usage statistics for registered states.
  StateMemoryStats getMemoryStats() {
    performGarbageCollection(); // Clean up first

    final registryStats = StateRegistry.instance.getStats();
    final activeCount = getActiveStates().length;
    final totalRegistered = _stateRegistry.length;
    final disposedCount = _disposedStates.length;

    return StateMemoryStats(
      activeStates: activeCount,
      totalRegistered: totalRegistered,
      disposedStates: disposedCount,
      oldestStateAge: _getOldestStateAge(),
      registryStats: registryStats,
    );
  }

  /// Detects potential memory leaks by finding long-lived states.
  ///
  /// Returns a list of state IDs that have been active for longer
  /// than the specified duration.
  List<String> detectPotentialLeaks({
    Duration threshold = const Duration(minutes: 30),
  }) {
    // Use the new registry's leak detection
    final registryLeaks = StateRegistry.instance.detectMemoryLeaks(
      threshold: threshold,
    );

    // Also check legacy registry for backward compatibility
    final now = DateTime.now();
    final legacyLeaks = <String>[];

    for (final entry in _creationTimes.entries) {
      final age = now.difference(entry.value);
      if (age > threshold) {
        final state = _stateRegistry[entry.key]?.target;
        if (state != null && !state.isDisposed) {
          legacyLeaks.add(entry.key);
        }
      }
    }

    // Combine and deduplicate
    final allLeaks = <String>{...registryLeaks, ...legacyLeaks};
    return allLeaks.toList();
  }

  /// Adds a dependency relationship between states.
  void addStateDependency(String dependentId, String dependencyId) {
    StateRegistry.instance.addStateDependency(dependentId, dependencyId);
  }

  /// Removes a dependency relationship between states.
  void removeStateDependency(String dependentId, String dependencyId) {
    StateRegistry.instance.removeStateDependency(dependentId, dependencyId);
  }

  /// Gets states by type using the new registry.
  List<T> getStatesByType<T extends ObservableState>() {
    return StateRegistry.instance.getStatesByType<T>();
  }

  /// Gets states by tag using the new registry.
  List<ObservableState> getStatesByTag(String tag) {
    return StateRegistry.instance.getStatesByTag(tag);
  }

  /// Gets comprehensive lifecycle statistics.
  StateLifecycleStats getLifecycleStats() {
    return StateLifecycleManager.instance.getLifecycleStats();
  }

  /// Detects circular references in state dependencies.
  List<List<String>> detectCircularReferences() {
    return StateLifecycleManager.instance.detectCircularReferences();
  }

  void _cleanupDeadReference(String stateId) {
    _stateRegistry.remove(stateId);
    _creationTimes.remove(stateId);
  }

  Duration? _getOldestStateAge() {
    if (_creationTimes.isEmpty) return null;

    final now = DateTime.now();
    final oldestTime = _creationTimes.values.reduce(
      (a, b) => a.isBefore(b) ? a : b,
    );
    return now.difference(oldestTime);
  }
}

/// Statistics about state memory usage.
class StateMemoryStats {
  /// Number of currently active (non-disposed) states.
  final int activeStates;

  /// Total number of registered states (including disposed ones).
  final int totalRegistered;

  /// Number of states that have been disposed.
  final int disposedStates;

  /// Age of the oldest active state, or null if no states exist.
  final Duration? oldestStateAge;

  /// Comprehensive registry statistics.
  final StateRegistryStats? registryStats;

  const StateMemoryStats({
    required this.activeStates,
    required this.totalRegistered,
    required this.disposedStates,
    this.oldestStateAge,
    this.registryStats,
  });

  @override
  String toString() {
    return 'StateMemoryStats('
        'active: $activeStates, '
        'total: $totalRegistered, '
        'disposed: $disposedStates, '
        'oldest: ${oldestStateAge?.inMinutes ?? 0} minutes'
        '${registryStats != null ? ', registry: $registryStats' : ''})';
  }
}
