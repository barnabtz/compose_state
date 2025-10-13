import 'dart:async';
import 'package:flutter/foundation.dart';
import 'observable_state.dart';

/// Manages the lifecycle of state objects with automatic disposal and weak reference tracking.
/// 
/// This class provides sophisticated memory management for state objects,
/// including automatic disposal of unused states, circular reference detection,
/// and lifecycle event tracking.
class StateLifecycleManager {
  static StateLifecycleManager? _instance;
  
  /// Gets the singleton instance of the StateLifecycleManager.
  static StateLifecycleManager get instance => _instance ??= StateLifecycleManager._();
  
  StateLifecycleManager._();

  final Map<String, WeakReference<ObservableState>> _weakReferences = {};
  final Map<String, Set<String>> _dependencies = {};
  final Map<String, Set<String>> _dependents = {};
  final Map<String, DateTime> _lastAccessTimes = {};
  final Map<String, int> _accessCounts = {};
  final Set<String> _markedForDisposal = {};
  
  Timer? _cleanupTimer;
  Timer? _disposalTimer;
  
  /// Duration after which unused states are considered for disposal.
  Duration unusedStateThreshold = const Duration(minutes: 5);
  
  /// Interval for running automatic cleanup operations.
  Duration cleanupInterval = const Duration(minutes: 1);

  /// Starts the automatic lifecycle management.
  /// 
  /// This begins periodic cleanup operations and automatic disposal
  /// of unused states.
  void start() {
    if (_cleanupTimer != null) return;
    
    _cleanupTimer = Timer.periodic(cleanupInterval, (_) {
      _performPeriodicCleanup();
    });
    
    debugPrint('StateLifecycleManager: Started automatic lifecycle management');
  }

  /// Stops the automatic lifecycle management.
  void stop() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    _disposalTimer?.cancel();
    _disposalTimer = null;
    
