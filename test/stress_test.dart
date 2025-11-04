import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:compose_state/compose_state.dart';

void main() {
  group('Stress Tests', () {
    test('Handles concurrent updates to a single state without race conditions', () async {
      const updateCount = 1000;
      final state = mutableStateOf(0);
      final completer = Completer<void>();

      // Simulate concurrent updates from multiple isolates
      final futures = <Future<void>>[];
      for (var i = 0; i < updateCount; i++) {
        futures.add(Future(() => state.value++));
      }

      Future.wait(futures).then((_) {
        completer.complete();
      });

      await completer.future;

      // The final value should be equal to the number of updates
      expect(state.value, equals(updateCount));
    });
  });
}
