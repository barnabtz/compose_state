# Compose State Examples

This directory contains comprehensive examples demonstrating how to use the compose_state package in real-world scenarios.

## Examples Overview

- [Basic Counter App](#basic-counter-app) - Simple state management
- [User Profile Management](#user-profile-management) - Complex object state with persistence
- [Shopping Cart](#shopping-cart) - Multiple related states with transactions
- [API Data Fetching](#api-data-fetching) - Async state with error handling
- [Form Validation](#form-validation) - Complex form state with validation
- [Theme Management](#theme-management) - App-wide state with persistence
- [Undo/Redo Text Editor](#undoredo-text-editor) - History state usage
- [Real-time Chat](#real-time-chat) - Stream state integration
- [Testing Examples](#testing-examples) - Comprehensive testing patterns

## Basic Counter App

A simple counter app demonstrating basic state management:

```dart
import 'package:flutter/material.dart';
import 'package:compose_state/compose_state.dart';

class CounterApp extends StatelessWidget {
  // Create a mutable state for the counter
  final counter = mutableStateOf(0);

  CounterApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('Counter App')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Use StateBuilder to rebuild when counter changes
              StateBuilder<int>(
                state: counter,
                builder: (context, count) {
                  return Text(
                    'Count: $count',
                    style: Theme.of(context).textTheme.headlineMedium,
                  );
                },
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () => counter.value--,
                    child: Text('-'),
                  ),
                  SizedBox(width: 20),
                  ElevatedButton(
                    onPressed: () => counter.value++,
                    child: Text('+'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

## User Profile Management

Managing complex user data with persistence:

```dart
import 'package:flutter/material.dart';
import 'package:compose_state/compose_state.dart';

class User {
  final String id;
  final String name;
  final String email;
  final int age;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.age,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'age': age,
  };

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'],
    name: json['name'],
    email: json['email'],
    age: json['age'],
  );

  @override
  bool operator ==(Object other) =>
    identical(this, other) ||
    other is User &&
    runtimeType == other.runtimeType &&
    id == other.id &&
    name == other.name &&
    email == other.email &&
    age == other.age;

  @override
  int get hashCode => Object.hash(id, name, email, age);
}

class UserProfileViewModel {
  // Persistable state for user data
  late final PersistableState<User?> userState;
  
  // Loading state for async operations
  final isLoading = mutableStateOf(false);
  
  // Error state
  final error = mutableStateOf<String?>(null);

  UserProfileViewModel() {
    userState = persistableStateOf<User?>(
      'user_profile',
      defaultValue: null,
      serializer: (user) => user?.toJson(),
      deserializer: (json) => json != null ? User.fromJson(json) : null,
    );
  }

  Future<void> updateUser(User user) async {
    isLoading.value = true;
    error.value = null;

    try {
      // Simulate API call
      await Future.delayed(Duration(seconds: 1));
      
      // Update state (automatically persisted)
      userState.value = user;
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  void clearUser() {
    userState.value = null;
  }
}

class UserProfileScreen extends StatelessWidget {
  final UserProfileViewModel viewModel = UserProfileViewModel();

  UserProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('User Profile')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // User display
            StateBuilder<User?>(
              state: viewModel.userState,
              builder: (context, user) {
                if (user == null) {
                  return Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No user profile'),
                    ),
                  );
                }

                return Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Name: ${user.name}'),
                        Text('Email: ${user.email}'),
                        Text('Age: ${user.age}'),
                      ],
                    ),
                  ),
                );
              },
            ),
            
            SizedBox(height: 20),
            
            // Loading indicator
            StateBuilder<bool>(
              state: viewModel.isLoading,
              builder: (context, loading) {
                return loading 
                  ? CircularProgressIndicator()
                  : SizedBox.shrink();
              },
            ),
            
            // Error display
            StateBuilder<String?>(
              state: viewModel.error,
              builder: (context, errorMsg) {
                return errorMsg != null
                  ? Card(
                      color: Colors.red[100],
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Error: $errorMsg'),
                      ),
                    )
                  : SizedBox.shrink();
              },
            ),
            
            SizedBox(height: 20),
            
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () => _showUpdateDialog(context),
                  child: Text('Update Profile'),
                ),
                ElevatedButton(
                  onPressed: viewModel.clearUser,
                  child: Text('Clear Profile'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showUpdateDialog(BuildContext context) {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final ageController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Update Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: emailController,
              decoration: InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: ageController,
              decoration: InputDecoration(labelText: 'Age'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final user = User(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: nameController.text,
                email: emailController.text,
                age: int.tryParse(ageController.text) ?? 0,
              );
              
              viewModel.updateUser(user);
              Navigator.pop(context);
            },
            child: Text('Update'),
          ),
        ],
      ),
    );
  }
}
```

## Shopping Cart

Multiple related states with atomic transactions:

```dart
import 'package:flutter/material.dart';
import 'package:compose_state/compose_state.dart';

