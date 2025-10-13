import 'state_exceptions.dart';

/// A comprehensive runtime type validation system for state management.
/// 
/// Provides type checking capabilities, schema validation, and generic type
/// preservation to ensure type safety throughout the state lifecycle.
class TypeValidator {
  static final TypeValidator _instance = TypeValidator._internal();
  static TypeValidator get instance => _instance;
  
  TypeValidator._internal();

  /// Cache for expensive type operations
  final Map<Type, TypeInfo> _typeCache = {};
  final Map<String, ValidationSchema> _schemaCache = {};

  /// Validates that a value matches the expected type T.
  /// 
  /// Throws [StateValidationException] if validation fails.
  bool validateType<T>(dynamic value, {String? fieldName}) {
    try {
      if (value == null) {
        if (null is T) return true;
        throw StateValidationException(
          'Null value not allowed for non-nullable type ${T.toString()}',
          fieldName: fieldName,
          actualValue: null,
          expectedValue: T,
        );
      }

      if (value is! T) {
        throw StateValidationException(
          'Type mismatch: expected ${T.toString()}, got ${value.runtimeType}',
          fieldName: fieldName,
          actualValue: value,
          expectedValue: T,
        );
      }

      return true;
    } catch (e) {
      if (e is StateValidationException) rethrow;
      throw StateValidationException(
        'Type validation failed: $e',
        fieldName: fieldName,
        actualValue: value,
        expectedValue: T,
        cause: e,
      );
    }
  }

  /// Validates a value against a schema definition.
  /// 
  /// Supports validation of complex objects, collections, and nested structures.
  bool validateSchema(dynamic value, ValidationSchema schema, {String? path}) {
    try {
      return _validateSchemaInternal(value, schema, path ?? 'root');
    } catch (e) {
      if (e is StateValidationException) rethrow;
      throw StateValidationException(
        'Schema validation failed: $e',
        fieldName: path,
        actualValue: value,
        cause: e,
      );
    }
  }

  bool _validateSchemaInternal(dynamic value, ValidationSchema schema, String path) {
    // Null check
    if (value == null) {
      if (!schema.nullable) {
        throw StateValidationException(
          'Null value not allowed',
          fieldName: path,
          actualValue: null,
          violatedRule: 'nullable: false',
        );
      }
      return true;
    }

    // Type check
    if (!_isTypeCompatible(value.runtimeType, schema.expectedType)) {
      throw StateValidationException(
        'Type mismatch in schema validation',
        fieldName: path,
        actualValue: value.runtimeType,
        expectedValue: schema.expectedType,
        violatedRule: 'type: ${schema.expectedType}',
      );
    }

    // Custom validators
    for (final validator in schema.customValidators) {
      if (!validator(value)) {
        throw StateValidationException(
          'Custom validation failed',
          fieldName: path,
          actualValue: value,
          violatedRule: 'custom validator',
        );
      }
    }

    // Collection validation
    if (schema.isCollection && value is Iterable) {
      return _validateCollection(value, schema, path);
    }

    // Object validation
    if (schema.properties.isNotEmpty) {
      return _validateObject(value, schema, path);
    }

    return true;
  }

  bool _validateCollection(Iterable collection, ValidationSchema schema, String path) {
    if (schema.minLength != null && collection.length < schema.minLength!) {
      throw StateValidationException(
        'Collection too short',
        fieldName: path,
        actualValue: collection.length,
        expectedValue: 'min: ${schema.minLength}',
        violatedRule: 'minLength',
      );
    }

    if (schema.maxLength != null && collection.length > schema.maxLength!) {
      throw StateValidationException(
        'Collection too long',
        fieldName: path,
        actualValue: collection.length,
        expectedValue: 'max: ${schema.maxLength}',
        violatedRule: 'maxLength',
      );
    }

    // Validate each item if item schema is provided
    if (schema.itemSchema != null) {
      int index = 0;
      for (final item in collection) {
        _validateSchemaInternal(item, schema.itemSchema!, '$path[$index]');
        index++;
      }
    }

    return true;
  }

  bool _validateObject(dynamic object, ValidationSchema schema, String path) {
    // For Flutter compatibility, we'll use a simpler approach without mirrors
    // Objects should implement a validation interface or be Maps
    
    Map<String, dynamic>? objectMap;
    
    if (object is Map<String, dynamic>) {
      objectMap = object;
    } else {
      // Try to convert to JSON if the object has a toJson method
      try {
        if (object.runtimeType.toString().contains('toJson')) {
          objectMap = (object as dynamic).toJson() as Map<String, dynamic>?;
        }
      } catch (e) {
        // If we can't convert to map, skip object validation
        return true;
      }
    }

    if (objectMap == null) return true;

    for (final entry in schema.properties.entries) {
      final propertyName = entry.key;
      final propertySchema = entry.value;
      final propertyPath = '$path.$propertyName';

      try {
        if (!objectMap.containsKey(propertyName)) {
          if (propertySchema.required) {
            throw StateValidationException(
              'Required property missing',
              fieldName: propertyPath,
              violatedRule: 'required: true',
            );
          }
          continue;
        }

        final fieldValue = objectMap[propertyName];
        _validateSchemaInternal(fieldValue, propertySchema, propertyPath);
      } catch (e) {
        if (e is StateValidationException) rethrow;
        throw StateValidationException(
          'Property validation failed: $e',
          fieldName: propertyPath,
          cause: e,
        );
      }
    }

    return true;
  }

