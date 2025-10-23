# DerivedState Fixes - Usage Examples

This document shows how to use the improved DerivedState with proper error handling, dependency validation, and circular dependency detection.

## Table of Contents

1. [Basic DerivedState Usage](#basic-derivedstate-usage)
2. [Error Handling](#error-handling)
3. [Dependency Validation](#dependency-validation)
4. [Circular Dependency Detection](#circular-dependency-detection)
5. [Advanced Examples](#advanced-examples)
6. [Best Practices](#best-practices)

## Basic DerivedState Usage

### Simple Derived State

```dart
import 'package:compose_state/compose_state.dart';

class CounterViewModel extends ComposeViewModel {
  late final count = mutableStateOf(0);
  late final multiplier = mutableStateOf(1);
  
  // Derived state that computes count * multiplier
  late final total = derivedStateOf(
    () => count.value * multiplier.value,
    dependencies: [count, multiplier],
  );
  
  // Derived state that computes if count is even
  late final isEven = derivedStateOf(
    () => count.value % 2 == 0,
    dependencies: [count],
  );
  
  // Derived state that computes count squared
  late final squared = derivedStateOf(
    () => count.value * count.value,
    dependencies: [count],
  );
  
  void increment() {
    count.value++;
  }
  
  void decrement() {
    count.value--;
  }
  
  void setMultiplier(int value) {
    multiplier.value = value;
  }
}
```

### Using DerivedState in Widgets

```dart
class CounterWidget extends StatelessWidget {
  final CounterViewModel viewModel;
  
  const CounterWidget({super.key, required this.viewModel});
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Basic count
        StateBuilder<int>(
          state: viewModel.count,
          builder: (context, count) => Text('Count: $count'),
        ),
        
        // Derived total
        StateBuilder<int>(
          state: viewModel.total,
          builder: (context, total) => Text('Total: $total'),
        ),
        
        // Derived isEven
        StateBuilder<bool>(
          state: viewModel.isEven,
          builder: (context, isEven) => Text(
            isEven ? 'Even' : 'Odd',
            style: TextStyle(
              color: isEven ? Colors.green : Colors.red,
            ),
          ),
        ),
        
        // Derived squared
        StateBuilder<int>(
          state: viewModel.squared,
          builder: (context, squared) => Text('Squared: $squared'),
        ),
        
        Row(
          children: [
            ElevatedButton(
              onPressed: () => viewModel.increment(),
              child: const Text('+'),
            ),
            ElevatedButton(
              onPressed: () => viewModel.decrement(),
              child: const Text('-'),
            ),
          ],
        ),
      ],
    );
  }
}
```

## Error Handling

### DerivedState with Error Handling

```dart
class ErrorHandlingViewModel extends ComposeViewModel {
  late final numerator = mutableStateOf(10);
  late final denominator = mutableStateOf(2);
  
  // Derived state with error handling
  late final division = derivedStateOf(
    () {
      if (denominator.value == 0) {
        throw StateValidationException(
          'Cannot divide by zero',
          violatedRule: 'division_by_zero',
        );
      }
      return numerator.value / denominator.value;
    },
    dependencies: [numerator, denominator],
  );
  
  // Derived state with safe computation
  late final safeDivision = derivedStateOf(
    () {
      try {
        if (denominator.value == 0) {
          return double.infinity;
        }
        return numerator.value / denominator.value;
      } catch (e) {
        return 0.0; // Fallback value
      }
    },
    dependencies: [numerator, denominator],
  );
  
  void setNumerator(int value) {
    numerator.value = value;
  }
  
  void setDenominator(int value) {
    denominator.value = value;
  }
}
```

### Error Handling in Widgets

```dart
class ErrorHandlingWidget extends StatelessWidget {
  final ErrorHandlingViewModel viewModel;
  
  const ErrorHandlingWidget({super.key, required this.viewModel});
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Numerator input
        TextField(
          onChanged: (value) {
            final num = int.tryParse(value);
            if (num != null) viewModel.setNumerator(num);
          },
          decoration: const InputDecoration(labelText: 'Numerator'),
        ),
        
        // Denominator input
        TextField(
          onChanged: (value) {
            final den = int.tryParse(value);
            if (den != null) viewModel.setDenominator(den);
          },
          decoration: const InputDecoration(labelText: 'Denominator'),
        ),
        
        // Division result with error handling
        StateBuilder<double>(
          state: viewModel.division,
          builder: (context, result) {
            return Text('Result: $result');
          },
        ),
        
        // Safe division result
        StateBuilder<double>(
          state: viewModel.safeDivision,
          builder: (context, result) {
            return Text('Safe Result: $result');
          },
        ),
      ],
    );
  }
}
```

## Dependency Validation

### Validating Dependencies

```dart
class DependencyValidationViewModel extends ComposeViewModel {
  late final user = mutableStateOf<User?>(null);
  late final settings = mutableStateOf<UserSettings?>(null);
  late final preferences = mutableStateOf<UserPreferences?>(null);
  
  // Derived state with dependency validation
  late final userProfile = derivedStateOf(
    () {
      if (user.value == null) {
        throw StateValidationException(
          'User is required for profile computation',
          violatedRule: 'user_required',
        );
      }
      
      if (settings.value == null) {
        throw StateValidationException(
          'Settings are required for profile computation',
          violatedRule: 'settings_required',
        );
      }
      
      return UserProfile(
        user: user.value!,
        settings: settings.value!,
        preferences: preferences.value,
      );
    },
    dependencies: [user, settings, preferences],
  );
  
  // Derived state with safe dependency handling
  late final safeUserProfile = derivedStateOf(
    () {
      if (user.value == null || settings.value == null) {
        return null; // Return null instead of throwing
      }
      
      return UserProfile(
        user: user.value!,
        settings: settings.value!,
        preferences: preferences.value,
      );
    },
    dependencies: [user, settings, preferences],
  );
  
  Future<void> loadUser() async {
    try {
      final userData = await userService.getCurrentUser();
      user.value = userData;
    } catch (e) {
      // Handle error
    }
  }
  
  Future<void> loadSettings() async {
    try {
      final settingsData = await settingsService.getSettings();
      settings.value = settingsData;
    } catch (e) {
      // Handle error
    }
  }
}
```

## Circular Dependency Detection

### Avoiding Circular Dependencies

```dart
class CircularDependencyViewModel extends ComposeViewModel {
  late final a = mutableStateOf(1);
  late final b = mutableStateOf(2);
  late final c = mutableStateOf(3);
  
  // This will be detected as circular dependency
  late final sumAB = derivedStateOf(
    () => a.value + b.value,
    dependencies: [a, b],
  );
  
  late final sumBC = derivedStateOf(
    () => b.value + c.value,
    dependencies: [b, c],
  );
  
  // This would create a circular dependency if uncommented
  // late final sumABC = derivedStateOf(
  //   () => sumAB.value + sumBC.value,
  //   dependencies: [sumAB, sumBC],
  // );
  
  // Safe alternative: compute directly from source states
  late final sumABC = derivedStateOf(
    () => a.value + b.value + c.value,
    dependencies: [a, b, c],
  );
  
  // Another safe alternative: use intermediate computation
  late final intermediateSum = derivedStateOf(
    () => a.value + b.value,
    dependencies: [a, b],
  );
  
  late final finalSum = derivedStateOf(
    () => intermediateSum.value + c.value,
    dependencies: [intermediateSum, c],
  );
}
```

### Complex Dependency Chain

```dart
class ComplexDependencyViewModel extends ComposeViewModel {
  late final items = mutableStateOf<List<Item>>([]);
  late final filter = mutableStateOf(ItemFilter.all);
  late final sortBy = mutableStateOf(SortBy.name);
  late final ascending = mutableStateOf(true);
  
  // Filtered items
  late final filteredItems = derivedStateOf(
    () {
      switch (filter.value) {
        case ItemFilter.all:
          return items.value;
        case ItemFilter.active:
          return items.value.where((item) => item.isActive).toList();
        case ItemFilter.completed:
          return items.value.where((item) => item.isCompleted).toList();
      }
    },
    dependencies: [items, filter],
  );
  
  // Sorted items
  late final sortedItems = derivedStateOf(
    () {
      final itemsToSort = filteredItems.value;
      final sorted = List<Item>.from(itemsToSort);
      
      switch (sortBy.value) {
        case SortBy.name:
          sorted.sort((a, b) => a.name.compareTo(b.name));
          break;
        case SortBy.date:
          sorted.sort((a, b) => a.date.compareTo(b.date));
          break;
        case SortBy.priority:
          sorted.sort((a, b) => a.priority.compareTo(b.priority));
          break;
      }
      
      if (!ascending.value) {
        sorted.reversed.toList();
      }
      
      return sorted;
    },
    dependencies: [filteredItems, sortBy, ascending],
  );
  
  // Item count
  late final itemCount = derivedStateOf(
    () => sortedItems.value.length,
    dependencies: [sortedItems],
  );
  
  // Active item count
  late final activeItemCount = derivedStateOf(
    () => sortedItems.value.where((item) => item.isActive).length,
    dependencies: [sortedItems],
  );
  
  // Completion percentage
  late final completionPercentage = derivedStateOf(
    () {
      if (itemCount.value == 0) return 0.0;
      return (itemCount.value - activeItemCount.value) / itemCount.value * 100;
    },
    dependencies: [itemCount, activeItemCount],
  );
}
```

## Advanced Examples

### Shopping Cart with Derived States

```dart
class ShoppingCartViewModel extends ComposeViewModel {
  late final items = mutableStateOf<List<CartItem>>([]);
  late final taxRate = mutableStateOf(0.08);
  late final discountCode = mutableStateOf<String?>(null);
  late final shippingCost = mutableStateOf(0.0);
  
  // Subtotal
  late final subtotal = derivedStateOf(
    () => items.value.fold(0.0, (sum, item) => sum + item.price * item.quantity),
    dependencies: [items],
  );
  
  // Tax amount
  late final taxAmount = derivedStateOf(
    () => subtotal.value * taxRate.value,
    dependencies: [subtotal, taxRate],
  );
  
  // Discount amount
  late final discountAmount = derivedStateOf(
    () {
      if (discountCode.value == null) return 0.0;
      
      // Apply discount logic
      switch (discountCode.value) {
        case 'SAVE10':
          return subtotal.value * 0.1;
        case 'SAVE20':
          return subtotal.value * 0.2;
        case 'FREESHIP':
          return shippingCost.value;
        default:
          return 0.0;
      }
    },
    dependencies: [subtotal, discountCode, shippingCost],
  );
  
  // Total before shipping
  late final totalBeforeShipping = derivedStateOf(
    () => subtotal.value + taxAmount.value - discountAmount.value,
    dependencies: [subtotal, taxAmount, discountAmount],
  );
  
  // Final total
  late final total = derivedStateOf(
    () => totalBeforeShipping.value + shippingCost.value,
    dependencies: [totalBeforeShipping, shippingCost],
  );
  
  // Item count
  late final itemCount = derivedStateOf(
    () => items.value.fold(0, (sum, item) => sum + item.quantity),
    dependencies: [items],
  );
  
  // Is empty
  late final isEmpty = derivedStateOf(
    () => items.value.isEmpty,
    dependencies: [items],
  );
  
  // Can checkout
  late final canCheckout = derivedStateOf(
    () => !isEmpty.value && total.value > 0,
    dependencies: [isEmpty, total],
  );
  
  void addItem(Product product, int quantity) {
    final existingItem = items.value.firstWhere(
      (item) => item.product.id == product.id,
      orElse: () => CartItem(product: product, quantity: 0, price: product.price),
    );
    
    if (existingItem.quantity > 0) {
      // Update existing item
      items.value = items.value.map((item) {
        if (item.product.id == product.id) {
          return item.copyWith(quantity: item.quantity + quantity);
        }
        return item;
      }).toList();
    } else {
      // Add new item
      items.value = [...items.value, existingItem.copyWith(quantity: quantity)];
    }
  }
  
  void removeItem(String productId) {
    items.value = items.value.where((item) => item.product.id != productId).toList();
  }
  
  void updateQuantity(String productId, int quantity) {
    if (quantity <= 0) {
      removeItem(productId);
      return;
    }
    
    items.value = items.value.map((item) {
      if (item.product.id == productId) {
        return item.copyWith(quantity: quantity);
      }
      return item;
    }).toList();
  }
  
  void applyDiscountCode(String code) {
    discountCode.value = code;
  }
  
  void removeDiscountCode() {
    discountCode.value = null;
  }
}
```

### Dashboard with Multiple Derived States

```dart
class DashboardViewModel extends ComposeViewModel {
  late final user = mutableStateOf<User?>(null);
  late final stats = mutableStateOf<Stats?>(null);
  late final notifications = mutableStateOf<List<Notification>>([]);
  late final isLoading = mutableStateOf(false);
  late final error = mutableStateOf<String?>(null);
  
  // User display name
  late final userDisplayName = derivedStateOf(
    () {
      if (user.value == null) return 'Guest';
      return '${user.value!.firstName} ${user.value!.lastName}';
    },
    dependencies: [user],
  );
  
  // Unread notification count
  late final unreadNotificationCount = derivedStateOf(
    () => notifications.value.where((n) => !n.isRead).length,
    dependencies: [notifications],
  );
  
  // Has notifications
  late final hasNotifications = derivedStateOf(
    () => notifications.value.isNotEmpty,
    dependencies: [notifications],
  );
  
  // Dashboard data
  late final dashboardData = derivedStateOf(
    () {
      if (user.value == null || stats.value == null) return null;
      
      return DashboardData(
        user: user.value!,
        stats: stats.value!,
        notifications: notifications.value,
        unreadCount: unreadNotificationCount.value,
      );
    },
    dependencies: [user, stats, notifications, unreadNotificationCount],
  );
  
  // Is ready
  late final isReady = derivedStateOf(
    () => !isLoading.value && error.value == null && dashboardData.value != null,
    dependencies: [isLoading, error, dashboardData],
  );
  
  // Error message
  late final errorMessage = derivedStateOf(
    () => error.value,
    dependencies: [error],
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
```

## Best Practices

### 1. Keep Derived States Simple

```dart
// ✅ Good: Simple derived state
late final total = derivedStateOf(
  () => items.value.fold(0.0, (sum, item) => sum + item.price),
  dependencies: [items],
);

// ❌ Bad: Complex derived state
late final complexCalculation = derivedStateOf(
  () {
    // 50+ lines of complex logic
    // Multiple API calls
    // Complex business logic
    return result;
  },
  dependencies: [items],
);
```

### 2. Use Meaningful Dependencies

```dart
// ✅ Good: Only include necessary dependencies
late final filteredItems = derivedStateOf(
  () => items.value.where((item) => item.isActive).toList(),
  dependencies: [items], // Only items, not filter
);

// ❌ Bad: Including unnecessary dependencies
late final filteredItems = derivedStateOf(
  () => items.value.where((item) => item.isActive).toList(),
  dependencies: [items, filter, sortBy], // filter and sortBy not used
);
```

### 3. Handle Errors Gracefully

```dart
// ✅ Good: Graceful error handling
late final safeCalculation = derivedStateOf(
  () {
    try {
      return performCalculation();
    } catch (e) {
      return defaultValue; // Fallback value
    }
  },
  dependencies: [items],
);

// ❌ Bad: Letting errors propagate
late final unsafeCalculation = derivedStateOf(
  () => performCalculation(), // Might throw
  dependencies: [items],
);
```

### 4. Avoid Circular Dependencies

```dart
// ✅ Good: Direct computation
late final total = derivedStateOf(
  () => a.value + b.value + c.value,
  dependencies: [a, b, c],
);

// ❌ Bad: Circular dependency
late final sumAB = derivedStateOf(() => a.value + b.value, dependencies: [a, b]);
late final sumBC = derivedStateOf(() => b.value + c.value, dependencies: [b, c]);
late final sumABC = derivedStateOf(
  () => sumAB.value + sumBC.value,
  dependencies: [sumAB, sumBC], // Circular dependency!
);
```

### 5. Use Type Safety

```dart
// ✅ Good: Type-safe derived state
late final userDisplayName = derivedStateOf<String>(
  () => user.value?.name ?? 'Guest',
  dependencies: [user],
);

// ❌ Bad: Using dynamic types
late final userDisplayName = derivedStateOf(
  () => user.value?.name ?? 'Guest',
  dependencies: [user],
);
```

The improved DerivedState provides robust error handling, dependency validation, and circular dependency detection, making it safe and reliable for complex state computations.
