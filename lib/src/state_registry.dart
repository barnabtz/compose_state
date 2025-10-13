import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'observable_state.dart';
import 'state_lifecycle_manager.dart';

/// Global registry for state tracking and memory monitoring.
/// 
/// This class provides comprehensive state management capabilities including
/// registration, lookup, memory monitoring, and automatic cleanup.
class StateRegistry {
  static StateRegistry? _instance;
  
  /// Gets the singleton instance of the StateRegistry.
  static StateRegistry get instance => _instance ??= StateRegistry._();
  
  StateRegistry._();

  final Map<String, WeakReference<ObservableState>> _states = {};
  final Map<String, StateMetadata> _metadata = {};
  final Map<Type, Set<String>> _statesByType = {};
  final Map<String, Set<String>> _statesByTag = {};
  final Queue<StateEvent> _eventHistory = Queue();
  
  Timer? _monitoringTimer;
  
  /// Maximum number of events to keep in history.
  int maxEventHistory = 1000;
  
  /// Interval for memory monitoring checks.
  Duration monitoringInterval = const Duration(seconds: 30);

  /// Starts the state registry with monitoring capabilities.
  void start() {
    if (_monitoringTimer != null) return;
    
    StateLifecycleManager.instance.start();
    
    _monitoringTimer = Timer.periodic(monitoringInterval, (_) {
      _performMonitoring();
    });
    
    _recordEvent(StateEvent.registryStarted());
    debugPrint('StateRegistry: Started with monitoring');
  }

  /// Stops the state registry and cleanup monitoring.
  void stop() {
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    
    StateLifecycleManager.instance.stop();
    
    _recordEvent(StateEvent.registryStopped());
    debugPrint('StateRegistry: Stopped');
  }

  /// Registers a state in the global registry.
  /// 
  /// Returns a unique identifier for the registered state.
  String registerState<T>(
    ObservableState<T> state, {
    String? name,
    Set<String>? tags,
    Map<String, dynamic>? customMetadata,
  }) {
    final id = name ?? _generateStateId(state);
    
    // Register with lifecycle manager
    StateLifecycleManager.instance.trackState(state, name: id);
    
    // Store weak reference
    _states[id] = WeakReference(state);
    
    // Store metadata
    _metadata[id] = StateMetadata(
      id: id,
      type: T,
      runtimeType: state.runtimeType,
      createdAt: DateTime.now(),
      tags: tags ?? {},
      customMetadata: customMetadata ?? {},
    );
    
    // Index by type
    _statesByType.putIfAbsent(state.runtimeType, () => <String>{}).add(id);
    
    // Index by tags
    for (final tag in tags ?? <String>{}) {
      _statesByTag.putIfAbsent(tag, () => <String>{}).add(id);
    }
    
    _recordEvent(StateEvent.stateRegistered(id, state.runtimeType));
    debugPrint('StateRegistry: Registered state $id (${state.runtimeType})');
    
    return id;
  }

  /// Unregisters a state from the global registry.
  void unregisterState(String stateId) {
    final metadata = _metadata.remove(stateId);
    if (metadata == null) return;
    
    // Remove from lifecycle manager
    StateLifecycleManager.instance.untrackState(stateId);
    
    // Remove weak reference
    _states.remove(stateId);
    
    // Remove from type index
    _statesByType[metadata.runtimeType]?.remove(stateId);
    if (_statesByType[metadata.runtimeType]?.isEmpty == true) {
      _statesByType.remove(metadata.runtimeType);
    }
    
    // Remove from tag indices
    for (final tag in metadata.tags) {
      _statesByTag[tag]?.remove(stateId);
      if (_statesByTag[tag]?.isEmpty == true) {
        _statesByTag.remove(tag);
      }
    }
    
    _recordEvent(StateEvent.stateUnregistered(stateId, metadata.runtimeType));
    debugPrint('StateRegistry: Unregistered state $stateId');
  }

