import 'mutable_state.dart';
import 'ui_state.dart';

class ApiState<T> extends MutableState<UiState<T>> {
  ApiState() : super(const Loading());

  Future<void> fetch(Future<T> Function() apiCall) async {
    value = const Loading();
    try {
      value = Success(await apiCall());
    } catch (e) {
      value = Error(e.toString());
    }
  }

  @override
  void dispose() => super.dispose();
}

ApiState<T> apiStateOf<T>() => ApiState<T>();