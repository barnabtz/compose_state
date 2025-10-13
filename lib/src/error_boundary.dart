import 'dart:async';

import 'package:flutter/foundation.dart';

import 'state_error_handler.dart';
import 'state_exceptions.dart';

/// Mixin that provides error boundary functionality to state classes.
/// 
/// This mixin wraps state operations with error handling and recovery,
/// ensuring that errors are caught, logged, and handled gracefully.
mixin ErrorBoundary {
  /// The error handler instance for this state.
  StateErrorHandler? _errorHandler;

  /// Gets or creates the error handler for this state.
  StateErrorHandler get errorHandler {
    return _errorHandler ??= StateErrorHandler();
  }

  /// Sets a custom error handler for this state.
  set errorHandler(StateErrorHandler handler) {
    _errorHandler = handler;
  }

  /// Wraps an async operation with error boundary protection.
  /// 
  /// Automatically catches exceptions and attempts recovery using
  /// the configured error handler.
  Future<T> withErrorBoundary<T>(
    String operation,
    Future<T> Function() operationFunc, {
    String? stateKey,
    Type? valueType,
    Map<String, dynamic>? metadata,
    T? lastKnownValue,
    T? fallbackValue,
  }) async {
    try {
      return await errorHandler.withErrorBoundary<T>(
        operation,
        operationFunc,
        stateKey: stateKey ?? _getStateKey(),
        valueType: valueType ?? T,
        metadata: metadata,
      );
    } on StateException catch (error) {
      // Attempt recovery for StateExceptions
      final context = ErrorContext(
        stateKey: stateKey ?? _getStateKey(),
        operation: operation,
        valueType: valueType ?? T,
        metadata: metadata ?? {},
      );

      return await errorHandler.handleError<T>(
        error,
        context,
        lastKnownValue: lastKnownValue,
        fallbackValue: fallbackValue,
      );
    }
  }

  /// Wraps a synchronous operation with error boundary protection.
  T withErrorBoundarySync<T>(
    String operation,
    T Function() operationFunc, {
    String? stateKey,
    Type? valueType,
    Map<String, dynamic>? metadata,
    T? lastKnownValue,
    T? fallbackValue,
  }) {
    try {
      return errorHandler.withErrorBoundarySync<T>(
        operation,
        operationFunc,
        stateKey: stateKey ?? _getStateKey(),
        valueType: valueType ?? T,
        metadata: metadata,
      );
    } on StateException {
      // For sync operations, we can't do async recovery
      // So we either use fallback value or rethrow
      if (fallbackValue != null) {
        return fallbackValue;
      } else if (lastKnownValue != null) {
        return lastKnownValue;
      } else {
        rethrow;
      }
    }
  }

  /// Gets the state key for error context.
  /// Override this method to provide a meaningful state identifier.
  String? _getStateKey() {
    return runtimeType.toString();
  }
}

/// Mixin for states that need to handle serialization errors.
mixin SerializationErrorBoundary on ErrorBoundary {
  /// Wraps serialization operations with error handling.
  Future<Map<String, dynamic>> withSerializationBoundary(
    Future<Map<String, dynamic>> Function() serializeFunc, {
    Map<String, dynamic>? fallbackData,
  }) async {
    return await withErrorBoundary<Map<String, dynamic>>(
      'serialize',
      serializeFunc,
      valueType: Map<String, dynamic>,
      fallbackValue: fallbackData ?? {},
    );
  }

  /// Wraps deserialization operations with error handling.
  Future<T> withDeserializationBoundary<T>(
    Future<T> Function() deserializeFunc, {
    T? fallbackValue,
    T? lastKnownValue,
  }) async {
    return await withErrorBoundary<T>(
      'deserialize',
      deserializeFunc,
      valueType: T,
      fallbackValue: fallbackValue,
      lastKnownValue: lastKnownValue,
    );
  }
}

/// Mixin for states that need to handle persistence errors.
mixin PersistenceErrorBoundary on ErrorBoundary {
  /// Wraps save operations with error handling.
  Future<void> withSaveBoundary(
    Future<void> Function() saveFunc, {
    String? storageKey,
  }) async {
    await withErrorBoundary<void>(
      'save',
      saveFunc,
      metadata: {'storageKey': storageKey},
    );
  }

  /// Wraps load operations with error handling.
  Future<T?> withLoadBoundary<T>(
    Future<T?> Function() loadFunc, {
    String? storageKey,
    T? fallbackValue,
  }) async {
    return await withErrorBoundary<T?>(
      'load',
      loadFunc,
      valueType: T,
      metadata: {'storageKey': storageKey},
      fallbackValue: fallbackValue,
    );
  }

  /// Wraps delete operations with error handling.
  Future<void> withDeleteBoundary(
    Future<void> Function() deleteFunc, {
    String? storageKey,
  }) async {
    await withErrorBoundary<void>(
      'delete',
      deleteFunc,
      metadata: {'storageKey': storageKey},
    );
  }
}