  /// Gets a registered state by its ID.
  ObservableState<T>? getState<T>(String stateId) {
    final weakRef = _states[stateId];
    if (weakRef == null) return null;
    
    final state = weakRef.target;
    if (state == null) {
      // State was garbage collected, clean up
      _cleanupDeadState(stateId);
      return null;
    }
    
    // Record access for lifecycle management
    StateLifecycleManager.instance.recordAccess(stateId);
    
    return state as ObservableState<T>?;
  }

  /// Gets all states of a specific type.
  List<T> getStatesByType<T extends ObservableState>() {
    final stateIds = _statesByType[T] ?? <String>{};
    final states = <T>[];
    final deadStates = <String>[];
    
    for (final stateId in stateIds) {
      final weakRef = _states[stateId];
      final state = weakRef?.target;
      
      if (state == null) {
        deadStates.add(stateId);
      } else if (state is T) {
        states.add(state);
        StateLifecycleManager.instance.recordAccess(stateId);
      }
    }
    
    // Clean up dead states
    for (final deadState in deadStates) {
      _cleanupDeadState(deadState);
    }
    
    return states;
  }

  /// Gets all states with a specific tag.
  List<ObservableState> getStatesByTag(String tag) {
    final stateIds = _statesByTag[tag] ?? <String>{};
    final states = <ObservableState>[];
    final deadStates = <String>[];
    
    for (final stateId in stateIds) {
      final weakRef = _states[stateId];
      final state = weakRef?.target;
      
      if (state == null) {
        deadStates.add(stateId);
      } else {
        states.add(state);
        StateLifecycleManager.instance.recordAccess(stateId);
      }
    }
    
    // Clean up dead states
    for (final deadState in deadStates) {
      _cleanupDeadState(deadState);
    }
    
    return states;
  }

  /// Gets metadata for a registered state.
  StateMetadata? getStateMetadata(String stateId) {
    return _metadata[stateId];
  }

  /// Gets all currently active states.
  List<ObservableState> getAllActiveStates() {
    final activeStates = <ObservableState>[];
    final deadStates = <String>[];
    
    for (final entry in _states.entries) {
      final state = entry.value.target;
      if (state == null) {
        deadStates.add(entry.key);
      } else if (!state.isDisposed) {
        activeStates.add(state);
      }
    }
    
    // Clean up dead states
    for (final deadState in deadStates) {
      _cleanupDeadState(deadState);
    }
    
    return activeStates;
  }

  /// Performs a comprehensive memory cleanup.
  void performCleanup() {
    final deadStates = <String>[];
    
    // Find all dead references
    for (final entry in _states.entries) {
      if (entry.value.target == null) {
        deadStates.add(entry.key);
      }
    }
    
    // Clean up dead states
    for (final deadState in deadStates) {
      _cleanupDeadState(deadState);
    }
    
    // Trigger lifecycle manager cleanup
    StateLifecycleManager.instance.disposeMarkedStates();
    
    _recordEvent(StateEvent.cleanupPerformed(deadStates.length));
    
    if (deadStates.isNotEmpty) {
      debugPrint('StateRegistry: Cleaned up ${deadStates.length} dead states');
    }
  }

  /// Gets comprehensive memory monitoring statistics.
  StateRegistryStats getStats() {
    performCleanup(); // Clean up first for accurate stats
    
    final now = DateTime.now();
    final activeStates = getAllActiveStates();
    final typeDistribution = <Type, int>{};
    final tagDistribution = <String, int>{};
    final ageDistribution = <String, int>{
      'under_1min': 0,
      'under_5min': 0,
      'under_30min': 0,
      'over_30min': 0,
    };
    
    // Calculate distributions
    for (final entry in _metadata.entries) {
      final metadata = entry.value;
      final age = now.difference(metadata.createdAt);
      
      // Type distribution
      typeDistribution[metadata.runtimeType] = 
          (typeDistribution[metadata.runtimeType] ?? 0) + 1;
      
      // Tag distribution
      for (final tag in metadata.tags) {
        tagDistribution[tag] = (tagDistribution[tag] ?? 0) + 1;
      }
      
      // Age distribution
      if (age < const Duration(minutes: 1)) {
        ageDistribution['under_1min'] = ageDistribution['under_1min']! + 1;
      } else if (age < const Duration(minutes: 5)) {
        ageDistribution['under_5min'] = ageDistribution['under_5min']! + 1;
      } else if (age < const Duration(minutes: 30)) {
        ageDistribution['under_30min'] = ageDistribution['under_30min']! + 1;
      } else {
        ageDistribution['over_30min'] = ageDistribution['over_30min']! + 1;
      }
    }
    
    final lifecycleStats = StateLifecycleManager.instance.getLifecycleStats();
    
    return StateRegistryStats(
      totalRegistered: _states.length,
      activeStates: activeStates.length,
      typeDistribution: typeDistribution,
      tagDistribution: tagDistribution,
      ageDistribution: ageDistribution,
      lifecycleStats: lifecycleStats,
      eventHistorySize: _eventHistory.length,
    );
  }

