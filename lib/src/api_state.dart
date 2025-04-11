import 'mutable_state.dart';
import 'ui_state.dart';
import 'state_builder.dart';

class ApiState<T> extends MutableState<UiState<T>> implements ObservableState<UiState<T>> {
  ApiState() : super(const Loading());

  // Removed unnecessary override
  // @override
  // set value(UiState<T> newValue) => super.value = newValue;

  Future<void> fetch(Future<T> Function() apiCall) async {
    value = const Loading();
    try {
      value = Success(await apiCall());
    } catch (e) {
      value = Error(e.toString());
    }
  }
}

ApiState<T> apiStateOf<T>() => ApiState<T>();