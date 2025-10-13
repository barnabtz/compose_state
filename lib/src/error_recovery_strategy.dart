import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'state_exceptions.dart';

/// Interface for defining error recovery strategies.
/// 
/// Recovery strategies determine how the system should respond to errors
/// and what actions to take to recover from failure conditions.
abstract interface class ErrorRecoveryStrategy {
  /// Attempts to recover from the given error.
  /// 
  /// Returns a [RecoveryResult] indicating whether recovery was successful
  /// and what value should be used.
  Future<RecoveryResult<T>> recover<T>(
    StateException error,
    T? lastKnownValue,
    Map<String, dynamic> context,
  );

  /// Whether this strategy can handle the given error type.
  bool canHandle(StateException error);

  /// The name of this recovery strategy for logging purposes.
  String get name;
}

/// Result of an error recovery attempt.
class RecoveryResult<T> {
  /// Whether the recovery was successful.
  final bool isSuccess;

  /// The recovered value, if recovery was successful.
  final T? value;

  /// Error message if recovery failed.
  final String? errorMessage;

  /// Whether the operation should be retried.
  final bool shouldRetry;

  /// Delay before retry, if applicable.
  final Duration? retryDelay;

  /// Additional context from the recovery attempt.
  final Map<String, dynamic> context;

  const RecoveryResult._({
    required this.isSuccess,
    this.value,
    this.errorMessage,
    this.shouldRetry = false,
    this.retryDelay,
    this.context = const {},
  });

  /// Creates a successful recovery result.
  factory RecoveryResult.success(T value, {Map<String, dynamic>? context}) {
    return RecoveryResult._(
      isSuccess: true,
      value: value,
      context: context ?? {},
    );
  }

  /// Creates a failed recovery result.
  factory RecoveryResult.failure(
    String errorMessage, {
    Map<String, dynamic>? context,
  }) {
    return RecoveryResult._(
      isSuccess: false,
      errorMessage: errorMessage,
      context: context ?? {},
    );
  }

  /// Creates a retry recovery result.
  factory RecoveryResult.retry({
    Duration? delay,
    Map<String, dynamic>? context,
  }) {
    return RecoveryResult._(
      isSuccess: false,
      shouldRetry: true,
      retryDelay: delay,
      context: context ?? {},
    );
  }
}

/// Retry strategy with exponential backoff.
class RetryStrategy implements ErrorRecoveryStrategy {
  /// Maximum number of retry attempts.
  final int maxAttempts;

  /// Base delay between retries.
  final Duration baseDelay;

  /// Maximum delay between retries.
  final Duration maxDelay;

  /// Multiplier for exponential backoff.
  final double backoffMultiplier;

  /// Random jitter to prevent thundering herd.
  final bool useJitter;

  /// Current attempt count (tracked per error context).
  final Map<String, int> _attemptCounts = {};

  RetryStrategy({
    this.maxAttempts = 3,
    this.baseDelay = const Duration(milliseconds: 100),
    this.maxDelay = const Duration(seconds: 30),
    this.backoffMultiplier = 2.0,
    this.useJitter = true,
  });

  @override
  Future<RecoveryResult<T>> recover<T>(
    StateException error,
    T? lastKnownValue,
    Map<String, dynamic> context,
  ) async {
    final errorKey = _getErrorKey(error, context);
    final currentAttempt = _attemptCounts[errorKey] ?? 0;

    if (currentAttempt >= maxAttempts) {
      _attemptCounts.remove(errorKey);
      return RecoveryResult.failure(
        'Max retry attempts ($maxAttempts) exceeded',
        context: {'attempts': currentAttempt},
      );
    }

    _attemptCounts[errorKey] = currentAttempt + 1;

    final delay = _calculateDelay(currentAttempt);
    return RecoveryResult.retry(
      delay: delay,
      context: {
        'attempt': currentAttempt + 1,
        'maxAttempts': maxAttempts,
        'delay': delay.inMilliseconds,
      },
    );
  }

