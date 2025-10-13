# Best Practices for Compose State

This guide outlines best practices for using the compose_state package effectively in your Flutter applications.

## Table of Contents

- [State Organization](#state-organization)
- [Performance Optimization](#performance-optimization)
- [Error Handling](#error-handling)
- [Memory Management](#memory-management)
- [Testing Strategies](#testing-strategies)
- [Architecture Patterns](#architecture-patterns)
- [Common Pitfalls](#common-pitfalls)
- [Code Style](#code-style)

## State Organization

### 1. Use Appropriate State Types

Choose the right state type for your use case:

```dart
// ✅ Good: Use MutableState for simple reactive data
final counter = mutableStateOf(0);

// ✅ Good: Use PersistableState for data that needs persistence
final userPreferences = persistableStateOf<UserPrefs>(
  'user_prefs',
  defaultValue: UserPrefs.defaults(),
);

// ✅ Good: Use ApiState for async data fetching
final userState = apiStateOf<User>(() => fetchUser());

// ✅ Good: Use DerivedState for computed values
final fullName = derivedStateOf(() => '${firstName.value} ${lastName.value}');

// ❌ Bad: Using MutableState for async operations
final userData = mutableStateOf<User?>(null);
// Then manually managing loading states, errors, etc.
```

### 2. Group Related States

Organize related states together using classes or modules:

```dart
// ✅ Good: Group related states in a class
class UserProfileState {
  final user = apiStateOf<User>(() => fetchUser());
  final avatar = apiStateOf<String>(() => fetchAvatar());
  final preferences = persistableStateOf<UserPrefs>(
    'user_prefs',
    defaultValue: UserPrefs.defaults(),
  );
  
  late final displayName = derivedStateOf(() {
    final userData = user.data;
    return userData?.displayName ?? 'Anonymous';
  });
}

// ❌ Bad: Scattered global states
final globalUser = apiStateOf<User>(() => fetchUser());
final globalAvatar = apiStateOf<String>(() => fetchAvatar());
final globalPrefs = persistableStateOf<UserPrefs>('prefs', defaultValue: UserPrefs.defaults());
```

### 3. Use Meaningful Names

Choose descriptive names for your states:

```dart
// ✅ Good: Descriptive names
final currentUserProfile = apiStateOf<UserProfile>(() => fetchUserProfile());
final shoppingCartItems = mutableStateOf<List<CartItem>>([]);
final isUserAuthenticated = derivedStateOf(() => authToken.value != null);

// ❌ Bad: Generic or unclear names
final data = apiStateOf<UserProfile>(() => fetchUserProfile());
final items = mutableStateOf<List<CartItem>>([]);
final flag = derivedStateOf(() => authToken.value != null);
```

### 4. Scope States Appropriately

Consider the scope and lifetime of your states:

```dart
// ✅ Good: App-level state for global data
class AppState {
  static final theme = persistableStateOf<ThemeMode>(
    'theme_mode',
    defaultValue: ThemeMode.system,
  );
  
  static final user = apiStateOf<User?>(() => getCurrentUser());
}

// ✅ Good: Feature-level state for specific features
class ShoppingCartState {
  final items = mutableStateOf<List<CartItem>>([]);
  final total = derivedStateOf(() => 
    items.value.fold(0.0, (sum, item) => sum + item.price));
}

// ✅ Good: Widget-level state for temporary UI state
class _MyWidgetState extends State<MyWidget> {
  final isExpanded = mutableStateOf(false);
  
  @override
  void dispose() {
    isExpanded.dispose();
    super.dispose();
  }
}
```

## Performance Optimization

### 1. Use Custom Equality Checkers

Implement custom equality for complex objects to prevent unnecessary rebuilds:

```dart
// ✅ Good: Custom equality for complex objects
final userState = mutableStateOf(
  User(id: 1, name: 'John', email: 'john@example.com'),
  equalityChecker: EqualityChecker<User>(
    customEquals: (a, b) => a.id == b.id && a.name == b.name && a.email == b.email,
    customHashCode: (user) => Object.hash(user.id, user.name, user.email),
  ),
);

// ❌ Bad: No custom equality for complex objects
final userState = mutableStateOf(User(id: 1, name: 'John', email: 'john@example.com'));
// This will trigger rebuilds even when the content is the same
```

### 2. Use OptimizedStateBuilder for Complex Widgets

Use `OptimizedStateBuilder` for widgets that are expensive to rebuild:

```dart
// ✅ Good: Optimized builder for expensive widgets
OptimizedStateBuilder<List<Item>>(
  state: itemsState,
  equalityChecker: EqualityChecker<List<Item>>(),
  builder: (context, items) {
    return ExpensiveItemList(items: items);
  },
)

// ❌ Bad: Regular StateBuilder for expensive widgets
StateBuilder<List<Item>>(
  state: itemsState,
  builder: (context, items) {
    return ExpensiveItemList(items: items);
  },
)
```

### 3. Batch State Updates

Use notification batching for multiple related updates:

```dart
// ✅ Good: Batch multiple updates
final batcher = NotificationBatcher();

void updateUserProfile(String name, String email, int age) {
  batcher.batch(() {
    userName.value = name;
    userEmail.value = email;
    userAge.value = age;
  });
}

// ❌ Bad: Individual updates causing multiple rebuilds
void updateUserProfile(String name, String email, int age) {
  userName.value = name;   // Rebuild 1
  userEmail.value = email; // Rebuild 2
  userAge.value = age;     // Rebuild 3
}
```

### 4. Use DerivedState for Computed Values

Prefer `DerivedState` over manual computation in builders:

```dart
// ✅ Good: Use DerivedState for computed values
final firstName = mutableStateOf('John');
final lastName = mutableStateOf('Doe');
final fullName = derivedStateOf(() => '${firstName.value} ${lastName.value}');

StateBuilder<String>(
  state: fullName,
  builder: (context, name) => Text(name),
)

// ❌ Bad: Computing in builder
StateBuilder<String>(
  state: firstName,
  builder: (context, first) {
    return StateBuilder<String>(
      state: lastName,
      builder: (context, last) => Text('$first $last'),
    );
  },
)
```

## Error Handling

### 1. Configure Appropriate Error Strategies

Choose error handling strategies based on your use case:

```dart
// ✅ Good: Retry strategy for network operations
final apiState = apiStateOf<Data>(
  () => fetchData(),
  errorHandler: StateErrorHandler(
    defaultStrategy: RetryStrategy(
      maxAttempts: 3,
      backoffMultiplier: 2.0,
      initialDelay: Duration(seconds: 1),
    ),
  ),
);

// ✅ Good: Fallback strategy for non-critical data
final recommendationsState = apiStateOf<List<Item>>(
  () => fetchRecommendations(),
  errorHandler: StateErrorHandler(
    defaultStrategy: FallbackStrategy(fallbackValue: []),
  ),
);

// ✅ Good: Circuit breaker for unreliable services
final externalServiceState = apiStateOf<ExternalData>(
  () => fetchFromExternalService(),
  errorHandler: StateErrorHandler(
    defaultStrategy: CircuitBreakerStrategy(
      failureThreshold: 5,
      timeout: Duration(minutes: 2),
    ),
  ),
);
```

### 2. Handle Errors in UI

Provide meaningful error handling in your UI:

```dart
// ✅ Good: Comprehensive error handling in UI
StateBuilder<ApiStateData<User>>(
  state: userState,
  builder: (context, apiData) {
    if (apiData.isLoading) {
      return Center(child: CircularProgressIndicator());
    }
    
    if (apiData.hasError) {
      return ErrorWidget(
        error: apiData.error.toString(),
        onRetry: () => userState.refresh(),
        canRetry: apiData.error is! AuthenticationException,
      );
    }
    
    return UserProfile(user: apiData.data!);
  },
)

// ❌ Bad: No error handling
StateBuilder<ApiStateData<User>>(
  state: userState,
  builder: (context, apiData) {
    return UserProfile(user: apiData.data!); // Will crash if data is null
  },
)
```

### 3. Use Error Boundaries

Wrap error-prone widgets with error boundaries:

```dart
// ✅ Good: Error boundary for error-prone sections
ErrorBoundary(
  child: ComplexFeatureWidget(),
  onError: (error, stackTrace) {
    return ErrorFallbackWidget(
      error: error,
      onRestart: () => Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => ComplexFeatureWidget()),
      ),
    );
  },
)
```

## Memory Management

### 1. Dispose States When Appropriate

While states have automatic disposal, manual disposal may be needed in some cases:

```dart
// ✅ Good: Manual disposal for widget-scoped states
class _MyWidgetState extends State<MyWidget> {
  final localState = mutableStateOf('initial');
  
  @override
  void dispose() {
    localState.dispose();
    super.dispose();
  }
}

// ✅ Good: Automatic disposal for global states (no manual disposal needed)
final globalState = mutableStateOf('global');
```

### 2. Monitor Memory Usage

Regularly check memory usage in development:

```dart
// ✅ Good: Monitor memory in debug builds
void checkMemoryUsage() {
  if (kDebugMode) {
    final stats = StateManager.instance.getMemoryStats();
    print('Active states: ${stats.activeStates}');
    
    final leaks = StateManager.instance.detectPotentialLeaks();
    if (leaks.isNotEmpty) {
      print('Potential leaks: $leaks');
    }
  }
}
```

### 3. Use Weak References for Listeners

Avoid strong references that prevent garbage collection:

```dart
// ✅ Good: The state management system handles weak references automatically
final state = mutableStateOf('value');
state.addListener(() {
  // Listener is automatically managed
});

// ❌ Bad: Creating strong references manually
final state = mutableStateOf('value');
final strongRef = state; // Keeps state alive unnecessarily
```

## Testing Strategies

### 1. Use Mock States for Testing

Leverage the built-in testing utilities:

```dart
// ✅ Good: Use mock states for predictable testing
test('should handle user interaction correctly', () {
  final mockUserState = mockStateOf<User?>(null);
  final viewModel = UserViewModel(userState: mockUserState);
  
  // Control the mock behavior
  mockUserState.returnValue(User(id: 1, name: 'Test User'));
  
  expect(viewModel.displayName, 'Test User');
});
```

### 2. Test State Interactions

Test how states interact with each other:

```dart
// ✅ Good: Test state dependencies
test('should update derived state when dependencies change', () {
  final firstName = mutableStateOf('John');
  final lastName = mutableStateOf('Doe');
  final fullName = derivedStateOf(() => '${firstName.value} ${lastName.value}');
  
  expect(fullName.value, 'John Doe');
  
  firstName.value = 'Jane';
  expect(fullName.value, 'Jane Doe');
});
```

### 3. Test Error Scenarios

Include error scenarios in your tests:

```dart
// ✅ Good: Test error handling
test('should handle API errors correctly', () async {
  final mockApiState = mockStateOf<ApiStateData<User>>(
    ApiStateData<User>(isLoading: false, hasError: true, error: 'Network error'),
  );
  
  final viewModel = UserViewModel(userState: mockApiState);
  
  expect(viewModel.hasError, true);
  expect(viewModel.errorMessage, 'Network error');
});
```

## Architecture Patterns

### 1. MVVM Pattern

Use ViewModels to separate business logic from UI:

```dart
// ✅ Good: ViewModel pattern
class UserProfileViewModel {
  final _userState = apiStateOf<User>(() => fetchUser());
  final _isEditing = mutableStateOf(false);
  
  // Expose read-only states
  ApiState<User> get userState => _userState;
  ObservableState<bool> get isEditing => _isEditing;
  
  // Business logic methods
  Future<void> refreshUser() => _userState.refresh();
  void startEditing() => _isEditing.value = true;
  void stopEditing() => _isEditing.value = false;
}

// Usage in widget
class UserProfileScreen extends StatelessWidget {
  final UserProfileViewModel viewModel = UserProfileViewModel();
  
  @override
  Widget build(BuildContext context) {
    return StateBuilder<ApiStateData<User>>(
      state: viewModel.userState,
      builder: (context, userData) {
        // UI logic only
      },
    );
  }
}
```

### 2. Repository Pattern

Use repositories for data access:

```dart
// ✅ Good: Repository pattern
abstract class UserRepository {
  Future<User> getUser(String id);
  Future<void> updateUser(User user);
}

class ApiUserRepository implements UserRepository {
  @override
  Future<User> getUser(String id) => ApiService.fetchUser(id);
  
  @override
  Future<void> updateUser(User user) => ApiService.updateUser(user);
}

class UserViewModel {
  final UserRepository _repository;
  
  UserViewModel(this._repository);
  
  late final userState = apiStateOf<User>(() => _repository.getUser(userId));
}
```

### 3. Service Layer

Use services for complex business logic:

```dart
// ✅ Good: Service layer
class AuthenticationService {
  final _isAuthenticated = mutableStateOf(false);
  final _currentUser = mutableStateOf<User?>(null);
  
  ObservableState<bool> get isAuthenticated => _isAuthenticated;
  ObservableState<User?> get currentUser => _currentUser;
  
  Future<void> login(String email, String password) async {
    try {
      final user = await ApiService.login(email, password);
      _currentUser.value = user;
      _isAuthenticated.value = true;
    } catch (e) {
      _isAuthenticated.value = false;
      rethrow;
    }
  }
  
  void logout() {
    _currentUser.value = null;
    _isAuthenticated.value = false;
  }
}
```

## Common Pitfalls

### 1. Avoid Circular Dependencies

Be careful with derived states that might create circular dependencies:

```dart
// ❌ Bad: Circular dependency
final stateA = mutableStateOf(0);
final stateB = derivedStateOf(() => stateA.value + stateC.value);
final stateC = derivedStateOf(() => stateB.value * 2); // Circular!

// ✅ Good: Clear dependency chain
final baseValue = mutableStateOf(0);
final doubledValue = derivedStateOf(() => baseValue.value * 2);
final finalValue = derivedStateOf(() => baseValue.value + doubledValue.value);
```

### 2. Don't Overuse Global State

Avoid making everything global:

```dart
// ❌ Bad: Everything is global
final globalCounter = mutableStateOf(0);
final globalText = mutableStateOf('');
final globalFlag = mutableStateOf(false);

// ✅ Good: Appropriate scoping
class CounterWidget extends StatelessWidget {
  final counter = mutableStateOf(0); // Widget-scoped
  
  @override
  Widget build(BuildContext context) {
    // ...
  }
}

final appTheme = persistableStateOf<ThemeMode>( // App-scoped
  'theme',
  defaultValue: ThemeMode.system,
);
```

### 3. Handle Async Operations Properly

Don't mix async operations with synchronous state updates:

```dart
// ❌ Bad: Manual async handling with MutableState
final userData = mutableStateOf<User?>(null);
final isLoading = mutableStateOf(false);
final error = mutableStateOf<String?>(null);

Future<void> loadUser() async {
  isLoading.value = true;
  error.value = null;
  try {
    final user = await fetchUser();
    userData.value = user;
  } catch (e) {
    error.value = e.toString();
  } finally {
    isLoading.value = false;
  }
}

// ✅ Good: Use ApiState for async operations
final userState = apiStateOf<User>(() => fetchUser());
// Automatically handles loading, error, and data states
```

## Code Style

### 1. Consistent Naming Conventions

Use consistent naming for your states:

```dart
// ✅ Good: Consistent naming
final userName = mutableStateOf('');
final userEmail = mutableStateOf('');
final userAge = mutableStateOf(0);

final userState = apiStateOf<User>(() => fetchUser());
final postsState = apiStateOf<List<Post>>(() => fetchPosts());

// ❌ Bad: Inconsistent naming
final name = mutableStateOf('');
final emailAddress = mutableStateOf('');
final ageOfUser = mutableStateOf(0);
```

### 2. Group Imports

Organize your imports logically:

```dart
// ✅ Good: Organized imports
import 'package:flutter/material.dart';

import 'package:compose_state/compose_state.dart';
import 'package:compose_state/testing.dart';

import '../models/user.dart';
import '../services/api_service.dart';
```

### 3. Document Complex States

Add documentation for complex state logic:

```dart
// ✅ Good: Documented complex state
/// Manages the shopping cart state with automatic persistence
/// and real-time price calculations.
class ShoppingCartState {
  /// List of items currently in the cart
  final items = persistableStateOf<List<CartItem>>(
    'cart_items',
    defaultValue: [],
    serializer: (items) => items.map((item) => item.toJson()).toList(),
    deserializer: (json) => (json as List)
        .map((item) => CartItem.fromJson(item))
        .toList(),
  );
  
  /// Total price of all items in the cart, including tax
  late final totalPrice = derivedStateOf(() {
    final cartItems = items.value;
    final subtotal = cartItems.fold(0.0, (sum, item) => sum + item.totalPrice);
    return subtotal * 1.08; // Add 8% tax
  });
}
```

By following these best practices, you'll create more maintainable, performant, and reliable Flutter applications with compose_state.