  /// Gets recent state events for debugging and monitoring.
  List<StateEvent> getRecentEvents({int? limit}) {
    final events = _eventHistory.toList();
    if (limit != null && events.length > limit) {
      return events.sublist(events.length - limit);
    }
    return events;
  }

  /// Adds a dependency relationship between states.
  void addStateDependency(String dependentId, String dependencyId) {
    StateLifecycleManager.instance.addDependency(dependentId, dependencyId);
    _recordEvent(StateEvent.dependencyAdded(dependentId, dependencyId));
  }

  /// Removes a dependency relationship between states.
  void removeStateDependency(String dependentId, String dependencyId) {
    StateLifecycleManager.instance.removeDependency(dependentId, dependencyId);
    _recordEvent(StateEvent.dependencyRemoved(dependentId, dependencyId));
  }

  /// Detects potential memory leaks.
  List<String> detectMemoryLeaks({Duration threshold = const Duration(minutes: 30)}) {
    final now = DateTime.now();
    final potentialLeaks = <String>[];
    
    for (final entry in _metadata.entries) {
      final stateId = entry.key;
      final metadata = entry.value;
      final age = now.difference(metadata.createdAt);
      
      if (age > threshold) {
        final state = _states[stateId]?.target;
        if (state != null && !state.isDisposed) {
          potentialLeaks.add(stateId);
        }
      }
    }
    
    return potentialLeaks;
  }

  void _performMonitoring() {
    performCleanup();
    
    final stats = getStats();
    final memoryLeaks = detectMemoryLeaks();
    
    if (memoryLeaks.isNotEmpty) {
      _recordEvent(StateEvent.memoryLeaksDetected(memoryLeaks));
      debugPrint('StateRegistry: Detected ${memoryLeaks.length} potential memory leaks');
    }
    
    _recordEvent(StateEvent.monitoringCheck(stats));
  }

  void _cleanupDeadState(String stateId) {
    final metadata = _metadata.remove(stateId);
    if (metadata != null) {
      // Remove from type index
      _statesByType[metadata.runtimeType]?.remove(stateId);
      if (_statesByType[metadata.runtimeType]?.isEmpty == true) {
        _statesByType.remove(metadata.runtimeType);
      }
      
      // Remove from tag indices
      for (final tag in metadata.tags) {
        _statesByTag[tag]?.remove(stateId);
        if (_statesByTag[tag]?.isEmpty == true) {
          _statesByTag.remove(tag);
        }
      }
    }
    
    _states.remove(stateId);
    StateLifecycleManager.instance.untrackState(stateId);
  }

  void _recordEvent(StateEvent event) {
    _eventHistory.add(event);
    
    // Limit event history size
    while (_eventHistory.length > maxEventHistory) {
      _eventHistory.removeFirst();
    }
  }

  String _generateStateId(ObservableState state) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final hashCode = state.hashCode;
    return '${state.runtimeType}_${timestamp}_$hashCode';
  }
}

/// Metadata associated with a registered state.
class StateMetadata {
  /// Unique identifier for the state.
  final String id;
  
  /// Generic type of the state.
  final Type type;
  
  /// Runtime type of the state implementation.
  @override
  final Type runtimeType;
  
