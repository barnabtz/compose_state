import 'package:flutter/material.dart';
import 'observable_state.dart';
import 'disposable_state.dart';
import 'equality_checker.dart';
import 'error_boundary.dart';
import 'state_error_handler.dart';
import 'state_exceptions.dart';
import 'state_lifecycle_manager.dart';

/// Enhanced StateBuilder with automatic disposal, error boundaries, and performance optimizations.
/// 
/// This builder provides comprehensive error handling, automatic resource cleanup,
/// and performance optimizations to reduce unnecessary rebuilds.
class StateBuilder<T> extends StatefulWidget {
  /// The state to observe and build from.
  final ObservableState<T> state;
  
  /// The builder function that creates the widget tree.
  final Widget Function(BuildContext, T) builder;
  
  /// Optional error builder for displaying error states.
  final Widget Function(BuildContext, StateException)? errorBuilder;
  
  /// Optional loading builder for async operations.
  final Widget Function(BuildContext)? loadingBuilder;
  
  /// Custom equality checker for performance optimization.
  final EqualityChecker<T>? equalityChecker;
  
  /// Whether to enable performance optimizations.
  final bool enableOptimizations;
  
  /// Whether to enable automatic disposal of the state when the widget is disposed.
  final bool enableAutoDisposal;
  
  /// Whether to enable error boundaries for state operations.
  final bool enableErrorBoundary;
  
  /// Custom error handler for this builder.
  final StateErrorHandler? errorHandler;
  
  /// Key for identifying this builder in error contexts.
  final String? builderKey;

  const StateBuilder({
    super.key,
    required this.state,
    required this.builder,
    this.errorBuilder,
    this.loadingBuilder,
    this.equalityChecker,
    this.enableOptimizations = true,
    this.enableAutoDisposal = true,
    this.enableErrorBoundary = true,
    this.errorHandler,
    this.builderKey,
  });

  @override
  State<StateBuilder<T>> createState() => _StateBuilderState<T>();
}

class _StateBuilderState<T> extends State<StateBuilder<T>> with ErrorBoundary {
  late T _currentValue;
  late EqualityChecker<T> _equalityChecker;
  StateException? _currentError;
  bool _isLoading = false;
  int _buildCount = 0;
  int _skippedBuilds = 0;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize equality checker
    _equalityChecker = widget.equalityChecker ?? EqualityChecker<T>();
    
    // Set custom error handler if provided
    if (widget.errorHandler != null) {
      errorHandler = widget.errorHandler!;
    }
    
    // Initialize current value with error handling
    _initializeValue();
    
    // Add listener to state
    widget.state.addListener(_onStateChanged);
    
