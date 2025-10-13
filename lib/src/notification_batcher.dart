import 'dart:async';
import 'package:flutter/scheduler.dart';

/// Strategy for batching notifications.
enum BatchingStrategy {
  /// Batch notifications within the same frame
  frame,
  /// Batch notifications with a fixed delay
  delayed,
  /// Batch notifications with debouncing (reset timer on new notifications)
  debounced,
  /// No batching - immediate notifications
  immediate,
}

/// Configuration for notification batching behavior.
class BatchingConfig {
  final BatchingStrategy strategy;
  final Duration delay;
  final int maxBatchSize;
  final bool enableFrameAlignment;

  const BatchingConfig({
    this.strategy = BatchingStrategy.frame,
    this.delay = const Duration(milliseconds: 16), // ~60fps
    this.maxBatchSize = 100,
    this.enableFrameAlignment = true,
  });

  /// Default configuration optimized for UI performance.
  static const defaultConfig = BatchingConfig();

  /// Configuration for immediate notifications (no batching).
  static const immediateConfig = BatchingConfig(
    strategy: BatchingStrategy.immediate,
  );

  /// Configuration for debounced notifications.
  static const debouncedConfig = BatchingConfig(
    strategy: BatchingStrategy.debounced,
    delay: Duration(milliseconds: 50),
  );
}

/// A notification batcher that reduces unnecessary widget rebuilds
/// by batching multiple state changes together.
class NotificationBatcher {
  final BatchingConfig _config;
  final Set<VoidCallback> _pendingNotifications = {};
  Timer? _batchTimer;
  bool _isScheduled = false;

  NotificationBatcher([this._config = BatchingConfig.defaultConfig]);

  /// Schedules a notification to be batched.
  /// 
  /// [callback] - The notification callback to execute
  /// [priority] - Optional priority for ordering notifications
  void scheduleNotification(VoidCallback callback, {int priority = 0}) {
    switch (_config.strategy) {
      case BatchingStrategy.immediate:
        callback();
        break;
      case BatchingStrategy.frame:
        _scheduleFrameNotification(callback);
        break;
      case BatchingStrategy.delayed:
        _scheduleDelayedNotification(callback);
        break;
      case BatchingStrategy.debounced:
        _scheduleDebouncedNotification(callback);
        break;
    }
  }

  /// Schedules notification for the next frame.
  void _scheduleFrameNotification(VoidCallback callback) {
    _pendingNotifications.add(callback);
    
    if (!_isScheduled) {
      _isScheduled = true;
      if (_config.enableFrameAlignment) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          _flushNotifications();
        });
      } else {
        SchedulerBinding.instance.scheduleFrameCallback((_) {
          _flushNotifications();
        });
      }
    }
  }

  /// Schedules notification with a fixed delay.
  void _scheduleDelayedNotification(VoidCallback callback) {
    _pendingNotifications.add(callback);
    
    if (_batchTimer == null || !_batchTimer!.isActive) {
      _batchTimer = Timer(_config.delay, () {
        _flushNotifications();
      });
    }
  }

  /// Schedules notification with debouncing.
  void _scheduleDebouncedNotification(VoidCallback callback) {
    _pendingNotifications.add(callback);
    
    // Cancel existing timer and start a new one
    _batchTimer?.cancel();
    _batchTimer = Timer(_config.delay, () {
      _flushNotifications();
    });
  }

  /// Flushes all pending notifications.
  void _flushNotifications() {
    if (_pendingNotifications.isEmpty) {
      _isScheduled = false;
      return;
    }

    // Create a copy to avoid concurrent modification
    final notifications = List<VoidCallback>.from(_pendingNotifications);
    _pendingNotifications.clear();
    _isScheduled = false;

    // Execute all notifications
    for (final notification in notifications) {
      try {
        notification();
      } catch (e) {
        // Log error but continue with other notifications
        print('Error executing batched notification: $e');
      }
    }
  }

  /// Forces immediate execution of all pending notifications.
  void flush() {
    _batchTimer?.cancel();
    _flushNotifications();
  }

  /// Cancels all pending notifications.
  void cancel() {
    _batchTimer?.cancel();
    _pendingNotifications.clear();
    _isScheduled = false;
  }

  /// Gets the number of pending notifications.
  int get pendingCount => _pendingNotifications.length;

  /// Checks if there are pending notifications.
  bool get hasPending => _pendingNotifications.isNotEmpty;

  /// Gets batching statistics for debugging.
  Map<String, dynamic> getStats() {
    return {
      'strategy': _config.strategy.name,
      'pendingCount': _pendingNotifications.length,
      'isScheduled': _isScheduled,
      'hasActiveTimer': _batchTimer?.isActive ?? false,
      'maxBatchSize': _config.maxBatchSize,
      'delay': _config.delay.inMilliseconds,
    };
  }

  /// Disposes of the batcher and cancels all pending operations.
  void dispose() {
    cancel();
  }
}

/// Global notification batcher instance.
final globalNotificationBatcher = NotificationBatcher();

/// Creates a notification batcher with custom configuration.
NotificationBatcher createNotificationBatcher({
  BatchingStrategy strategy = BatchingStrategy.frame,
  Duration delay = const Duration(milliseconds: 16),
  int maxBatchSize = 100,
  bool enableFrameAlignment = true,
}) {
  return NotificationBatcher(
    BatchingConfig(
      strategy: strategy,
      delay: delay,
      maxBatchSize: maxBatchSize,
      enableFrameAlignment: enableFrameAlignment,
    ),
  );
}