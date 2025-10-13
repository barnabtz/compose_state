# Migration Guide for Compose State

This guide helps you migrate to the latest version of compose_state and upgrade from other state management solutions.

## Table of Contents

- [Migrating from Previous Versions](#migrating-from-previous-versions)
- [Migrating from Provider](#migrating-from-provider)
- [Migrating from Bloc](#migrating-from-bloc)
- [Migrating from Riverpod](#migrating-from-riverpod)
- [Migrating from GetX](#migrating-from-getx)
- [Breaking Changes](#breaking-changes)
- [Migration Tools](#migration-tools)
- [Best Practices](#best-practices)

## Migrating from Previous Versions

### From v0.0.x to v0.1.x

#### Major Changes

1. **Enhanced ObservableState Interface**
   - Added `isDisposed`, `dispose()`, `equals()`, `createSnapshot()`, and `restoreSnapshot()` methods
   - All existing state implementations now support these methods

2. **New Error Handling System**
   - Comprehensive error handling with recovery strategies
   - Error boundaries for UI components
   - Configurable retry mechanisms

3. **Automatic Memory Management**
   - States are now automatically tracked and disposed
   - Memory leak detection and prevention
   - Weak reference management for listeners

4. **Performance Optimizations**
   - Deep equality checking with caching
   - Notification batching to reduce rebuilds
   - Optimized StateBuilder components

5. **Testing Infrastructure**
   - Mock implementations for all state types
   - State change tracking utilities
   - Comprehensive testing helpers

#### Migration Steps

1. **Update Dependencies**
   ```yaml
   dependencies:
     compose_state: ^0.1.0
   ```

2. **Update State Creation**
   ```dart
   // Before
   final counter = MutableState(0);
   
   // After (recommended)
   final counter = mutableStateOf(0);
   ```

3. **Handle Disposal (Optional)**
   ```dart
   // Before - manual disposal required
   @override
   void dispose() {
     myState.dispose();
     super.dispose();
   }
   
   // After - automatic disposal (but manual still supported)
   @override
   void dispose() {
     // Disposal is automatic, but you can still dispose manually if needed
     myState.dispose();
     super.dispose();
   }
   ```

4. **Update Error Handling**
   ```dart
   // Before - basic error handling
   final apiState = ApiState(() => fetchData());
   
   // After - enhanced error handling
   final apiState = apiStateOf<Data>(
     fetchData,
     errorHandler: StateErrorHandler(
       defaultStrategy: RetryStrategy(maxAttempts: 3),
     ),
   );
   ```

5. **Update Testing**
   ```dart
   // Before
   import 'package:compose_state/compose_state.dart';
   
   // After - add testing import
   import 'package:compose_state/compose_state.dart';
   import 'package:compose_state/testing.dart';
   
   // Use new testing utilities
   final mockState = mockStateOf(42);
   final tracker = createStateTracker();
   ```

#### Deprecated Features

- `MutableState()` constructor - use `mutableStateOf()` instead
- `PersistableState()` constructor - use `persistableStateOf()` instead
- `ApiState()` constructor - use `apiStateOf()` instead
- Manual listener management - now handled automatically

#### New Features to Adopt

1. **State Snapshots**
   ```dart
   final snapshot = state.createSnapshot();
   // ... later
   state.restoreSnapshot(snapshot);
   ```

2. **Transactions**
   ```dart
   await transactionManager.executeTransaction((transaction) async {
     state1.setValueInTransaction('value1', transaction);
     state2.setValueInTransaction('value2', transaction);
   });
   ```

3. **Memory Monitoring**
   ```dart
   final stats = StateManager.instance.getMemoryStats();
   final leaks = StateManager.instance.detectPotentialLeaks();
   ```

## Migrating from Provider

### Key Differences

- **Reactive by Default**: States automatically notify listeners
- **No Context Required**: States can be accessed without BuildContext
- **Built-in Persistence**: PersistableState handles storage automatically
- **Type Safety**: Strong typing with generic state types

### Migration Example

#### Before (Provider)
```dart
class CounterProvider extends ChangeNotifier {
  int _count = 0;
  int get count => _count;
  
  void increment() {
    _count++;
    notifyListeners();
  }
}

// Usage
class CounterApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => CounterProvider(),
      child: Consumer<CounterProvider>(
        builder: (context, counter, child) {
          return Text('Count: ${counter.count}');
        },
      ),
    );
  }
}
```

#### After (Compose State)
```dart
// Create state (can be global or scoped)
final counter = mutableStateOf(0);

void increment() {
  counter.value++;
}

// Usage
class CounterApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StateBuilder<int>(
      state: counter,
      builder: (context, count) {
        return Text('Count: $count');
      },
    );
  }
}
```

### Migration Steps

1. **Replace ChangeNotifier with MutableState**
   ```dart
   // Before
   class MyProvider extends ChangeNotifier {
     String _value = '';
     String get value => _value;
     set value(String newValue) {
       _value = newValue;
       notifyListeners();
     }
   }
   
   // After
   final myState = mutableStateOf('');
   ```

2. **Replace Provider with StateBuilder**
   ```dart
   // Before
   Consumer<MyProvider>(
     builder: (context, provider, child) {
       return Text(provider.value);
     },
   )
   
   // After
   StateBuilder<String>(
     state: myState,
     builder: (context, value) {
       return Text(value);
     },
   )
   ```

3. **Handle Complex State**
   ```dart
   // Before
   class UserProvider extends ChangeNotifier {
     User? _user;
     bool _isLoading = false;
     String? _error;
     
     // ... methods
   }
   
   // After
   final userState = apiStateOf<User>(() => fetchUser());
   // Automatically handles loading, error, and data states
   ```

## Migrating from Bloc

### Key Differences

- **Simpler State Management**: No events/states pattern required
- **Direct State Access**: Access state values directly
- **Built-in Async Handling**: ApiState handles async operations
- **Less Boilerplate**: Minimal setup required

### Migration Example

#### Before (Bloc)
```dart
abstract class CounterEvent {}
class Increment extends CounterEvent {}
class Decrement extends CounterEvent {}

class CounterState {
  final int count;
  CounterState(this.count);
}

class CounterBloc extends Bloc<CounterEvent, CounterState> {
  CounterBloc() : super(CounterState(0)) {
    on<Increment>((event, emit) => emit(CounterState(state.count + 1)));
    on<Decrement>((event, emit) => emit(CounterState(state.count - 1)));
  }
}

// Usage
BlocBuilder<CounterBloc, CounterState>(
  builder: (context, state) {
    return Text('Count: ${state.count}');
  },
)
```

#### After (Compose State)
```dart
final counter = mutableStateOf(0);

void increment() => counter.value++;
void decrement() => counter.value--;

// Usage
StateBuilder<int>(
  state: counter,
  builder: (context, count) {
    return Text('Count: $count');
  },
)
```

### Migration Steps

1. **Replace Bloc with State**
   ```dart
   // Before
   class DataBloc extends Bloc<DataEvent, DataState> {
     // Complex event/state handling
   }
   
   // After
   final dataState = apiStateOf<Data>(() => fetchData());
   ```

2. **Replace Events with Direct Methods**
   ```dart
   // Before
   context.read<CounterBloc>().add(Increment());
   
   // After
   counter.value++;
   ```

3. **Simplify State Classes**
   ```dart
   // Before
   class LoadingState extends DataState {}
   class LoadedState extends DataState {
     final Data data;
     LoadedState(this.data);
   }
   class ErrorState extends DataState {
     final String error;
     ErrorState(this.error);
   }
   
   // After
   // ApiState automatically handles loading, loaded, and error states
   final dataState = apiStateOf<Data>(() => fetchData());
   ```

## Migrating from Riverpod

### Key Differences

- **No Providers Required**: States are created directly
- **Simpler Dependency Injection**: Use DerivedState for computed values
- **Built-in Persistence**: PersistableState handles storage
- **Automatic Disposal**: Memory management is handled automatically

### Migration Example

#### Before (Riverpod)
```dart
final counterProvider = StateProvider<int>((ref) => 0);

final doubledProvider = Provider<int>((ref) {
  final count = ref.watch(counterProvider);
  return count * 2;
});

// Usage
Consumer(
  builder: (context, ref, child) {
    final count = ref.watch(counterProvider);
    return Text('Count: $count');
  },
)
```

#### After (Compose State)
```dart
final counter = mutableStateOf(0);
final doubled = derivedStateOf(() => counter.value * 2);

// Usage
StateBuilder<int>(
  state: counter,
  builder: (context, count) {
    return Text('Count: $count');
  },
)
```

### Migration Steps

1. **Replace Providers with States**
   ```dart
   // Before
   final nameProvider = StateProvider<String>((ref) => '');
   
   // After
   final name = mutableStateOf('');
   ```

2. **Replace Computed Providers with DerivedState**
   ```dart
   // Before
   final fullNameProvider = Provider<String>((ref) {
     final first = ref.watch(firstNameProvider);
     final last = ref.watch(lastNameProvider);
     return '$first $last';
   });
   
   // After
   final fullName = derivedStateOf(() => 
       '${firstName.value} ${lastName.value}');
   ```

3. **Replace AsyncNotifier with ApiState**
   ```dart
   // Before
   class UserNotifier extends AsyncNotifier<User> {
     @override
     Future<User> build() => fetchUser();
   }
   
   // After
   final userState = apiStateOf<User>(() => fetchUser());
   ```

## Migrating from GetX

### Key Differences

- **No Global State by Default**: States are explicitly created and managed
- **Type Safety**: Strong typing without dynamic access
- **No Magic**: Explicit state management without hidden dependencies
- **Better Testing**: Built-in testing utilities

### Migration Example

#### Before (GetX)
```dart
class CounterController extends GetxController {
  var count = 0.obs;
  
  void increment() => count++;
}

// Usage
Obx(() => Text('Count: ${controller.count}'))
```

#### After (Compose State)
```dart
final counter = mutableStateOf(0);

void increment() => counter.value++;

// Usage
StateBuilder<int>(
  state: counter,
  builder: (context, count) {
    return Text('Count: $count');
  },
)
```

### Migration Steps

1. **Replace Controllers with States**
   ```dart
   // Before
   class UserController extends GetxController {
     var user = Rx<User?>(null);
     var isLoading = false.obs;
   }
   
   // After
   final userState = apiStateOf<User>(() => fetchUser());
   ```

2. **Replace Obx with StateBuilder**
   ```dart
   // Before
   Obx(() => Text(controller.user.value?.name ?? ''))
   
   // After
   StateBuilder<User?>(
     state: userState,
     builder: (context, user) {
       return Text(user?.name ?? '');
     },
   )
   ```

3. **Replace GetBuilder with StateBuilder**
   ```dart
   // Before
   GetBuilder<UserController>(
     builder: (controller) {
       return Text(controller.user.value?.name ?? '');
     },
   )
   
   // After
   StateBuilder<ApiStateData<User>>(
     state: userState,
     builder: (context, apiData) {
       return Text(apiData.data?.name ?? '');
     },
   )
   ```

## Breaking Changes

### Version 0.1.0

1. **Constructor Changes**
   - `MutableState(value)` → `mutableStateOf(value)`
   - `PersistableState(key, defaultValue)` → `persistableStateOf(key, defaultValue: defaultValue)`
   - `ApiState(fetcher)` → `apiStateOf(fetcher)`

2. **Interface Changes**
   - Added required methods to `ObservableState` interface
   - Changed error handling signatures
   - Updated testing utilities

3. **Behavior Changes**
   - Automatic disposal is now default
   - Enhanced equality checking
   - Improved error handling

## Migration Tools

### Automated Migration Script

Create a script to help with common migrations:

```dart
// migration_helper.dart
import 'dart:io';

void main() {
  final directory = Directory('lib');
  
  directory.listSync(recursive: true).forEach((file) {
    if (file is File && file.path.endsWith('.dart')) {
      String content = file.readAsStringSync();
      
      // Replace old constructors
      content = content.replaceAll(
        RegExp(r'MutableState\(([^)]+)\)'),
        'mutableStateOf(\$1)',
      );
      
      content = content.replaceAll(
        RegExp(r'PersistableState\(([^,]+),\s*([^)]+)\)'),
        'persistableStateOf(\$1, defaultValue: \$2)',
      );
      
      content = content.replaceAll(
        RegExp(r'ApiState\(([^)]+)\)'),
        'apiStateOf(\$1)',
      );
      
      file.writeAsStringSync(content);
    }
  });
  
  print('Migration completed!');
}
```

### Manual Migration Checklist

- [ ] Update pubspec.yaml dependencies
- [ ] Replace old constructors with factory functions
- [ ] Add error handling where needed
- [ ] Update test imports and utilities
- [ ] Review and update disposal logic
- [ ] Test memory management
- [ ] Update documentation and comments

## Best Practices

### During Migration

1. **Incremental Migration**: Migrate one feature at a time
2. **Test Thoroughly**: Ensure functionality remains the same
3. **Monitor Performance**: Check for memory leaks and performance issues
4. **Update Documentation**: Keep docs in sync with changes
5. **Team Communication**: Ensure all team members understand changes

### After Migration

1. **Adopt New Features**: Take advantage of new capabilities
2. **Optimize Performance**: Use new performance features
3. **Improve Testing**: Use new testing utilities
4. **Monitor Memory**: Use built-in memory management tools
5. **Stay Updated**: Keep up with future releases

### Common Pitfalls

1. **Not Disposing States**: Even with automatic disposal, manual disposal may be needed in some cases
2. **Ignoring Error Handling**: Take advantage of new error handling capabilities
3. **Not Using Testing Tools**: Leverage new testing infrastructure
4. **Mixing Patterns**: Stick to one state management approach
5. **Over-Engineering**: Keep it simple, compose_state is designed for simplicity

This migration guide should help you successfully transition to compose_state or upgrade to the latest version. Remember to test thoroughly and migrate incrementally to ensure a smooth transition.