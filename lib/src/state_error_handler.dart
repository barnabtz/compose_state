import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import 'error_recovery_strategy.dart';
import 'state_exceptions.dart';
import 'state_manager.dart';

/// Configuration for error handling behavior.
class ErrorHandlerConfig {
  /// Whether to enable error logging.
  final bool enableLogging;

  /// Whether to enable error reporting to external services.
  final bool enableReporting;

  /// Maximum time to spend on recovery attempts.
  final Duration maxRecoveryTime;

  /// Timeout for individual recovery strategy attempts.
  final Duration strategyTimeout;

  /// Whether to use circuit breaker for cascading failure prevention.
  final bool useCircuitBreaker;

  /// Custom error reporter function.
  final void Function(StateException error, Map<String, dynamic> context)? errorReporter;

  /// Custom logger function.
  final void Function(String message, {String? level, Map<String, dynamic>? context})? logger;

  const ErrorHandlerConfig({
    this.enableLogging = true,
    this.enableReporting = false,
    this.maxRecoveryTime = const Duration(seconds: 30),
    this.strategyTimeout = const Duration(seconds: 5),
    this.useCircuitBreaker = true,
    this.errorReporter,
    this.logger,
  });
}

/// Context information for error handling operations.
class ErrorContext {
  /// The state key where the error occurred.
  final String? stateKey;

  /// The operation that was being performed.
  final String operation;

  /// The type of the state value.
  final Type? valueType;

  /// Additional metadata about the error context.
  final Map<String, dynamic> metadata;

  /// Timestamp when the error occurred.
  final DateTime timestamp;

  /// Stack trace where the error was caught.
  final StackTrace? stackTrace;

  /// Memory statistics at time of error.
  final Map<String, dynamic>? memoryStats;

  /// Current app lifecycle state.
  final String? appState;

