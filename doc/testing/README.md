# Testing Guide for Compose State

This guide covers comprehensive testing strategies for applications using the compose_state package, including unit testing, widget testing, integration testing, and performance testing.

## Table of Contents

- [Testing Philosophy](#testing-philosophy)
- [Setting Up Tests](#setting-up-tests)
- [Unit Testing States](#unit-testing-states)
- [Widget Testing](#widget-testing)
- [Integration Testing](#integration-testing)
- [Performance Testing](#performance-testing)
- [Mock Testing](#mock-testing)
- [Best Practices](#best-practices)
- [Common Patterns](#common-patterns)
- [Troubleshooting](#troubleshooting)

## Testing Philosophy

The compose_state package is designed with testability as a core principle. All state types are:

- **Deterministic**: Same inputs produce same outputs
- **Isolated**: States can be tested independently
- **Observable**: State changes can be monitored and verified
- **Mockable**: All state types have mock implementations

## Setting Up Tests

### Dependencies

Add testing dependencies to your `pubspec.yaml`:

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  compose_state: ^0.1.0
  mockito: ^5.4.0
  build_runner: ^2.4.0
```

### Test Structure

Organize your tests following this structure:

```
test/
├── unit/
│   ├── states/
│   ├── view_models/
│   └── services/
├── widget/
│   ├── screens/
│   └── components/
├── integration/
│   ├── flows/
│   └── scenarios/
└── performance/
    ├── memory/
    └── benchmarks/
```

### Basic Test Setup

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:compose_state/compose_state.dart';
import 'package:compose_state/testing.dart';

void main() {
  setUp(() {
    // Reset state manager before each test
    StateManager.instance.disposeAllStates();
  });

  tearDown(() {
    // Clean up after each test
    StateManager.instance.performGarbageCollection();
  });
}
```

## Unit Testing States

### Testing MutableState

```dart
group('MutableState Tests', () {
  test('should update value correctly', () {
    final state = mutableStateOf(0);
    
    expect(state.value, 0);
    
    state.value = 42;
    expect(state.value, 42);
  });

  test('should notify listeners on change', () {
    final state = mutableStateOf('initial');
    bool wasNotified = false;
    
    state.addListener(() {
      wasNotified = true;
    });
    
    state.value = 'changed';
    expect(wasNotified, true);
  });

  test('should not notify on same value', () {
    final state = mutableStateOf(42);
    int notificationCount = 0;
    
    state.addListener(() {
      notificationCount++;
    });
    
    state.value = 42; // Same value
    expect(notificationCount, 0);
    
    state.value = 43; // Different value
    expect(notificationCount, 1);
  });

  test('should handle disposal correctly', () {
    final state = mutableStateOf('test');
    
    expect(state.isDisposed, false);
    
    state.dispose();
    expect(state.isDisposed, true);
    
    // Should throw when accessing disposed state
    expect(() => state.value, throwsA(isA<StateException>()));
  });
});
```

### Testing PersistableState

```dart
group('PersistableState Tests', () {
  late MockStorage mockStorage;
  
  setUp(() {
    mockStorage = MockStorage();
  });

  test('should load initial value from storage', () async {
    when(mockStorage.getString('test_key'))
        .thenReturn('"saved_value"');
    
    final state = persistableStateOf<String>(
      'test_key',
      defaultValue: 'default',
      storage: mockStorage,
    );
    
    await state.initialize();
    expect(state.value, 'saved_value');
  });

  test('should save value to storage on change', () async {
    when(mockStorage.setString(any, any))
        .thenAnswer((_) async => true);
    
    final state = persistableStateOf<String>(
      'test_key',
      defaultValue: 'default',
      storage: mockStorage,
    );
    
    state.value = 'new_value';
    
    // Wait for async save
    await Future.delayed(Duration(milliseconds: 100));
    
    verify(mockStorage.setString('test_key', '"new_value"')).called(1);
  });

  test('should handle storage errors gracefully', () async {
    when(mockStorage.getString('test_key'))
        .thenThrow(Exception('Storage error'));
    
    final state = persistableStateOf<String>(
      'test_key',
      defaultValue: 'default',
      storage: mockStorage,
    );
    
    await state.initialize();
    
    // Should fall back to default value
    expect(state.value, 'default');
  });
});
```

### Testing ApiState

```dart
group('ApiState Tests', () {
  test('should handle successful data fetching', () async {
    final apiState = apiStateOf<String>(
      () async {
        await Future.delayed(Duration(milliseconds: 100));
        return 'success data';
      },
    );

    expect(apiState.isLoading, true);
    expect(apiState.data, null);

    await apiState.refresh();

    expect(apiState.isLoading, false);
    expect(apiState.data, 'success data');
    expect(apiState.hasError, false);
  });

  test('should handle errors with retry strategy', () async {
    int attemptCount = 0;
    final apiState = apiStateOf<String>(
      () async {
        attemptCount++;
        if (attemptCount < 3) {
          throw Exception('Network error');
        }
        return 'success after retry';
      },
      errorHandler: StateErrorHandler(
        defaultStrategy: RetryStrategy(maxAttempts: 3),
      ),
    );

    await apiState.refresh();

    expect(apiState.data, 'success after retry');
    expect(attemptCount, 3);
  });

  test('should handle timeout errors', () async {
    final apiState = apiStateOf<String>(
      () async {
        await Future.delayed(Duration(seconds: 2));
        return 'data';
      },
      timeout: Duration(milliseconds: 500),
    );

    await apiState.refresh();

    expect(apiState.hasError, true);
    expect(apiState.error, isA<TimeoutException>());
  });
});
```

### Testing DerivedState

```dart
group('DerivedState Tests', () {
  test('should compute value from dependencies', () {
    final firstName = mutableStateOf('John');
    final lastName = mutableStateOf('Doe');
    
    final fullName = derivedStateOf(() => 
        '${firstName.value} ${lastName.value}');
    
    expect(fullName.value, 'John Doe');
  });

  test('should update when dependencies change', () {
    final counter = mutableStateOf(0);
    final doubled = derivedStateOf(() => counter.value * 2);
    
    expect(doubled.value, 0);
    
    counter.value = 5;
    expect(doubled.value, 10);
  });

  test('should notify listeners when computed value changes', () {
    final input = mutableStateOf(1);
    final output = derivedStateOf(() => input.value > 5 ? 'high' : 'low');
    
    String? lastValue;
    output.addListener(() {
      lastValue = output.value;
    });
    
    input.value = 3; // Still 'low'
    expect(lastValue, null); // No notification
    
    input.value = 7; // Now 'high'
    expect(lastValue, 'high'); // Notification sent
  });
});
```

## Widget Testing

### Testing StateBuilder

```dart
group('StateBuilder Widget Tests', () {
  testWidgets('should rebuild when state changes', (tester) async {
    final counter = mutableStateOf(0);
    
    await tester.pumpWidget(
      MaterialApp(
        home: StateBuilder<int>(
          state: counter,
          builder: (context, value) {
            return Text('Count: $value');
          },
        ),
      ),
    );
    
    expect(find.text('Count: 0'), findsOneWidget);
    
    counter.value = 42;
    await tester.pump();
    
    expect(find.text('Count: 42'), findsOneWidget);
  });

  testWidgets('should handle state errors gracefully', (tester) async {
    final errorState = mutableStateOf('normal');
    
    await tester.pumpWidget(
      MaterialApp(
        home: ErrorBoundary(
          child: StateBuilder<String>(
            state: errorState,
            builder: (context, value) {
              if (value == 'error') {
                throw Exception('Test error');
              }
              return Text(value);
            },
          ),
          onError: (error, stackTrace) {
            return Text('Error: ${error.toString()}');
          },
        ),
      ),
    );
    
    expect(find.text('normal'), findsOneWidget);
    
    errorState.value = 'error';
    await tester.pump();
    
    expect(find.textContaining('Error:'), findsOneWidget);
  });
});
```

### Testing Complex Widgets

```dart
group('Complex Widget Tests', () {
  testWidgets('should handle form validation correctly', (tester) async {
    final nameState = mutableStateOf('');
    final emailState = mutableStateOf('');
    final isFormValid = derivedStateOf(() =>
        nameState.value.isNotEmpty && emailState.value.contains('@'));
    
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              StateBuilder<String>(
                state: nameState,
                builder: (context, value) {
                  return TextField(
                    key: Key('name_field'),
                    onChanged: (text) => nameState.value = text,
                  );
                },
              ),
              StateBuilder<String>(
                state: emailState,
                builder: (context, value) {
                  return TextField(
                    key: Key('email_field'),
                    onChanged: (text) => emailState.value = text,
                  );
                },
              ),
              StateBuilder<bool>(
                state: isFormValid,
                builder: (context, isValid) {
                  return ElevatedButton(
                    key: Key('submit_button'),
                    onPressed: isValid ? () {} : null,
                    child: Text('Submit'),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
    
    // Initially form should be invalid
    expect(
      tester.widget<ElevatedButton>(find.byKey(Key('submit_button'))).onPressed,
      null,
    );
    
    // Enter name
    await tester.enterText(find.byKey(Key('name_field')), 'John');
    await tester.pump();
    
    // Still invalid (no email)
    expect(
      tester.widget<ElevatedButton>(find.byKey(Key('submit_button'))).onPressed,
      null,
    );
    
    // Enter email
    await tester.enterText(find.byKey(Key('email_field')), 'john@example.com');
    await tester.pump();
    
    // Now valid
    expect(
      tester.widget<ElevatedButton>(find.byKey(Key('submit_button'))).onPressed,
      isNotNull,
    );
  });
});
```

## Integration Testing

### Testing Complete Flows

```dart
group('Integration Tests', () {
  testWidgets('should complete user registration flow', (tester) async {
    final registrationViewModel = UserRegistrationViewModel();
    
    await tester.pumpWidget(
      MaterialApp(
        home: RegistrationScreen(viewModel: registrationViewModel),
      ),
    );
    
    // Fill out form
    await tester.enterText(find.byKey(Key('name_field')), 'John Doe');
    await tester.enterText(find.byKey(Key('email_field')), 'john@example.com');
    await tester.enterText(find.byKey(Key('password_field')), 'SecurePass123');
    await tester.enterText(find.byKey(Key('confirm_password_field')), 'SecurePass123');
    
    // Accept terms
    await tester.tap(find.byKey(Key('terms_checkbox')));
    await tester.pump();
    
    // Submit form
    await tester.tap(find.byKey(Key('submit_button')));
    await tester.pump();
    
    // Should show loading state
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    
    // Wait for completion
    await tester.pumpAndSettle();
    
    // Verify success state
    expect(registrationViewModel.isSubmitting.value, false);
    expect(registrationViewModel.submitError.value, null);
  });

  testWidgets('should handle API errors in data fetching flow', (tester) async {
    final postsViewModel = PostsViewModel();
    
    // Mock API to return error
    when(mockApiService.fetchPosts())
        .thenThrow(Exception('Network error'));
    
    await tester.pumpWidget(
      MaterialApp(
        home: PostsScreen(viewModel: postsViewModel),
      ),
    );
    
    // Trigger data loading
    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pump();
    
    // Should show loading
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    
    // Wait for error
    await tester.pumpAndSettle();
    
    // Should show error state
    expect(find.textContaining('Error:'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
});
```

## Performance Testing

### Memory Leak Detection

```dart
group('Memory Performance Tests', () {
  test('should not leak memory with many state creations', () {
    final initialStats = StateManager.instance.getMemoryStats();
    
    // Create many states
    for (int i = 0; i < 1000; i++) {
      final state = mutableStateOf(i);
      state.dispose();
    }
    
    // Force garbage collection
    StateManager.instance.performGarbageCollection();
    
    final finalStats = StateManager.instance.getMemoryStats();
    
    // Should not have significantly more active states
    expect(
      finalStats.activeStates - initialStats.activeStates,
      lessThan(10),
    );
  });

  test('should detect potential memory leaks', () async {
    // Create long-lived states
    final state1 = mutableStateOf('test1');
    final state2 = mutableStateOf('test2');
    
    // Wait to simulate age
    await Future.delayed(Duration(milliseconds: 100));
    
    final leaks = StateManager.instance.detectPotentialLeaks(
      threshold: Duration(milliseconds: 50),
    );
    
    expect(leaks.length, greaterThanOrEqualTo(2));
    
    // Clean up
    state1.dispose();
    state2.dispose();
  });
});
```

### Performance Benchmarks

```dart
group('Performance Benchmarks', () {
  test('state update performance', () {
    final state = mutableStateOf(0);
    final stopwatch = Stopwatch()..start();
    
    for (int i = 0; i < 10000; i++) {
      state.value = i;
    }
    
    stopwatch.stop();
    
    // Should complete within reasonable time
    expect(stopwatch.elapsedMilliseconds, lessThan(100));
  });

  test('equality checking performance', () {
    final complexObject = List.generate(1000, (i) => {'id': i, 'data': 'item_$i'});
    final state = mutableStateOf(
      complexObject,
      equalityChecker: EqualityChecker<List<Map<String, dynamic>>>(),
    );
    
    final stopwatch = Stopwatch()..start();
    
    // Set same value multiple times (should use cached equality)
    for (int i = 0; i < 100; i++) {
      state.value = List.from(complexObject);
    }
    
    stopwatch.stop();
    
    // Should be fast due to caching
    expect(stopwatch.elapsedMilliseconds, lessThan(50));
  });
});
```

## Mock Testing

### Using Mock States

```dart
group('Mock State Tests', () {
  test('should control mock state behavior', () {
    final mockState = mockStateOf(42);
    
    // Test normal behavior
    expect(mockState.value, 42);
    
    // Control return value
    mockState.returnValue(100);
    expect(mockState.value, 100);
    
    // Test error behavior
    mockState.throwOnGet();
    expect(() => mockState.value, throwsException);
    
    // Reset behavior
    mockState.reset();
    expect(mockState.value, 42); // Back to original
  });

  test('should track mock state interactions', () {
    final mockState = mockStateOf('test');
    
    // Perform operations
    mockState.value; // get
    mockState.value; // get
    mockState.value = 'new'; // set
    
    // Verify interactions
    expect(mockState.getCallCount, 2);
    expect(mockState.setCallCount, 1);
    expect(mockState.lastSetValue, 'new');
  });
});
```

### Mocking Dependencies

```dart
class MockApiService extends Mock implements ApiService {}
class MockStorage extends Mock implements Storage {}

group('Dependency Mocking Tests', () {
  late MockApiService mockApiService;
  late MockStorage mockStorage;
  
  setUp(() {
    mockApiService = MockApiService();
    mockStorage = MockStorage();
  });

  test('should mock API service correctly', () async {
    when(mockApiService.fetchUser(any))
        .thenAnswer((_) async => User(id: '1', name: 'Test User'));
    
    final userState = apiStateOf<User>(
      () => mockApiService.fetchUser('1'),
    );
    
    await userState.refresh();
    
    expect(userState.data?.name, 'Test User');
    verify(mockApiService.fetchUser('1')).called(1);
  });
});
```

## Best Practices

### Test Organization

1. **Group Related Tests**: Use `group()` to organize related test cases
2. **Descriptive Names**: Use clear, descriptive test names
3. **Setup and Teardown**: Use `setUp()` and `tearDown()` for common initialization
4. **Isolation**: Each test should be independent and not rely on others

### State Testing Guidelines

1. **Test State Transitions**: Verify state changes correctly
2. **Test Error Conditions**: Ensure errors are handled gracefully
3. **Test Disposal**: Verify resources are cleaned up properly
4. **Test Notifications**: Ensure listeners are notified appropriately

### Widget Testing Guidelines

1. **Test User Interactions**: Simulate real user behavior
2. **Test State Integration**: Verify widgets respond to state changes
3. **Test Error Boundaries**: Ensure error states are handled in UI
4. **Test Accessibility**: Verify widgets are accessible

### Performance Testing Guidelines

1. **Memory Testing**: Check for memory leaks and excessive usage
2. **Speed Testing**: Ensure operations complete within reasonable time
3. **Scalability Testing**: Test with large datasets and many states
4. **Stress Testing**: Test under high load conditions

## Common Patterns

### Testing Async Operations

```dart
test('should handle async operations correctly', () async {
  final state = apiStateOf<String>(() async {
    await Future.delayed(Duration(milliseconds: 100));
    return 'async data';
  });

  // Test initial state
  expect(state.isLoading, true);
  expect(state.data, null);

  // Wait for completion
  await state.refresh();

  // Test final state
  expect(state.isLoading, false);
  expect(state.data, 'async data');
});
```

### Testing State Combinations

```dart
test('should handle multiple state dependencies', () {
  final loading = mutableStateOf(false);
  final error = mutableStateOf<String?>(null);
  final data = mutableStateOf<String?>(null);
  
  final uiState = derivedStateOf(() {
    if (loading.value) return 'loading';
    if (error.value != null) return 'error';
    if (data.value != null) return 'success';
    return 'initial';
  });
  
  expect(uiState.value, 'initial');
  
  loading.value = true;
  expect(uiState.value, 'loading');
  
  loading.value = false;
  error.value = 'Something went wrong';
  expect(uiState.value, 'error');
  
  error.value = null;
  data.value = 'Success data';
  expect(uiState.value, 'success');
});
```

### Testing Custom Equality

```dart
test('should use custom equality correctly', () {
  final state = mutableStateOf(
    Person(id: 1, name: 'John'),
    equalityChecker: EqualityChecker<Person>(
      customEquals: (a, b) => a.id == b.id,
    ),
  );
  
  int notificationCount = 0;
  state.addListener(() => notificationCount++);
  
  // Same ID, different name - should not notify
  state.value = Person(id: 1, name: 'Jane');
  expect(notificationCount, 0);
  
  // Different ID - should notify
  state.value = Person(id: 2, name: 'Jane');
  expect(notificationCount, 1);
});
```

## Troubleshooting

### Common Issues

1. **Tests Not Cleaning Up**: Always dispose states in `tearDown()`
2. **Async Tests Hanging**: Use `pumpAndSettle()` for widget tests
3. **Memory Leaks in Tests**: Reset StateManager between tests
4. **Flaky Tests**: Ensure proper async handling and state isolation

### Debugging Tips

1. **Use State Debugger**: Enable state debugging for detailed logs
2. **Check Memory Stats**: Monitor memory usage during tests
3. **Verify Mock Interactions**: Use `verify()` to check mock calls
4. **Add Logging**: Use `debugPrint()` for test debugging

### Performance Issues

1. **Slow Tests**: Check for unnecessary state creations
2. **Memory Growth**: Ensure proper disposal and garbage collection
3. **Excessive Notifications**: Verify equality checkers are working
4. **Widget Rebuild Issues**: Use `OptimizedStateBuilder` for complex widgets

This comprehensive testing guide should help you write robust, maintainable tests for your compose_state applications. Remember to test not just the happy path, but also error conditions, edge cases, and performance characteristics.