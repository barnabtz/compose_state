import 'package:flutter/material.dart';
import 'observable_state.dart';
import 'state_builder.dart';
import 'state_exceptions.dart';
import 'state_error_handler.dart';
import 'equality_checker.dart';
import 'testing/test_state_builder.dart';
import 'testing/state_change_tracker.dart';

/// Enhanced UI components with comprehensive error handling and testing support.
/// 
/// These components provide production-ready error boundaries, performance optimizations,
/// and testing-friendly interfaces for state-driven UI development.

/// Enhanced StateBuilder with comprehensive error handling and recovery.
class EnhancedStateBuilder<T> extends StatelessWidget {
  /// The state to observe and build from.
  final ObservableState<T> state;
  
  /// The builder function that creates the widget tree.
  final Widget Function(BuildContext, T) builder;
  
  /// Custom error builder for displaying error states.
  final Widget Function(BuildContext, StateException)? errorBuilder;
  
  /// Custom loading builder for async operations.
  final Widget Function(BuildContext)? loadingBuilder;
  
  /// Custom equality checker for performance optimization.
  final EqualityChecker<T>? equalityChecker;
  
  /// Whether to enable performance optimizations.
  final bool enableOptimizations;
  
  /// Whether to enable automatic disposal.
  final bool enableAutoDisposal;
  
  /// Whether to enable error boundaries.
  final bool enableErrorBoundary;
  
  /// Custom error handler.
  final StateErrorHandler? errorHandler;
  
  /// Key for identifying this builder in error contexts.
  final String? builderKey;
  
  /// Whether this is being used in a test environment.
  final bool isTestMode;
  
  /// Test-specific configuration.
  final TestConfiguration? testConfig;

  const EnhancedStateBuilder({
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
    this.isTestMode = false,
    this.testConfig,
  });

  @override
  Widget build(BuildContext context) {
    if (isTestMode && testConfig != null) {
      return TestStateBuilder<T>(
        state: state,
        builder: builder,
        errorBuilder: errorBuilder,
        equalityChecker: equalityChecker,
        enableAutoRebuild: testConfig!.enableAutoRebuild,
        enableChangeTracking: testConfig!.enableChangeTracking,
        testKey: testConfig!.testKey,
        changeTracker: testConfig!.changeTracker,
      );
    }

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
}

/// Configuration for test mode behavior.
class TestConfiguration {
  final bool enableAutoRebuild;
  final bool enableChangeTracking;
  final String? testKey;
  final StateChangeTracker? changeTracker;

  const TestConfiguration({
    this.enableAutoRebuild = true,
    this.enableChangeTracking = true,
    this.testKey,
    this.changeTracker,
  });
}

/// Enhanced state-driven form field with comprehensive error handling.
class StateFormField<T> extends StatelessWidget {
  /// The state that holds the field value.
  final ObservableState<T> state;
  
  /// Function to convert the state value to a string for display.
  final String Function(T) valueToString;
  
  /// Function to parse user input back to the state type.
  final T Function(String) parseValue;
  
  /// Validation function for the field.
  final String? Function(T?)? validator;
  
  /// Label for the form field.
  final String? label;
  
  /// Hint text for the form field.
  final String? hint;
  
  /// Whether the field is enabled.
  final bool enabled;
  
  /// Custom error handler for validation errors.
  final StateErrorHandler? errorHandler;
  
  /// Custom decoration for the field.
  final InputDecoration? decoration;
  
  /// Text input type.
  final TextInputType? keyboardType;
  
  /// Whether to obscure the text (for passwords).
  final bool obscureText;
  
  /// Maximum number of lines.
  final int? maxLines;

