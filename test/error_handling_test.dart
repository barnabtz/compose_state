import 'package:flutter_test/flutter_test.dart';
import 'package:compose_state/compose_state.dart';

void main() {
  group('Comprehensive Error Handling Tests', () {
    test('StateErrorHandler handles errors with retry strategy', () async {
      final errorHandler = StateErrorHandler();
      final retryStrategy = RetryStrategy(maxAttempts: 2);
      errorHandler.addStrategy(retryStrategy);

      final error = const StatePersistenceException(
        'Test persistence error',
        operation: 'save',
        storageKey: 'test_key',
      );

      final context = ErrorContext(
        stateKey: 'test_state',
        operation: 'save',
        valueType: String,
      );

      // This should use fallback value since we provided one
      final result = await errorHandler.handleError<String>(
        error,
        context,
        fallbackValue: 'fallback',
      );
      
      expect(result, equals('fallback'));
    });

    test('StateErrorHandler throws error when no recovery possible', () async {
      final errorHandler = StateErrorHandler();
      // Remove all strategies except circuit breaker
      errorHandler.removeStrategy<RetryStrategy>();
      errorHandler.removeStrategy<FallbackStrategy>();
      errorHandler.removeStrategy<ResetStrategy>();

      final error = const StatePersistenceException(
        'Test persistence error',
        operation: 'save',
        storageKey: 'test_key',
      );

      final context = ErrorContext(
        stateKey: 'test_state',
        operation: 'save',
        valueType: String,
      );

      // This should throw since no recovery strategies are available
      expect(
        () async => await errorHandler.handleError<String>(error, context),
        throwsA(isA<StatePersistenceException>()),
      );
    });

    test('FallbackStrategy provides fallback values', () async {
      final strategy = FallbackStrategy();
      strategy.setDefaultFallback<String>('default_value');

      final error = const StateSerializationException('Test error');
      final result = await strategy.recover<String>(
        error,
        null,
        {'stateKey': 'test'},
      );

      expect(result.isSuccess, isTrue);
      expect(result.value, equals('default_value'));
    });

    test('RetryStrategy respects max attempts', () async {
      final strategy = RetryStrategy(maxAttempts: 2);
      final error = const StatePersistenceException('Test error', storageKey: 'test');

      // First attempt should return retry
      var result = await strategy.recover<String>(
        error,
        null,
        {'stateKey': 'test'},
      );
      expect(result.shouldRetry, isTrue);

      // Second attempt should return retry
      result = await strategy.recover<String>(
        error,
        null,
        {'stateKey': 'test'},
      );
      expect(result.shouldRetry, isTrue);

      // Third attempt should fail
      result = await strategy.recover<String>(
        error,
        null,
        {'stateKey': 'test'},
      );
      expect(result.isSuccess, isFalse);
      expect(result.shouldRetry, isFalse);
    });

    test('CircuitBreakerStrategy opens after threshold failures', () async {
      final strategy = CircuitBreakerStrategy(failureThreshold: 2);
      final error = const StateValidationException('Test error');

      expect(strategy.state, equals(CircuitState.closed));

      // First failure
      await strategy.recover<String>(error, null, {});
      expect(strategy.state, equals(CircuitState.closed));

      // Second failure should open circuit
      await strategy.recover<String>(error, null, {});
      expect(strategy.state, equals(CircuitState.open));
    });

    test('ErrorContext builder creates proper context', () {
      final context = ErrorContext(
        stateKey: 'test_state',
        operation: 'test_operation',
        valueType: String,
        metadata: {'key': 'value'},
      );

      expect(context.stateKey, equals('test_state'));
      expect(context.operation, equals('test_operation'));
      expect(context.valueType, equals(String));
      expect(context.metadata['key'], equals('value'));
    });

    test('Error statistics are tracked correctly', () async {
      final errorHandler = StateErrorHandler();
      final error = const StateValidationException('Test error');
      final context = ErrorContext(
        stateKey: 'test_state',
        operation: 'validate',
      );

      try {
        await errorHandler.handleError<String>(error, context);
      } catch (e) {
        // Expected to throw
      }

      final stats = errorHandler.getErrorStats();
      expect(stats.isNotEmpty, isTrue);
      
      final statsValues = stats.values.toList();
      final totalErrors = statsValues.fold<int>(0, (sum, stat) => sum + stat.totalErrors);
      expect(totalErrors, equals(1));
    });

    test('Error recovery with fallback values', () async {
      final errorHandler = StateErrorHandler();
      final fallbackStrategy = FallbackStrategy();
      fallbackStrategy.setDefaultFallback<String>('fallback_value');
      errorHandler.addStrategy(fallbackStrategy);

      final error = const StateSerializationException('Test error');
      final context = ErrorContext(
        stateKey: 'test_state',
        operation: 'serialize',
        valueType: String,
      );

      final result = await errorHandler.handleError<String>(
        error,
        context,
        fallbackValue: 'custom_fallback',
      );
      
      expect(result, equals('custom_fallback'));
    });

    test('Error statistics tracking', () async {
      final errorHandler = StateErrorHandler();
      
      // Generate different types of errors
      final errors = [
        const StateSerializationException('Serialization failed'),
        const StatePersistenceException('Storage error', storageKey: 'test'),
        const StateValidationException('Invalid data'),
      ];

      for (final error in errors) {
        try {
          await errorHandler.handleError<String>(
            error,
            ErrorContext(stateKey: 'test', operation: 'test'),
          );
        } catch (e) {
          // Expected to throw
        }
      }

      final stats = errorHandler.getErrorStats();
      expect(stats.isNotEmpty, isTrue);
    });
  });
}