    // Register with lifecycle manager for automatic disposal
    if (widget.enableAutoDisposal) {
      StateLifecycleManager.instance.trackState(widget.state, name: widget.builderKey);
    }
  }

  @override
  void didUpdateWidget(StateBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Handle state changes
    if (oldWidget.state != widget.state) {
      oldWidget.state.removeListener(_onStateChanged);
      widget.state.addListener(_onStateChanged);
      
      // Update lifecycle manager registration
      if (widget.enableAutoDisposal) {
        if (oldWidget.builderKey != null) {
          StateLifecycleManager.instance.untrackState(oldWidget.builderKey!);
        }
        StateLifecycleManager.instance.trackState(widget.state, name: widget.builderKey);
      }
      
      _initializeValue();
    }
    
    // Update equality checker if changed
    if (oldWidget.equalityChecker != widget.equalityChecker) {
      _equalityChecker = widget.equalityChecker ?? EqualityChecker<T>();
    }
    
    // Update error handler if changed
    if (oldWidget.errorHandler != widget.errorHandler && widget.errorHandler != null) {
      errorHandler = widget.errorHandler!;
    }
  }

  @override
  void dispose() {
    // Remove listener
    widget.state.removeListener(_onStateChanged);
    
    // Unregister from lifecycle manager
    if (widget.enableAutoDisposal && widget.builderKey != null) {
      StateLifecycleManager.instance.untrackState(widget.builderKey!);
      
      // Auto-dispose state if it's disposable and no longer referenced
      if (widget.state is DisposableState) {
        final disposableState = widget.state as DisposableState;
        if (!disposableState.isDisposed) {
          // Check if state can be disposed by looking at lifecycle stats
          final stats = StateLifecycleManager.instance.getLifecycleStats();
          if (stats.unusedStates > 0) {
            disposableState.dispose();
          }
        }
      }
    }
    
    super.dispose();
  }

  void _initializeValue() {
    if (widget.enableErrorBoundary) {
      try {
        _currentValue = withErrorBoundarySync<T>(
          'getValue',
          () => widget.state.value,
          stateKey: widget.builderKey ?? widget.state.runtimeType.toString(),
          valueType: T,
        );
        _currentError = null;
      } catch (error) {
        if (error is StateException) {
          _currentError = error;
        } else {
          _currentError = StateValidationException(
            'Failed to get initial state value: $error',
            cause: error,
            violatedRule: 'initial_value_access',
          );
        }
      }
    } else {
      _currentValue = widget.state.value;
      _currentError = null;
    }
  }

  void _onStateChanged() {
    if (!mounted) return;

    if (widget.enableErrorBoundary) {
      _handleStateChangeWithErrorBoundary();
    } else {
      _handleStateChangeBasic();
    }
  }

  void _handleStateChangeWithErrorBoundary() {
    try {
      final newValue = withErrorBoundarySync<T>(
        'getValue',
        () => widget.state.value,
        stateKey: widget.builderKey ?? widget.state.runtimeType.toString(),
        valueType: T,
      );
      
      // Use equality checker to avoid unnecessary rebuilds
      if (widget.enableOptimizations && 
          _currentError == null && 
          _equalityChecker.equals(_currentValue, newValue)) {
        _skippedBuilds++;
        return;
      }

      setState(() {
        _currentValue = newValue;
        _currentError = null;
        _buildCount++;
      });
    } catch (error) {
      setState(() {
        if (error is StateException) {
          _currentError = error;
        } else {
          _currentError = StateValidationException(
            'Failed to get state value: $error',
            cause: error,
            violatedRule: 'value_access',
          );
        }
        _buildCount++;
      });
    }
  }

  void _handleStateChangeBasic() {
    final newValue = widget.state.value;
    
    // Use equality checker to avoid unnecessary rebuilds
    if (widget.enableOptimizations && 
        _equalityChecker.equals(_currentValue, newValue)) {
      _skippedBuilds++;
      return;
    }

    setState(() {
      _currentValue = newValue;
      _buildCount++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Handle error state
    if (_currentError != null) {
      if (widget.errorBuilder != null) {
        return widget.errorBuilder!(context, _currentError!);
      } else {
        return _buildDefaultErrorWidget(context, _currentError!);
      }
    }
    
    // Handle loading state
    if (_isLoading) {
      if (widget.loadingBuilder != null) {
        return widget.loadingBuilder!(context);
      } else {
        return _buildDefaultLoadingWidget(context);
      }
    }
    
    // Build normal state
    try {
      if (widget.enableErrorBoundary) {
        return withErrorBoundarySync<Widget>(
          'build',
          () => widget.builder(context, _currentValue),
          stateKey: widget.builderKey ?? widget.state.runtimeType.toString(),
          valueType: Widget,
        );
      } else {
        return widget.builder(context, _currentValue);
      }
    } catch (error) {
      final stateError = error is StateException 
          ? error 
          : StateValidationException(
              'Builder function failed: $error',
              cause: error,
              violatedRule: 'builder_execution',
            );
      
      if (widget.errorBuilder != null) {
        return widget.errorBuilder!(context, stateError);
      } else {
        return _buildDefaultErrorWidget(context, stateError);
      }
    }
  }

  Widget _buildDefaultErrorWidget(BuildContext context, StateException error) {
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
              Icon(
                Icons.error_outline,
                color: Color(0xFFD32F2F),
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'State Error',
                style: TextStyle(
                  color: Color(0xFFD32F2F),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            error.message,
            style: const TextStyle(
              color: Color(0xFFD32F2F),
              fontSize: 12,
            ),
          ),
          if (error.context.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Context: ${error.context}',
              style: const TextStyle(
                color: Color(0xFF757575),
                fontSize: 10,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDefaultLoadingWidget(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  /// Gets performance statistics for this builder.
  Map<String, dynamic> getPerformanceStats() {
    return {
      'buildCount': _buildCount,
      'skippedBuilds': _skippedBuilds,
      'optimizationsEnabled': widget.enableOptimizations,
      'autoDisposalEnabled': widget.enableAutoDisposal,
      'errorBoundaryEnabled': widget.enableErrorBoundary,
      'stateType': widget.state.runtimeType.toString(),
      'hasError': _currentError != null,
      'isLoading': _isLoading,
      'equalityStats': _equalityChecker.getCacheStats(),
    };
  }

  /// Manually triggers a rebuild (useful for testing).
  void forceRebuild() {
    if (mounted) {
      setState(() {
        _buildCount++;
      });
    }
  }

  /// Gets the current error, if any.
  StateException? get currentError => _currentError;

  /// Sets the loading state (useful for async operations).
  void setLoading(bool loading) {
    if (mounted && _isLoading != loading) {
      setState(() {
        _isLoading = loading;
      });
    }
  }
}

/// Convenience function to create a StateBuilder with common configurations.
Widget buildState<T>(
  ObservableState<T> state,
  Widget Function(BuildContext, T) builder, {
  Widget Function(BuildContext, StateException)? errorBuilder,
  Widget Function(BuildContext)? loadingBuilder,
  EqualityChecker<T>? equalityChecker,
  bool enableOptimizations = true,
  bool enableAutoDisposal = true,
  bool enableErrorBoundary = true,
  StateErrorHandler? errorHandler,
  String? builderKey,
}) {
  return StateBuilder<T>(
    state: state,
    builder: builder,
    errorBuilder: errorBuilder,
    loadingBuilder: loadingBuilder,
    equalityChecker: equalityChecker,
    enableOptimizations: enableOptimizations,
    enableAutoDisposal: enableAutoDisposal,
    enableErrorBoundary: enableErrorBoundary,
    errorHandler: errorHandler,
    builderKey: builderKey,
  );
}