  const StateFormField({
    super.key,
    required this.state,
    required this.valueToString,
    required this.parseValue,
    this.validator,
    this.label,
    this.hint,
    this.enabled = true,
    this.errorHandler,
    this.decoration,
    this.keyboardType,
    this.obscureText = false,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return EnhancedStateBuilder<T>(
      state: state,
      errorHandler: errorHandler,
      builder: (context, value) {
        return TextFormField(
          initialValue: valueToString(value),
          enabled: enabled,
          obscureText: obscureText,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: decoration ?? InputDecoration(
            labelText: label,
            hintText: hint,
            border: const OutlineInputBorder(),
          ),
          validator: validator != null ? (text) => validator!(value) : null,
          onChanged: (text) {
            try {
              final newValue = parseValue(text);
              state.value = newValue;
            } catch (error) {
              // Handle parsing errors gracefully
              if (errorHandler != null) {
                final stateError = StateValidationException(
                  'Failed to parse input: $error',
                  cause: error,
                  violatedRule: 'input_parsing',
                  actualValue: text,
                );
                
                // Log the error but don't crash the UI
                errorHandler!.withErrorBoundarySync(
                  'parseInput',
                  () => throw stateError,
                  stateKey: 'StateFormField',
                );
              }
            }
          },
        );
      },
      errorBuilder: (context, error) => _buildFieldErrorWidget(context, error),
    );
  }

  Widget _buildFieldErrorWidget(BuildContext context, StateException error) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          enabled: false,
          decoration: (decoration ?? InputDecoration(
            labelText: label,
            hintText: hint,
            border: const OutlineInputBorder(),
          )).copyWith(
            errorText: 'Field Error',
            errorBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.red, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            border: Border.all(color: Colors.red.shade200),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade700, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  error.message,
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Enhanced state-driven list view with error handling and performance optimization.
class StateListView<T> extends StatelessWidget {
  /// The state that holds the list data.
  final ObservableState<List<T>> listState;
  
  /// Builder function for individual list items.
  final Widget Function(BuildContext, T, int) itemBuilder;
  
  /// Optional builder for empty state.
  final Widget Function(BuildContext)? emptyBuilder;
  
  /// Optional builder for loading state.
  final Widget Function(BuildContext)? loadingBuilder;
  
  /// Optional builder for error state.
  final Widget Function(BuildContext, StateException)? errorBuilder;
  
  /// Custom equality checker for list optimization.
  final EqualityChecker<List<T>>? equalityChecker;
  
  /// Whether to enable performance optimizations.
  final bool enableOptimizations;
  
  /// Custom error handler.
  final StateErrorHandler? errorHandler;
  
  /// Scroll controller for the list.
  final ScrollController? controller;
  
  /// Scroll physics for the list.
  final ScrollPhysics? physics;
  
  /// Whether to shrink wrap the list.
  final bool shrinkWrap;
  
  /// Padding for the list.
  final EdgeInsetsGeometry? padding;

  const StateListView({
    super.key,
    required this.listState,
    required this.itemBuilder,
    this.emptyBuilder,
    this.loadingBuilder,
    this.errorBuilder,
    this.equalityChecker,
    this.enableOptimizations = true,
    this.errorHandler,
    this.controller,
    this.physics,
    this.shrinkWrap = false,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return EnhancedStateBuilder<List<T>>(
      state: listState,
      equalityChecker: equalityChecker,
      enableOptimizations: enableOptimizations,
      errorHandler: errorHandler,
      builder: (context, items) {
        if (items.isEmpty) {
          return emptyBuilder?.call(context) ?? _buildDefaultEmptyWidget(context);
        }

        return ListView.builder(
          controller: controller,
          physics: physics,
          shrinkWrap: shrinkWrap,
          padding: padding,
          itemCount: items.length,
          itemBuilder: (context, index) {
            if (index >= items.length) {
              return const SizedBox.shrink();
            }
            
            try {
              return itemBuilder(context, items[index], index);
            } catch (error) {
              return _buildItemErrorWidget(context, error, index);
            }
          },
        );
      },
      errorBuilder: errorBuilder ?? (context, error) => _buildListErrorWidget(context, error),
      loadingBuilder: loadingBuilder,
    );
  }

  Widget _buildDefaultEmptyWidget(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No items to display',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemErrorWidget(BuildContext context, Object error, int index) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border.all(color: Colors.red.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Error in item $index',
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  error.toString(),
                  style: TextStyle(
                    color: Colors.red.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListErrorWidget(BuildContext context, StateException error) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          border: Border.all(color: Colors.red.shade200),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade700, size: 48),
            const SizedBox(height: 16),
            Text(
              'List Error',
              style: TextStyle(
                color: Colors.red.shade700,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.red.shade600,
                fontSize: 14,
              ),
            ),
            if (error.context.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Context: ${error.context}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Enhanced state-driven button with loading and error states.
class StateButton<T> extends StatelessWidget {
  /// The state that controls the button behavior.
  final ObservableState<T> state;
  
  /// Function to determine if the button should be enabled.
  final bool Function(T) isEnabled;
  
  /// Function to determine if the button should show loading.
  final bool Function(T) isLoading;
  
  /// Function to determine if there's an error state.
  final bool Function(T) hasError;
  
  /// The button's child widget.
  final Widget child;
  
  /// Callback when the button is pressed.
  final VoidCallback? onPressed;
  
  /// Custom loading widget.
  final Widget? loadingWidget;
  
  /// Custom error widget.
  final Widget? errorWidget;
  
  /// Button style.
  final ButtonStyle? style;
  
  /// Custom error handler.
  final StateErrorHandler? errorHandler;

  const StateButton({
    super.key,
    required this.state,
    required this.isEnabled,
    required this.isLoading,
    required this.hasError,
    required this.child,
    this.onPressed,
    this.loadingWidget,
    this.errorWidget,
    this.style,
    this.errorHandler,
  });

  @override
  Widget build(BuildContext context) {
    return EnhancedStateBuilder<T>(
      state: state,
      errorHandler: errorHandler,
      builder: (context, value) {
        final enabled = isEnabled(value);
        final loading = isLoading(value);
        final error = hasError(value);

        Widget buttonChild = child;
        
        if (loading) {
          buttonChild = loadingWidget ?? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 8),
              child,
            ],
          );
        } else if (error) {
          buttonChild = errorWidget ?? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 16),
              const SizedBox(width: 8),
              child,
            ],
          );
        }

        return ElevatedButton(
          onPressed: enabled && !loading ? onPressed : null,
          style: style?.copyWith(
            backgroundColor: error 
                ? WidgetStateProperty.all(Colors.red.shade400)
                : style?.backgroundColor,
          ) ?? (error 
              ? ElevatedButton.styleFrom(backgroundColor: Colors.red.shade400)
              : null),
          child: buttonChild,
        );
      },
    );
  }
}

/// Factory functions for creating enhanced UI components.

/// Creates an enhanced state builder with sensible defaults.
Widget buildEnhancedState<T>(
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
  bool isTestMode = false,
  TestConfiguration? testConfig,
}) {
  return EnhancedStateBuilder<T>(
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
    isTestMode: isTestMode,
    testConfig: testConfig,
  );
}

/// Creates a state-driven form field with validation.
Widget buildStateFormField<T>(
  ObservableState<T> state,
  String Function(T) valueToString,
  T Function(String) parseValue, {
  String? Function(T?)? validator,
  String? label,
  String? hint,
  bool enabled = true,
  StateErrorHandler? errorHandler,
  InputDecoration? decoration,
  TextInputType? keyboardType,
  bool obscureText = false,
  int? maxLines = 1,
}) {
  return StateFormField<T>(
    state: state,
    valueToString: valueToString,
    parseValue: parseValue,
    validator: validator,
    label: label,
    hint: hint,
    enabled: enabled,
    errorHandler: errorHandler,
    decoration: decoration,
    keyboardType: keyboardType,
    obscureText: obscureText,
    maxLines: maxLines,
  );
}

/// Creates a state-driven list view with error handling.
Widget buildStateListView<T>(
  ObservableState<List<T>> listState,
  Widget Function(BuildContext, T, int) itemBuilder, {
  Widget Function(BuildContext)? emptyBuilder,
  Widget Function(BuildContext)? loadingBuilder,
  Widget Function(BuildContext, StateException)? errorBuilder,
  EqualityChecker<List<T>>? equalityChecker,
  bool enableOptimizations = true,
  StateErrorHandler? errorHandler,
  ScrollController? controller,
  ScrollPhysics? physics,
  bool shrinkWrap = false,
  EdgeInsetsGeometry? padding,
}) {
  return StateListView<T>(
    listState: listState,
    itemBuilder: itemBuilder,
    emptyBuilder: emptyBuilder,
    loadingBuilder: loadingBuilder,
    errorBuilder: errorBuilder,
    equalityChecker: equalityChecker,
    enableOptimizations: enableOptimizations,
    errorHandler: errorHandler,
    controller: controller,
    physics: physics,
    shrinkWrap: shrinkWrap,
    padding: padding,
  );
}

/// Creates a state-driven button with loading and error states.
Widget buildStateButton<T>(
  ObservableState<T> state,
  bool Function(T) isEnabled,
  bool Function(T) isLoading,
  bool Function(T) hasError,
  Widget child, {
  VoidCallback? onPressed,
  Widget? loadingWidget,
  Widget? errorWidget,
  ButtonStyle? style,
  StateErrorHandler? errorHandler,
}) {
  return StateButton<T>(
    state: state,
    isEnabled: isEnabled,
    isLoading: isLoading,
    hasError: hasError,
    onPressed: onPressed,
    loadingWidget: loadingWidget,
    errorWidget: errorWidget,
    style: style,
    errorHandler: errorHandler,
    child: child,
  );
}