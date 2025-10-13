import 'package:flutter/foundation.dart';
import 'mutable_state.dart';
import 'type_validator.dart';
import 'serialization_validator.dart';
import 'generic_type_handler.dart';
import 'validation_mixin.dart';
import 'compose_view_model.dart';
import 'state_exceptions.dart';

/// Example demonstrating runtime type validation usage.
class ValidationExamples {
  static void demonstrateTypeValidation() {
    final validator = TypeValidator.instance;

    // Basic type validation
    try {
      validator.validateType<String>("Hello World");
      debugPrint("✓ String validation passed");
    } catch (e) {
      debugPrint("✗ String validation failed: $e");
    }

    // Schema validation
    final userSchema = ValidationSchema.object(
      User,
      properties: {
        'name': ValidationSchema.primitive(
          String,
          validators: [(value) => value.toString().isNotEmpty],
        ),
        'age': ValidationSchema.primitive(
          int,
          validators: [(value) => value >= 0 && value <= 150],
        ),
        'email': ValidationSchema.primitive(
          String,
          validators: [(value) => value.toString().contains('@')],
        ),
      },
    );

    validator.registerSchema('user', userSchema);

    final user = User(name: "John Doe", age: 30, email: "john@example.com");
    try {
      validator.validateSchema(user, userSchema);
      debugPrint("✓ User schema validation passed");
    } catch (e) {
      debugPrint("✗ User schema validation failed: $e");
    }
  }

  static void demonstrateSerializationValidation() {
    final validator = SerializationValidator.instance;

    // Register a serialization schema
    final userSerializationSchema = SerializationSchema.object(
      User,
      id: 'user_v1',
      properties: {
        'name': ValidationSchema.primitive(String),
        'age': ValidationSchema.primitive(int),
        'email': ValidationSchema.primitive(String),
      },
    );

    validator.registerSchema('user_v1', userSerializationSchema);

    final user = User(name: "Jane Doe", age: 25, email: "jane@example.com");

    try {
      validator.validateSerialization<User>(user, schemaId: 'user_v1');
      debugPrint("✓ User serialization validation passed");
    } catch (e) {
      debugPrint("✗ User serialization validation failed: $e");
    }
  }

  static void demonstrateGenericTypeHandling() {
    final handler = GenericTypeHandler.instance;

    // Register type tokens
    handler.registerTypeToken<List<String>>('string_list');
    handler.registerTypeToken<Map<String, int>>('string_int_map');

    // Validate generic types
    final stringList = ["hello", "world"];
    try {
      final isValid = handler.validateGenericType<List<String>>(stringList);
      debugPrint("✓ Generic List<String> validation: $isValid");
    } catch (e) {
      debugPrint("✗ Generic List<String> validation failed: $e");
    }

    final stringIntMap = {"count": 42, "total": 100};
    try {
      final isValid = handler.validateGenericType<Map<String, int>>(stringIntMap);
      debugPrint("✓ Generic Map<String, int> validation: $isValid");
    } catch (e) {
      debugPrint("✗ Generic Map<String, int> validation failed: $e");
    }

    // Serialize type information
    final typeInfo = handler.serializeTypeInfo<List<User>>();
    debugPrint("Type info for List<User>: $typeInfo");
  }

  static void demonstrateValidatedState() {
    // Create a validated mutable state
    final validatedState = ValidatedMutableState<String>(
      "initial value",
      validator: (value) => value.isNotEmpty,
      errorMessage: "Value cannot be empty",
    );

    try {
      validatedState.value = "new value";
      debugPrint("✓ Validated state update succeeded");
    } catch (e) {
      debugPrint("✗ Validated state update failed: $e");
    }

    try {
      validatedState.value = "";
      debugPrint("✗ Empty value should have failed validation");
    } catch (e) {
      debugPrint("✓ Empty value correctly rejected: $e");
    }
  }
}

/// Example user class for validation demonstrations.
class User {
  final String name;
  final int age;
  final String email;

  User({required this.name, required this.age, required this.email});

  Map<String, dynamic> toJson() => {
    'name': name,
    'age': age,
    'email': email,
  };

  factory User.fromJson(Map<String, dynamic> json) => User(
    name: json['name'] as String,
    age: json['age'] as int,
    email: json['email'] as String,
  );

  @override
  String toString() => 'User(name: $name, age: $age, email: $email)';
}

/// Example of a state class that uses validation.
class ValidatedMutableState<T> extends MutableState<T> with ValidationMixin<T> {
  final bool Function(T)? validator;
  final String? errorMessage;

  ValidatedMutableState(
    super.initialValue, {
    this.validator,
    this.errorMessage,
  });

  @override
  set value(T newValue) {
    // Validate before setting
    validateValue(newValue);
    super.value = newValue;
  }

  @override
  void performCustomValidation(T value, {String? context}) {
    if (validator != null && !validator!(value)) {
      throw StateValidationException(
        errorMessage ?? 'Custom validation failed',
        fieldName: context,
        actualValue: value,
      );
    }
  }
}

/// Example ViewModel that uses validation.
class ValidatedUserViewModel extends ComposeViewModel {
  late final ValidatedMutableState<String> _name;
  late final ValidatedMutableState<int> _age;
  late final ValidatedMutableState<String> _email;

  ValidatedUserViewModel() {
    _name = ValidatedMutableState<String>(
      "",
      validator: (value) => value.trim().isNotEmpty,
      errorMessage: "Name cannot be empty",
    );

    _age = ValidatedMutableState<int>(
      0,
      validator: (value) => value >= 0 && value <= 150,
      errorMessage: "Age must be between 0 and 150",
    );

    _email = ValidatedMutableState<String>(
      "",
      validator: (value) => value.contains('@') && value.contains('.'),
      errorMessage: "Email must be valid",
    );

    // Set up validation schemas
    final userSchema = ValidationSchema.object(
      User,
      properties: {
        'name': ValidationSchema.primitive(
          String,
          validators: [(value) => value.toString().trim().isNotEmpty],
        ),
        'age': ValidationSchema.primitive(
          int,
          validators: [(value) => value >= 0 && value <= 150],
        ),
        'email': ValidationSchema.primitive(
          String,
          validators: [(value) => (value as String).contains('@')],
        ),
      },
    );

    _name.setCustomValidationSchema(userSchema.properties['name']!);
    _age.setCustomValidationSchema(userSchema.properties['age']!);
    _email.setCustomValidationSchema(userSchema.properties['email']!);
  }

  String get name => _name.value;
  set name(String value) => _name.value = value;

  int get age => _age.value;
  set age(int value) => _age.value = value;

  String get email => _email.value;
  set email(String value) => _email.value = value;

  User createUser() {
    // Validate all fields before creating user
    _name.validateValue(_name.value, context: 'name');
    _age.validateValue(_age.value, context: 'age');
    _email.validateValue(_email.value, context: 'email');

    return User(name: name, age: age, email: email);
  }

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    _email.dispose();
    super.dispose();
  }
}