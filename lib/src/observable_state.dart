import 'package:flutter/foundation.dart';

/// Base interface for all observable state types in the compose_state package.
/// 
/// This interface extends Flutter's [Listenable] to provide change notification
/// capabilities and defines the contract for accessing and modifying state values.
/// 
/// All state implementations should implement this interface to ensure
/// consistent behavior and enable polymorphic usage.
abstract interface class ObservableState<T> extends Listenable {
  /// The current value of the state.
  T get value;
  
  /// Sets a new value for the state.
  /// 
  /// Implementations should notify listeners when the value changes.
  set value(T newValue);
}