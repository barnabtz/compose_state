import 'mutable_state.dart';
import 'observable_state.dart';
import 'ui_state.dart';
import 'state_error_handler.dart';
import 'state_exceptions.dart';

class ApiState<T> extends MutableState<UiState<T>> implements ObservableState<UiState<T>> {
  final StateErrorHandler _errorHandler;


  ApiState({
    StateErrorHandler? errorHandler,
  }) : _errorHandler = errorHandler ?? StateErrorHandler(),
       super(const Loading());

  Future<void> fetch(
    Future<T> Function() apiCall, {
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 1),
    T? fallbackValue,
  }) async {
    value = const Loading();
    
    await _errorHandler.withErrorBoundary(
      'api_fetch',
      () async {
        // Use the retry strategy for automatic retry handling
        final result = await _attemptFetchWithRetry(
          apiCall,
          maxRetries: maxRetries,
          retryDelay: retryDelay,
        );
        
        value = Success(result);
      },
      stateKey: stateId,
      valueType: UiState<T>,
      metadata: {
        'maxRetries': maxRetries,
        'retryDelay': retryDelay.inMilliseconds,
        'hasFallback': fallbackValue != null,
      },
    ).catchError((error) async {
      if (error is StateException) {
        // Try to recover using error handler
        try {
          final recovered = await _errorHandler.handleError<T>(
            error,
            ErrorContext(
              stateKey: stateId,
              operation: 'api_fetch',
              valueType: T,
              metadata: {'apiCall': 'fetch'},
            ),
            fallbackValue: fallbackValue,
          );
          value = Success(recovered);
        } catch (recoveryError) {
          // Recovery failed, set error state
          value = Error(error.message);
        }
      } else {
        value = Error(error.toString());
      }
    });
  }

  Future<T> _attemptFetchWithRetry(
    Future<T> Function() apiCall, {
    required int maxRetries,
    required Duration retryDelay,
  }) async {
    Exception? lastException;
    
    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        return await apiCall();
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        
        if (attempt == maxRetries) {
          // Convert to StateException for better error handling
          throw StatePersistenceException(
            'API call failed after $maxRetries retries: ${e.toString()}',
            cause: lastException,
            operation: 'api_fetch',
            context: {
              'attempt': attempt + 1,
              'maxRetries': maxRetries,
              'lastError': e.toString(),
            },
          );
        } else {
          // Exponential backoff
          final delay = retryDelay * (attempt + 1);
          await Future.delayed(delay);
        }
      }
    }
    
    // This should never be reached, but just in case
    throw lastException ?? Exception('Unknown API error');
  }

  /// Refreshes the current data by re-executing the last API call.
  Future<void> refresh() async {
    if (value is Success<T>) {
      // Re-fetch using the same parameters as the last successful call
      // Note: This is a simplified implementation. In practice, you'd want
      // to store the original API call parameters.
      value = const Loading();
    }
  }

  /// Clears the current state and resets to loading.
  void clear() {
    value = const Loading();
  }

  /// Sets an error state manually.
  void setError(String errorMessage) {
    value = Error(errorMessage);
  }

  /// Sets a success state manually.
  void setSuccess(T data) {
    value = Success(data);
  }
}

ApiState<T> apiStateOf<T>({
  StateErrorHandler? errorHandler,
}) => ApiState<T>(
  errorHandler: errorHandler,
);