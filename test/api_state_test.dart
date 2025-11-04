import 'package:flutter_test/flutter_test.dart';
import 'package:compose_state/compose_state.dart';

void main() {
  group('ApiState', () {
    test('should handle successful data fetching', () async {
      final apiState = apiStateOf<String>(
        (page, params) async {
          await Future.delayed(const Duration(milliseconds: 100));
          return 'success data';
        },
      );

      expect(apiState.value.isLoading, true);
      expect(apiState.value.data, null);

      await apiState.fetch();

      expect(apiState.value.isLoading, false);
      expect(apiState.value.data, 'success data');
      expect(apiState.value.isSuccess, true);
    });

    test('should handle errors with retry', () async {
      int attemptCount = 0;
              final errorHandler = StateErrorHandler();
              errorHandler.removeStrategy<RetryStrategy>();
              errorHandler.addStrategy(RetryStrategy(maxAttempts: 3));
              final apiState = apiStateOf<String>(
                (page, params) async {
                  attemptCount++;
                  if (attemptCount < 3) {
                    throw Exception('Network error');
                  }
                  return 'success after retry';
                },
                errorHandler: errorHandler,      );

      await apiState.fetch();

      expect(apiState.value.data, 'success after retry');
      expect(attemptCount, 3);
    });
  });
}