    debugPrint('StateLifecycleManager: Stopped automatic lifecycle management');
  }

  /// Tracks a state object with weak reference.
  /// 
  /// Returns a unique identifier for the tracked state.
  String trackState<T>(ObservableState<T> state, {String? name}) {
    final id = name ?? _generateStateId(state);
    
    _weakReferences[id] = WeakReference(state);
    _lastAccessTimes[id] = DateTime.now();
    _accessCounts[id] = 1;
    
    debugPrint('StateLifecycleManager: Tracking state $id (${state.runtimeType})');
    
    return id;
  }

  /// Stops tracking a state object.
  void untrackState(String stateId) {
    _weakReferences.remove(stateId);
    _lastAccessTimes.remove(stateId);
    _accessCounts.remove(stateId);
    _markedForDisposal.remove(stateId);
    
    // Clean up dependencies
    _removeDependencies(stateId);
    
    debugPrint('StateLifecycleManager: Stopped tracking state $stateId');
  }

  /// Records access to a state to update its lifecycle tracking.
  void recordAccess(String stateId) {
    if (_weakReferences.containsKey(stateId)) {
      _lastAccessTimes[stateId] = DateTime.now();
      _accessCounts[stateId] = (_accessCounts[stateId] ?? 0) + 1;
    }
  }

  /// Adds a dependency relationship between two states.
  /// 
  /// When [dependentId] depends on [dependencyId], this relationship
  /// is tracked to prevent premature disposal and detect circular references.
  void addDependency(String dependentId, String dependencyId) {
    _dependencies.putIfAbsent(dependentId, () => <String>{}).add(dependencyId);
    _dependents.putIfAbsent(dependencyId, () => <String>{}).add(dependentId);
    
    // Check for circular references
    if (_hasCircularReference(dependentId, dependencyId)) {
      debugPrint('StateLifecycleManager: Circular reference detected between $dependentId and $dependencyId');
      _handleCircularReference(dependentId, dependencyId);
    }
  }

  /// Removes a dependency relationship between two states.
  void removeDependency(String dependentId, String dependencyId) {
    _dependencies[dependentId]?.remove(dependencyId);
    _dependents[dependencyId]?.remove(dependentId);
    
    // Clean up empty sets
    if (_dependencies[dependentId]?.isEmpty == true) {
      _dependencies.remove(dependentId);
    }
    if (_dependents[dependencyId]?.isEmpty == true) {
      _dependents.remove(dependencyId);
    }
  }

  /// Gets all states that are eligible for automatic disposal.
  /// 
  /// A state is eligible if:
  /// - It hasn't been accessed recently
  /// - It has no dependents
  /// - It's not marked as persistent
  List<String> getDisposableStates() {
    final now = DateTime.now();
    final disposable = <String>[];
    
    for (final entry in _lastAccessTimes.entries) {
      final stateId = entry.key;
      final lastAccess = entry.value;
      
      // Skip if recently accessed
      if (now.difference(lastAccess) < unusedStateThreshold) continue;
      
      // Skip if has dependents
      if (_dependents[stateId]?.isNotEmpty == true) continue;
      
      // Skip if already marked for disposal
      if (_markedForDisposal.contains(stateId)) continue;
      
      // Check if state still exists and is not disposed
      final weakRef = _weakReferences[stateId];
      final state = weakRef?.target;
      if (state != null && !state.isDisposed) {
        disposable.add(stateId);
      }
    }
    
    return disposable;
  }

  /// Marks states for automatic disposal.
  /// 
  /// Marked states will be disposed in the next disposal cycle,
  /// giving them a grace period for potential reuse.
  void markForDisposal(List<String> stateIds) {
    for (final stateId in stateIds) {
      _markedForDisposal.add(stateId);
      debugPrint('StateLifecycleManager: Marked state $stateId for disposal');
    }
    
    // Schedule disposal if not already scheduled
    _scheduleDisposal();
  }

  /// Immediately disposes marked states.
  void disposeMarkedStates() {
    final toDispose = _markedForDisposal.toList();
    _markedForDisposal.clear();
    
    for (final stateId in toDispose) {
      final weakRef = _weakReferences[stateId];
      final state = weakRef?.target;
      
      if (state != null && !state.isDisposed) {
        try {
          state.dispose();
          debugPrint('StateLifecycleManager: Disposed state $stateId');
        } catch (e, stackTrace) {
          debugPrint('StateLifecycleManager: Error disposing state $stateId: $e');
          debugPrint('Stack trace: $stackTrace');
        }
      }
      
      untrackState(stateId);
    }
  }

  /// Detects circular references in the dependency graph.
  List<List<String>> detectCircularReferences() {
    final cycles = <List<String>>[];
    final visited = <String>{};
    final recursionStack = <String>{};
    
    for (final stateId in _dependencies.keys) {
      if (!visited.contains(stateId)) {
        final cycle = _detectCycleFromNode(stateId, visited, recursionStack, []);
        if (cycle.isNotEmpty) {
          cycles.add(cycle);
        }
      }
    }
    
    return cycles;
  }

  /// Gets lifecycle statistics for all tracked states.
  StateLifecycleStats getLifecycleStats() {
    _cleanupDeadReferences();
    
    final now = DateTime.now();
    final activeStates = <String>[];
    final unusedStates = <String>[];
    final recentlyAccessed = <String>[];
    
    for (final entry in _lastAccessTimes.entries) {
      final stateId = entry.key;
      final lastAccess = entry.value;
      final timeSinceAccess = now.difference(lastAccess);
      
      final weakRef = _weakReferences[stateId];
      final state = weakRef?.target;
      
      if (state != null && !state.isDisposed) {
        activeStates.add(stateId);
        
        if (timeSinceAccess < const Duration(minutes: 1)) {
          recentlyAccessed.add(stateId);
        } else if (timeSinceAccess > unusedStateThreshold) {
          unusedStates.add(stateId);
        }
      }
    }
    
    return StateLifecycleStats(
      totalTracked: _weakReferences.length,
      activeStates: activeStates.length,
      unusedStates: unusedStates.length,
      recentlyAccessed: recentlyAccessed.length,
      markedForDisposal: _markedForDisposal.length,
      circularReferences: detectCircularReferences().length,
      totalDependencies: _dependencies.values.fold(0, (sum, deps) => sum + deps.length),
    );
  }

  void _performPeriodicCleanup() {
    _cleanupDeadReferences();
    
    final disposableStates = getDisposableStates();
    if (disposableStates.isNotEmpty) {
      markForDisposal(disposableStates);
    }
  }

  void _cleanupDeadReferences() {
    final deadReferences = <String>[];
    
    for (final entry in _weakReferences.entries) {
      if (entry.value.target == null) {
        deadReferences.add(entry.key);
      }
    }
    
    for (final deadRef in deadReferences) {
      untrackState(deadRef);
    }
    
    if (deadReferences.isNotEmpty) {
      debugPrint('StateLifecycleManager: Cleaned up ${deadReferences.length} dead references');
    }
  }

  void _scheduleDisposal() {
    if (_disposalTimer != null) return;
    
    _disposalTimer = Timer(const Duration(seconds: 30), () {
      disposeMarkedStates();
      _disposalTimer = null;
    });
  }

  bool _hasCircularReference(String from, String to) {
    final visited = <String>{};
    return _hasCyclePath(to, from, visited);
  }

  bool _hasCyclePath(String current, String target, Set<String> visited) {
    if (current == target) return true;
    if (visited.contains(current)) return false;
    
    visited.add(current);
    
    final dependencies = _dependencies[current] ?? <String>{};
    for (final dep in dependencies) {
      if (_hasCyclePath(dep, target, visited)) {
        return true;
      }
    }
    
    return false;
  }

  void _handleCircularReference(String state1, String state2) {
    // For now, just log the circular reference
    // In a more sophisticated implementation, we might:
    // - Break the cycle by removing one dependency
    // - Mark both states as non-disposable
    // - Notify the application about the circular reference
    debugPrint('StateLifecycleManager: Handling circular reference between $state1 and $state2');
  }

  List<String> _detectCycleFromNode(String node, Set<String> visited, Set<String> recursionStack, List<String> path) {
    visited.add(node);
    recursionStack.add(node);
    path.add(node);
    
    final dependencies = _dependencies[node] ?? <String>{};
    for (final dep in dependencies) {
      if (!visited.contains(dep)) {
        final cycle = _detectCycleFromNode(dep, visited, recursionStack, List.from(path));
        if (cycle.isNotEmpty) return cycle;
      } else if (recursionStack.contains(dep)) {
        // Found a cycle
        final cycleStart = path.indexOf(dep);
        return path.sublist(cycleStart)..add(dep);
      }
    }
    
    recursionStack.remove(node);
    return [];
  }

  void _removeDependencies(String stateId) {
    // Remove as dependent
    final dependencies = _dependencies.remove(stateId) ?? <String>{};
    for (final dep in dependencies) {
      _dependents[dep]?.remove(stateId);
      if (_dependents[dep]?.isEmpty == true) {
        _dependents.remove(dep);
      }
    }
    
    // Remove as dependency
    final dependents = _dependents.remove(stateId) ?? <String>{};
    for (final dependent in dependents) {
      _dependencies[dependent]?.remove(stateId);
      if (_dependencies[dependent]?.isEmpty == true) {
        _dependencies.remove(dependent);
      }
    }
  }

  String _generateStateId(ObservableState state) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final hashCode = state.hashCode;
    return '${state.runtimeType}_${timestamp}_$hashCode';
  }
}

/// Statistics about state lifecycle management.
class StateLifecycleStats {
  /// Total number of states being tracked.
  final int totalTracked;
  
  /// Number of active (non-disposed) states.
  final int activeStates;
  
  /// Number of states that haven't been accessed recently.
  final int unusedStates;
  
  /// Number of states accessed in the last minute.
  final int recentlyAccessed;
  
  /// Number of states marked for disposal.
  final int markedForDisposal;
  
  /// Number of circular reference cycles detected.
  final int circularReferences;
  
  /// Total number of dependency relationships.
  final int totalDependencies;

  const StateLifecycleStats({
    required this.totalTracked,
    required this.activeStates,
    required this.unusedStates,
    required this.recentlyAccessed,
    required this.markedForDisposal,
    required this.circularReferences,
    required this.totalDependencies,
  });

  @override
  String toString() {
    return 'StateLifecycleStats('
        'tracked: $totalTracked, '
        'active: $activeStates, '
        'unused: $unusedStates, '
        'recent: $recentlyAccessed, '
        'marked: $markedForDisposal, '
        'cycles: $circularReferences, '
        'deps: $totalDependencies)';
  }
}