  @override
  bool canHandle(StateException error) {
    // Retry strategy can handle most transient errors
    return error is StatePersistenceException ||
        error is StateSerializationException ||
        (error.cause is TimeoutException) ||
        (error.cause is SocketException);
  }

  @override
  String get name => 'retry';

  Duration _calculateDelay(int attempt) {
    var delay = baseDelay.inMilliseconds * pow(backoffMultiplier, attempt);
    delay = delay.clamp(baseDelay.inMilliseconds, maxDelay.inMilliseconds);

    if (useJitter) {
      final jitter = Random().nextDouble() * 0.1; // 10% jitter
      delay = delay * (1 + jitter);
    }

    return Duration(milliseconds: delay.round());
  }

  String _getErrorKey(StateException error, Map<String, dynamic> context) {
    return '${error.runtimeType}_${context['stateKey'] ?? 'unknown'}';
  }

  /// Resets retry count for a specific error context.
  void resetRetryCount(String errorKey) {
    _attemptCounts.remove(errorKey);
  }

  /// Clears all retry counts.
  void clearAllRetryCounts() {
    _attemptCounts.clear();
  }
}

/// Fallback strategy that provides default values.
class FallbackStrategy implements ErrorRecoveryStrategy {
  /// Function to provide fallback values based on type and context.
  final Map<Type, dynamic Function(Map<String, dynamic>)> _fallbackProviders = {};

  /// Default fallback values for common types.
  final Map<Type, dynamic> _defaultFallbacks = {
    String: '',
    int: 0,
    double: 0.0,
    bool: false,
    List: <dynamic>[],
    Map: <String, dynamic>{},
  };

  FallbackStrategy();

  /// Registers a fallback provider for a specific type.
  void registerFallback<T>(T Function(Map<String, dynamic> context) provider) {
    _fallbackProviders[T] = provider;
  }

  /// Sets a default fallback value for a type.
  void setDefaultFallback<T>(T value) {
    _defaultFallbacks[T] = value;
  }

  @override
  Future<RecoveryResult<T>> recover<T>(
    StateException error,
    T? lastKnownValue,
    Map<String, dynamic> context,
  ) async {
    // Try to use last known value first
    if (lastKnownValue != null) {
      return RecoveryResult.success(
        lastKnownValue,
        context: {'source': 'lastKnownValue'},
      );
    }

    // Try registered fallback provider
    final provider = _fallbackProviders[T];
    if (provider != null) {
      try {
        final value = provider(context) as T;
        return RecoveryResult.success(
          value,
          context: {'source': 'registeredProvider'},
        );
      } catch (e) {
        // Continue to default fallback
      }
    }

    // Try default fallback
    final defaultValue = _defaultFallbacks[T];
    if (defaultValue != null) {
      return RecoveryResult.success(
        defaultValue as T,
        context: {'source': 'defaultFallback'},
      );
    }

    return RecoveryResult.failure(
      'No fallback available for type $T',
      context: {'availableTypes': _defaultFallbacks.keys.toList()},
    );
  }

  @override
  bool canHandle(StateException error) {
    // Fallback can handle any error as a last resort
    return true;
  }

  @override
  String get name => 'fallback';
}

/// Reset strategy that resets state to initial values.
class ResetStrategy implements ErrorRecoveryStrategy {
  /// Function to provide initial values for reset.
  final Map<String, dynamic Function()> _initialValueProviders = {};

  ResetStrategy();

  /// Registers an initial value provider for a state key.
  void registerInitialValue(String stateKey, dynamic Function() provider) {
    _initialValueProviders[stateKey] = provider;
  }

  @override
  Future<RecoveryResult<T>> recover<T>(
    StateException error,
    T? lastKnownValue,
    Map<String, dynamic> context,
  ) async {
    final stateKey = context['stateKey'] as String?;
    
    if (stateKey != null) {
      final provider = _initialValueProviders[stateKey];
      if (provider != null) {
        try {
          final initialValue = provider() as T;
          return RecoveryResult.success(
            initialValue,
            context: {'source': 'initialValue', 'stateKey': stateKey},
          );
        } catch (e) {
          return RecoveryResult.failure(
            'Failed to get initial value: $e',
            context: {'stateKey': stateKey},
          );
        }
      }
    }

    return RecoveryResult.failure(
      'No initial value provider registered for state: $stateKey',
      context: {'stateKey': stateKey},
    );
  }

