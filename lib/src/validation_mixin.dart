import 'state_exceptions.dart';
import 'type_validator.dart';
import 'serialization_validator.dart';

/// Mixin that provides validation capabilities to state implementations.
///
/// This mixin adds runtime type validation, schema validation, and
/// serialization validation to any state class that uses it.
mixin ValidationMixin<T> {
  final TypeValidator _typeValidator = TypeValidator.instance;
  final SerializationValidator _serializationValidator =
      SerializationValidator.instance;

  String? _validationSchemaId;
  String? _serializationSchemaId;
  ValidationSchema? _customSchema;

  /// Sets the validation schema ID for this state.
  void setValidationSchema(String schemaId) {
    _validationSchemaId = schemaId;
  }

  /// Sets the serialization schema ID for this state.
  void setSerializationSchema(String schemaId) {
    _serializationSchemaId = schemaId;
  }

  /// Sets a custom validation schema for this state.
  void setCustomValidationSchema(ValidationSchema schema) {
    _customSchema = schema;
  }

  /// Validates a value before setting it as the state value.
  ///
  /// Throws [StateValidationException] if validation fails.
  void validateValue(T value, {String? context}) {
    try {
      // Basic type validation
      _typeValidator.validateType<T>(value, fieldName: context);

      // Schema validation if available
      if (_customSchema != null) {
        _typeValidator.validateSchema(value, _customSchema!, path: context);
      } else if (_validationSchemaId != null) {
        final schema = _typeValidator.getSchema(_validationSchemaId!);
        if (schema != null) {
          _typeValidator.validateSchema(value, schema, path: context);
        }
      }

      // Additional custom validation
      performCustomValidation(value, context: context);
    } catch (e) {
      if (e is StateValidationException) rethrow;
      throw StateValidationException(
        'Value validation failed: $e',
        fieldName: context,
        actualValue: value,
        cause: e,
      );
    }
  }

  /// Validates a value before serialization.
  ///
  /// Throws [StateSerializationException] if validation fails.
  void validateSerialization(T value, {String? context}) {
    try {
      _serializationValidator.validateSerialization<T>(
        value,
        schemaId: _serializationSchemaId,
      );

      // Additional custom serialization validation
      performCustomSerializationValidation(value, context: context);
    } catch (e) {
      if (e is StateSerializationException) rethrow;
      throw StateSerializationException(
        'Serialization validation failed: $e',
        targetType: T,
        failedValue: value,
        cause: e,
        context: {'validationContext': context},
      );
    }
  }

  /// Validates data before deserialization.
  ///
  /// Throws [StateSerializationException] if validation fails.
  void validateDeserialization(dynamic data, {String? context}) {
    try {
      _serializationValidator.validateDeserialization<T>(
        data,
        schemaId: _serializationSchemaId,
      );

      // Additional custom deserialization validation
      performCustomDeserializationValidation(data, context: context);
    } catch (e) {
      if (e is StateSerializationException) rethrow;
      throw StateSerializationException(
        'Deserialization validation failed: $e',
        targetType: T,
        failedValue: data,
        cause: e,
        context: {'validationContext': context},
      );
    }
  }

  /// Validates that a collection meets the specified constraints.
  void validateCollection(
    dynamic collection, {
    int? minLength,
    int? maxLength,
    ValidationSchema? itemSchema,
    String? context,
  }) {
    if (collection == null) return;

    if (collection is! Iterable) {
      throw StateValidationException(
        'Expected collection type, got ${collection.runtimeType}',
        fieldName: context,
        actualValue: collection.runtimeType,
        expectedValue: 'Iterable',
      );
    }

    final length = collection.length;

    if (minLength != null && length < minLength) {
      throw StateValidationException(
        'Collection too short',
        fieldName: context,
        actualValue: length,
        expectedValue: 'min: $minLength',
        violatedRule: 'minLength',
      );
    }

    if (maxLength != null && length > maxLength) {
      throw StateValidationException(
        'Collection too long',
        fieldName: context,
        actualValue: length,
        expectedValue: 'max: $maxLength',
        violatedRule: 'maxLength',
      );
    }

    if (itemSchema != null) {
      int index = 0;
      for (final item in collection) {
        try {
          _typeValidator.validateSchema(
            item,
            itemSchema,
            path: '${context ?? 'collection'}[$index]',
          );
        } catch (e) {
          throw StateValidationException(
            'Collection item validation failed at index $index: $e',
            fieldName: context,
            actualValue: item,
            cause: e,
          );
        }
        index++;
      }
    }
  }

  /// Validates that an object meets the specified property constraints.
  void validateObject(
    dynamic object,
    Map<String, ValidationSchema> propertySchemas, {
    String? context,
  }) {
    if (object == null) return;

    for (final entry in propertySchemas.entries) {
      final propertyName = entry.key;
      final propertySchema = entry.value;
      final propertyContext =
          context != null ? '$context.$propertyName' : propertyName;

      try {
        // This is a simplified version - in practice, you'd use reflection
        // or require objects to implement a specific interface
        final propertyValue = _getObjectProperty(object, propertyName);

        if (propertyValue == null && propertySchema.required) {
          throw StateValidationException(
            'Required property missing',
            fieldName: propertyContext,
            violatedRule: 'required: true',
          );
        }

        if (propertyValue != null) {
          _typeValidator.validateSchema(
            propertyValue,
            propertySchema,
            path: propertyContext,
          );
        }
      } catch (e) {
        if (e is StateValidationException) rethrow;
        throw StateValidationException(
          'Object property validation failed: $e',
          fieldName: propertyContext,
          cause: e,
        );
      }
    }
  }

  /// Gets a property value from an object.
  ///
  /// This is a simplified implementation. In practice, you might use
  /// reflection, require objects to implement a specific interface,
  /// or use code generation.
  dynamic _getObjectProperty(dynamic object, String propertyName) {
    // This is a placeholder implementation
    // In a real implementation, you'd use reflection or require
    // objects to implement a specific interface
    if (object is Map) {
      return object[propertyName];
    }

    // For other objects, you might use reflection or require
    // them to implement a specific interface
    return null;
  }

  /// Override this method to provide custom validation logic.
  ///
  /// This method is called after basic type and schema validation.
  void performCustomValidation(T value, {String? context}) {
    // Default implementation does nothing
    // Subclasses can override to add custom validation
  }

  /// Override this method to provide custom serialization validation.
  ///
  /// This method is called after basic serialization validation.
  void performCustomSerializationValidation(T value, {String? context}) {
    // Default implementation does nothing
    // Subclasses can override to add custom serialization validation
  }

  /// Override this method to provide custom deserialization validation.
  ///
  /// This method is called after basic deserialization validation.
  void performCustomDeserializationValidation(dynamic data, {String? context}) {
    // Default implementation does nothing
    // Subclasses can override to add custom deserialization validation
  }

  /// Gets the current validation schema ID.
  String? get validationSchemaId => _validationSchemaId;

  /// Gets the current serialization schema ID.
  String? get serializationSchemaId => _serializationSchemaId;

  /// Gets the current custom validation schema.
  ValidationSchema? get customValidationSchema => _customSchema;
}

