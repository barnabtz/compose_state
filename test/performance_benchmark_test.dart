import 'package:flutter_test/flutter_test.dart';
import 'package:compose_state/compose_state.dart';

void main() {
  group('Performance Benchmarks', () {
    test('Measures the performance of creating and updating a large number of states', () {
      const stateCount = 1000;
      final states = <MutableState<int>>[];

      final creationStopwatch = Stopwatch()..start();
      for (var i = 0; i < stateCount; i++) {
        states.add(mutableStateOf(i));
      }
      creationStopwatch.stop();

      final updateStopwatch = Stopwatch()..start();
      for (final state in states) {
        state.value++;
      }
      updateStopwatch.stop();

      // ignore: avoid_print
      print('Creation of $stateCount states took: ${creationStopwatch.elapsedMilliseconds}ms');
      // ignore: avoid_print
      print('Update of $stateCount states took: ${updateStopwatch.elapsedMilliseconds}ms');

      // These are not hard assertions, but rather a way to ensure the benchmark runs
      // and to provide a baseline for future performance tracking.
      expect(creationStopwatch.elapsedMilliseconds, lessThan(1000));
      expect(updateStopwatch.elapsedMilliseconds, lessThan(1000));
    });
  });
}