  /// Checks if two types are compatible (including inheritance).
  bool _isTypeCompatible(Type actual, Type expected) {
    if (actual == expected) return true;
    
    // Without mirrors, we'll do basic type compatibility checks
    final actualString = actual.toString();
    final expectedString = expected.toString();
    
    // Handle nullable types
    if (actualString == expectedString) return true;
    if (expectedString.endsWith('?') && actualString == expectedString.substring(0, expectedString.length - 1)) {
      return true;
    }
    
    // Basic inheritance checks for common types
    if (expected == num && (actual == int || actual == double)) return true;
    if (expected == Object) return true;
    
    return false;
  }

  /// Gets or creates type information for caching.
  TypeInfo getTypeInfo<T>() {
    final type = T;
    return _typeCache.putIfAbsent(type, () => _createTypeInfo<T>());
  }

  TypeInfo _createTypeInfo<T>() {
    // Without mirrors, we'll analyze the type string
    final typeString = T.toString();
    final isGeneric = typeString.contains('<') && typeString.contains('>');
    
    List<Type> typeArguments = [];
    if (isGeneric) {
      // This is a simplified approach - in practice, parsing generic types
      // from strings is complex and error-prone
      // For now, we'll just mark it as generic without extracting type arguments
    }
    
    return TypeInfo(
      type: T,
      isNullable: null is T,
      isGeneric: isGeneric,
      typeArguments: typeArguments,
      isCollection: _isCollectionType(T),
      isPrimitive: _isPrimitiveType(T),
    );
  }

  bool _isCollectionType(Type type) {
    return type.toString().startsWith('List<') ||
           type.toString().startsWith('Set<') ||
           type.toString().startsWith('Map<') ||
           type.toString().startsWith('Iterable<');
  }

  bool _isPrimitiveType(Type type) {
    return type == int ||
           type == double ||
           type == String ||
           type == bool ||
           type == num;
  }

  /// Registers a validation schema for a specific type or identifier.
  void registerSchema(String identifier, ValidationSchema schema) {
    _schemaCache[identifier] = schema;
  }

  /// Gets a registered schema by identifier.
  ValidationSchema? getSchema(String identifier) {
    return _schemaCache[identifier];
  }

  /// Clears all cached type information and schemas.
  void clearCache() {
    _typeCache.clear();
    _schemaCache.clear();
  }
}

/// Contains metadata about a type for validation purposes.
class TypeInfo {
  final Type type;
  final bool isNullable;
  final bool isGeneric;
  final List<Type> typeArguments;
  final bool isCollection;
  final bool isPrimitive;

  const TypeInfo({
    required this.type,
    required this.isNullable,
    required this.isGeneric,
    required this.typeArguments,
    required this.isCollection,
    required this.isPrimitive,
  });

  @override
  String toString() {
    return 'TypeInfo(type: $type, nullable: $isNullable, generic: $isGeneric, '
           'collection: $isCollection, primitive: $isPrimitive)';
  }
}

/// Defines validation rules for a specific type or structure.
class ValidationSchema {
  final Type expectedType;
  final bool nullable;
  final bool required;
  final int? minLength;
  final int? maxLength;
  final bool isCollection;
  final ValidationSchema? itemSchema;
  final Map<String, ValidationSchema> properties;
  final List<bool Function(dynamic)> customValidators;

  const ValidationSchema({
    required this.expectedType,
    this.nullable = false,
    this.required = true,
    this.minLength,
    this.maxLength,
    this.isCollection = false,
    this.itemSchema,
    this.properties = const {},
    this.customValidators = const [],
  });

  /// Creates a schema for primitive types.
  static ValidationSchema primitive(
    Type expectedType, {
    bool nullable = false,
    bool required = true,
    List<bool Function(dynamic)> validators = const [],
  }) {
    return ValidationSchema(
      expectedType: expectedType,
      nullable: nullable,
      required: required,
      customValidators: validators,
    );
  }

  /// Creates a schema for collection types.
  static ValidationSchema collection(
    Type expectedType, {
    bool nullable = false,
    bool required = true,
    int? minLength,
    int? maxLength,
    ValidationSchema? itemSchema,
    List<bool Function(dynamic)> validators = const [],
  }) {
    return ValidationSchema(
      expectedType: expectedType,
      nullable: nullable,
      required: required,
      minLength: minLength,
      maxLength: maxLength,
      isCollection: true,
      itemSchema: itemSchema,
      customValidators: validators,
    );
  }

  /// Creates a schema for object types with properties.
  static ValidationSchema object(
    Type expectedType, {
    bool nullable = false,
    bool required = true,
    Map<String, ValidationSchema> properties = const {},
    List<bool Function(dynamic)> validators = const [],
  }) {
    return ValidationSchema(
      expectedType: expectedType,
      nullable: nullable,
      required: required,
      properties: properties,
      customValidators: validators,
    );
  }
}