class Product {
  final String id;
  final String name;
  final double price;

  Product({required this.id, required this.name, required this.price});

  @override
  bool operator ==(Object other) =>
    identical(this, other) ||
    other is Product && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class CartItem {
  final Product product;
  final int quantity;

  CartItem({required this.product, required this.quantity});

  double get totalPrice => product.price * quantity;

  CartItem copyWith({int? quantity}) {
    return CartItem(
      product: product,
      quantity: quantity ?? this.quantity,
    );
  }

  @override
  bool operator ==(Object other) =>
    identical(this, other) ||
    other is CartItem &&
    product == other.product &&
    quantity == other.quantity;

  @override
  int get hashCode => Object.hash(product, quantity);
}

class ShoppingCartViewModel {
  // Cart items state
  final cartItems = mutableStateOf<List<CartItem>>([]);
  
  // Derived state for total price
  late final DerivedState<double> totalPrice;
  
  // Derived state for item count
  late final DerivedState<int> itemCount;
  
  // Transaction manager for atomic operations
  final transactionManager = TransactionManager();

  ShoppingCartViewModel() {
    totalPrice = derivedStateOf(() {
      return cartItems.value.fold(0.0, (sum, item) => sum + item.totalPrice);
    });

    itemCount = derivedStateOf(() {
      return cartItems.value.fold(0, (sum, item) => sum + item.quantity);
    });
  }

  Future<void> addProduct(Product product, {int quantity = 1}) async {
    await transactionManager.executeTransaction((transaction) async {
      final currentItems = List<CartItem>.from(cartItems.value);
      
      final existingIndex = currentItems.indexWhere(
        (item) => item.product == product,
      );

      if (existingIndex >= 0) {
        // Update existing item
        currentItems[existingIndex] = currentItems[existingIndex].copyWith(
          quantity: currentItems[existingIndex].quantity + quantity,
        );
      } else {
        // Add new item
        currentItems.add(CartItem(product: product, quantity: quantity));
      }

      cartItems.setValueInTransaction(currentItems, transaction);
    });
  }

  Future<void> removeProduct(Product product) async {
    await transactionManager.executeTransaction((transaction) async {
      final currentItems = List<CartItem>.from(cartItems.value);
      currentItems.removeWhere((item) => item.product == product);
      cartItems.setValueInTransaction(currentItems, transaction);
    });
  }

  Future<void> updateQuantity(Product product, int quantity) async {
    if (quantity <= 0) {
      await removeProduct(product);
      return;
    }

    await transactionManager.executeTransaction((transaction) async {
      final currentItems = List<CartItem>.from(cartItems.value);
      final index = currentItems.indexWhere((item) => item.product == product);
      
      if (index >= 0) {
        currentItems[index] = currentItems[index].copyWith(quantity: quantity);
        cartItems.setValueInTransaction(currentItems, transaction);
      }
    });
  }

  Future<void> clearCart() async {
    await transactionManager.executeTransaction((transaction) async {
      cartItems.setValueInTransaction([], transaction);
    });
  }
}

class ShoppingCartScreen extends StatelessWidget {
  final ShoppingCartViewModel viewModel = ShoppingCartViewModel();
  
  final List<Product> availableProducts = [
    Product(id: '1', name: 'Apple', price: 1.50),
    Product(id: '2', name: 'Banana', price: 0.80),
    Product(id: '3', name: 'Orange', price: 2.00),
    Product(id: '4', name: 'Milk', price: 3.50),
    Product(id: '5', name: 'Bread', price: 2.50),
  ];

  ShoppingCartScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Shopping Cart'),
        actions: [
          StateBuilder<int>(
            state: viewModel.itemCount,
            builder: (context, count) {
              return Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: Text('Items: $count'),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Available products
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Available Products',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: availableProducts.length,
                    itemBuilder: (context, index) {
                      final product = availableProducts[index];
                      return ListTile(
                        title: Text(product.name),
                        subtitle: Text('\$${product.price.toStringAsFixed(2)}'),
                        trailing: ElevatedButton(
                          onPressed: () => viewModel.addProduct(product),
                          child: Text('Add'),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          
          Divider(),
          
          // Cart items
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Cart',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      StateBuilder<double>(
                        state: viewModel.totalPrice,
                        builder: (context, total) {
                          return Text(
                            'Total: \$${total.toStringAsFixed(2)}',
                            style: Theme.of(context).textTheme.titleMedium,
                          );
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: StateBuilder<List<CartItem>>(
                    state: viewModel.cartItems,
                    builder: (context, items) {
                      if (items.isEmpty) {
                        return Center(
                          child: Text('Cart is empty'),
                        );
                      }

                      return ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return ListTile(
                            title: Text(item.product.name),
                            subtitle: Text(
                              '\$${item.product.price.toStringAsFixed(2)} x ${item.quantity}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  onPressed: () => viewModel.updateQuantity(
                                    item.product,
                                    item.quantity - 1,
                                  ),
                                  icon: Icon(Icons.remove),
                                ),
                                Text('${item.quantity}'),
                                IconButton(
                                  onPressed: () => viewModel.updateQuantity(
                                    item.product,
                                    item.quantity + 1,
                                  ),
                                  icon: Icon(Icons.add),
                                ),
                                IconButton(
                                  onPressed: () => viewModel.removeProduct(
                                    item.product,
                                  ),
                                  icon: Icon(Icons.delete),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          
          // Action buttons
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: viewModel.clearCart,
                    child: Text('Clear Cart'),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: StateBuilder<List<CartItem>>(
                    state: viewModel.cartItems,
                    builder: (context, items) {
                      return ElevatedButton(
                        onPressed: items.isEmpty ? null : () {
                          // Simulate checkout
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Checkout successful!')),
                          );
                          viewModel.clearCart();
                        },
                        child: Text('Checkout'),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

## API Data Fetching

Async state management with comprehensive error handling:

```dart
import 'package:flutter/material.dart';
import 'package:compose_state/compose_state.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class Post {
  final int id;
  final String title;
  final String body;
  final int userId;

  Post({
    required this.id,
    required this.title,
    required this.body,
    required this.userId,
  });

  factory Post.fromJson(Map<String, dynamic> json) => Post(
    id: json['id'],
    title: json['title'],
    body: json['body'],
    userId: json['userId'],
  );

  @override
  bool operator ==(Object other) =>
    identical(this, other) ||
    other is Post && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class PostsApiService {
  static const String baseUrl = 'https://jsonplaceholder.typicode.com';

  static Future<List<Post>> fetchPosts() async {
    final response = await http.get(Uri.parse('$baseUrl/posts'));
    
    if (response.statusCode == 200) {
      final List<dynamic> jsonList = json.decode(response.body);
      return jsonList.map((json) => Post.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load posts: ${response.statusCode}');
    }
  }

  static Future<Post> fetchPost(int id) async {
    final response = await http.get(Uri.parse('$baseUrl/posts/$id'));
    
    if (response.statusCode == 200) {
      return Post.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to load post: ${response.statusCode}');
    }
  }
}

class PostsViewModel {
  // API state for posts list
  late final ApiState<List<Post>> postsState;
  
  // API state for selected post
  late final ApiState<Post?> selectedPostState;
  
  // Search query state
  final searchQuery = mutableStateOf('');
  
  // Filtered posts derived state
  late final DerivedState<List<Post>> filteredPosts;

  PostsViewModel() {
    // Configure error handling with retry strategy
    final errorHandler = StateErrorHandler(
      defaultStrategy: RetryStrategy(
        maxAttempts: 3,
        initialDelay: Duration(seconds: 1),
        backoffMultiplier: 2.0,
      ),
      onError: (error, context) {
        print('API Error: $error');
      },
    );

    postsState = apiStateOf<List<Post>>(
      PostsApiService.fetchPosts,
      errorHandler: errorHandler,
    );

    selectedPostState = apiStateOf<Post?>(
      () => Future.value(null),
      errorHandler: errorHandler,
    );

    filteredPosts = derivedStateOf(() {
      final posts = postsState.data ?? [];
      final query = searchQuery.value.toLowerCase();
      
      if (query.isEmpty) return posts;
      
      return posts.where((post) =>
        post.title.toLowerCase().contains(query) ||
        post.body.toLowerCase().contains(query)
      ).toList();
    });
  }

  Future<void> loadPosts() async {
    await postsState.refresh();
  }

  Future<void> loadPost(int id) async {
    selectedPostState.updateFetcher(() => PostsApiService.fetchPost(id));
    await selectedPostState.refresh();
  }

  void clearSelectedPost() {
    selectedPostState.updateFetcher(() => Future.value(null));
  }
}

class PostsScreen extends StatefulWidget {
  @override
  _PostsScreenState createState() => _PostsScreenState();
}

class _PostsScreenState extends State<PostsScreen> {
  final PostsViewModel viewModel = PostsViewModel();

  @override
  void initState() {
    super.initState();
    viewModel.loadPosts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Posts'),
        actions: [
          IconButton(
            onPressed: viewModel.loadPosts,
            icon: Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: EdgeInsets.all(16),
            child: StateBuilder<String>(
              state: viewModel.searchQuery,
              builder: (context, query) {
                return TextField(
                  decoration: InputDecoration(
                    hintText: 'Search posts...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => viewModel.searchQuery.value = value,
                );
              },
            ),
          ),
          
          // Posts list
          Expanded(
            child: StateBuilder<ApiStateData<List<Post>>>(
              state: viewModel.postsState,
              builder: (context, apiData) {
                // Loading state
                if (apiData.isLoading && apiData.data == null) {
                  return Center(child: CircularProgressIndicator());
                }

                // Error state
                if (apiData.hasError && apiData.data == null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error, size: 64, color: Colors.red),
                        SizedBox(height: 16),
                        Text('Error: ${apiData.error}'),
                        SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: viewModel.loadPosts,
                          child: Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                // Success state with filtered posts
                return StateBuilder<List<Post>>(
                  state: viewModel.filteredPosts,
                  builder: (context, posts) {
                    if (posts.isEmpty) {
                      return Center(
                        child: Text('No posts found'),
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: viewModel.loadPosts,
                      child: ListView.builder(
                        itemCount: posts.length,
                        itemBuilder: (context, index) {
                          final post = posts[index];
                          return Card(
                            margin: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: ListTile(
                              title: Text(
                                post.title,
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                post.body,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: apiData.isLoading
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(Icons.arrow_forward_ios),
                              onTap: () => _showPostDetails(context, post),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showPostDetails(BuildContext context, Post post) {
    viewModel.loadPost(post.id);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) {
          return Container(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Post Details',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Expanded(
                  child: StateBuilder<ApiStateData<Post?>>(
                    state: viewModel.selectedPostState,
                    builder: (context, apiData) {
                      if (apiData.isLoading) {
                        return Center(child: CircularProgressIndicator());
                      }

                      if (apiData.hasError) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Error loading post details'),
                              SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () => viewModel.loadPost(post.id),
                                child: Text('Retry'),
                              ),
                            ],
                          ),
                        );
                      }

                      final selectedPost = apiData.data ?? post;
                      return SingleChildScrollView(
                        controller: scrollController,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              selectedPost.title,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'User ID: ${selectedPost.userId}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            SizedBox(height: 16),
                            Text(selectedPost.body),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ).whenComplete(() {
      viewModel.clearSelectedPost();
    });
  }
}
```

This is the first part of the examples. Let me continue with more examples:

<function_calls>
<invoke name="fsAppend">
<parameter name="path">doc/examples/README.md
##
 Form Validation

Complex form state management with validation:

```dart
import 'package:flutter/material.dart';
import 'package:compose_state/compose_state.dart';

class FormField<T> {
  final T value;
  final String? error;
  final bool isValid;

  FormField({
    required this.value,
    this.error,
  }) : isValid = error == null;

  FormField<T> copyWith({
    T? value,
    String? error,
    bool clearError = false,
  }) {
    return FormField<T>(
      value: value ?? this.value,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  bool operator ==(Object other) =>
    identical(this, other) ||
    other is FormField<T> &&
    value == other.value &&
    error == other.error;

  @override
  int get hashCode => Object.hash(value, error);
}

class UserRegistrationForm {
  final name = mutableStateOf(FormField<String>(value: ''));
  final email = mutableStateOf(FormField<String>(value: ''));
  final password = mutableStateOf(FormField<String>(value: ''));
  final confirmPassword = mutableStateOf(FormField<String>(value: ''));
  final agreeToTerms = mutableStateOf(FormField<bool>(value: false));
  
  late final DerivedState<bool> isFormValid;
  final isSubmitting = mutableStateOf(false);
  final submitError = mutableStateOf<String?>(null);

  UserRegistrationForm() {
    isFormValid = derivedStateOf(() {
      return name.value.isValid &&
             email.value.isValid &&
             password.value.isValid &&
             confirmPassword.value.isValid &&
             agreeToTerms.value.isValid;
    });
  }

  void updateName(String value) {
    name.value = FormField<String>(
      value: value,
      error: _validateName(value),
    );
  }

  void updateEmail(String value) {
    email.value = FormField<String>(
      value: value,
      error: _validateEmail(value),
    );
  }

  void updatePassword(String value) {
    password.value = FormField<String>(
      value: value,
      error: _validatePassword(value),
    );
    
    // Re-validate confirm password when password changes
    if (confirmPassword.value.value.isNotEmpty) {
      updateConfirmPassword(confirmPassword.value.value);
    }
  }

  void updateConfirmPassword(String value) {
    confirmPassword.value = FormField<String>(
      value: value,
      error: _validateConfirmPassword(value, password.value.value),
    );
  }

  void updateAgreeToTerms(bool value) {
    agreeToTerms.value = FormField<bool>(
      value: value,
      error: _validateAgreeToTerms(value),
    );
  }

  String? _validateName(String value) {
    if (value.isEmpty) return 'Name is required';
    if (value.length < 2) return 'Name must be at least 2 characters';
    return null;
  }

  String? _validateEmail(String value) {
    if (value.isEmpty) return 'Email is required';
    
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) return 'Invalid email format';
    
    return null;
  }

  String? _validatePassword(String value) {
    if (value.isEmpty) return 'Password is required';
    if (value.length < 8) return 'Password must be at least 8 characters';
    
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Password must contain at least one uppercase letter';
    }
    
    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return 'Password must contain at least one lowercase letter';
    }
    
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Password must contain at least one number';
    }
    
    return null;
  }

  String? _validateConfirmPassword(String value, String password) {
    if (value.isEmpty) return 'Please confirm your password';
    if (value != password) return 'Passwords do not match';
    return null;
  }

  String? _validateAgreeToTerms(bool value) {
    if (!value) return 'You must agree to the terms and conditions';
    return null;
  }

  Future<void> submitForm() async {
    if (!isFormValid.value) return;

    isSubmitting.value = true;
    submitError.value = null;

    try {
      // Simulate API call
      await Future.delayed(Duration(seconds: 2));
      
      // Simulate random failure for demo
      if (DateTime.now().millisecond % 3 == 0) {
        throw Exception('Registration failed. Please try again.');
      }
      
      // Success - form would be cleared or navigation would occur
      print('Registration successful!');
      
    } catch (e) {
      submitError.value = e.toString();
    } finally {
      isSubmitting.value = false;
    }
  }

  void clearForm() {
    name.value = FormField<String>(value: '');
    email.value = FormField<String>(value: '');
    password.value = FormField<String>(value: '');
    confirmPassword.value = FormField<String>(value: '');
    agreeToTerms.value = FormField<bool>(value: false);
    submitError.value = null;
  }
}

class RegistrationScreen extends StatelessWidget {
  final UserRegistrationForm form = UserRegistrationForm();

  RegistrationScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Register')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Name field
            StateBuilder<FormField<String>>(
              state: form.name,
              builder: (context, field) {
                return TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Name',
                    errorText: field.error,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: form.updateName,
                );
              },
            ),
            
            SizedBox(height: 16),
            
            // Email field
            StateBuilder<FormField<String>>(
              state: form.email,
              builder: (context, field) {
                return TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Email',
                    errorText: field.error,
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  onChanged: form.updateEmail,
                );
              },
            ),
            
            SizedBox(height: 16),
            
            // Password field
            StateBuilder<FormField<String>>(
              state: form.password,
              builder: (context, field) {
                return TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Password',
                    errorText: field.error,
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  onChanged: form.updatePassword,
                );
              },
            ),
            
            SizedBox(height: 16),
            
            // Confirm password field
            StateBuilder<FormField<String>>(
              state: form.confirmPassword,
              builder: (context, field) {
                return TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    errorText: field.error,
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  onChanged: form.updateConfirmPassword,
                );
              },
            ),
            
            SizedBox(height: 16),
            
            // Terms checkbox
            StateBuilder<FormField<bool>>(
              state: form.agreeToTerms,
              builder: (context, field) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CheckboxListTile(
                      title: Text('I agree to the terms and conditions'),
                      value: field.value,
                      onChanged: (value) => form.updateAgreeToTerms(value ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                    if (field.error != null)
                      Padding(
                        padding: EdgeInsets.only(left: 16, top: 4),
                        child: Text(
                          field.error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            
            SizedBox(height: 24),
            
            // Submit error
            StateBuilder<String?>(
              state: form.submitError,
              builder: (context, error) {
                return error != null
                  ? Container(
                      padding: EdgeInsets.all(12),
                      margin: EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red),
                      ),
                      child: Text(
                        error,
                        style: TextStyle(color: Colors.red[800]),
                      ),
                    )
                  : SizedBox.shrink();
              },
            ),
            
            // Submit button
            StateBuilder<bool>(
              state: form.isSubmitting,
              builder: (context, isSubmitting) {
                return StateBuilder<bool>(
                  state: form.isFormValid,
                  builder: (context, isValid) {
                    return ElevatedButton(
                      onPressed: isSubmitting || !isValid ? null : form.submitForm,
                      child: isSubmitting
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              SizedBox(width: 12),
                              Text('Registering...'),
                            ],
                          )
                        : Text('Register'),
                    );
                  },
                );
              },
            ),
            
            SizedBox(height: 16),
            
            // Clear button
            TextButton(
              onPressed: form.clearForm,
              child: Text('Clear Form'),
            ),
          ],
        ),
      ),
    );
  }
}
```

## Theme Management

App-wide theme state with persistence:

```dart
import 'package:flutter/material.dart';
import 'package:compose_state/compose_state.dart';

enum AppTheme {
  light,
  dark,
  system,
}

class ThemeSettings {
  final AppTheme theme;
  final Color primaryColor;
  final bool useMaterial3;
  final double textScaleFactor;

  const ThemeSettings({
    this.theme = AppTheme.system,
    this.primaryColor = Colors.blue,
    this.useMaterial3 = true,
    this.textScaleFactor = 1.0,
  });

  ThemeSettings copyWith({
    AppTheme? theme,
    Color? primaryColor,
    bool? useMaterial3,
    double? textScaleFactor,
  }) {
    return ThemeSettings(
      theme: theme ?? this.theme,
      primaryColor: primaryColor ?? this.primaryColor,
      useMaterial3: useMaterial3 ?? this.useMaterial3,
      textScaleFactor: textScaleFactor ?? this.textScaleFactor,
    );
  }

  Map<String, dynamic> toJson() => {
    'theme': theme.index,
    'primaryColor': primaryColor.value,
    'useMaterial3': useMaterial3,
    'textScaleFactor': textScaleFactor,
  };

  factory ThemeSettings.fromJson(Map<String, dynamic> json) => ThemeSettings(
    theme: AppTheme.values[json['theme'] ?? 0],
    primaryColor: Color(json['primaryColor'] ?? Colors.blue.value),
    useMaterial3: json['useMaterial3'] ?? true,
    textScaleFactor: (json['textScaleFactor'] ?? 1.0).toDouble(),
  );

  @override
  bool operator ==(Object other) =>
    identical(this, other) ||
    other is ThemeSettings &&
    theme == other.theme &&
    primaryColor == other.primaryColor &&
    useMaterial3 == other.useMaterial3 &&
    textScaleFactor == other.textScaleFactor;

  @override
  int get hashCode => Object.hash(theme, primaryColor, useMaterial3, textScaleFactor);
}

class ThemeManager {
  static ThemeManager? _instance;
  static ThemeManager get instance => _instance ??= ThemeManager._();

  ThemeManager._();

  // Persistable theme settings
  late final PersistableState<ThemeSettings> themeSettings;
  
  // Derived theme data states
  late final DerivedState<ThemeData> lightTheme;
  late final DerivedState<ThemeData> darkTheme;
  late final DerivedState<ThemeMode> themeMode;

  void initialize() {
    themeSettings = persistableStateOf<ThemeSettings>(
      'app_theme_settings',
      defaultValue: ThemeSettings(),
      serializer: (settings) => settings.toJson(),
      deserializer: (json) => ThemeSettings.fromJson(json),
    );

    lightTheme = derivedStateOf(() {
      final settings = themeSettings.value;
      return ThemeData(
        useMaterial3: settings.useMaterial3,
        colorScheme: ColorScheme.fromSeed(
          seedColor: settings.primaryColor,
          brightness: Brightness.light,
        ),
        textTheme: ThemeData.light().textTheme.apply(
          fontSizeFactor: settings.textScaleFactor,
        ),
      );
    });

    darkTheme = derivedStateOf(() {
      final settings = themeSettings.value;
      return ThemeData(
        useMaterial3: settings.useMaterial3,
        colorScheme: ColorScheme.fromSeed(
          seedColor: settings.primaryColor,
          brightness: Brightness.dark,
        ),
        textTheme: ThemeData.dark().textTheme.apply(
          fontSizeFactor: settings.textScaleFactor,
        ),
      );
    });

    themeMode = derivedStateOf(() {
      switch (themeSettings.value.theme) {
        case AppTheme.light:
          return ThemeMode.light;
        case AppTheme.dark:
          return ThemeMode.dark;
        case AppTheme.system:
          return ThemeMode.system;
      }
    });
  }

  void updateTheme(AppTheme theme) {
    themeSettings.value = themeSettings.value.copyWith(theme: theme);
  }

  void updatePrimaryColor(Color color) {
    themeSettings.value = themeSettings.value.copyWith(primaryColor: color);
  }

  void updateMaterial3(bool useMaterial3) {
    themeSettings.value = themeSettings.value.copyWith(useMaterial3: useMaterial3);
  }

  void updateTextScale(double scale) {
    themeSettings.value = themeSettings.value.copyWith(textScaleFactor: scale);
  }

  void resetToDefaults() {
    themeSettings.value = ThemeSettings();
  }
}

class ThemedApp extends StatelessWidget {
  final ThemeManager themeManager = ThemeManager.instance;

  ThemedApp({Key? key}) : super(key: key) {
    themeManager.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return StateBuilder<ThemeData>(
      state: themeManager.lightTheme,
      builder: (context, lightTheme) {
        return StateBuilder<ThemeData>(
          state: themeManager.darkTheme,
          builder: (context, darkTheme) {
            return StateBuilder<ThemeMode>(
              state: themeManager.themeMode,
              builder: (context, themeMode) {
                return MaterialApp(
                  title: 'Themed App',
                  theme: lightTheme,
                  darkTheme: darkTheme,
                  themeMode: themeMode,
                  home: HomeScreen(),
                );
              },
            );
          },
        );
      },
    );
  }
}

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Theme Demo'),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ThemeSettingsScreen()),
            ),
            icon: Icon(Icons.settings),
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Theme Demo',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            SizedBox(height: 16),
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Theme',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    SizedBox(height: 8),
                    StateBuilder<ThemeSettings>(
                      state: ThemeManager.instance.themeSettings,
                      builder: (context, settings) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Mode: ${settings.theme.name}'),
                            Text('Material 3: ${settings.useMaterial3}'),
                            Text('Text Scale: ${settings.textScaleFactor.toStringAsFixed(1)}'),
                            SizedBox(height: 8),
                            Container(
                              width: 50,
                              height: 20,
                              decoration: BoxDecoration(
                                color: settings.primaryColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Sample Content',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 8),
            Text(
              'This is sample text to demonstrate the current theme. '
              'The text scale and colors will change based on your theme settings.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () {},
                  child: Text('Elevated Button'),
                ),
                SizedBox(width: 16),
                OutlinedButton(
                  onPressed: () {},
                  child: Text('Outlined Button'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ThemeSettingsScreen extends StatelessWidget {
  final ThemeManager themeManager = ThemeManager.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Theme Settings'),
        actions: [
          TextButton(
            onPressed: themeManager.resetToDefaults,
            child: Text('Reset'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: StateBuilder<ThemeSettings>(
          state: themeManager.themeSettings,
          builder: (context, settings) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Theme mode selection
                Text(
                  'Theme Mode',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                SizedBox(height: 8),
                ...AppTheme.values.map((theme) {
                  return RadioListTile<AppTheme>(
                    title: Text(theme.name.toUpperCase()),
                    value: theme,
                    groupValue: settings.theme,
                    onChanged: (value) {
                      if (value != null) {
                        themeManager.updateTheme(value);
                      }
                    },
                  );
                }),
                
                Divider(),
                
                // Primary color selection
                Text(
                  'Primary Color',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Colors.blue,
                    Colors.red,
                    Colors.green,
                    Colors.purple,
                    Colors.orange,
                    Colors.teal,
                    Colors.indigo,
                    Colors.pink,
                  ].map((color) {
                    final isSelected = settings.primaryColor == color;
                    return GestureDetector(
                      onTap: () => themeManager.updatePrimaryColor(color),
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(8),
                          border: isSelected
                            ? Border.all(color: Colors.white, width: 3)
                            : null,
                          boxShadow: isSelected
                            ? [BoxShadow(color: Colors.black26, blurRadius: 4)]
                            : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                
                SizedBox(height: 24),
                
                // Material 3 toggle
                SwitchListTile(
                  title: Text('Use Material 3'),
                  subtitle: Text('Enable Material You design system'),
                  value: settings.useMaterial3,
                  onChanged: themeManager.updateMaterial3,
                ),
                
                Divider(),
                
                // Text scale slider
                Text(
                  'Text Scale Factor',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                SizedBox(height: 8),
                Slider(
                  value: settings.textScaleFactor,
                  min: 0.8,
                  max: 1.5,
                  divisions: 7,
                  label: settings.textScaleFactor.toStringAsFixed(1),
                  onChanged: themeManager.updateTextScale,
                ),
                Text(
                  'Sample text at ${settings.textScaleFactor.toStringAsFixed(1)}x scale',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
```

## Testing Examples

Comprehensive testing patterns for state management:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:compose_state/compose_state.dart';
import 'package:compose_state/testing.dart';

void main() {
  group('State Management Tests', () {
    setUp(() {
      // Reset state manager before each test
      StateManager.instance.disposeAllStates();
    });

    group('Basic State Tests', () {
      test('mutable state updates correctly', () {
        final state = mutableStateOf(0);
        
        expect(state.value, 0);
        
        state.value = 42;
        expect(state.value, 42);
      });

      test('state notifies listeners on change', () {
        final state = mutableStateOf('initial');
        bool notified = false;
        
        state.addListener(() {
          notified = true;
        });
        
        state.value = 'changed';
        expect(notified, true);
      });

      test('state does not notify on same value', () {
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
    });

    group('Mock State Tests', () {
      test('mock state can be controlled', () {
        final mockState = mockStateOf(42);
        
        // Test normal behavior
        expect(mockState.value, 42);
        
        // Control behavior
        mockState.returnValue(100);
        expect(mockState.value, 100);
        
        // Test error behavior
        mockState.throwOnGet();
        expect(() => mockState.value, throwsException);
      });

      test('mock state tracks interactions', () {
        final mockState = mockStateOf('test');
        
        // Access value multiple times
        mockState.value;
        mockState.value;
        mockState.value = 'new value';
        
        expect(mockState.getCallCount, 2);
        expect(mockState.setCallCount, 1);
      });
    });

    group('State Change Tracking Tests', () {
      test('tracks state changes over time', () async {
        final state = mutableStateOf(0);
        final tracker = createStateTracker();
        
        tracker.trackState('counter', state);
        tracker.startTracking();
        
        // Make some changes
        state.value = 1;
        await Future.delayed(Duration(milliseconds: 10));
        state.value = 2;
        await Future.delayed(Duration(milliseconds: 10));
        state.value = 3;
        
        final history = tracker.getChangeHistory('counter');
        expect(history.length, 4); // initial + 3 changes
        expect(history.last.newValue, 3);
      });

      test('can verify specific state changes', () {
        final state = mutableStateOf('initial');
        final tracker = createStateTracker();
        
        tracker.trackState('text', state);
        tracker.startTracking();
        
        state.value = 'changed';
        
        expect(
          tracker.hasStateChanged('text', from: 'initial', to: 'changed'),
          true,
        );
      });
    });

    group('API State Tests', () {
      test('api state handles successful data fetching', () async {
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

      test('api state handles errors with retry', () async {
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
    });

    group('Transaction Tests', () {
      test('transaction commits all changes atomically', () async {
        final state1 = mutableStateOf('initial1');
        final state2 = mutableStateOf('initial2');
        final transactionManager = TransactionManager();

        await transactionManager.executeTransaction((transaction) async {
          state1.setValueInTransaction('changed1', transaction);
          state2.setValueInTransaction('changed2', transaction);
        });

        expect(state1.value, 'changed1');
        expect(state2.value, 'changed2');
      });

      test('transaction rolls back on error', () async {
        final state1 = mutableStateOf('initial1');
        final state2 = mutableStateOf('initial2');
        final transactionManager = TransactionManager();

        try {
          await transactionManager.executeTransaction((transaction) async {
            state1.setValueInTransaction('changed1', transaction);
            state2.setValueInTransaction('changed2', transaction);
            throw Exception('Simulated error');
          });
        } catch (e) {
          // Expected error
        }

        // Values should be rolled back
        expect(state1.value, 'initial1');
        expect(state2.value, 'initial2');
      });
    });

    group('Memory Management Tests', () {
      test('detects potential memory leaks', () async {
        final state1 = mutableStateOf('test1');
        final state2 = mutableStateOf('test2');
        
        // Simulate old states
        await Future.delayed(Duration(milliseconds: 100));
        
        final leaks = StateManager.instance.detectPotentialLeaks(
          threshold: Duration(milliseconds: 50),
        );
        
        expect(leaks.length, greaterThanOrEqualTo(2));
      });

      test('garbage collection cleans up disposed states', () {
        final initialStats = StateManager.instance.getMemoryStats();
        
        // Create and dispose states
        final state1 = mutableStateOf('test1');
        final state2 = mutableStateOf('test2');
        state1.dispose();
        state2.dispose();
        
        StateManager.instance.performGarbageCollection();
        
        final finalStats = StateManager.instance.getMemoryStats();
        expect(finalStats.disposedStates, greaterThan(initialStats.disposedStates));
      });
    });

    group('Form Validation Tests', () {
      test('form validation works correctly', () {
        final nameState = mutableStateOf('');
        final emailState = mutableStateOf('');
        
        final isFormValid = derivedStateOf(() {
          return nameState.value.isNotEmpty && 
                 emailState.value.contains('@');
        });
        
        expect(isFormValid.value, false);
        
        nameState.value = 'John';
        expect(isFormValid.value, false); // Still invalid email
        
        emailState.value = 'john@example.com';
        expect(isFormValid.value, true); // Now valid
      });
    });

    group('Performance Tests', () {
      test('equality checker prevents unnecessary notifications', () {
        final complexObject = {'key': 'value', 'nested': {'data': 123}};
        final state = mutableStateOf(
          complexObject,
          equalityChecker: EqualityChecker<Map<String, dynamic>>(),
        );
        
        int notificationCount = 0;
        state.addListener(() => notificationCount++);
        
        // Set same value (deep equality)
        state.value = {'key': 'value', 'nested': {'data': 123}};
        expect(notificationCount, 0);
        
        // Set different value
        state.value = {'key': 'different', 'nested': {'data': 123}};
        expect(notificationCount, 1);
      });

      test('notification batching reduces rebuild frequency', () {
        final state1 = mutableStateOf(0);
        final state2 = mutableStateOf(0);
        final batcher = NotificationBatcher();
        
        int totalNotifications = 0;
        state1.addListener(() => totalNotifications++);
        state2.addListener(() => totalNotifications++);
        
        batcher.batch(() {
          state1.value = 1;
          state1.value = 2;
          state2.value = 1;
          state2.value = 2;
        });
        
        // Should batch notifications
        expect(totalNotifications, lessThan(4));
      });
    });
  });
}

// Helper functions for testing
StateChangeTracker createStateTracker() {
  return StateChangeTracker();
}

// Custom matchers for better test readability
Matcher hasStateValue<T>(T expectedValue) {
  return predicate<ObservableState<T>>(
    (state) => state.value == expectedValue,
    'has state value $expectedValue',
  );
}

Matcher isLoadingState() {
  return predicate<ApiState>(
    (state) => state.isLoading,
    'is in loading state',
  );
}

Matcher hasErrorState() {
  return predicate<ApiState>(
    (state) => state.hasError,
    'has error state',
  );
}
```