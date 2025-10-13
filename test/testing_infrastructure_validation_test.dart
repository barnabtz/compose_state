import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:compose_state/compose_state.dart';

void main() {
  group('Testing Infrastructure Validation', () {
    group('MockState Functionality', () {
      test('MockState provides controllable behavior', () {
        final mockState = MockState<int>(42);

        expect(mockState.value, equals(42));
        expect(mockState.isDisposed, isFalse);

        // Test controllable notifications
        int notificationCount = 0;
        mockState.addListener(() => notificationCount++);

        mockState.value = 100;
        expect(mockState.value, equals(100));
        expect(notificationCount, equals(1));

        mockState.dispose();
        expect(mockState.isDisposed, isTrue);
      });

      test('MockState simulates error conditions', () {
        final mockState = MockState<String>('initial');

        // Configure to throw on get
        mockState.throwOnGet();

        expect(() => mockState.value, throwsException);

        // Reset behavior
        mockState.resetMockBehavior();
        expect(mockState.value, equals('initial'));

        mockState.dispose();
      });

      test('MockState simulates delays', () async {
        final mockState = MockState<int>(0);

        // Configure delay
        mockState.delaySet(const Duration(milliseconds: 50));

        final stopwatch = Stopwatch()..start();
        mockState.value = 100;

        // Wait for the delayed update
        await Future.delayed(const Duration(milliseconds: 60));
        stopwatch.stop();

        expect(mockState.value, equals(100));
        expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(45));

        mockState.dispose();
      });

      test('MockState tracks change history', () {
        final mockState = MockState<String>('start');

        mockState.value = 'first';
        mockState.value = 'second';
        mockState.value = 'third';

        final history = mockState.changeHistory;
        expect(history.length, equals(3));
        expect(history[0].newValue, equals('first'));
        expect(history[1].newValue, equals('second'));
        expect(history[2].newValue, equals('third'));

        mockState.dispose();
      });
    });

    group('StateTestUtils Functionality', () {
      test('StateTestUtils provides wait utilities', () async {
        final state = mutableStateOf<int>(42);

        // Test waiting for state change
        final future = StateTestUtils.waitForStateChange(state, 100);

        // Change the state after a delay
        Future.delayed(const Duration(milliseconds: 10), () {
          state.value = 100;
        });

        final result = await future;
        expect(result, isTrue);

        state.dispose();
      });

      test('StateTestUtils records state changes', () async {
        final state = mutableStateOf<int>(0);

        // Start recording changes
        final recordingFuture = StateTestUtils.recordStateChanges(
          state,
          const Duration(milliseconds: 100),
        );

        // Make some changes
        await Future.delayed(const Duration(milliseconds: 10));
        state.value = 1;
        await Future.delayed(const Duration(milliseconds: 10));
        state.value = 2;
        await Future.delayed(const Duration(milliseconds: 10));
        state.value = 3;

        final changes = await recordingFuture;
        expect(changes.length, equals(3));
        expect(changes[0].newValue, equals(1));
        expect(changes[1].newValue, equals(2));
        expect(changes[2].newValue, equals(3));

        state.dispose();
      });

      test('StateTestUtils verifies state sequences', () async {
        final state = mutableStateOf<int>(0);

        // Start recording and make changes during recording
        final recordingFuture = StateTestUtils.recordStateChanges(
          state,
          const Duration(milliseconds: 100),
        );

        // Make changes after starting recording
        await Future.delayed(const Duration(milliseconds: 10));
        state.value = 10;
        await Future.delayed(const Duration(milliseconds: 10));
        state.value = 20;
        await Future.delayed(const Duration(milliseconds: 10));
        state.value = 30;

        final changes = await recordingFuture;

        // Verify the sequence
        StateTestUtils.verifyStateSequence(changes, [10, 20, 30]);

        state.dispose();
      });

      test('StateTestUtils creates test listeners', () {
        final state = mutableStateOf<String>('initial');
        final listener = StateTestUtils.createTestListener(state);

        listener.startListening();

        state.value = 'first';
        state.value = 'second';
        state.value = 'third';

        listener.expectCallCount(3);
        listener.expectValues(['first', 'second', 'third']);
        expect(listener.lastValue, equals('third'));

        listener.dispose();
        state.dispose();
      });
    });

    group('TestStateBuilder Functionality', () {
      test('TestStateBuilder provides widget testing capabilities', () {
        final state = mutableStateOf<String>('initial');

        final widget = TestStateBuilder<String>(
          state: state,
          builder: (context, value) => Text(value),
        );

        expect(widget.state, equals(state));
        expect(widget.enableAutoRebuild, isTrue);
        expect(widget.enableChangeTracking, isTrue);

        state.dispose();
      });

      test('TestStateBuilder can be configured for manual control', () {
        final state = mutableStateOf<int>(42);

        final widget = TestStateBuilder<int>(
          state: state,
          builder: (context, value) => Text('$value'),
          enableAutoRebuild: false,
          enableChangeTracking: true,
          testKey: 'test_builder',
        );

        expect(widget.enableAutoRebuild, isFalse);
        expect(widget.testKey, equals('test_builder'));

        state.dispose();
      });

      test('TestStateBuilder supports error handling', () {
        final state = mutableStateOf<String>('test');

        final widget = TestStateBuilder<String>(
          state: state,
          builder: (context, value) => Text(value),
          errorBuilder: (context, error) => Text('Error: ${error.message}'),
        );

        expect(widget.errorBuilder, isNotNull);

        state.dispose();
      });
    });

    group('Integration with Real States', () {
      test('Testing infrastructure works with MutableState', () async {
        final state = mutableStateOf<List<int>>([1, 2, 3]);
        final listener = StateTestUtils.createTestListener(state);

        listener.startListening();

        state.value = [1, 2, 3, 4];
        state.value = [1, 2, 3, 4, 5];

        listener.expectCallCount(2);
        expect(listener.values[0], equals([1, 2, 3, 4]));
        expect(listener.values[1], equals([1, 2, 3, 4, 5]));

        listener.dispose();
        state.dispose();
      });

      test('Testing infrastructure works with derived states', () async {
        final sourceState = mutableStateOf<int>(10);
        final derivedState = DerivedState<String>(
          () => 'Value: ${sourceState.value}',
          dependencies: [sourceState],
        );

        final listener = StateTestUtils.createTestListener(derivedState);
        listener.startListening();

        sourceState.value = 20;
        sourceState.value = 30;

        // Wait for derived state updates
        await Future.delayed(const Duration(milliseconds: 10));

        listener.expectCallCount(2);
        expect(listener.values[0], equals('Value: 20'));
        expect(listener.values[1], equals('Value: 30'));

        listener.dispose();
        derivedState.dispose();
        sourceState.dispose();
      });

      test('Testing infrastructure works with API states', () async {
        final apiState = MockApiState<String>();
        final listener = StateTestUtils.createTestListener(apiState);

        listener.startListening();

        // MockApiState starts with Loading state, so first change is to success
        apiState.simulateSuccess('test data');
        expect(apiState.value, isA<Success<String>>());
        expect((apiState.value as Success<String>).data, equals('test data'));

        // Test error state
        apiState.simulateError('test error');
        expect(apiState.value, isA<Error<String>>());
        expect((apiState.value as Error<String>).message, equals('test error'));

        // Should have 2 changes: Loading->Success, Success->Error
        listener.expectCallCount(2);

        listener.dispose();
        apiState.dispose();
      });
    });

    group('State Matchers and Utilities', () {
      test('State matchers work correctly', () {
        final disposedState = mutableStateOf<int>(42);
        disposedState.dispose();

        expect(disposedState, StateMatchers.isDisposed);

        final loadingState = const Loading<String>();
        expect(loadingState, StateMatchers.isLoading);

        final successState = const Success<String>('test data');
        expect(successState, StateMatchers.isSuccess<String>('test data'));

        final errorState = const Error<String>('test error');
        expect(errorState, StateMatchers.isError<String>('test error'));
      });

      test('Test scenario management', () {
        final states = {
          'counter': mutableStateOf<int>(0),
          'name': mutableStateOf<String>('test'),
          'flag': mutableStateOf<bool>(false),
        };

        final scenario = StateTestUtils.createScenario(states);

        expect(scenario.state('counter').value, equals(0));
        expect(scenario.state('name').value, equals('test'));
        expect(scenario.state('flag').value, equals(false));

        scenario.startListening();

        // Make changes
        scenario.state('counter').value = 10;
        scenario.state('name').value = 'updated';
        scenario.state('flag').value = true;

        // Verify listeners tracked changes
        scenario.listener('counter').expectCallCount(1);
        scenario.listener('name').expectCallCount(1);
        scenario.listener('flag').expectCallCount(1);

        scenario.dispose();
      });

      test('Mock state factory functions', () {
        final mockState = mockStateOf<int>(42);
        expect(mockState.value, equals(42));
        expect(mockState, isA<MockState<int>>());

        final mockApiState = mockApiStateOf<String>();
        expect(mockApiState.value, isA<Loading<String>>());
        expect(mockApiState, isA<MockApiState<String>>());

        mockState.dispose();
        mockApiState.dispose();
      });
    });
  });
}
