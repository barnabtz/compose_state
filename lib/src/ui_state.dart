import 'package:flutter/widgets.dart';
import 'state_builder.dart';

sealed class UiState<T> {
  const UiState();
}

class Loading<T> extends UiState<T> {
  const Loading();
}

class Success<T> extends UiState<T> {
  final T data;
  const Success(this.data);
}

class Error<T> extends UiState<T> {
  final String message;
  const Error(this.message);
}

class UiStateBuilder<T> extends StatelessWidget {
  final ObservableState<UiState<T>> state; // Changed from MutableState<UiState<T>>
  final Widget Function(BuildContext) loading;
  final Widget Function(BuildContext, T) success;
  final Widget Function(BuildContext, String) error;

  const UiStateBuilder({
    super.key,
    required this.state,
    required this.loading,
    required this.success,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    return StateBuilder<UiState<T>>(
      state: state,
      builder: (context, value) {
        return switch (value) {
          Loading() => loading(context),
          Success(:final data) => success(context, data),
          Error(:final message) => error(context, message),
        };
      },
    );
  }
}