  @override
  bool canHandle(StateException error) {
    // Reset strategy handles corruption and consistency errors
    return error is StateValidationException ||
        error is StateConsistencyException ||
        error is StateSerializationException;
  }

  @override
  String get name => 'reset';
}

/// Circuit breaker strategy to prevent cascading failures.
class CircuitBreakerStrategy implements ErrorRecoveryStrategy {
  /// Number of failures before opening the circuit.
  final int failureThreshold;

  /// Duration to keep circuit open.
  final Duration openDuration;

  /// Duration for half-open state.
  final Duration halfOpenDuration;

  /// Current state of the circuit breaker.
  CircuitState _state = CircuitState.closed;

  /// Timestamp when circuit was opened.
  DateTime? _openedAt;

  /// Current failure count.
  int _failureCount = 0;



  CircuitBreakerStrategy({
    this.failureThreshold = 5,
    this.openDuration = const Duration(minutes: 1),
    this.halfOpenDuration = const Duration(seconds: 30),
  });

  @override
  Future<RecoveryResult<T>> recover<T>(
    StateException error,
    T? lastKnownValue,
    Map<String, dynamic> context,
  ) async {
    switch (_state) {
      case CircuitState.closed:
        _failureCount++;
        if (_failureCount >= failureThreshold) {
          _openCircuit(error);
          return RecoveryResult.failure(
            'Circuit breaker opened due to repeated failures',
            context: {'circuitState': 'opened', 'failureCount': _failureCount},
          );
        }
        return RecoveryResult.failure(
          'Circuit breaker recording failure',
          context: {'circuitState': 'closed', 'failureCount': _failureCount},
        );

      case CircuitState.open:
        if (_shouldTransitionToHalfOpen()) {
          _state = CircuitState.halfOpen;
          return RecoveryResult.retry(
            delay: const Duration(milliseconds: 100),
            context: {'circuitState': 'halfOpen'},
          );
        }
        return RecoveryResult.failure(
          'Circuit breaker is open',
          context: {
            'circuitState': 'open',
            'remainingTime': _getRemainingOpenTime().inSeconds,
          },
        );

      case CircuitState.halfOpen:
        // In half-open state, allow one attempt
        _closeCircuit();
        return RecoveryResult.retry(
          delay: const Duration(milliseconds: 50),
          context: {'circuitState': 'closed'},
        );
    }
  }

  @override
  bool canHandle(StateException error) {
    // Circuit breaker can handle any error to prevent cascading failures
    return true;
  }

  @override
  String get name => 'circuitBreaker';

  void _openCircuit(StateException error) {
    _state = CircuitState.open;
    _openedAt = DateTime.now();
  }

  void _closeCircuit() {
    _state = CircuitState.closed;
    _failureCount = 0;
    _openedAt = null;
  }

  bool _shouldTransitionToHalfOpen() {
    if (_openedAt == null) return false;
    return DateTime.now().difference(_openedAt!) >= openDuration;
  }

  Duration _getRemainingOpenTime() {
    if (_openedAt == null) return Duration.zero;
    final elapsed = DateTime.now().difference(_openedAt!);
    final remaining = openDuration - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Gets the current circuit state.
  CircuitState get state => _state;

  /// Gets the current failure count.
  int get failureCount => _failureCount;

  /// Manually resets the circuit breaker.
  void reset() {
    _closeCircuit();
  }
}

/// States of a circuit breaker.
enum CircuitState {
  /// Circuit is closed, allowing all requests.
  closed,

  /// Circuit is open, blocking all requests.
  open,

  /// Circuit is half-open, allowing limited requests to test recovery.
  halfOpen,
}