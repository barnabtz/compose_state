
import 'package:flutter_test/flutter_test.dart';
import 'package:compose_state/compose_state.dart';

void main() {
  group('MutableState', () {
    test('initial value is set correctly', () {
      final state = mutableStateOf(42);
      expect(state.value, 42);
    });

    test('value updates trigger listeners', () {
      final state = mutableStateOf(0);
      int callCount = 0;

      state.addListener(() {
        callCount++;
      });

      state.value = 1;
      expect(state.value, 1);
      expect(callCount, 1);

      state.setValue(2);  // Test setValue
      expect(state.value, 2);
      expect(callCount, 2);

      state.value = 2;  // Same value
      expect(callCount, 2);
    });

    test('removeListener stops updates', () {
      final state = mutableStateOf(0);
      int callCount = 0;

      void listener() => callCount++;
      state.addListener(listener);

      state.setValue(1);
      expect(callCount, 1);

      state.removeListener(listener);
      state.setValue(2);
      expect(callCount, 1);
    });

    test('dispose clears listeners', () {
      final state = mutableStateOf(0);
      int callCount = 0;

      state.addListener(() => callCount++);
      state.dispose();

      state.setValue(1);
      expect(callCount, 0);
    });
  });
}