  /// When the state was created/registered.
  final DateTime createdAt;
  
  /// Tags associated with the state for categorization.
  final Set<String> tags;
  
  /// Custom metadata provided during registration.
  final Map<String, dynamic> customMetadata;

  const StateMetadata({
    required this.id,
    required this.type,
    required this.runtimeType,
    required this.createdAt,
    required this.tags,
    required this.customMetadata,
  });

  @override
  String toString() {
    return 'StateMetadata(id: $id, type: $type, created: $createdAt, tags: $tags)';
  }
}

/// Statistics about the state registry.
class StateRegistryStats {
  /// Total number of registered states.
  final int totalRegistered;
  
  /// Number of active (non-disposed) states.
  final int activeStates;
  
  /// Distribution of states by type.
  final Map<Type, int> typeDistribution;
  
  /// Distribution of states by tag.
  final Map<String, int> tagDistribution;
  
  /// Distribution of states by age.
  final Map<String, int> ageDistribution;
  
  /// Lifecycle management statistics.
  final StateLifecycleStats lifecycleStats;
  
  /// Number of events in history.
  final int eventHistorySize;

  const StateRegistryStats({
    required this.totalRegistered,
    required this.activeStates,
    required this.typeDistribution,
    required this.tagDistribution,
    required this.ageDistribution,
    required this.lifecycleStats,
    required this.eventHistorySize,
  });

  @override
  String toString() {
    return 'StateRegistryStats('
        'total: $totalRegistered, '
        'active: $activeStates, '
        'types: ${typeDistribution.length}, '
        'tags: ${tagDistribution.length}, '
        'events: $eventHistorySize)';
  }
}

/// Events that occur in the state registry for monitoring and debugging.
class StateEvent {
  /// Type of the event.
  final StateEventType type;
  
  /// When the event occurred.
  final DateTime timestamp;
  
  /// Additional data associated with the event.
  final Map<String, dynamic> data;

  StateEvent._(this.type, this.data) : timestamp = DateTime.now();

  factory StateEvent.registryStarted() => StateEvent._(
    StateEventType.registryStarted,
    {},
  );

  factory StateEvent.registryStopped() => StateEvent._(
    StateEventType.registryStopped,
    {},
  );

  factory StateEvent.stateRegistered(String stateId, Type stateType) => StateEvent._(
    StateEventType.stateRegistered,
    {'stateId': stateId, 'stateType': stateType.toString()},
  );

  factory StateEvent.stateUnregistered(String stateId, Type stateType) => StateEvent._(
    StateEventType.stateUnregistered,
    {'stateId': stateId, 'stateType': stateType.toString()},
  );

  factory StateEvent.cleanupPerformed(int cleanedCount) => StateEvent._(
    StateEventType.cleanupPerformed,
    {'cleanedCount': cleanedCount},
  );

  factory StateEvent.dependencyAdded(String dependentId, String dependencyId) => StateEvent._(
    StateEventType.dependencyAdded,
    {'dependentId': dependentId, 'dependencyId': dependencyId},
  );

  factory StateEvent.dependencyRemoved(String dependentId, String dependencyId) => StateEvent._(
    StateEventType.dependencyRemoved,
    {'dependentId': dependentId, 'dependencyId': dependencyId},
  );

  factory StateEvent.memoryLeaksDetected(List<String> leakIds) => StateEvent._(
    StateEventType.memoryLeaksDetected,
    {'leakIds': leakIds, 'count': leakIds.length},
  );

  factory StateEvent.monitoringCheck(StateRegistryStats stats) => StateEvent._(
    StateEventType.monitoringCheck,
    {'stats': stats.toString()},
  );

  @override
  String toString() {
    return 'StateEvent(type: $type, timestamp: $timestamp, data: $data)';
  }
}

/// Types of events that can occur in the state registry.
enum StateEventType {
  registryStarted,
  registryStopped,
  stateRegistered,
  stateUnregistered,
  cleanupPerformed,
  dependencyAdded,
  dependencyRemoved,
  memoryLeaksDetected,
  monitoringCheck,
}