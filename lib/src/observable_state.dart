import 'package:flutter/foundation.dart';

/// Represents a snapshot of state at a specific point in time.
class StateSnapshot<T> {
  final T value;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  const StateSnapshot(
    this.value, {
    required this.timestamp,
    this.metadata = const {},
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StateSnapshot<T> &&
          runtimeType == other.runtimeType &&
          value == other.value &&
          timestamp == other.timestamp;

  @override
  int get hashCode => Object.hash(value, timestamp);
}

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

  /// Whether this state has been disposed and is no longer usable.
  bool get isDisposed;

  /// Disposes of this state and releases any resources.
  /// 
  /// After calling dispose, this state should not be used anymore.
  void dispose();

  /// Checks if the given value is equal to the current state value.
  /// 
  /// This method can be overridden to provide custom equality logic,
  /// including deep equality for complex objects.
  bool equals(T other);

  /// Creates a snapshot of the current state.
  /// 
  /// The snapshot captures the current value and timestamp,
  /// and can include additional metadata.
  StateSnapshot<T> createSnapshot();

  /// Restores the state from a previously created snapshot.
  /// 
  /// This will update the current value to match the snapshot
  /// and notify listeners of the change.
  void restoreSnapshot(StateSnapshot<T> snapshot);
}