# State Composition - Usage Examples

The State Composition system provides powerful widgets for observing multiple states without nesting StateBuilders. This system is perfect for complex UIs that need to observe multiple states simultaneously.

## Table of Contents

1. [StateComposer - Multiple States](#statecomposer---multiple-states)
2. [StateSelector - Selective Observation](#stateselector---selective-observation)
3. [StateProvider/Consumer - Dependency Injection](#stateproviderconsumer---dependency-injection)
4. [MultiStateBuilder - Enhanced StateBuilder](#multistatebuilder---enhanced-statebuilder)
5. [Real-World Examples](#real-world-examples)
6. [Performance Considerations](#performance-considerations)

## StateComposer - Multiple States

### Basic Usage

```dart
import 'package:compose_state/compose_state.dart';

class UserProfileViewModel extends ComposeViewModel {
  late final user = mutableStateOf<User?>(null);
  late final isLoading = mutableStateOf(false);
  late final error = mutableStateOf<String?>(null);
  late final settings = mutableStateOf<UserSettings?>(null);
  late final preferences = mutableStateOf<UserPreferences?>(null);
}

class UserProfileWidget extends StatelessWidget {
  final UserProfileViewModel viewModel;
  
  const UserProfileWidget({super.key, required this.viewModel});
  
  @override
  Widget build(BuildContext context) {
    return StateComposer(
      states: {
        'user': viewModel.user,
        'isLoading': viewModel.isLoading,
        'error': viewModel.error,
        'settings': viewModel.settings,
        'preferences': viewModel.preferences,
      },
      builder: (context, stateValues) {
        final user = stateValues['user'] as User?;
        final isLoading = stateValues['isLoading'] as bool;
        final error = stateValues['error'] as String?;
        final settings = stateValues['settings'] as UserSettings?;
        final preferences = stateValues['preferences'] as UserPreferences?;
        
        if (isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (error != null) {
          return Center(
            child: Column(
              children: [
                Text('Error: $error'),
                ElevatedButton(
                  onPressed: () => viewModel.loadUser(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        
        if (user == null) {
          return const Center(child: Text('No user data'));
        }
        
        return UserProfileContent(
          user: user,
          settings: settings,
          preferences: preferences,
        );
      },
    );
  }
}
```

### Advanced StateComposer with Error Handling

```dart
class AdvancedStateComposerExample extends StatelessWidget {
  final DashboardViewModel viewModel;
  
  const AdvancedStateComposerExample({super.key, required this.viewModel});
  
  @override
  Widget build(BuildContext context) {
    return StateComposer(
      states: {
        'user': viewModel.user,
        'stats': viewModel.stats,
        'notifications': viewModel.notifications,
        'isLoading': viewModel.isLoading,
        'error': viewModel.error,
      },
      errorBuilder: (context, error) => CustomErrorWidget(
        error: error,
        onRetry: () => viewModel.loadDashboard(),
      ),
      builder: (context, stateValues) {
        final user = stateValues['user'] as User?;
        final stats = stateValues['stats'] as Stats?;
        final notifications = stateValues['notifications'] as List<Notification>?;
        final isLoading = stateValues['isLoading'] as bool;
        final error = stateValues['error'] as String?;
        
        return DashboardContent(
          user: user,
          stats: stats,
          notifications: notifications ?? [],
          isLoading: isLoading,
          error: error,
        );
      },
    );
  }
}
```

## StateSelector - Selective Observation

### Observing Specific States

```dart
class UserSettingsWidget extends StatelessWidget {
  final UserProfileViewModel viewModel;
  
  const UserSettingsWidget({super.key, required this.viewModel});
  
  @override
  Widget build(BuildContext context) {
    return StateSelector(
      states: {
        'user': viewModel.user,
        'settings': viewModel.settings,
        'preferences': viewModel.preferences,
        'isLoading': viewModel.isLoading,
        'error': viewModel.error,
      },
      selectKeys: ['user', 'settings', 'preferences'], // Only observe these
      builder: (context, selectedValues) {
        final user = selectedValues['user'] as User?;
        final settings = selectedValues['settings'] as UserSettings?;
        final preferences = selectedValues['preferences'] as UserPreferences?;
        
        return UserSettingsContent(
          user: user,
          settings: settings,
          preferences: preferences,
        );
      },
    );
  }
}
```

### Dynamic State Selection

```dart
class DynamicStateSelectorExample extends StatefulWidget {
  final DashboardViewModel viewModel;
  
  const DynamicStateSelectorExample({super.key, required this.viewModel});
  
  @override
  State<DynamicStateSelectorExample> createState() => _DynamicStateSelectorExampleState();
}

class _DynamicStateSelectorExampleState extends State<DynamicStateSelectorExample> {
  List<String> selectedKeys = ['user', 'stats'];
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Toggle buttons for state selection
        Wrap(
          children: [
            'user', 'stats', 'notifications', 'isLoading', 'error'
          ].map((key) => FilterChip(
            label: Text(key),
            selected: selectedKeys.contains(key),
            onSelected: (selected) {
              setState(() {
                if (selected) {
                  selectedKeys.add(key);
                } else {
                  selectedKeys.remove(key);
                }
              });
            },
          )).toList(),
        ),
        
        // StateSelector with dynamic selection
        StateSelector(
          states: {
            'user': widget.viewModel.user,
            'stats': widget.viewModel.stats,
            'notifications': widget.viewModel.notifications,
            'isLoading': widget.viewModel.isLoading,
            'error': widget.viewModel.error,
          },
          selectKeys: selectedKeys,
          builder: (context, selectedValues) {
            return Column(
              children: selectedValues.entries.map((entry) {
                return ListTile(
                  title: Text(entry.key),
                  subtitle: Text(entry.value.toString()),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
```

## StateProvider/Consumer - Dependency Injection

### Setting up StateProvider

```dart
class AppStateProvider extends StatelessWidget {
  final Widget child;
  
  const AppStateProvider({super.key, required this.child});
  
  @override
  Widget build(BuildContext context) {
    return StateProvider(
      states: {
        'user': UserViewModel(),
        'settings': SettingsViewModel(),
        'notifications': NotificationViewModel(),
        'theme': ThemeViewModel(),
      },
      child: child,
    );
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: AppStateProvider(
        child: HomePage(),
      ),
    );
  }
}
```

### Using StateConsumer

```dart
class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          // Consumer for user state
          StateConsumer(
            stateKeys: ['user'],
            builder: (context, states) {
              final user = states['user'] as UserViewModel?;
              return Text(user?.user.value?.name ?? 'Guest');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Consumer for multiple states
          StateConsumer(
            stateKeys: ['user', 'settings', 'theme'],
            builder: (context, states) {
              final user = states['user'] as UserViewModel?;
              final settings = states['settings'] as SettingsViewModel?;
              final theme = states['theme'] as ThemeViewModel?;
              
              return UserProfileCard(
                user: user?.user.value,
                settings: settings?.settings.value,
                theme: theme?.theme.value,
              );
            },
          ),
          
          // Consumer for notifications
          StateConsumer(
            stateKeys: ['notifications'],
            builder: (context, states) {
              final notifications = states['notifications'] as NotificationViewModel?;
              return NotificationList(
                notifications: notifications?.notifications.value ?? [],
              );
            },
          ),
        ],
      ),
    );
  }
}
```

### Nested StateProvider

```dart
class NestedStateProviderExample extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StateProvider(
      states: {
        'global': GlobalState(),
        'app': AppState(),
      },
      child: StateProvider(
        states: {
          'page': PageState(),
          'local': LocalState(),
        },
        child: PageContent(),
      ),
    );
  }
}

class PageContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StateConsumer(
      stateKeys: ['global', 'app', 'page', 'local'],
      builder: (context, states) {
        final global = states['global'] as GlobalState?;
        final app = states['app'] as AppState?;
        final page = states['page'] as PageState?;
        final local = states['local'] as LocalState?;
        
        return PageContent(
          global: global,
          app: app,
          page: page,
          local: local,
        );
      },
    );
  }
}
```

## MultiStateBuilder - Enhanced StateBuilder

### Basic MultiStateBuilder

```dart
class MultiStateBuilderExample extends StatelessWidget {
  final UserProfileViewModel viewModel;
  
  const MultiStateBuilderExample({super.key, required this.viewModel});
  
  @override
  Widget build(BuildContext context) {
    return MultiStateBuilder(
      states: {
        'user': viewModel.user,
        'settings': viewModel.settings,
        'isLoading': viewModel.isLoading,
        'error': viewModel.error,
      },
      builder: (context, states) {
        final user = states['user'] as User?;
        final settings = states['settings'] as UserSettings?;
        final isLoading = states['isLoading'] as bool;
        final error = states['error'] as String?;
        
        if (isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (error != null) {
          return Center(child: Text('Error: $error'));
        }
        
        return UserProfileContent(
          user: user,
          settings: settings,
        );
      },
    );
  }
}
```

### MultiStateBuilder with Error Handling

```dart
class MultiStateBuilderWithErrorHandling extends StatelessWidget {
  final DashboardViewModel viewModel;
  
  const MultiStateBuilderWithErrorHandling({super.key, required this.viewModel});
  
  @override
  Widget build(BuildContext context) {
    return MultiStateBuilder(
      states: {
        'user': viewModel.user,
        'stats': viewModel.stats,
        'notifications': viewModel.notifications,
        'isLoading': viewModel.isLoading,
        'error': viewModel.error,
      },
      errorBuilder: (context, error) => CustomErrorWidget(
        error: error,
        onRetry: () => viewModel.loadDashboard(),
      ),
      builder: (context, states) {
        final user = states['user'] as User?;
        final stats = states['stats'] as Stats?;
        final notifications = states['notifications'] as List<Notification>?;
        final isLoading = states['isLoading'] as bool;
        final error = states['error'] as String?;
        
        return DashboardContent(
          user: user,
          stats: stats,
          notifications: notifications ?? [],
          isLoading: isLoading,
          error: error,
        );
      },
    );
  }
}
```

## Real-World Examples

### E-commerce Product Page

```dart
class ProductPageViewModel extends ComposeViewModel {
  late final product = mutableStateOf<Product?>(null);
  late final isLoading = mutableStateOf(false);
  late final error = mutableStateOf<String?>(null);
  late final cart = mutableStateOf<Cart?>(null);
  late final wishlist = mutableStateOf<List<Product>>([]);
  late final reviews = mutableStateOf<List<Review>>([]);
  late final relatedProducts = mutableStateOf<List<Product>>([]);
  late final user = mutableStateOf<User?>(null);
}

class ProductPageWidget extends StatelessWidget {
  final ProductPageViewModel viewModel;
  final String productId;
  
  const ProductPageWidget({
    super.key,
    required this.viewModel,
    required this.productId,
  });
  
  @override
  Widget build(BuildContext context) {
    return StateComposer(
      states: {
        'product': viewModel.product,
        'isLoading': viewModel.isLoading,
        'error': viewModel.error,
        'cart': viewModel.cart,
        'wishlist': viewModel.wishlist,
        'reviews': viewModel.reviews,
        'relatedProducts': viewModel.relatedProducts,
        'user': viewModel.user,
      },
      builder: (context, states) {
        final product = states['product'] as Product?;
        final isLoading = states['isLoading'] as bool;
        final error = states['error'] as String?;
        final cart = states['cart'] as Cart?;
        final wishlist = states['wishlist'] as List<Product>;
        final reviews = states['reviews'] as List<Review>;
        final relatedProducts = states['relatedProducts'] as List<Product>;
        final user = states['user'] as User?;
        
        if (isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (error != null) {
          return Center(
            child: Column(
              children: [
                Text('Error: $error'),
                ElevatedButton(
                  onPressed: () => viewModel.loadProduct(productId),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        
        if (product == null) {
          return const Center(child: Text('Product not found'));
        }
        
        return ProductPageContent(
          product: product,
          cart: cart,
          wishlist: wishlist,
          reviews: reviews,
          relatedProducts: relatedProducts,
          user: user,
          onAddToCart: () => viewModel.addToCart(product),
          onAddToWishlist: () => viewModel.addToWishlist(product),
          onWriteReview: (review) => viewModel.submitReview(review),
        );
      },
    );
  }
}
```

### Chat Application

```dart
class ChatViewModel extends ComposeViewModel {
  late final messages = mutableStateOf<List<Message>>([]);
  late final isLoading = mutableStateOf(false);
  late final error = mutableStateOf<String?>(null);
  late final user = mutableStateOf<User?>(null);
  late final chat = mutableStateOf<Chat?>(null);
  late final typingUsers = mutableStateOf<Set<String>>({});
  late final onlineUsers = mutableStateOf<Set<String>>({});
  late final unreadCount = mutableStateOf(0);
}

class ChatWidget extends StatelessWidget {
  final ChatViewModel viewModel;
  
  const ChatWidget({super.key, required this.viewModel});
  
  @override
  Widget build(BuildContext context) {
    return StateComposer(
      states: {
        'messages': viewModel.messages,
        'isLoading': viewModel.isLoading,
        'error': viewModel.error,
        'user': viewModel.user,
        'chat': viewModel.chat,
        'typingUsers': viewModel.typingUsers,
        'onlineUsers': viewModel.onlineUsers,
        'unreadCount': viewModel.unreadCount,
      },
      builder: (context, states) {
        final messages = states['messages'] as List<Message>;
        final isLoading = states['isLoading'] as bool;
        final error = states['error'] as String?;
        final user = states['user'] as User?;
        final chat = states['chat'] as Chat?;
        final typingUsers = states['typingUsers'] as Set<String>;
        final onlineUsers = states['onlineUsers'] as Set<String>;
        final unreadCount = states['unreadCount'] as int;
        
        return ChatContent(
          messages: messages,
          isLoading: isLoading,
          error: error,
          user: user,
          chat: chat,
          typingUsers: typingUsers,
          onlineUsers: onlineUsers,
          unreadCount: unreadCount,
          onSendMessage: (text) => viewModel.sendMessage(text),
          onTyping: () => viewModel.setTyping(true),
          onStopTyping: () => viewModel.setTyping(false),
        );
      },
    );
  }
}
```

## Performance Considerations

### Optimizing StateComposer

```dart
class OptimizedStateComposerExample extends StatelessWidget {
  final DashboardViewModel viewModel;
  
  const OptimizedStateComposerExample({super.key, required this.viewModel});
  
  @override
  Widget build(BuildContext context) {
    return StateComposer(
      states: {
        'user': viewModel.user,
        'stats': viewModel.stats,
        'notifications': viewModel.notifications,
        'isLoading': viewModel.isLoading,
        'error': viewModel.error,
      },
      // Enable performance optimizations
      enableOptimizations: true,
      // Custom equality checker for better performance
      equalityChecker: (oldValues, newValues) {
        // Only rebuild if critical states change
        return oldValues['user'] != newValues['user'] ||
               oldValues['stats'] != newValues['stats'] ||
               oldValues['isLoading'] != newValues['isLoading'];
      },
      builder: (context, states) {
        final user = states['user'] as User?;
        final stats = states['stats'] as Stats?;
        final notifications = states['notifications'] as List<Notification>?;
        final isLoading = states['isLoading'] as bool;
        final error = states['error'] as String?;
        
        return DashboardContent(
          user: user,
          stats: stats,
          notifications: notifications ?? [],
          isLoading: isLoading,
          error: error,
        );
      },
    );
  }
}
```

### Using StateSelector for Performance

```dart
class PerformanceOptimizedWidget extends StatelessWidget {
  final DashboardViewModel viewModel;
  
  const PerformanceOptimizedWidget({super.key, required this.viewModel});
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Only observe user state for header
        StateSelector(
          states: {
            'user': viewModel.user,
            'isLoading': viewModel.isLoading,
            'error': viewModel.error,
          },
          selectKeys: ['user'],
          builder: (context, states) {
            final user = states['user'] as User?;
            return UserHeader(user: user);
          },
        ),
        
        // Only observe stats for stats widget
        StateSelector(
          states: {
            'stats': viewModel.stats,
            'isLoading': viewModel.isLoading,
            'error': viewModel.error,
          },
          selectKeys: ['stats'],
          builder: (context, states) {
            final stats = states['stats'] as Stats?;
            return StatsWidget(stats: stats);
          },
        ),
        
        // Only observe notifications for notifications widget
        StateSelector(
          states: {
            'notifications': viewModel.notifications,
            'isLoading': viewModel.isLoading,
            'error': viewModel.error,
          },
          selectKeys: ['notifications'],
          builder: (context, states) {
            final notifications = states['notifications'] as List<Notification>?;
            return NotificationsWidget(notifications: notifications ?? []);
          },
        ),
      ],
    );
  }
}
```

## Best Practices

### 1. Use StateComposer for Related States

```dart
// ✅ Good: Related states in one composer
StateComposer(
  states: {
    'user': viewModel.user,
    'profile': viewModel.profile,
    'settings': viewModel.settings,
  },
  builder: (context, states) {
    // Build user profile UI
  },
)

// ❌ Bad: Unrelated states in one composer
StateComposer(
  states: {
    'user': viewModel.user,
    'weather': viewModel.weather,
    'news': viewModel.news,
  },
  builder: (context, states) {
    // Mixed concerns
  },
)
```

### 2. Use StateSelector for Performance

```dart
// ✅ Good: Only observe needed states
StateSelector(
  states: {
    'user': viewModel.user,
    'stats': viewModel.stats,
    'notifications': viewModel.notifications,
  },
  selectKeys: ['user'], // Only observe user state
  builder: (context, states) {
    final user = states['user'] as User?;
    return UserWidget(user: user);
  },
)

// ❌ Bad: Observe all states when only one is needed
StateComposer(
  states: {
    'user': viewModel.user,
    'stats': viewModel.stats,
    'notifications': viewModel.notifications,
  },
  builder: (context, states) {
    final user = states['user'] as User?;
    return UserWidget(user: user); // Only using user, but observing all
  },
)
```

### 3. Use StateProvider for Global State

```dart
// ✅ Good: Global state in provider
StateProvider(
  states: {
    'user': UserViewModel(),
    'theme': ThemeViewModel(),
    'settings': SettingsViewModel(),
  },
  child: MyApp(),
)

// ❌ Bad: Passing state through props
class MyApp extends StatelessWidget {
  final UserViewModel userViewModel;
  final ThemeViewModel themeViewModel;
  final SettingsViewModel settingsViewModel;
  
  const MyApp({
    super.key,
    required this.userViewModel,
    required this.themeViewModel,
    required this.settingsViewModel,
  });
}
```

### 4. Handle Errors Properly

```dart
// ✅ Good: Proper error handling
StateComposer(
  states: {...},
  errorBuilder: (context, error) => ErrorWidget(
    error: error,
    onRetry: () => viewModel.retry(),
  ),
  builder: (context, states) {
    // Build UI
  },
)

// ❌ Bad: No error handling
StateComposer(
  states: {...},
  builder: (context, states) {
    // No error handling - app might crash
  },
)
```

This State Composition system provides powerful tools for managing complex UI state while maintaining performance and type safety. It's perfect for applications that need to observe multiple states without the complexity of nested StateBuilders.