  ErrorContext({
    this.stateKey,
    required this.operation,
    this.valueType,
    this.metadata = const {},
    DateTime? timestamp,
    this.stackTrace,
    this.memoryStats,
    this.appState,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Creates a copy with updated values.
  ErrorContext copyWith({
    String? stateKey,
    String? operation,
    Type? valueType,
    Map<String, dynamic>? metadata,
    DateTime? timestamp,
    StackTrace? stackTrace,
    Map<String, dynamic>? memoryStats,
    String? appState,
  }) {
    return ErrorContext(
      stateKey: stateKey ?? this.stateKey,
      operation: operation ?? this.operation,
      valueType: valueType ?? this.valueType,
      metadata: metadata ?? this.metadata,
      timestamp: timestamp ?? this.timestamp,
      stackTrace: stackTrace ?? this.stackTrace,
      memoryStats: memoryStats ?? this.memoryStats,
      appState: appState ?? this.appState,
    );
  }

  /// Converts to a map for logging and reporting.
  Map<String, dynamic> toMap() {
    return {
      'stateKey': stateKey,
      'operation': operation,
      'valueType': valueType?.toString(),
      'metadata': metadata,
      'timestamp': timestamp.toIso8601String(),
      'hasStackTrace': stackTrace != null,
      'memoryStats': memoryStats,
      'appState': appState,
    };
  }
}

/// Comprehensive error handler for state management operations.
/// 
/// Provides configurable error recovery strategies, logging, reporting,
/// and error boundaries for all state operations.
class StateErrorHandler {
  /// Configuration for error handling behavior.
  final ErrorHandlerConfig config;

  /// List of recovery strategies in order of preference.
  final List<ErrorRecoveryStrategy> _strategies = [];

  /// Circuit breaker for preventing cascading failures.
  late final CircuitBreakerStrategy _circuitBreaker;

  /// Error statistics for monitoring.
  final Map<String, ErrorStats> _errorStats = {};

  /// Active recovery operations to prevent duplicate attempts.
  final Set<String> _activeRecoveries = {};

  StateErrorHandler({ErrorHandlerConfig? config}) 
      : config = config ?? const ErrorHandlerConfig() {
    
    // Initialize circuit breaker if enabled
    if (this.config.useCircuitBreaker) {
      _circuitBreaker = CircuitBreakerStrategy();
      _strategies.add(_circuitBreaker);
    }

    // Add default recovery strategies
    _strategies.addAll([
      RetryStrategy(),
      FallbackStrategy(),
      ResetStrategy(),
    ]);
  }

  /// Adds a custom recovery strategy.
  void addStrategy(ErrorRecoveryStrategy strategy) {
    _strategies.insert(_strategies.length - 1, strategy); // Insert before fallback
  }

  /// Removes a recovery strategy by type.
  void removeStrategy<T extends ErrorRecoveryStrategy>() {
    _strategies.removeWhere((strategy) => strategy is T);
  }

  /// Handles an error with automatic recovery attempts.
  /// 
  /// Returns the recovered value or rethrows the error if recovery fails.
  Future<T> handleError<T>(
    StateException error,
    ErrorContext context, {
    T? lastKnownValue,
    T? fallbackValue,
  }) async {
    final recoveryKey = _getRecoveryKey(error, context);
    
    // Prevent duplicate recovery attempts
    if (_activeRecoveries.contains(recoveryKey)) {
      _log('Recovery already in progress for $recoveryKey', level: 'debug');
      throw error;
    }

    _activeRecoveries.add(recoveryKey);
    
    try {
      _recordError(error, context);
      _log('Handling error: ${error.message}', context: context.toMap());

      final result = await _attemptRecovery<T>(
        error,
        context,
        lastKnownValue: lastKnownValue,
        fallbackValue: fallbackValue,
      );

      if (result.isSuccess && result.value != null) {
        _log('Error recovery successful', context: context.toMap());
        return result.value!;
      } else {
        _log('Error recovery failed: ${result.errorMessage}', 
             level: 'error', context: context.toMap());
        _reportError(error, context);
        throw error;
      }
    } finally {
      _activeRecoveries.remove(recoveryKey);
    }
  }

  /// Wraps an operation with error boundary protection.
  /// 
  /// Catches any exceptions and converts them to StateExceptions with context.
  Future<T> withErrorBoundary<T>(
    String operation,
    Future<T> Function() operationFunc, {
    String? stateKey,
    Type? valueType,
    Map<String, dynamic>? metadata,
  }) async {
    final context = ErrorContext(
      stateKey: stateKey,
      operation: operation,
      valueType: valueType,
      metadata: metadata ?? {},
      memoryStats: _captureMemoryStats(),
      appState: _captureAppState(),
    );

    try {
      return await operationFunc();
    } on StateException {
      rethrow; // Already a StateException, let it bubble up
    } catch (error, stackTrace) {
      final stateError = _convertToStateException(error, stackTrace, context);
      _log('Error boundary caught: ${stateError.message}', 
           level: 'error', context: context.toMap());
      throw stateError;
    }
  }

  /// Synchronous version of withErrorBoundary.
  T withErrorBoundarySync<T>(
    String operation,
    T Function() operationFunc, {
    String? stateKey,
    Type? valueType,
    Map<String, dynamic>? metadata,
  }) {
    final context = ErrorContext(
      stateKey: stateKey,
      operation: operation,
      valueType: valueType,
      metadata: metadata ?? {},
      memoryStats: _captureMemoryStats(),
      appState: _captureAppState(),
    );

    try {
      return operationFunc();
    } on StateException {
      rethrow; // Already a StateException, let it bubble up
    } catch (error, stackTrace) {
      final stateError = _convertToStateException(error, stackTrace, context);
      _log('Error boundary caught: ${stateError.message}', 
           level: 'error', context: context.toMap());
      throw stateError;
    }
  }

  /// Gets error statistics for monitoring.
  Map<String, ErrorStats> getErrorStats() {
    return Map.unmodifiable(_errorStats);
  }

  /// Clears error statistics.
  void clearErrorStats() {
    _errorStats.clear();
  }

  /// Gets the current circuit breaker state.
  CircuitState? get circuitBreakerState => 
      config.useCircuitBreaker ? _circuitBreaker.state : null;

  /// Resets the circuit breaker.
  void resetCircuitBreaker() {
    if (config.useCircuitBreaker) {
      _circuitBreaker.reset();
    }
  }

  /// Captures memory statistics for error context
  Map<String, dynamic>? _captureMemoryStats() {
    try {
      // Try to get memory stats from StateManager if available
      final stats = StateManager.instance.getMemoryStats();
      return {
        'activeStates': stats.activeStates,
        'totalRegistered': stats.totalRegistered,
        'disposedStates': stats.disposedStates,
        'oldestStateAge': stats.oldestStateAge?.inSeconds,
      };
    } catch (e) {
      // Ignore errors in error capture
      return null;
    }
  }

  /// Captures app state for error context
  String? _captureAppState() {
    try {
      // This would typically integrate with Flutter's lifecycle
      // For now, we'll return a placeholder
      return 'unknown';
    } catch (e) {
      // Ignore errors in error capture
      return null;
    }
  }

  Future<RecoveryResult<T>> _attemptRecovery<T>(
    StateException error,
    ErrorContext context, {
    T? lastKnownValue,
    T? fallbackValue,
  }) async {
    final startTime = DateTime.now();
    final contextMap = context.toMap();
    
    // Add fallback value to context if provided
    if (fallbackValue != null) {
      final fallbackStrategy = _strategies.whereType<FallbackStrategy>().firstOrNull;
      fallbackStrategy?.setDefaultFallback<T>(fallbackValue);
    }

    for (final strategy in _strategies) {
      if (!strategy.canHandle(error)) continue;

      // Check if we've exceeded max recovery time
      if (DateTime.now().difference(startTime) > config.maxRecoveryTime) {
        _log('Recovery timeout exceeded', level: 'warning');
        break;
      }

      try {
        _log('Attempting recovery with ${strategy.name}', context: contextMap);
        
        // Apply timeout to individual strategy attempts
        final result = await strategy.recover<T>(error, lastKnownValue, contextMap)
            .timeout(config.strategyTimeout, onTimeout: () {
          _log('Strategy ${strategy.name} timed out', level: 'warning', context: contextMap);
          return RecoveryResult.failure('Strategy timeout exceeded: ${config.strategyTimeout}');
        });
        
        if (result.isSuccess) {
          _log('Recovery successful with ${strategy.name}', context: contextMap);
          return result;
        } else if (result.shouldRetry && result.retryDelay != null) {
          _log('Strategy ${strategy.name} requested retry in ${result.retryDelay}', 
               context: contextMap);
          await Future.delayed(result.retryDelay!);
          // Continue to next strategy or retry
        } else {
          _log('Strategy ${strategy.name} failed: ${result.errorMessage}', 
               context: contextMap);
        }
      } catch (strategyError) {
        _log('Strategy ${strategy.name} threw error: $strategyError', 
             level: 'error', context: contextMap);
        // Continue to next strategy
      }
    }

    return RecoveryResult.failure('All recovery strategies failed');
  }

  StateException _convertToStateException(
    Object error,
    StackTrace stackTrace,
    ErrorContext context,
  ) {
    final contextMap = context.toMap();

    if (error is TimeoutException) {
      return StatePersistenceException(
        'Operation timed out: ${context.operation}',
        context: contextMap,
        cause: error,
        stackTrace: stackTrace,
        operation: context.operation,
        storageKey: context.stateKey,
      );
    }

    if (error is FormatException) {
      return StateSerializationException(
        'Format error during ${context.operation}: ${error.message}',
        context: contextMap,
        cause: error,
        stackTrace: stackTrace,
        targetType: context.valueType,
      );
    }

    if (error is ArgumentError) {
      return StateValidationException(
        'Validation error during ${context.operation}: ${error.message}',
        context: contextMap,
        cause: error,
        stackTrace: stackTrace,
        violatedRule: 'argument_validation',
      );
    }

    // Generic state exception for unknown errors
    return StateValidationException(
      'Unexpected error during ${context.operation}: $error',
      context: contextMap,
      cause: error,
      stackTrace: stackTrace,
      violatedRule: 'unexpected_error',
    );
  }

  void _recordError(StateException error, ErrorContext context) {
    final key = '${error.runtimeType}_${context.operation}';
    final stats = _errorStats.putIfAbsent(key, () => ErrorStats(key));
    stats.recordError(error, context);
  }

  void _reportError(StateException error, ErrorContext context) {
    if (!config.enableReporting) return;

    try {
      config.errorReporter?.call(error, context.toMap());
    } catch (reportingError) {
      _log('Error reporting failed: $reportingError', level: 'error');
    }
  }

  void _log(String message, {String? level, Map<String, dynamic>? context}) {
    if (!config.enableLogging) return;

    try {
      if (config.logger != null) {
        config.logger!(message, level: level, context: context);
      } else {
        // Default logging using developer.log
        developer.log(
          message,
          name: 'StateErrorHandler',
          level: _getLogLevel(level),
          error: context,
        );
      }
    } catch (loggingError) {
      // Fallback to print if logging fails
      debugPrint('StateErrorHandler: $message');
    }
  }

  int _getLogLevel(String? level) {
    switch (level?.toLowerCase()) {
      case 'error':
        return 1000;
      case 'warning':
        return 900;
      case 'info':
        return 800;
      case 'debug':
        return 700;
      default:
        return 800; // info level
    }
  }

  String _getRecoveryKey(StateException error, ErrorContext context) {
    return '${error.runtimeType}_${context.stateKey}_${context.operation}';
  }
}

/// Statistics for error tracking and monitoring.
class ErrorStats {
  /// The error key for identification.
  final String key;

  /// Total number of errors recorded.
  int totalErrors = 0;

  /// Number of successful recoveries.
  int successfulRecoveries = 0;

  /// Number of failed recoveries.
  int failedRecoveries = 0;

  /// First occurrence of this error.
  DateTime? firstOccurrence;

  /// Last occurrence of this error.
  DateTime? lastOccurrence;

  /// Most recent error instance.
  StateException? lastError;

  /// Most recent error context.
  ErrorContext? lastContext;

  ErrorStats(this.key);

  /// Records a new error occurrence.
  void recordError(StateException error, ErrorContext context) {
    totalErrors++;
    firstOccurrence ??= context.timestamp;
    lastOccurrence = context.timestamp;
    lastError = error;
    lastContext = context;
  }

  /// Records a successful recovery.
  void recordSuccessfulRecovery() {
    successfulRecoveries++;
  }

  /// Records a failed recovery.
  void recordFailedRecovery() {
    failedRecoveries++;
  }

  /// Gets the recovery success rate.
  double get recoverySuccessRate {
    final totalRecoveries = successfulRecoveries + failedRecoveries;
    return totalRecoveries > 0 ? successfulRecoveries / totalRecoveries : 0.0;
  }

  /// Converts to a map for serialization.
  Map<String, dynamic> toMap() {
    return {
      'key': key,
      'totalErrors': totalErrors,
      'successfulRecoveries': successfulRecoveries,
      'failedRecoveries': failedRecoveries,
      'recoverySuccessRate': recoverySuccessRate,
      'firstOccurrence': firstOccurrence?.toIso8601String(),
      'lastOccurrence': lastOccurrence?.toIso8601String(),
      'lastErrorType': lastError?.runtimeType.toString(),
      'lastErrorMessage': lastError?.message,
    };
  }
}

/// Extension to add firstOrNull to Iterable.
extension IterableExtension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}