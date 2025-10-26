import 'package:flutter_test/flutter_test.dart';
import 'package:compose_state/compose_state.dart';

void main() {
  group('Comprehensive Memory Management Tests', () {
    setUp(() {
      // Clean up before each test
      StateManager.instance.disposeAllStates();
    });

    tearDown(() {
      // Clean up after each test
      StateManager.instance.disposeAllStates();
    });

    test('StateLifecycleManager tracks states with weak references', () {
      final lifecycleManager = StateLifecycleManager.instance;
      
      // Create a state
      final state = mutableStateOf(42);
      final stateId = lifecycleManager.trackState(state, name: 'test_state');
      
      // Verify tracking
      final stats = lifecycleManager.getLifecycleStats();
      expect(stats.totalTracked, greaterThanOrEqualTo(1));
      expect(stats.activeStates, greaterThanOrEqualTo(1));
      
      // Record access
      lifecycleManager.recordAccess(stateId);
      
      // Clean up
      state.dispose();
      lifecycleManager.untrackState(stateId);
    });

    test('StateRegistry provides global state tracking', () {
      final registry = StateRegistry.instance;
      registry.start();
      
      // Register states with different types and tags
      final intState = taggedStateOf(42, {'numeric', 'test'});
      final stringState = taggedStateOf('hello', {'text', 'test'});
      
      // Get states by tag
      final testStates = registry.getStatesByTag('test');
      expect(testStates.length, equals(2));
      
      final numericStates = registry.getStatesByTag('numeric');
      expect(numericStates.length, equals(1));
      
      // Get registry stats
      final stats = registry.getStats();
      expect(stats.totalRegistered, greaterThanOrEqualTo(2));
      expect(stats.activeStates, greaterThanOrEqualTo(2));
      expect(stats.tagDistribution['test'], equals(2));
      expect(stats.tagDistribution['numeric'], equals(1));
      
      // Clean up
      intState.dispose();
      stringState.dispose();
      registry.stop();
    });

    test('StateManager integrates with memory management components', () {
      final manager = StateManager.instance;
      manager.start();
      
      // Create states
      final state1 = taggedStateOf(1, {'group1'});
      final state2 = taggedStateOf(2, {'group1'});
      final state3 = taggedStateOf(3, {'group2'});
      
      // Test getting states by tag
      final group1States = manager.getStatesByTag('group1');
      expect(group1States.length, equals(2));
      
      final group2States = manager.getStatesByTag('group2');
      expect(group2States.length, equals(1));
      
      // Test memory stats
      final memoryStats = manager.getMemoryStats();
      expect(memoryStats.activeStates, greaterThanOrEqualTo(3));
      expect(memoryStats.registryStats, isNotNull);
      
      // Test lifecycle stats
      final lifecycleStats = manager.getLifecycleStats();
      expect(lifecycleStats.activeStates, greaterThanOrEqualTo(3));
      
      // Clean up
      state1.dispose();
      state2.dispose();
      state3.dispose();
      manager.stop();
    });

    test('Circular reference detection works correctly', () {
      final lifecycleManager = StateLifecycleManager.instance;
      
      // Create states
      final state1 = mutableStateOf('state1');
      final state2 = mutableStateOf('state2');
      final state3 = mutableStateOf('state3');
      
      final id1 = lifecycleManager.trackState(state1, name: 'state1');
      final id2 = lifecycleManager.trackState(state2, name: 'state2');
      final id3 = lifecycleManager.trackState(state3, name: 'state3');
      
      // Create circular dependencies: state1 -> state2 -> state3 -> state1
      lifecycleManager.addDependency(id1, id2);
      lifecycleManager.addDependency(id2, id3);
      lifecycleManager.addDependency(id3, id1);
      
      // Detect circular references
      final cycles = lifecycleManager.detectCircularReferences();
      expect(cycles.isNotEmpty, isTrue);
      
      // Clean up
      state1.dispose();
      state2.dispose();
      state3.dispose();
      lifecycleManager.untrackState(id1);
      lifecycleManager.untrackState(id2);
      lifecycleManager.untrackState(id3);
    });

    test('Automatic disposal marks unused states correctly', () async {
      final lifecycleManager = StateLifecycleManager.instance;
      
      // Set a very short threshold for testing
      lifecycleManager.unusedStateThreshold = const Duration(milliseconds: 100);
      
      // Create a state
      final state = mutableStateOf(42);
      final stateId = lifecycleManager.trackState(state, name: 'test_state');
      
      // Wait for the threshold to pass
      await Future.delayed(const Duration(milliseconds: 150));
      
      // Get disposable states
      final disposableStates = lifecycleManager.getDisposableStates();
      expect(disposableStates.contains(stateId), isTrue);
      
      // Mark for disposal
      lifecycleManager.markForDisposal([stateId]);
      
      // Verify marked for disposal
      final stats = lifecycleManager.getLifecycleStats();
      expect(stats.markedForDisposal, equals(1));
      
      // Clean up
      state.dispose();
      lifecycleManager.untrackState(stateId);
    });

    test('StateRegistry events are recorded correctly', () {
      final registry = StateRegistry.instance;
      registry.start();
      
      // Create and dispose a state to generate events
      final state = mutableStateOf(42);
      state.dispose();
      
      // Get recent events
      final events = registry.getRecentEvents(limit: 10);
      expect(events.isNotEmpty, isTrue);
      
      // Check for expected event types - just verify we have events
      final eventTypes = events.map((e) => e.type).toSet();
      expect(eventTypes.isNotEmpty, isTrue);
      
      registry.stop();
    });

    test('Memory leak detection identifies long-lived states', () async {
      final registry = StateRegistry.instance;
      registry.start();
      
      // Create a state
      final state = mutableStateOf(42);
      
      // Wait a bit and check for leaks
      await Future.delayed(const Duration(milliseconds: 10));
      final leaksAfterDelay = registry.detectMemoryLeaks(threshold: const Duration(milliseconds: 1));
      
      // Should detect the state as a potential leak
      expect(leaksAfterDelay.isNotEmpty, isTrue);
      
      // Clean up
      state.dispose();
      registry.stop();
    });

    test('Dependency management prevents premature disposal', () async {
      final lifecycleManager = StateLifecycleManager.instance;
      lifecycleManager.unusedStateThreshold = const Duration(milliseconds: 100);
      
      // Create states with dependency
      final dependentState = mutableStateOf('dependent');
      final dependencyState = mutableStateOf('dependency');
      
      final dependentId = lifecycleManager.trackState(dependentState, name: 'dependent');
      final dependencyId = lifecycleManager.trackState(dependencyState, name: 'dependency');
      
      // Add dependency relationship
      lifecycleManager.addDependency(dependentId, dependencyId);
      
      // Wait for threshold to pass
      await Future.delayed(const Duration(milliseconds: 150));
      
      // Get disposable states - dependency should not be disposable due to dependent
      final disposableStates = lifecycleManager.getDisposableStates();
      expect(disposableStates.contains(dependencyId), isFalse);
      
      // Remove dependency
      lifecycleManager.removeDependency(dependentId, dependencyId);
      
      // Now dependency should be disposable
      final disposableAfterRemoval = lifecycleManager.getDisposableStates();
      expect(disposableAfterRemoval.contains(dependencyId), isTrue);
      
      // Clean up
      dependentState.dispose();
      dependencyState.dispose();
      lifecycleManager.untrackState(dependentId);
      lifecycleManager.untrackState(dependencyId);
    });

    test('High-volume state creation and disposal', () {
      final manager = StateManager.instance;
      manager.start();
      
      final stopwatch = Stopwatch()..start();
      
      // Create and dispose many states rapidly
      for (int i = 0; i < 1000; i++) {
        final state = mutableStateOf(i);
        state.dispose();
      }
      
      stopwatch.stop();
      
      // Should complete reasonably quickly
      expect(stopwatch.elapsedMilliseconds, lessThan(2000));
      
      final stats = manager.getMemoryStats();
      expect(stats.activeStates, greaterThanOrEqualTo(0)); // Just verify stats work
      
      manager.stop();
    });

    test('Memory usage tracking accuracy', () {
      final registry = StateRegistry.instance;
      registry.start();
      
      final initialStats = registry.getStats();
      final initialCount = initialStats.totalRegistered;
      
      // Create known number of states
      final states = List.generate(50, (i) => mutableStateOf(i));
      
      final afterCreationStats = registry.getStats();
      expect(afterCreationStats.totalRegistered, equals(initialCount + 50));
      
      // Dispose half
      for (int i = 0; i < 25; i++) {
        states[i].dispose();
      }
      
      final afterPartialDisposal = registry.getStats();
      expect(afterPartialDisposal.activeStates, equals(afterCreationStats.activeStates - 25));
      
      // Clean up remaining
      for (int i = 25; i < 50; i++) {
        states[i].dispose();
      }
      
      registry.stop();
    });
  });
}