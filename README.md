# Compose State

A comprehensive Flutter state management package inspired by Jetpack Compose, offering reactive state, centralized ViewModel scoping, API handling, and persistence for basic, complex, and dynamic objects.

[![pub package](https://img.shields.io/pub/v/compose_state.svg)](https://pub.dev/packages/compose_state)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## 🚀 Features

### Core State Types
- **MutableState**: Reactive state holder with automatic disposal
- **PersistableState**: Built-in persistence with SharedPreferences
- **ApiState**: Async data fetching with comprehensive error handling and retry logic
- **DerivedState**: Reactive computed states that update automatically
- **HistoryState**: Undo/redo support with configurable history size
- **StreamState**: Reactive state from Stream sources
- **SignalState**: Granular reactivity for performance optimization

### Advanced Features
- **🛡️ Comprehensive Error Handling**: Configurable error recovery strategies, retry mechanisms, and error boundaries
- **🧠 Automatic Memory Management**: Weak reference tracking, automatic disposal, and memory leak detection
- **⚡ Performance Optimization**: Deep equality checking, notification batching, and optimized rebuilds
- **🧪 Testing Infrastructure**: Mock implementations, state change tracking, and comprehensive testing utilities
- **🔒 Runtime Type Validation**: Type safety for serialization and persistence operations
- **🔄 State Transactions**: Atomic operations across multiple states with rollback support
- **🧩 State Composition**: Observe multiple states simultaneously with StateComposer, StateSelector, and StateProvider/Consumer
- **📱 UI State Pattern**: Single-state solution for complex UI states with loading, error, success, and empty states

### UI Components
- **StateBuilder**: Reactive UI components that rebuild on state changes
- **OptimizedStateBuilder**: Performance-optimized builder with custom equality
- **ErrorBoundary**: Graceful error handling in UI components
- **UiStateBuilder**: Single-state builder for complex UI states (loading, error, success, empty)
- **StateComposer/StateSelector**: Observe multiple states without nesting
- **StateProvider/Consumer**: Dependency injection for global state management

## 📦 Installation

```yaml
dependencies:
  compose_state: ^0.1.0
```

## 🏃 Quick Start

### Basic Counter Example

```dart
import 'package:flutter/material.dart';
import 'package:compose_state/compose_state.dart';

// Create a reactive state
final counter = mutableStateOf(0);

class CounterApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('Counter')),
        body: Center(
          child: StateBuilder<int>(
            state: counter,
            builder: (context, count) {
              return Text('Count: $count', style: TextStyle(fontSize: 24));
            },
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => counter.value++,
          child: Icon(Icons.add),
        ),
      ),
    );
  }
}
```

### Persistent Settings Example

```dart
// Create a persistent state that automatically saves to storage
final themeMode = persistableStateOf<String>(
  'theme_mode',
  defaultValue: 'system',
);

// Usage in widget
StateBuilder<String>(
  state: themeMode,
  builder: (context, mode) {
    return DropdownButton<String>(
      value: mode,
      onChanged: (newMode) => themeMode.value = newMode!,
      items: ['light', 'dark', 'system']
          .map((mode) => DropdownMenuItem(value: mode, child: Text(mode)))
          .toList(),
    );
  },
)
```

### API Data Fetching Example

```dart
// Create an API state with automatic error handling and retry
final userState = apiStateOf<User>(
  () => ApiService.fetchUser(userId),
  errorHandler: StateErrorHandler(
    defaultStrategy: RetryStrategy(maxAttempts: 3),
  ),
);

// Usage in widget
StateBuilder<UiState<User>>(
  state: userState,
  builder: (context, uiData) {
    if (uiData is LoadingState) {
      return CircularProgressIndicator();
    }
    
    if (uiData is ErrorState) {
      return Column(
        children: [
          Text('Error: ${uiData.message}'),
          ElevatedButton(
            onPressed: () => userState.refresh(),
            child: Text('Retry'),
          ),
        ],
      );
    }
    
    if (uiData is SuccessState<User>) {
      final user = uiData.data;
      return UserProfile(user: user);
    }
    
    return Container(); // Empty state
  },
)
```

### Derived State Example

```dart
final firstName = mutableStateOf('John');
final lastName = mutableStateOf('Doe');

// Computed state that automatically updates when dependencies change
final fullName = derivedStateOf(
  () => '${firstName.value} ${lastName.value}',
  dependencies: [firstName, lastName],
);

print(fullName.value); // "John Doe"

firstName.value = 'Jane';
print(fullName.value); // "Jane Doe" (automatically updated)
```

### UI State Pattern Example

```dart
class TodoViewModel extends ComposeViewModel {
  late final isLoading = mutableStateOf(false);
  late final error = mutableStateOf<String?>(null);
  late final todos = mutableStateOf<List<Todo>>([]);
  
  // Computed UI state
  late final uiState = createUiState<List<Todo>>(
    'todos',
    () {
      if (isLoading.value) {
        return UiState.loading();
      }
      
      if (error.value != null) {
        return UiState.error(error.value!);
      }
      
      if (todos.value.isEmpty) {
        return UiState.empty();
      }
      
      return UiState.success(todos.value);
    },
    dependencies: [isLoading, error, todos],
  );
}

// Usage in widget
UiStateBuilder<List<Todo>>(
  state: viewModel.uiState,
  loadingBuilder: (context) => const Center(
    child: CircularProgressIndicator(),
  ),
  errorBuilder: (context, error) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error, size: 48, color: Colors.red),
        const SizedBox(height: 16),
        Text('Error: $error'),
        ElevatedButton(
          onPressed: () => viewModel.loadTodos(),
          child: const Text('Retry'),
        ),
      ],
    ),
  ),
  emptyBuilder: (context) => const Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.inbox, size: 48, color: Colors.grey),
        SizedBox(height: 16),
        Text('No todos yet'),
      ],
    ),
  ),
  successBuilder: (context, todos) => ListView.builder(
    itemCount: todos.length,
    itemBuilder: (context, index) {
      final todo = todos[index];
      return ListTile(
        title: Text(todo.title),
        subtitle: Text(todo.description),
        trailing: Checkbox(
          value: todo.isCompleted,
          onChanged: (value) => viewModel.toggleTodo(todo.id),
        ),
      );
    },
  ),
)
```

### State Composition Example

```dart
class DashboardViewModel extends ComposeViewModel {
  late final user = mutableStateOf<User?>(null);
  late final stats = mutableStateOf<Stats?>(null);
  late final notifications = mutableStateOf<List<Notification>>([]);
  late final isLoading = mutableStateOf(false);
  late final error = mutableStateOf<String?>(null);
}

// Observe multiple states simultaneously
StateComposer(
  states: {
    'user': viewModel.user,
    'stats': viewModel.stats,
    'notifications': viewModel.notifications,
    'isLoading': viewModel.isLoading,
    'error': viewModel.error,
  },
  builder: (context, stateValues) {
    final user = stateValues['user'] as User?;
    final stats = stateValues['stats'] as Stats?;
    final notifications = stateValues['notifications'] as List<Notification>?;
    final isLoading = stateValues['isLoading'] as bool;
    final error = stateValues['error'] as String?;
    
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (error != null) {
      return Center(
        child: Column(
          children: [
            Text('Error: $error'),
            ElevatedButton(
              onPressed: () => viewModel.loadDashboard(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    
    return DashboardContent(
      user: user,
      stats: stats,
      notifications: notifications ?? [],
    );
  },
)
```

## 📚 Documentation

### Core Concepts
- [API Documentation](doc/api/README.md) - Complete API reference
- [Examples](doc/examples/README.md) - Comprehensive usage examples
- [Testing Guide](doc/testing/README.md) - Testing strategies and utilities
- [Migration Guide](doc/migration/README.md) - Migrating from other solutions
- [Best Practices](doc/best_practices.md) - Guidelines for effective usage

### State Types

#### MutableState
Basic reactive state with automatic disposal and error handling:

```dart
final name = mutableStateOf('John');
final age = mutableStateOf(25);

// Listen to changes
name.addListener(() {
  print('Name changed to: ${name.value}');
});

// Update values
name.value = 'Jane';
age.value = 30;
```

#### PersistableState
State that automatically persists to storage:

```dart
final settings = persistableStateOf<Map<String, dynamic>>(
  'app_settings',
  defaultValue: {'theme': 'light', 'notifications': true},
  serializer: (value) => jsonEncode(value),
  deserializer: (json) => jsonDecode(json),
);

// Changes are automatically saved
settings.value = {'theme': 'dark', 'notifications': false};
```

#### ApiState
Handles asynchronous operations with comprehensive error handling:

```dart
final postsState = apiStateOf<List<Post>>(
  () => ApiService.fetchPosts(),
  errorHandler: StateErrorHandler(
    defaultStrategy: RetryStrategy(
      maxAttempts: 3,
      backoffMultiplier: 2.0,
    ),
  ),
);

// Check state
if (postsState.value is LoadingState) { /* show loading */ }
if (postsState.value is ErrorState) { /* show error */ }
if (postsState.value is SuccessState<List<Post>>) {
  final posts = postsState.value.data; // Access data
}
```

#### DerivedState
Computed state that automatically updates when dependencies change:

```dart
final firstName = mutableStateOf('John');
final lastName = mutableStateOf('Doe');

final fullName = derivedStateOf(
  () => '${firstName.value} ${lastName.value}',
  dependencies: [firstName, lastName],
);

print(fullName.value); // "John Doe"

firstName.value = 'Jane';
print(fullName.value); // "Jane Doe" (automatically updated)
```

#### HistoryState
State with undo/redo capabilities:

```dart
final textState = historyStateOf('Initial text');

textState.value = 'Modified text';
textState.value = 'Final text';

textState.undo(); // Back to "Modified text"
textState.undo(); // Back to "Initial text"
textState.redo(); // Forward to "Modified text"
```

### Advanced Features

#### Error Handling
Comprehensive error handling with recovery strategies:

```dart
final errorHandler = StateErrorHandler(
  defaultStrategy: RetryStrategy(maxAttempts: 3),
  fallbackStrategy: FallbackStrategy(fallbackValue: 'default'),
  onError: (error, context) {
    // Custom error logging
    print('State error: $error');
  },
);

final state = mutableStateOf('value', errorHandler: errorHandler);
```

#### Memory Management
Automatic memory management with leak detection:

```dart
// Get memory statistics
final stats = StateManager.instance.getMemoryStats();
print('Active states: ${stats.activeStates}');

// Detect potential memory leaks
final leaks = StateManager.instance.detectPotentialLeaks();
if (leaks.isNotEmpty) {
  print('Potential leaks detected: $leaks');
}

// Perform garbage collection
StateManager.instance.performGarbageCollection();
```

#### Transactions
Atomic operations across multiple states:

```dart
final transactionManager = TransactionManager();

await transactionManager.executeInTransaction((transaction) async {
  state1.setValueInTransaction('value1', transaction);
  state2.setValueInTransaction('value2', transaction);
  
  // If any operation fails, all changes are rolled back
  await someAsyncOperation();
});
```

#### Performance Optimization
Deep equality checking and notification batching:

```dart
// Custom equality for complex objects
final complexState = mutableStateOf(
  MyComplexObject(),
  equalityChecker: EqualityChecker<MyComplexObject>(
    customEquals: (a, b) => a.id == b.id,
  ),
);

// Batch multiple changes to reduce rebuilds
final batcher = NotificationBatcher();
batcher.batch(() {
  state1.value = 'new value 1';
  state2.value = 'new value 2';
  state3.value = 'new value 3';
});
```

#### State Composition
Observe multiple states without nesting:

```dart
// Observe multiple states simultaneously
StateComposer(
  states: {
    'user': userState,
    'settings': settingsState,
    'notifications': notificationsState,
  },
  builder: (context, states) {
    final user = states['user'] as User?;
    final settings = states['settings'] as Settings?;
    final notifications = states['notifications'] as List<Notification>?;
    
    return DashboardContent(
      user: user,
      settings: settings,
      notifications: notifications ?? [],
    );
  },
);
```

## 🧪 Testing

Compose State includes comprehensive testing utilities:

```dart
import 'package:compose_state/testing.dart';

void main() {
  group('State Tests', () {
    test('mock state behavior', () {
      final mockState = mockStateOf(42);
      
      // Control behavior
      mockState.throwOnSet();
      expect(() => mockState.value = 100, throwsException);
      
      mockState.returnValue(200);
      expect(mockState.value, 200);
    });
    
    test('state change tracking', () async {
      final state = mutableStateOf(0);
      final tracker = createStateTracker();
      
      tracker.trackState('counter', state);
      tracker.startTracking();
      
      state.value = 1;
      state.value = 2;
      
      final history = tracker.getChangeHistory('counter');
      expect(history.length, 3); // initial + 2 changes
    });
  });
}
```

## 🔄 Migration

Migrating from other state management solutions? Check our [Migration Guide](doc/migration/README.md) for detailed instructions on migrating from:

- Provider
- Bloc
- Riverpod
- GetX
- Previous versions of compose_state

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Inspired by Jetpack Compose's state management
- Built with Flutter's reactive principles
- Community feedback and contributions

---

**Made with ❤️ for the Flutter community**