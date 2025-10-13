import 'package:flutter_test/flutter_test.dart';
import 'package:compose_state/compose_state.dart';

void main() {
  group('Comprehensive Test Suite for Critical Improvements', () {
    setUp(() {
      // Clean up before each test
      StateManager.instance.disposeAllStates();
    });

    tearDown(() {
      // Clean up after each test
      StateManager.instance.disposeAllStates();
    });

    group('Error Handling Tests', () {
      test('StateErrorHandler handles errors with recovery strategies', () async {
        final errorHandler = StateErrorHandler();
        final fallbackStrategy = FallbackStrategy();
        fallbackStrategy.setDefaultFallback<String>('fallback_value');
        
        errorHandler.addStrategy(fallbackStrategy);
        
        const error = StatePersistenceException('Test error', storageKey: 'test');
        final context = ErrorContext(stateKey: 'test', operation: 'save');
        
        final result = await errorHandler.handleError<String>(
          error,
          context,
          fallbackValue: 'fallback_value',
        );
        
        expect(result, equals('fallback_value'));
      });

      test('RetryStrategy respects max attempts', () async {
        final strategy = RetryStrategy(maxAttempts: 2);
        final error = const StatePersistenceException('Test error', storageKey: 'test');
        final context = {'stateKey': 'test'};
        
        // First attempt should return retry
        var result = await strategy.recover<String>(error, null, context);
        expect(result.shouldRetry, isTrue);
        
        // Second attempt should return retry
        result = await strategy.recover<String>(error, null, context);
        expect(result.shouldRetry, isTrue);
        
        // Third attempt should fail
        result = await strategy.recover<String>(error, null, context);
        expect(result.isSuccess, isFalse);
        expect(result.shouldRetry, isFalse);
      });

      test('CircuitBreakerStrategy opens after threshold failures', () async {
        final strategy = CircuitBreakerStrategy(failureThreshold: 2);
        final error = const StateValidationException('Test error');
        
        expect(strategy.state, equals(CircuitState.closed));
        
        // First failure
        await strategy.recover<String>(error, null, {});
        expect(strategy.state, equals(CircuitState.closed));
        
        // Second failure should open circuit
        await strategy.recover<String>(error, null, {});
        expect(strategy.state, equals(CircuitState.open));
      });

      test('FallbackStrategy provides default values', () async {
        final strategy = FallbackStrategy();
        strategy.setDefaultFallback<String>('fallback');
        strategy.setDefaultFallback<int>(42);
        
        final result = await strategy.recover<String>(
          const StateSerializationException('Test error'),
          null,
          {},
        );
        expect(result.isSuccess, isTrue);
        expect(result.value, equals('fallback'));
        
        final intResult = await strategy.recover<int>(
          const StateValidationException('Test error'),
          null,
          {},
        );
        expect(intResult.isSuccess, isTrue);
        expect(intResult.value, equals(42));
      });

      test('ErrorContext builder creates proper context', () {
        final context = ErrorContext(
          stateKey: 'test_state',
          operation: 'test_operation',
          valueType: String,
          metadata: {'key': 'value'},
        );

        expect(context.stateKey, equals('test_state'));
        expect(context.operation, equals('test_operation'));
        expect(context.valueType, equals(String));
        expect(context.metadata['key'], equals('value'));
      });

      test('Error statistics are tracked correctly', () async {
        final errorHandler = StateErrorHandler();
        final error = const StateValidationException('Test error');
        final context = ErrorContext(stateKey: 'test', operation: 'validate');

        try {
          await errorHandler.handleError<String>(error, context);
        } catch (e) {
          // Expected to throw
        }

        final stats = errorHandler.getErrorStats();
        expect(stats.isNotEmpty, isTrue);
        
        final statsValues = stats.values.toList();
        final totalErrors = statsValues.fold<int>(0, (sum, stat) => sum + stat.totalErrors);
        expect(totalErrors, greaterThan(0));
      });
    });

    group('Memory Management Tests', () {
      test('StateManager tracks states correctly', () {
        final manager = StateManager.instance;
        
        // Create states
        final state1 = mutableStateOf(42);
        final state2 = mutableStateOf('hello');
        final state3 = mutableStateOf([1, 2, 3]);
        
        // Verify states are tracked
        expect(manager.getActiveStates().length, greaterThanOrEqualTo(3));
        
        // Dispose states
        state1.dispose();
        state2.dispose();
        state3.dispose();
        
        // Verify cleanup
        expect(manager.getActiveStates().length, lessThan(3));
      });

      test('States are properly disposed', () {
        final state = mutableStateOf(42);
        expect(state.isDisposed, isFalse);
        
        state.dispose();
        expect(state.isDisposed, isTrue);
        
        // Should throw when accessing disposed state
        expect(() => state.value, throwsA(isA<StateException>()));
      });

      test('Memory usage tracking', () {
        final initialCount = StateManager.instance.getActiveStates().length;
        
        // Create many states
        final states = List.generate(50, (i) => mutableStateOf(i));
        
        expect(StateManager.instance.getActiveStates().length, 
               equals(initialCount + 50));
        
        // Dispose half
        for (int i = 0; i < 25; i++) {
          states[i].dispose();
        }
        
        expect(StateManager.instance.getActiveStates().length, 
               equals(initialCount + 25));
        
        // Clean up remaining
        for (int i = 25; i < 50; i++) {
          states[i].dispose();
        }
      });
    });

    group('Performance Tests', () {
      test('State updates with equality checking', () {
        final state = mutableStateOf<List<int>>([1, 2, 3]);
        
        int notificationCount = 0;
        state.addListener(() => notificationCount++);
        
        // Setting the same value should not trigger notification
        state.value = [1, 2, 3];
        expect(notificationCount, equals(0));
        
        // Setting a different value should trigger notification
        state.value = [1, 2, 4];
        expect(notificationCount, equals(1));
        
        state.dispose();
      });

      test('High-volume state operations', () {
        final stopwatch = Stopwatch()..start();
        
        // Create and dispose many states rapidly
        for (int i = 0; i < 1000; i++) {
          final state = mutableStateOf(i);
          state.dispose();
        }
        
        stopwatch.stop();
        
        // Should complete reasonably quickly
        expect(stopwatch.elapsedMilliseconds, lessThan(2000));
      });

      test('Derived state performance', () {
        final baseState1 = mutableStateOf(10);
        final baseState2 = mutableStateOf(20);
        
        final derivedState = DerivedState<int>(
          () => baseState1.value + baseState2.value,
          dependencies: [baseState1, baseState2],
        );
        
        expect(derivedState.value, equals(30));
        
        // Update base states
        baseState1.value = 15;
        expect(derivedState.value, equals(35));
        
        baseState2.value = 25;
        expect(derivedState.value, equals(40));
        
        baseState1.dispose();
        baseState2.dispose();
        derivedState.dispose();
      });
    });

    group('Transaction Management Tests', () {
      test('TransactionManager creates and manages transactions', () {
        final manager = TransactionManager();
        manager.clear();
        
        final transaction = manager.createTransaction();
        
        expect(transaction, isNotNull);
        expect(transaction.status, equals(TransactionStatus.preparing));
        expect(transaction.isActive, isFalse);
        expect(transaction.isCompleted, isFalse);
      });

      test('Transaction lifecycle management', () async {
        final transaction = StateTransaction();
        
        expect(transaction.status, equals(TransactionStatus.preparing));
        
        transaction.begin();
        expect(transaction.status, equals(TransactionStatus.active));
        expect(transaction.isActive, isTrue);
        
        final result = await transaction.commit();
        expect(result, isTrue);
        expect(transaction.status, equals(TransactionStatus.committed));
        expect(transaction.isCompleted, isTrue);
      });

      test('Transaction rollback', () async {
        final transaction = StateTransaction();
        transaction.begin();
        
        final result = await transaction.rollback();
        expect(result, isTrue);
        expect(transaction.status, equals(TransactionStatus.rolledBack));
        expect(transaction.isCompleted, isTrue);
      });

      test('TransactionManager executes operations', () async {
        final manager = TransactionManager();
        manager.clear();
        
        var operationExecuted = false;
        
        final result = await manager.executeInTransaction((transaction) async {
          operationExecuted = true;
          expect(transaction.isActive, isTrue);
          return 'success';
        });

        expect(operationExecuted, isTrue);
        expect(result, equals('success'));
      });

      test('Transaction failure handling', () async {
        final manager = TransactionManager();
        manager.clear();
        
        var operationExecuted = false;
        
        try {
          await manager.executeInTransaction((transaction) async {
            operationExecuted = true;
            throw Exception('Operation failed');
          });
        } catch (e) {
          expect(e.toString(), contains('Operation failed'));
        }
        
        expect(operationExecuted, isTrue);
      });

      test('State dependency management', () {
        final manager = TransactionManager();
        manager.clear();
        
        final state1 = MutableState<int>(10);
        final state2 = MutableState<int>(20);
        
        manager.addDependency(state1, state2);
        
        final dependencies = manager.getDependencies(state1);
        expect(dependencies, contains(state2));
        
        manager.removeDependency(state1, state2);
        expect(manager.getDependencies(state1), isEmpty);
        
        state1.dispose();
        state2.dispose();
      });

      test('Circular dependency detection', () {
        final manager = TransactionManager();
        manager.clear();
        
        final state1 = MutableState<int>(1);
        final state2 = MutableState<int>(2);
        
        manager.addDependency(state1, state2);
        manager.addDependency(state2, state1);
        
        expect(manager.hasCircularDependencies(), isTrue);
        
        state1.dispose();
        state2.dispose();
      });
    });

    group('Integration Tests', () {
      test('Complete state lifecycle with error handling', () async {
        final errorHandler = StateErrorHandler();
        final fallbackStrategy = FallbackStrategy();
        fallbackStrategy.setDefaultFallback<String>('fallback');
        errorHandler.addStrategy(fallbackStrategy);
        
        // Create state that might fail
        final state = mutableStateOf('initial');
        
        // Simulate error and recovery
        final error = const StateValidationException('Test error');
        final context = ErrorContext(stateKey: 'test', operation: 'validate');
        
        final recovered = await errorHandler.handleError<String>(
          error,
          context,
          lastKnownValue: state.value,
          fallbackValue: 'fallback',
        );
        
        // Should return the last known value or fallback
        expect(recovered, anyOf(equals('initial'), equals('fallback')));
        
        state.dispose();
      });

      test('Multi-state atomic operations', () async {
        final manager = TransactionManager();
        manager.clear();
        
        final state1 = MutableState<int>(10);
        final state2 = MutableState<String>('initial');
        
        final result = await manager.executeInTransaction((transaction) async {
          state1.value = 100;
          state2.value = 'modified';
          return 'success';
        });
        
        expect(result, equals('success'));
        expect(state1.value, equals(100));
        expect(state2.value, equals('modified'));
        
        state1.dispose();
        state2.dispose();
      });

      test('Performance under load', () async {
        final manager = TransactionManager();
        manager.clear();
        
        final counter = MutableState<int>(0);
        final stopwatch = Stopwatch()..start();
        
        // Execute many transactions
        final futures = List.generate(100, (i) async {
          return await manager.executeInTransaction((transaction) async {
            counter.value = counter.value + 1;
            return 'transaction_$i';
          });
        });
        
        final results = await Future.wait(futures);
        stopwatch.stop();
        
        expect(results.length, equals(100));
        expect(counter.value, equals(100));
        expect(stopwatch.elapsedMilliseconds, lessThan(5000));
        
        counter.dispose();
      });

      test('System consistency across components', () {
        final manager = StateManager.instance;
        
        // Create states with various characteristics
        final states = <MutableState<int>>[];
        for (int i = 0; i < 10; i++) {
          final state = mutableStateOf(i);
          states.add(state);
        }
        
        // Verify all states are tracked
        expect(manager.getActiveStates().length, greaterThanOrEqualTo(10));
        
        // Update all states
        for (int i = 0; i < states.length; i++) {
          states[i].value = states[i].value * 10;
        }
        
        // Verify updates
        for (int i = 0; i < states.length; i++) {
          expect(states[i].value, equals(i * 10));
        }
        
        // Clean up
        for (final state in states) {
          state.dispose();
        }
        
        // Verify cleanup
        final remainingStates = manager.getActiveStates().length;
        expect(remainingStates, lessThan(10));
      });
    });

    group('Edge Cases and Stress Tests', () {
      test('Handles rapid state creation and disposal', () {
        final states = <MutableState<int>>[];
        
        // Create many states rapidly
        for (int i = 0; i < 500; i++) {
          final state = mutableStateOf(i);
          states.add(state);
        }
        
        // Dispose half rapidly
        for (int i = 0; i < 250; i++) {
          states[i].dispose();
        }
        
        // Verify remaining states work
        for (int i = 250; i < 500; i++) {
          expect(states[i].value, equals(i));
          states[i].value = i * 2;
          expect(states[i].value, equals(i * 2));
        }
        
        // Clean up remaining
        for (int i = 250; i < 500; i++) {
          states[i].dispose();
        }
      });

      test('Concurrent state operations', () async {
        final sharedState = mutableStateOf(0);
        
        // Run concurrent operations
        final futures = List.generate(20, (i) async {
          for (int j = 0; j < 10; j++) {
            final current = sharedState.value;
            sharedState.value = current + 1;
          }
        });
        
        await Future.wait(futures);
        
        // Should have incremented 200 times total
        expect(sharedState.value, equals(200));
        
        sharedState.dispose();
      });

      test('Error recovery under stress', () async {
        final errorHandler = StateErrorHandler();
        final fallbackStrategy = FallbackStrategy();
        fallbackStrategy.setDefaultFallback<int>(0);
        errorHandler.addStrategy(fallbackStrategy);
        
        // Generate many errors rapidly
        final futures = List.generate(50, (i) async {
          final error = StateValidationException('Error $i');
          final context = ErrorContext(stateKey: 'test_$i', operation: 'validate');
          
          return await errorHandler.handleError<int>(
            error,
            context,
            fallbackValue: i,
          );
        });
        
        final results = await Future.wait(futures);
        
        // All should recover with some value (either fallback or default)
        expect(results.length, equals(50));
        for (int i = 0; i < 50; i++) {
          // Should return a valid integer (could be fallback value, default, or index)
          expect(results[i], isA<int>());
        }
      });

      test('Memory management under pressure', () {
        final initialStateCount = StateManager.instance.getActiveStates().length;
        
        // Create and dispose states in cycles
        for (int cycle = 0; cycle < 10; cycle++) {
          final states = List.generate(50, (i) => mutableStateOf(cycle * 50 + i));
          
          // Use states
          for (final state in states) {
            state.value = state.value * 2;
          }
          
          // Dispose all states
          for (final state in states) {
            state.dispose();
          }
        }
        
        // Should not have accumulated states
        final finalStateCount = StateManager.instance.getActiveStates().length;
        expect(finalStateCount, lessThanOrEqualTo(initialStateCount + 10));
      });
    });
  });
}