/// Extension methods for common validation scenarios.
extension ValidationExtensions<T> on ValidationMixin<T> {
  /// Validates that a numeric value is within the specified range.
  void validateNumericRange(num value, num min, num max, {String? context}) {
    if (value < min || value > max) {
      throw StateValidationException(
        'Value out of range',
        fieldName: context,
        actualValue: value,
        expectedValue: 'range: $min-$max',
        violatedRule: 'range',
      );
    }
  }

  /// Validates that a string matches the specified pattern.
  void validateStringPattern(
    String value,
    RegExp pattern, {
    String? context,
    String? patternDescription,
  }) {
    if (!pattern.hasMatch(value)) {
      throw StateValidationException(
        'String does not match required pattern',
        fieldName: context,
        actualValue: value,
        expectedValue: patternDescription ?? pattern.pattern,
        violatedRule: 'pattern',
      );
    }
  }

  /// Validates that a string has the required length constraints.
  void validateStringLength(
    String value, {
    int? minLength,
    int? maxLength,
    String? context,
  }) {
    final length = value.length;

    if (minLength != null && length < minLength) {
      throw StateValidationException(
        'String too short',
        fieldName: context,
        actualValue: length,
        expectedValue: 'min: $minLength',
        violatedRule: 'minLength',
      );
    }

    if (maxLength != null && length > maxLength) {
      throw StateValidationException(
        'String too long',
        fieldName: context,
        actualValue: length,
        expectedValue: 'max: $maxLength',
        violatedRule: 'maxLength',
      );
    }
  }
}
