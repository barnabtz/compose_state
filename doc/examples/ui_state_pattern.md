# UI State Pattern - Usage Examples

The UI State Pattern provides a clean, single-state solution that eliminates the need for nested StateBuilders. This pattern is perfect for complex UI states that need to handle loading, error, success, and empty states.

## Table of Contents

1. [Basic Usage](#basic-usage)
2. [ViewModel with UI State](#viewmodel-with-ui-state)
3. [Complex UI State Composition](#complex-ui-state-composition)
4. [Error Handling](#error-handling)
5. [Custom UI State Builders](#custom-ui-state-builders)
6. [Migration from Nested StateBuilders](#migration-from-nested-statebuilders)

## Basic Usage

### Simple UI State

```dart
import 'package:compose_state/compose_state.dart';

class TodoViewModel extends ComposeViewModel {
  // Source states
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
  
  Future<void> loadTodos() async {
    isLoading.value = true;
    error.value = null;
    
    try {
      final fetchedTodos = await todoService.getTodos();
      todos.value = fetchedTodos;
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }
}
```

### Using UiStateBuilder

```dart
class TodoListWidget extends StatelessWidget {
  final TodoViewModel viewModel;
  
  const TodoListWidget({super.key, required this.viewModel});
  
  @override
  Widget build(BuildContext context) {
    return UiStateBuilder<List<Todo>>(
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
    );
  }
}
```

## ViewModel with UI State

### Complete Todo App Example

```dart
class Todo {
  final String id;
  final String title;
  final String description;
  final bool isCompleted;
  final DateTime createdAt;
  
  const Todo({
    required this.id,
    required this.title,
    required this.description,
    required this.isCompleted,
    required this.createdAt,
  });
  
  Todo copyWith({
    String? id,
    String? title,
    String? description,
    bool? isCompleted,
    DateTime? createdAt,
  }) {
    return Todo(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class TodoViewModel extends ComposeViewModel with Persistable {
  // Source states
  late final isLoading = mutableStateOf(false);
  late final error = mutableStateOf<String?>(null);
  late final todos = mutableStateOf<List<Todo>>([]);
  late final filter = mutableStateOf(TodoFilter.all);
  late final searchQuery = mutableStateOf('');
  
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
      
      final filteredTodos = _getFilteredTodos();
      if (filteredTodos.isEmpty) {
        return UiState.empty();
      }
      
      return UiState.success(filteredTodos);
    },
    dependencies: [isLoading, error, todos, filter, searchQuery],
  );
  
  List<Todo> _getFilteredTodos() {
    var filtered = todos.value;
    
    // Apply search filter
    if (searchQuery.value.isNotEmpty) {
      filtered = filtered.where((todo) =>
          todo.title.toLowerCase().contains(searchQuery.value.toLowerCase()) ||
          todo.description.toLowerCase().contains(searchQuery.value.toLowerCase())
      ).toList();
    }
    
    // Apply status filter
    switch (filter.value) {
      case TodoFilter.all:
        return filtered;
      case TodoFilter.active:
        return filtered.where((todo) => !todo.isCompleted).toList();
      case TodoFilter.completed:
        return filtered.where((todo) => todo.isCompleted).toList();
    }
  }
  
  Future<void> loadTodos() async {
    isLoading.value = true;
    error.value = null;
    
    try {
      final fetchedTodos = await todoService.getTodos();
      todos.value = fetchedTodos;
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }
  
  Future<void> addTodo(String title, String description) async {
    try {
      final newTodo = Todo(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        description: description,
        isCompleted: false,
        createdAt: DateTime.now(),
      );
      
      todos.value = [...todos.value, newTodo];
      await persist('todos', todos.value);
    } catch (e) {
      error.value = 'Failed to add todo: $e';
    }
  }
  
  Future<void> toggleTodo(String id) async {
    try {
      todos.value = todos.value.map((todo) {
        if (todo.id == id) {
          return todo.copyWith(isCompleted: !todo.isCompleted);
        }
        return todo;
      }).toList();
      
      await persist('todos', todos.value);
    } catch (e) {
      error.value = 'Failed to toggle todo: $e';
    }
  }
  
  void setFilter(TodoFilter newFilter) {
    filter.value = newFilter;
  }
  
  void setSearchQuery(String query) {
    searchQuery.value = query;
  }
}

enum TodoFilter { all, active, completed }
```

## Complex UI State Composition

### Multiple UI States in One ViewModel

```dart
class DashboardViewModel extends ComposeViewModel {
  // Source states
  late final user = mutableStateOf<User?>(null);
  late final isLoading = mutableStateOf(false);
  late final error = mutableStateOf<String?>(null);
  late final stats = mutableStateOf<Stats?>(null);
  late final notifications = mutableStateOf<List<Notification>>([]);
  
  // Multiple UI states
  late final userUiState = createUiState<User>(
    'user',
    () {
      if (isLoading.value) return UiState.loading();
      if (error.value != null) return UiState.error(error.value!);
      if (user.value == null) return UiState.empty();
      return UiState.success(user.value!);
    },
    dependencies: [isLoading, error, user],
  );
  
  late final statsUiState = createUiState<Stats>(
    'stats',
    () {
      if (isLoading.value) return UiState.loading();
      if (error.value != null) return UiState.error(error.value!);
      if (stats.value == null) return UiState.empty();
      return UiState.success(stats.value!);
    },
    dependencies: [isLoading, error, stats],
  );
  
  late final notificationsUiState = createUiState<List<Notification>>(
    'notifications',
    () {
      if (isLoading.value) return UiState.loading();
      if (error.value != null) return UiState.error(error.value!);
      if (notifications.value.isEmpty) return UiState.empty();
      return UiState.success(notifications.value);
    },
    dependencies: [isLoading, error, notifications],
  );
  
  // Combined dashboard UI state
  late final dashboardUiState = createUiState<DashboardData>(
    'dashboard',
    () {
      if (isLoading.value) return UiState.loading();
      if (error.value != null) return UiState.error(error.value!);
      
      if (user.value == null || stats.value == null) {
        return UiState.empty();
      }
      
      return UiState.success(DashboardData(
        user: user.value!,
        stats: stats.value!,
        notifications: notifications.value,
      ));
    },
    dependencies: [isLoading, error, user, stats, notifications],
  );
  
  Future<void> loadDashboard() async {
    isLoading.value = true;
    error.value = null;
    
    try {
      final results = await Future.wait([
        userService.getCurrentUser(),
        statsService.getStats(),
        notificationService.getNotifications(),
      ]);
      
      user.value = results[0] as User;
      stats.value = results[1] as Stats;
      notifications.value = results[2] as List<Notification>;
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }
}

class DashboardData {
  final User user;
  final Stats stats;
  final List<Notification> notifications;
  
  const DashboardData({
    required this.user,
    required this.stats,
    required this.notifications,
  });
}
```

## Error Handling

### Advanced Error Handling with Recovery

```dart
class ApiViewModel extends ComposeViewModel {
  late final isLoading = mutableStateOf(false);
  late final error = mutableStateOf<String?>(null);
  late final data = mutableStateOf<List<ApiData>>([]);
  late final retryCount = mutableStateOf(0);
  
  late final uiState = createUiState<List<ApiData>>(
    'api_data',
    () {
      if (isLoading.value) {
        return UiState.loading();
      }
      
      if (error.value != null) {
        return UiState.error('${error.value} (Retry: ${retryCount.value})');
      }
      
      if (data.value.isEmpty) {
        return UiState.empty();
      }
      
      return UiState.success(data.value);
    },
    dependencies: [isLoading, error, data, retryCount],
  );
  
  Future<void> loadData() async {
    isLoading.value = true;
    error.value = null;
    
    try {
      final result = await apiService.getData();
      data.value = result;
      retryCount.value = 0; // Reset retry count on success
    } catch (e) {
      error.value = e.toString();
      retryCount.value++;
      
      // Auto-retry logic
      if (retryCount.value < 3) {
        await Future.delayed(Duration(seconds: retryCount.value));
        await loadData();
      }
    } finally {
      isLoading.value = false;
    }
  }
  
  void retry() {
    retryCount.value = 0;
    loadData();
  }
}
```

## Custom UI State Builders

### Reusable UI State Components

```dart
class LoadingWidget extends StatelessWidget {
  final String? message;
  
  const LoadingWidget({super.key, this.message});
  
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(message!),
          ],
        ],
      ),
    );
  }
}

class ErrorWidget extends StatelessWidget {
  final String error;
  final VoidCallback? onRetry;
  
  const ErrorWidget({
    super.key,
    required this.error,
    this.onRetry,
  });
  
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text('Error: $error'),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ],
      ),
    );
  }
}

class EmptyWidget extends StatelessWidget {
  final String message;
  final IconData icon;
  final VoidCallback? onAction;
  final String? actionText;
  
  const EmptyWidget({
    super.key,
    required this.message,
    this.icon = Icons.inbox,
    this.onAction,
    this.actionText,
  });
  
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          Text(message),
          if (onAction != null && actionText != null) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onAction,
              child: Text(actionText!),
            ),
          ],
        ],
      ),
    );
  }
}

// Usage with custom widgets
class TodoListWidget extends StatelessWidget {
  final TodoViewModel viewModel;
  
  const TodoListWidget({super.key, required this.viewModel});
  
  @override
  Widget build(BuildContext context) {
    return UiStateBuilder<List<Todo>>(
      state: viewModel.uiState,
      loadingBuilder: (context) => const LoadingWidget(
        message: 'Loading todos...',
      ),
      errorBuilder: (context, error) => ErrorWidget(
        error: error,
        onRetry: () => viewModel.loadTodos(),
      ),
      emptyBuilder: (context) => EmptyWidget(
        message: 'No todos yet',
        icon: Icons.checklist,
        onAction: () => _showAddTodoDialog(context),
        actionText: 'Add Todo',
      ),
      successBuilder: (context, todos) => ListView.builder(
        itemCount: todos.length,
        itemBuilder: (context, index) {
          final todo = todos[index];
          return TodoTile(todo: todo, onToggle: () => viewModel.toggleTodo(todo.id));
        },
      ),
    );
  }
  
  void _showAddTodoDialog(BuildContext context) {
    // Show add todo dialog
  }
}
```

## Migration from Nested StateBuilders

### Before: Nested StateBuilders

```dart
// OLD WAY - Nested StateBuilders
class OldTodoListWidget extends StatelessWidget {
  final TodoViewModel viewModel;
  
  const OldTodoListWidget({super.key, required this.viewModel});
  
  @override
  Widget build(BuildContext context) {
    return StateBuilder<bool>(
      state: viewModel.isLoading,
      builder: (context, isLoading) {
        if (isLoading) return const CircularProgressIndicator();
        
        return StateBuilder<String?>(
          state: viewModel.error,
          builder: (context, error) {
            if (error != null) {
              return Center(
                child: Column(
                  children: [
                    Text('Error: $error'),
                    ElevatedButton(
                      onPressed: () => viewModel.loadTodos(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }
            
            return StateBuilder<List<Todo>>(
              state: viewModel.todos,
              builder: (context, todos) {
                if (todos.isEmpty) {
                  return const Center(
                    child: Text('No todos yet'),
                  );
                }
                
                return ListView.builder(
                  itemCount: todos.length,
                  itemBuilder: (context, index) {
                    final todo = todos[index];
                    return ListTile(
                      title: Text(todo.title),
                      trailing: Checkbox(
                        value: todo.isCompleted,
                        onChanged: (value) => viewModel.toggleTodo(todo.id),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}
```

### After: Single UiStateBuilder

```dart
// NEW WAY - Single UiStateBuilder
class NewTodoListWidget extends StatelessWidget {
  final TodoViewModel viewModel;
  
  const NewTodoListWidget({super.key, required this.viewModel});
  
  @override
  Widget build(BuildContext context) {
    return UiStateBuilder<List<Todo>>(
      state: viewModel.uiState,
      loadingBuilder: (context) => const CircularProgressIndicator(),
      errorBuilder: (context, error) => Center(
        child: Column(
          children: [
            Text('Error: $error'),
            ElevatedButton(
              onPressed: () => viewModel.loadTodos(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      emptyBuilder: (context) => const Center(
        child: Text('No todos yet'),
      ),
      successBuilder: (context, todos) => ListView.builder(
        itemCount: todos.length,
        itemBuilder: (context, index) {
          final todo = todos[index];
          return ListTile(
            title: Text(todo.title),
            trailing: Checkbox(
              value: todo.isCompleted,
              onChanged: (value) => viewModel.toggleTodo(todo.id),
            ),
          );
        },
      ),
    );
  }
}
```

## Best Practices

### 1. Keep UI State Logic in ViewModel

```dart
class GoodViewModel extends ComposeViewModel {
  // ✅ Good: UI state logic in ViewModel
  late final uiState = createUiState<List<Item>>(
    'items',
    () {
      if (isLoading.value) return UiState.loading();
      if (error.value != null) return UiState.error(error.value!);
      if (items.value.isEmpty) return UiState.empty();
      return UiState.success(items.value);
    },
    dependencies: [isLoading, error, items],
  );
}

class BadViewModel extends ComposeViewModel {
  // ❌ Bad: UI state logic in widget
  late final isLoading = mutableStateOf(false);
  late final error = mutableStateOf<String?>(null);
  late final items = mutableStateOf<List<Item>>([]);
}
```

### 2. Use Meaningful UI State Keys

```dart
class GoodViewModel extends ComposeViewModel {
  // ✅ Good: Meaningful keys
  late final userUiState = createUiState<User>('user', () { ... });
  late final todosUiState = createUiState<List<Todo>>('todos', () { ... });
  late final settingsUiState = createUiState<Settings>('settings', () { ... });
}

class BadViewModel extends ComposeViewModel {
  // ❌ Bad: Generic keys
  late final uiState1 = createUiState<User>('state1', () { ... });
  late final uiState2 = createUiState<List<Todo>>('state2', () { ... });
}
```

### 3. Handle All UI States

```dart
class GoodWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return UiStateBuilder<List<Item>>(
      state: viewModel.uiState,
      // ✅ Good: Handle all states
      loadingBuilder: (context) => const LoadingWidget(),
      errorBuilder: (context, error) => ErrorWidget(error: error),
      emptyBuilder: (context) => const EmptyWidget(),
      successBuilder: (context, items) => ItemList(items: items),
    );
  }
}

class BadWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return UiStateBuilder<List<Item>>(
      state: viewModel.uiState,
      // ❌ Bad: Missing error and empty handlers
      successBuilder: (context, items) => ItemList(items: items),
    );
  }
}
```

### 4. Use Type Safety

```dart
class GoodViewModel extends ComposeViewModel {
  // ✅ Good: Type-safe UI states
  late final userUiState = createUiState<User>('user', () { ... });
  late final todosUiState = createUiState<List<Todo>>('todos', () { ... });
}

class BadViewModel extends ComposeViewModel {
  // ❌ Bad: Using dynamic types
  late final userUiState = createUiState<dynamic>('user', () { ... });
  late final todosUiState = createUiState<dynamic>('todos', () { ... });
}
```

This UI State Pattern provides a clean, maintainable solution for complex UI states while eliminating the need for nested StateBuilders. It's perfect for applications that need to handle multiple UI states in a type-safe, performant way.
