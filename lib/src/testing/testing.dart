/// Comprehensive testing infrastructure for the compose_state package.
/// 
/// This module provides mock implementations, testing utilities, and
/// verification mechanisms for all state types in the package.
/// 
/// ## Key Components
/// 
/// - **MockState**: Controllable mock implementations of all state types
/// - **StateTestUtils**: Helper functions and assertion utilities
/// - **TestStateBuilder**: Test-friendly StateBuilder with tracking capabilities
/// - **StateChangeTracker**: Comprehensive state change tracking and verification
/// 
/// ## Usage
/// 
/// ```dart
/// import 'package:compose_state/testing.dart';
/// 
/// void main() {
///   group('State Tests', () {
///     test('mock state behavior', () {
///       final mock = mockStateOf(42);
///       mock.throwOnSet();
///       
///       expect(() => mock.value = 100, throwsException);
///     });
///     
///     test('state change tracking', () async {
///       final state = mutableStateOf(0);
///       final tracker = createStateTracker();
///       
///       tracker.trackState('counter', state);
///       tracker.startTracking();
///       
///       state.value = 1;
///       state.value = 2;
///       
///       final history = tracker.getChangeHistory('counter');
///       expect(history.length, 3); // initial + 2 changes
///     });
///   });
/// }
/// ```

export 'mock_state.dart';
export 'state_test_utils.dart';
export 'test_state_builder.dart';
export 'state_change_tracker.dart';