/// Mixin for states that need to handle validation errors.
mixin ValidationErrorBoundary on ErrorBoundary {
  /// Wraps validation operations with error handling.
  Future<bool> withValidationBoundary(
    Future<bool> Function() validateFunc, {
    String? fieldName,
    bool fallbackResult = false,
  }) async {
    return await withErrorBoundary<bool>(
      'validate',
      validateFunc,
      metadata: {'fieldName': fieldName},
      fallbackValue: fallbackResult,
    );
  }

  /// Wraps type checking operations with error handling.
  bool withTypeCheckBoundary(
    bool Function() typeCheckFunc, {
    Type? expectedType,
    bool fallbackResult = false,
  }) {
    return withErrorBoundarySync<bool>(
      'typeCheck',
      typeCheckFunc,
      metadata: {'expectedType': expectedType?.toString()},
      fallbackValue: fallbackResult,
    );
  }
}

/// Mixin for states that need to handle network/API errors.
mixin NetworkErrorBoundary on ErrorBoundary {
  /// Wraps API call operations with error handling.
  Future<T> withApiCallBoundary<T>(
    Future<T> Function() apiCallFunc, {
    String? endpoint,
    T? fallbackValue,
    T? cachedValue,
  }) async {
    return await withErrorBoundary<T>(
      'apiCall',
      apiCallFunc,
      valueType: T,
      metadata: {'endpoint': endpoint},
      fallbackValue: fallbackValue,
      lastKnownValue: cachedValue,
    );
  }

  /// Wraps network request operations with error handling.
  Future<T> withNetworkBoundary<T>(
    Future<T> Function() networkFunc, {
    String? url,
    T? fallbackValue,
  }) async {
    return await withErrorBoundary<T>(
      'network',
      networkFunc,
      valueType: T,
      metadata: {'url': url},
      fallbackValue: fallbackValue,
    );
  }
}

/// Global error boundary for catching unhandled state errors.
class GlobalErrorBoundary {
  static StateErrorHandler? _globalHandler;

  /// Gets the global error handler.
  static StateErrorHandler get handler {
    return _globalHandler ??= StateErrorHandler();
  }

  /// Sets a custom global error handler.
  static set handler(StateErrorHandler errorHandler) {
    _globalHandler = errorHandler;
  }

  /// Handles uncaught state errors globally.
  static void handleUncaughtError(
    Object error,
    StackTrace stackTrace, {
    String? context,
  }) {
    if (error is StateException) {
      final errorContext = ErrorContext(
        operation: 'uncaught',
        metadata: {'context': context ?? 'unknown'},
        stackTrace: stackTrace,
      );

      // Log the error but don't attempt recovery for uncaught errors
      // Note: Using print as fallback since _log is private
      debugPrint('StateErrorHandler: Uncaught state error: ${error.message}');
      
      // Report error if reporting is enabled
      try {
        final config = handler.config;
        if (config.enableReporting && config.errorReporter != null) {
          config.errorReporter!(error, errorContext.toMap());
        }
      } catch (reportingError) {
        debugPrint('StateErrorHandler: Error reporting failed: $reportingError');
      }
    }
  }

  /// Initializes global error handling.
  static void initialize({StateErrorHandler? customHandler}) {
    if (customHandler != null) {
      _globalHandler = customHandler;
    }

    // Set up global error handling for uncaught errors
    // This would typically be done in the main app initialization
  }
}

/// Utility class for creating error contexts.
class ErrorContextBuilder {
  String? _stateKey;
  String? _operation;
  Type? _valueType;
  final Map<String, dynamic> _metadata = {};
  DateTime? _timestamp;
  StackTrace? _stackTrace;

  /// Sets the state key.
  ErrorContextBuilder stateKey(String key) {
    _stateKey = key;
    return this;
  }

  /// Sets the operation name.
  ErrorContextBuilder operation(String op) {
    _operation = op;
    return this;
  }

  /// Sets the value type.
  ErrorContextBuilder valueType(Type type) {
    _valueType = type;
    return this;
  }

  /// Adds metadata.
  ErrorContextBuilder metadata(String key, dynamic value) {
    _metadata[key] = value;
    return this;
  }

  /// Adds multiple metadata entries.
  ErrorContextBuilder metadataMap(Map<String, dynamic> data) {
    _metadata.addAll(data);
    return this;
  }

  /// Sets the timestamp.
  ErrorContextBuilder timestamp(DateTime time) {
    _timestamp = time;
    return this;
  }

  /// Sets the stack trace.
  ErrorContextBuilder stackTrace(StackTrace trace) {
    _stackTrace = trace;
    return this;
  }

  /// Builds the error context.
  ErrorContext build() {
    if (_operation == null) {
      throw ArgumentError('Operation is required for ErrorContext');
    }

    return ErrorContext(
      stateKey: _stateKey,
      operation: _operation!,
      valueType: _valueType,
      metadata: Map.unmodifiable(_metadata),
      timestamp: _timestamp,
      stackTrace: _stackTrace,
    );
  }
}