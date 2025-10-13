import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:compose_state/compose_state.dart';

// Extension to add TestStateBuilder finder methods to WidgetTester
extension TestStateBuilderFinder on WidgetTester {
  TestStateBuilderState<T>? findTestStateBuilder<T>() {
    final finder = find.byType(TestStateBuilder<T>);
    if (finder.evaluate().isEmpty) return null;

    final element = finder.evaluate().first;
    return (element as StatefulElement).state as TestStateBuilderState<T>?;
  }
}

void main() {
  group('Testing Infrastructure', () {
    group('MockState', () {
      test('basic mock state functionality', () {
        final mock = mockStateOf(42);

        expect(mock.value, 42);
        expect(mock.isDisposed, false);
        expect(mock.listenerCount, 0);

        mock.value = 100;
        expect(mock.value, 100);
        expect(mock.changeHistory.length, 1);
        expect(mock.lastChange?.newValue, 100);
      });

      test('mock state with controllable errors', () {
        final mock = mockStateOf(0);

        mock.throwOnSet();
        expect(() => mock.value = 1, throwsException);

        mock.resetMockBehavior();
        mock.value = 1; // Should work now
        expect(mock.value, 1);
      });

      test('mock state with custom equality', () {
        final mock = mockStateOf('hello');
        int notificationCount = 0;

        mock.addListener(() => notificationCount++);
        mock.setCustomEquals((a, b) => a.toLowerCase() == b.toLowerCase());

        mock.value = 'HELLO'; // Should not notify due to custom equality
        expect(notificationCount, 0);

        mock.value = 'world'; // Should notify
        expect(notificationCount, 1);
      });

      test('mock state change tracking', () {
        final mock = mockStateOf(0);

        mock.value = 1;
        mock.value = 2;
        mock.value = 3;

        expect(mock.changeHistory.length, 3);
        expect(mock.wasValueSet(2), true);
        expect(mock.wasValueSet(5), false);
        expect(mock.getValueSetCount(1), 1);
      });

      test('mock API state', () {
        final mockApi = mockApiStateOf<String>();

        expect(mockApi.value, isA<Loading>());

        mockApi.simulateSuccess('data');
        expect(mockApi.value, isA<Success<String>>());
        expect((mockApi.value as Success<String>).data, 'data');

        mockApi.simulateError('error message');
        expect(mockApi.value, isA<Error<String>>());
        expect((mockApi.value as Error<String>).message, 'error message');
      });
    });

    group('StateTestUtils', () {
      test('wait for state change', () async {
        final state = mutableStateOf(0);

        // Change the value after a delay
        Future.delayed(const Duration(milliseconds: 100), () {
          state.value = 42;
        });

        final result = await StateTestUtils.waitForStateChange(state);
        expect(result, 42);
      });

      test('record state changes', () async {
        final state = mutableStateOf(0);

        // Start recording and make changes
        final recordingFuture = StateTestUtils.recordStateChanges(
          state,
          const Duration(milliseconds: 200),
        );

        await Future.delayed(const Duration(milliseconds: 50));
        state.value = 1;
        await Future.delayed(const Duration(milliseconds: 50));
        state.value = 2;

        final changes = await recordingFuture;
        expect(changes.length, 3); // initial + 2 changes
        expect(changes[1], 1); // changes[0] is initial value 0
        expect(changes[2], 2);
      });

      test('test listener functionality', () {
        final state = mutableStateOf(0);
        final listener = StateTestUtils.createTestListener<int>();
        state.addListener(listener.createListener(state));

        listener.startListening();

        state.value = 1;
        state.value = 2;
        state.value = 3;

        expect(listener.callCount, 3);
        expect(listener.values, [1, 2, 3]);
        expect(listener.lastValue, 3);

        listener.clear();
        expect(listener.callCount, 0);
        expect(listener.values, isEmpty);

        listener.dispose();
      });

      test('state matchers', () {
        final state = mutableStateOf(0);
        final apiState = mutableStateOf<UiState<String>>(const Success('data'));

        expect(state.isDisposed, isFalse);

        state.dispose();
        expect(StateMatchers.isDisposed(state), isTrue);

        expect(StateMatchers.isSuccess(apiState.value, 'data'), isTrue);

        apiState.value = const Error('error');
        expect(StateMatchers.isError(apiState.value, 'error'), isTrue);

        apiState.value = const Loading();
        expect(StateMatchers.isLoading(apiState.value), isTrue);
      });

      test('test scenario management', () {
        final scenario = StateTestUtils.createScenario();
        scenario.addState('counter', mutableStateOf(0));
        scenario.addState('name', mutableStateOf('test'));
        scenario.addListener<int>('counter', 'counter_listener');
        scenario.addListener<String>('name', 'name_listener');

        scenario.startListening();

        scenario.state('counter')!.value = 1;
        scenario.state('name')!.value = 'updated';

        expect(scenario.listener<int>('counter_listener')?.callCount, 1);
        expect(scenario.listener<String>('name_listener')?.callCount, 1);

        scenario.dispose();
      });
    });

    group('StateChangeTracker', () {
      test('basic state tracking', () {
        final tracker = createStateTracker();
        final state = mutableStateOf(0);

        tracker.trackState('counter', state);
        tracker.startTracking();

        state.value = 1;
        state.value = 2;

        final history = tracker.getChangeHistory('counter');
        expect(history.length, 3); // initial + 2 changes
        expect(history.last.currentValue, 2);

        tracker.dispose();
      });

      test('state tracking with verifications', () {
        final tracker = createStateTracker();
        final state = mutableStateOf(0);

        tracker.trackState('counter', state);
        tracker.addVerification(
          ValueVerification(
            stateIdentifier: 'counter',
            expectedValue: 5,
            description: 'Counter should reach 5',
          ),
        );

        tracker.startTracking();

        state.value = 5; // This should pass verification

        final stats = tracker.getStatistics();
        expect(stats.trackedStateCount, 1);
        expect(stats.totalChangeCount, 2); // initial + 1 change

        tracker.dispose();
      });

      test('wait for state value', () async {
        final tracker = createStateTracker();
        final state = mutableStateOf(0);

        tracker.trackState('counter', state);
        tracker.startTracking();

        // Change value after delay
        Future.delayed(const Duration(milliseconds: 100), () {
          state.value = 42;
        });

        final result = await tracker.waitForStateValue('counter', 42);
        expect(result, true);

        tracker.dispose();
      });

      test('state snapshots', () {
        final tracker = createStateTracker();
        final state1 = mutableStateOf(1);
        final state2 = mutableStateOf('hello');

        tracker.trackState('num', state1);
        tracker.trackState('str', state2);
        tracker.startTracking();

        final snapshot = tracker.createSnapshot();
        expect(snapshot.length, 2);
        expect(snapshot['num']?.value, 1);
        expect(snapshot['str']?.value, 'hello');

        // Change values
        state1.value = 100;
        state2.value = 'world';

        // Restore from snapshot
        tracker.restoreSnapshot(snapshot);
        expect(state1.value, 1);
        expect(state2.value, 'hello');

        tracker.dispose();
      });
    });

    group('TestStateBuilder', () {
      testWidgets('basic widget testing', (tester) async {
        final state = mutableStateOf(0);

        await tester.pumpWidget(
          MaterialApp(
            home: TestStateBuilder<int>(
              state: state,
              enableChangeTracking: true,
              builder: (context, value) => Text('$value'),
            ),
          ),
        );

        expect(find.text('0'), findsOneWidget);

        state.value = 42;
        await tester.pump();

        expect(find.text('42'), findsOneWidget);

        final builderState = tester.findTestStateBuilder<int>();
        expect(builderState?.stats.buildCount, 2); // initial + 1 update
        expect(builderState?.changeHistory.map((e) => e.newValue).toList(), [
          0,
          42,
        ]);

        // Clean up to prevent timer issues
        state.dispose();
        StateManager.instance.stop();
      });

      testWidgets('error handling in widget', (tester) async {
        final state = mutableStateOf(0);

        await tester.pumpWidget(
          MaterialApp(
            home: TestStateBuilder<int>(
              state: state,
              enableChangeTracking: true,
              builder: (context, value) {
                if (value == 42) {
                  throw Exception('Test error');
                }
                return Text('$value');
              },
            ),
          ),
        );

        expect(find.text('0'), findsOneWidget);

        state.value = 42; // This should trigger an error
        await tester.pump();

        final builderState = tester.findTestStateBuilder<int>();
        expect(builderState?.buildHistory.any((e) => e.error != null), true);
        expect(
          builderState?.buildHistory.where((e) => e.error != null).length,
          1,
        );

        // Clean up to prevent timer issues
        state.dispose();
        StateManager.instance.stop();
      });

      testWidgets('wait for specific value', (tester) async {
        final state = mutableStateOf(0);

        await tester.pumpWidget(
          MaterialApp(
            home: TestStateBuilder<int>(
              state: state,
              builder: (context, value) => Text('$value'),
            ),
          ),
        );

        // Verify initial state
        expect(find.text('0'), findsOneWidget);

        // Change state value immediately
        state.value = 99;

        // Pump to trigger rebuild
        await tester.pump();

        // Verify the change
        expect(find.text('99'), findsOneWidget);

        // Also test the current value
        final builderState = tester.findTestStateBuilder<int>();
        expect(builderState?.currentValue, 99);

        // Clean up state and stop services to prevent timer issues
        state.dispose();
        StateManager.instance.stop();
      });
    });

    group('Integration Tests', () {
      test('mock state with real state builder', () async {
        final mock = mockStateOf(0);
        final tracker = createStateTracker();

        tracker.trackState('mock', mock);
        tracker.startTracking();

        // Simulate some state changes
        mock.value = 1;
        mock.value = 2;
        mock.value = 3;

        final history = tracker.getChangeHistory('mock');
        expect(history.length, 4); // initial + 3 changes

        // Verify the sequence
        StateTestUtils.verifyStateSequence(
          history
              .map(
                (e) => StateChangeRecord(
                  oldValue: e.previousValue,
                  newValue: e.currentValue,
                  timestamp: e.timestamp,
                  changeType: 'change',
                ),
              )
              .toList(),
          [0, 1, 2, 3],
        );

        tracker.dispose();
        mock.dispose();
      });

      test('comprehensive testing workflow', () async {
        // Create states
        final counter = mutableStateOf(0);
        final name = mutableStateOf('initial');
        final apiState = mockApiStateOf<String>();

        // Set up tracking
        final tracker = createStateTracker();
        tracker.trackState('counter', counter);
        tracker.trackState('name', name);
        tracker.trackState('api', apiState);
        tracker.startTracking();

        // Set up listeners
        final counterListener = StateTestUtils.createTestListener<int>();
        final nameListener = StateTestUtils.createTestListener<String>();

        counter.addListener(counterListener.createListener(counter));
        name.addListener(nameListener.createListener(name));

        // Perform operations
        counter.value = 1;
        name.value = 'updated';
        apiState.simulateSuccess('api data');

        // Verify results
        expect(counterListener.callCount, 1);
        expect(nameListener.callCount, 1);
        expect(tracker.getChangeCount('counter'), 2); // initial + 1 change
        expect(tracker.getChangeCount('name'), 2); // initial + 1 change

        StateTestUtils.expectApiSuccess(apiState.value, 'api data');

        // Clean up
        counterListener.dispose();
        nameListener.dispose();
        tracker.dispose();
        counter.dispose();
        name.dispose();
        apiState.dispose();
      });
    });
  });
}
