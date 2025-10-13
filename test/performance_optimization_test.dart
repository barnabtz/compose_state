import 'package:flutter_test/flutter_test.dart';
import 'package:compose_state/compose_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('Comprehensive Performance Tests', () {
    group('EqualityChecker', () {
      test('performs deep equality for lists', () {
        final checker = EqualityChecker<List<int>>();

        final list1 = [1, 2, 3];
        final list2 = [1, 2, 3];
        final list3 = [1, 2, 4];

        expect(checker.equals(list1, list2), isTrue);
        expect(checker.equals(list1, list3), isFalse);
      });

      test('performs deep equality for maps', () {
        final checker = EqualityChecker<Map<String, dynamic>>();

        final map1 = {
          'a': 1,
          'b': [1, 2, 3],
        };
        final map2 = {
          'a': 1,
          'b': [1, 2, 3],
        };
        final map3 = {
          'a': 1,
          'b': [1, 2, 4],
        };

        expect(checker.equals(map1, map2), isTrue);
        expect(checker.equals(map1, map3), isFalse);
      });

      test('uses custom equality function when provided', () {
        final checker = EqualityChecker<String>(
          customEquals: (a, b) => a.toLowerCase() == b.toLowerCase(),
        );

        expect(checker.equals('Hello', 'HELLO'), isTrue);
        expect(checker.equals('Hello', 'World'), isFalse);
      });

      test('caches expensive equality checks', () {
        final checker = EqualityChecker<List<int>>();

        final list1 = List.generate(100, (i) => i);
        final list2 = List.generate(100, (i) => i);

        // First comparison should cache the result
        expect(checker.equals(list1, list2), isTrue);
        expect(checker.cacheSize, greaterThan(0));

        // Clear cache and verify
        checker.clearCache();
        expect(checker.cacheSize, equals(0));
      });

      test('provides cache statistics', () {
        final checker = EqualityChecker<List<int>>();
        final stats = checker.getCacheStats();

        expect(stats, containsPair('cacheSize', 0));
        expect(stats, containsPair('cachingEnabled', true));
        expect(stats, containsPair('hasCustomEquals', false));
      });
    });

    group('NotificationBatcher', () {
      test('batches notifications with frame strategy', () async {
        final batcher = createNotificationBatcher(
          strategy: BatchingStrategy.frame,
        );

        int callCount = 0;

        // Schedule multiple different notifications
        batcher.scheduleNotification(() => callCount++);
        batcher.scheduleNotification(() => callCount++);
        batcher.scheduleNotification(() => callCount++);

        expect(batcher.pendingCount, equals(3));
        expect(callCount, equals(0));

        // Force flush
        batcher.flush();
        expect(callCount, equals(3));
        expect(batcher.pendingCount, equals(0));

        batcher.dispose();
      });

      test('executes immediate notifications without batching', () {
        final batcher = createNotificationBatcher(
          strategy: BatchingStrategy.immediate,
        );

        int callCount = 0;
        void callback() => callCount++;

        batcher.scheduleNotification(callback);
        expect(callCount, equals(1));
        expect(batcher.pendingCount, equals(0));

        batcher.dispose();
      });

      test('provides batching statistics', () {
        final batcher = createNotificationBatcher();
        final stats = batcher.getStats();

        expect(stats, containsPair('strategy', 'frame'));
        expect(stats, containsPair('pendingCount', 0));
        expect(stats, containsPair('isScheduled', false));
      });
    });

    group('OptimizedState', () {
      test('uses deep equality to prevent unnecessary notifications', () {
        final state = immediateStateOf<List<int>>([1, 2, 3]);

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

      test('supports custom equality functions', () {
        final state = immediateStateOf<String>(
          'Hello',
          customEquals: (a, b) => a.toLowerCase() == b.toLowerCase(),
        );

        int notificationCount = 0;
        state.addListener(() => notificationCount++);

        // Case-insensitive equality should prevent notification
        state.value = 'HELLO';
        expect(notificationCount, equals(0));

        // Different value should trigger notification
        state.value = 'World';
        expect(notificationCount, equals(1));

        state.dispose();
      });

      test('provides performance statistics', () {
        final state = immediateStateOf<int>(42);
        final stats = state.getPerformanceStats();

        expect(stats.containsKey('stateId'), isTrue);
        expect(stats.containsKey('stateType'), isTrue);
        expect(stats.containsKey('equalityStats'), isTrue);
        expect(stats.containsKey('batchingStats'), isTrue);

        state.dispose();
      });

      test('supports silent value updates', () {
        final state = immediateStateOf<int>(42);

        int notificationCount = 0;
        state.addListener(() => notificationCount++);

        // Silent update should not trigger notification
        state.setValueSilently(100);
        expect(state.value, equals(100));
        expect(notificationCount, equals(0));

        // Regular update should trigger notification
        state.value = 200;
        expect(notificationCount, equals(1));

        state.dispose();
      });

      test('supports value updates with functions', () {
        final state = immediateStateOf<int>(10);

        int notificationCount = 0;
        state.addListener(() => notificationCount++);

        // Update with function
        state.updateValue((current) => current * 2);
        expect(state.value, equals(20));
        expect(notificationCount, equals(1));

        state.dispose();
      });
    });

    group('Factory Functions', () {
      test('immediateStateOf creates state with immediate notifications', () {
        final state = immediateStateOf<int>(42);
        final stats = state.getPerformanceStats();

        expect(stats['batchingStats']['strategy'], equals('immediate'));

        state.dispose();
      });

      test('debouncedStateOf creates state with debounced notifications', () {
        final state = debouncedStateOf<int>(42);
        final stats = state.getPerformanceStats();

        expect(stats['batchingStats']['strategy'], equals('debounced'));

        state.dispose();
      });
    });

    group('Enhanced MutableState', () {
      test('uses equality checker for comparisons', () {
        final state = mutableStateOf<List<int>>([
          1,
          2,
          3,
        ], equalityChecker: EqualityChecker<List<int>>());

        int notificationCount = 0;
        state.addListener(() => notificationCount++);

        // Setting equivalent list should not trigger notification
        state.value = [1, 2, 3];
        expect(notificationCount, equals(0));

        // Setting different list should trigger notification
        state.value = [1, 2, 4];
        expect(notificationCount, equals(1));

        state.dispose();
      });
    });

    group('Performance Benchmarks', () {
      test('EqualityChecker performance with large datasets', () {
        final checker = EqualityChecker<List<int>>();
        
        // Create large data structures
        final largeList1 = List.generate(100, (i) => i);
        final largeList2 = List.generate(100, (i) => i);
        
        final stopwatch = Stopwatch()..start();
        
        // First comparison
        final result1 = checker.equals(largeList1, largeList2);
        final firstComparisonTime = stopwatch.elapsedMicroseconds;
        
        stopwatch.reset();
        
        // Second comparison
        final result2 = checker.equals(largeList1, largeList2);
        final secondComparisonTime = stopwatch.elapsedMicroseconds;
        
        stopwatch.stop();
        
        expect(result1, isTrue);
        expect(result2, isTrue);
        
        // Both comparisons should complete
        expect(firstComparisonTime, greaterThan(0));
        expect(secondComparisonTime, greaterThanOrEqualTo(0));
      });

      test('NotificationBatcher performance under load', () {
        final batcher = createNotificationBatcher(
          strategy: BatchingStrategy.frame,
        );
        
        int executionCount = 0;
        
        // Schedule many notifications rapidly
        for (int i = 0; i < 100; i++) {
          batcher.scheduleNotification(() => executionCount++);
        }
        
        expect(batcher.pendingCount, equals(100));
        
        // Force flush
        batcher.flush();
        expect(executionCount, equals(100));
        
        batcher.dispose();
      });

      test('State notification performance with deep equality', () {
        final state = immediateStateOf<List<int>>([1, 2, 3]);
        
        int notificationCount = 0;
        state.addListener(() => notificationCount++);
        
        final stopwatch = Stopwatch()..start();
        
        // Set the same value multiple times (should not trigger notifications)
        for (int i = 0; i < 10; i++) {
          state.value = [1, 2, 3];
        }
        
        stopwatch.stop();
        
        // Should not have triggered any notifications due to deep equality
        expect(notificationCount, equals(0));
        
        // Should complete reasonably quickly
        expect(stopwatch.elapsedMilliseconds, lessThan(1000));
        
        state.dispose();
      });
    });
  });
}