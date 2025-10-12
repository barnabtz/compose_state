import 'mutable_state.dart';
import 'observable_state.dart';
import 'ui_state.dart';

class ApiState<T> extends MutableState<UiState<T>> implements ObservableState<UiState<T>> {
  ApiState() : super(const Loading());

  Future<void> fetch(
    Future<T> Function() apiCall, {
    int maxRetries = 0,
    Duration retryDelay = const Duration(seconds: 1),
  }) async {
    value = const Loading();
    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        value = Success(await apiCall());
        return;
      } catch (e) {
        if (attempt == maxRetries) {
          value = Error(e.toString());
        } else {
          await Future.delayed(retryDelay * (attempt + 1)); // Exponential backoff
        }
      }
    }
  }
}

ApiState<T> apiStateOf<T>() => ApiState<T>();