import 'package:flutter_test/flutter_test.dart';
import 'package:compose_state/compose_state.dart';

void main() {
  group('Simple Testing Infrastructure', () {
    test('mock state basic functionality', () {
      final mock = mockStateOf(42);
      
      expect(mock.value, 42);
      expect(mock.isDisposed, false);
      expect(mock.listenerCount, 0);
      
      mock.value = 100;
      expect(mock.value, 100);
      expect(mock.changeHistory.length, 1);
      expect(mock.lastChange?.newValue, 100);
      
      mock.dispose();
      expect(mock.isDisposed, true);
    });

    test('mock state with errors', () {
      final mock = mockStateOf(0);
      
      mock.throwOnSet();
      expect(() => mock.value = 1, throwsException);
      
      mock.resetMockBehavior();
      mock.value = 1; // Should work now
      expect(mock.value, 1);
    });

    test('state change tracker basic', () {
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
      state.dispose();
    });

    test('test listener', () {
      final state = mutableStateOf(0);
      final listener = StateTestUtils.createTestListener<int>();
      state.addListener(listener.createListener(state));
      
      // Listener is already active
      
      state.value = 1;
      state.value = 2;
      
      expect(listener.callCount, 2);
      expect(listener.values, [1, 2]);
      expect(listener.lastValue, 2);
      
      listener.dispose();
      state.dispose();
    });
  });
}