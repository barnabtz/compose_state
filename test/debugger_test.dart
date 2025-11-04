import 'package:flutter_test/flutter_test.dart';
import 'package:compose_state/compose_state.dart';

void main() {
  group('StateDebugger', () {
    test('prints debug information with timestamps', () {
      final state = mutableStateOf(0);
      final debugger = debuggerStateOf(state, 'counter');

      debugger.value = 1;
      debugger.value = 2;
      debugger.equals(2);
      final snapshot = debugger.createSnapshot();
      debugger.restoreSnapshot(snapshot);
      debugger.dispose();

      expect(() => debugger.value, throwsA(isA<StateValidationException>()));
    });
  });
}
