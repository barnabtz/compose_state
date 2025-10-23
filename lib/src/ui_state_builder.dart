import 'package:flutter/material.dart';
import 'ui_state.dart';
import 'observable_state.dart';
import 'state_error_handler.dart';
import 'state_exceptions.dart';
import 'error_boundary.dart';

/// A builder widget that handles UiState pattern matching.
///
/// This widget eliminates the need for nested StateBuilders by providing
/// a single state that represents the entire UI state (loading, error, success).
class UiStateBuilder<T> extends StatefulWidget {
  /// The UI state to observe.
  final ObservableState<UiState<T>> state;

  /// Builder function for loading state.
  final Widget Function(BuildContext context)? loadingBuilder;

  /// Builder function for error state.
  final Widget Function(BuildContext context, String error)? errorBuilder;

  /// Builder function for success state.
  final Widget Function(BuildContext context, T data) successBuilder;

  /// Builder function for empty state.
  final Widget Function(BuildContext context)? emptyBuilder;

  /// Fallback builder when no specific builder is provided.
  final Widget Function(BuildContext context, UiState<T> state)?
  fallbackBuilder;

  /// Whether to enable error boundaries.
  final bool enableErrorBoundary;

  /// Custom error handler.
  final StateErrorHandler? errorHandler;

  /// Key for identifying this builder.
  final String? builderKey;

  const UiStateBuilder({
    super.key,
    required this.state,
    required this.successBuilder,
    this.loadingBuilder,
    this.errorBuilder,
    this.emptyBuilder,
    this.fallbackBuilder,
    this.enableErrorBoundary = true,
    this.errorHandler,
    this.builderKey,
  });

  @override
  State<UiStateBuilder<T>> createState() => _UiStateBuilderState<T>();
}

class _UiStateBuilderState<T> extends State<UiStateBuilder<T>>
    with ErrorBoundary {
  late UiState<T> _currentState;
  StateException? _currentError;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();

    if (widget.errorHandler != null) {
      errorHandler = widget.errorHandler!;
    }

    _initializeState();
    widget.state.addListener(_onStateChanged);
  }

  void _initializeState() {
    try {
      _currentState = widget.state.value;
      _currentError = null;
      _isInitialized = true;
    } catch (error) {
      _currentError =
          error is StateException
              ? error
              : StateValidationException(
                'Failed to initialize UI state: $error',
                cause: error,
                violatedRule: 'ui_state_initialization',
              );
    }
  }

  void _onStateChanged() {
    if (!mounted) return;

    try {
      final newState = widget.state.value;
      setState(() {
        _currentState = newState;
        _currentError = null;
      });
    } catch (error) {
      setState(() {
        _currentError =
            error is StateException
                ? error
                : StateValidationException(
                  'Error updating UI state: $error',
                  cause: error,
                  violatedRule: 'ui_state_update',
                );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const SizedBox.shrink();
    }

    if (_currentError != null) {
      return _buildErrorWidget(context, _currentError!);
    }

    return _currentState.when(
      loading: () => _buildLoadingWidget(context),
      error: (error) => _buildErrorWidget(context, error),
      success: (data) => _buildSuccessWidget(context, data),
      empty: () => _buildEmptyWidget(context),
    );
  }

  Widget _buildLoadingWidget(BuildContext context) {
    if (widget.loadingBuilder != null) {
      return widget.loadingBuilder!(context);
    }
    return _buildDefaultLoadingWidget(context);
  }

  Widget _buildErrorWidget(BuildContext context, dynamic error) {
    if (error is String && widget.errorBuilder != null) {
      return widget.errorBuilder!(context, error);
    }
    return _buildDefaultErrorWidget(context, error);
  }

  Widget _buildSuccessWidget(BuildContext context, T data) {
    return widget.successBuilder(context, data);
  }

  Widget _buildEmptyWidget(BuildContext context) {
    if (widget.emptyBuilder != null) {
      return widget.emptyBuilder!(context);
    }
    return _buildDefaultEmptyWidget(context);
  }

  Widget _buildDefaultLoadingWidget(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildDefaultErrorWidget(BuildContext context, dynamic error) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        border: Border.all(color: const Color(0xFFE57373)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.error_outline, color: Color(0xFFD32F2F), size: 20),
              SizedBox(width: 8),
              Text(
                'Error',
                style: TextStyle(
                  color: Color(0xFFD32F2F),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            error is String ? error : error.toString(),
            style: const TextStyle(color: Color(0xFFD32F2F), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultEmptyWidget(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox, size: 48, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No data available',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    widget.state.removeListener(_onStateChanged);
    super.dispose();
  }
}

/// Convenience function to create a UiStateBuilder.
Widget buildUiState<T>(
  ObservableState<UiState<T>> state, {
  required Widget Function(BuildContext context, T data) successBuilder,
  Widget Function(BuildContext context)? loadingBuilder,
  Widget Function(BuildContext context, String error)? errorBuilder,
  Widget Function(BuildContext context)? emptyBuilder,
  Widget Function(BuildContext context, UiState<T> state)? fallbackBuilder,
  bool enableErrorBoundary = true,
  StateErrorHandler? errorHandler,
  String? builderKey,
}) {
  return UiStateBuilder<T>(
    state: state,
    successBuilder: successBuilder,
    loadingBuilder: loadingBuilder,
    errorBuilder: errorBuilder,
    emptyBuilder: emptyBuilder,
    fallbackBuilder: fallbackBuilder,
    enableErrorBoundary: enableErrorBoundary,
    errorHandler: errorHandler,
    builderKey: builderKey,
  );
}

/// Extension methods for UiStateBuilder to provide convenient constructors.
extension UiStateBuilderExtensions<T> on ObservableState<UiState<T>> {
  /// Creates a UiStateBuilder for this UI state.
  UiStateBuilder<T> build({
    required Widget Function(BuildContext context, T data) successBuilder,
    Widget Function(BuildContext context)? loadingBuilder,
    Widget Function(BuildContext context, String error)? errorBuilder,
    Widget Function(BuildContext context)? emptyBuilder,
    Widget Function(BuildContext context, UiState<T> state)? fallbackBuilder,
    bool enableErrorBoundary = true,
    StateErrorHandler? errorHandler,
    String? builderKey,
  }) {
    return UiStateBuilder<T>(
      state: this,
      successBuilder: successBuilder,
      loadingBuilder: loadingBuilder,
      errorBuilder: errorBuilder,
      emptyBuilder: emptyBuilder,
      fallbackBuilder: fallbackBuilder,
      enableErrorBoundary: enableErrorBoundary,
      errorHandler: errorHandler,
      builderKey: builderKey,
    );
  }
}
