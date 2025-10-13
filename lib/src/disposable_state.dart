import 'package:flutter/foundation.dart';

/// A mixin that provides automatic resource cleanup capabilities for state objects.
/// 
/// This mixin tracks listeners and provides mechanisms for automatic disposal
/// when the state is no longer needed, helping prevent memory leaks.
mixin DisposableState on ChangeNotifier {
  bool _isDisposed = false;
  final Set<VoidCallback> _listeners = <VoidCallback>{};

  /// Whether this state has been disposed.
  bool get isDisposed => _isDisposed;

  @override
  void addListener(VoidCallback listener) {
    if (_isDisposed) {
      throw StateError('Cannot add listener to disposed state');
    }
    _listeners.add(listener);
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
    super.removeListener(listener);
  }

  /// Disposes of this state and all its resources.
  /// 
  /// This method removes all listeners and marks the state as disposed.
  /// After calling dispose, this state should not be used anymore.
  @override
  void dispose() {
    if (_isDisposed) return;
    
    _isDisposed = true;
    
    // Remove all tracked listeners
    for (final listener in _listeners.toList()) {
      super.removeListener(listener);
    }
    _listeners.clear();
    
    super.dispose();
  }

  /// Throws a [StateError] if this state has been disposed.
  void checkNotDisposed() {
    if (_isDisposed) {
      throw StateError('State has been disposed and cannot be used');
    }
  }
}