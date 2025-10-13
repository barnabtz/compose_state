import 'package:flutter_test/flutter_test.dart';
import 'package:compose_state/compose_state.dart';

void main() {
  group('Core Infrastructure', () {
    group('Enhanced ObservableState Interface', () {
      test('isDisposed returns correct status', () {
        final state = mutableStateOf(42);
        expect(state.isDisposed, false);

        state.dispose();
        expect(state.isDisposed, true);
      });

      test('equals method works correctly', () {
        final state = mutableStateOf(42);
        expect(state.equals(42), true);
        expect(state.equals(43), false);
      });

      test('createSnapshot captures current state', () {
        final state = mutableStateOf(42);
        final snapshot = state.createSnapshot();

        expect(snapshot.value, 42);
        expect(snapshot.timestamp, isA<DateTime>());
        expect(snapshot.metadata, isA<Map<String, dynamic>>());
      });

      test('restoreSnapshot updates state value', () {
        final state = mutableStateOf(42);
        final snapshot = StateSnapshot(
          100,
          timestamp: DateTime.now(),
          metadata: {},
        );

        state.restoreSnapshot(snapshot);
        expect(state.value, 100);
      });
    });

    group('StateManager', () {
      test('registers and tracks states', () {
        final manager = StateManager.instance;
        final initialStats = manager.getMemoryStats();

        final state = mutableStateOf(42);
        final stats = manager.getMemoryStats();

        expect(stats.activeStates, initialStats.activeStates + 1);

        state.dispose();
        final finalStats = manager.getMemoryStats();
        expect(finalStats.activeStates, initialStats.activeStates);
      });

      test('detects potential memory leaks', () {
        final manager = StateManager.instance;
        final state = mutableStateOf(42);

        // Should not detect leaks for new states
        final leaks = manager.detectPotentialLeaks(
          threshold: const Duration(seconds: 1),
        );
        expect(leaks, isEmpty);

        state.dispose();
      });
    });

    group('DisposableState Mixin', () {
      test('prevents operations on disposed state', () {
        final state = mutableStateOf(42);
        state.dispose();

        expect(() => state.value, throwsA(isA<StateValidationException>()));
        expect(() => state.value = 100, throwsA(isA<StateValidationException>()));
        expect(() => state.createSnapshot(), throwsA(isA<StateValidationException>()));
      });

      test('prevents adding listeners to disposed state', () {
        final state = mutableStateOf(42);
        state.dispose();

        expect(() => state.addListener(() {}), throwsStateError);
      });
    });

    group('StateExceptions', () {
      test('StateSerializationException contains proper context', () {
        final exception = const StateSerializationException(
          'Failed to serialize',
          targetType: String,
          failedValue: 42,
          context: {'operation': 'toJson'},
        );

        expect(exception.message, 'Failed to serialize');
        expect(exception.targetType, String);
        expect(exception.failedValue, 42);
        expect(exception.context['operation'], 'toJson');
      });

      test('StatePersistenceException contains proper context', () {
        final exception = const StatePersistenceException(
          'Failed to save',
          storageKey: 'user_data',
          operation: 'save',
        );

        expect(exception.message, 'Failed to save');
        expect(exception.storageKey, 'user_data');
        expect(exception.operation, 'save');
      });

      test('StateValidationException contains proper context', () {
        final exception = const StateValidationException(
          'Invalid value',
          fieldName: 'age',
          violatedRule: 'must be positive',
          actualValue: -5,
          expectedValue: 'positive number',
        );

        expect(exception.message, 'Invalid value');
        expect(exception.fieldName, 'age');
        expect(exception.violatedRule, 'must be positive');
        expect(exception.actualValue, -5);
        expect(exception.expectedValue, 'positive number');
      });

      test('StateConsistencyException contains proper context', () {
        final exception = const StateConsistencyException(
          'Consistency violation',
          involvedStates: ['state1', 'state2'],
          operation: 'transaction',
          isConcurrencyIssue: true,
        );

        expect(exception.message, 'Consistency violation');
        expect(exception.involvedStates, ['state1', 'state2']);
        expect(exception.operation, 'transaction');
        expect(exception.isConcurrencyIssue, true);
      });
    });
  });
}
