import 'dart:convert';
import 'state_exceptions.dart';
import 'type_validator.dart';

/// Validates serialization operations to ensure type safety during persistence.
/// 
/// Provides validation for serialization input/output, schema migration support,
/// and type preservation across persistence operations.
class SerializationValidator {
  static final SerializationValidator _instance = SerializationValidator._internal();
  static SerializationValidator get instance => _instance;
  
  SerializationValidator._internal();

  final TypeValidator _typeValidator = TypeValidator.instance;
  final Map<String, SerializationSchema> _schemas = {};
  final Map<Type, Serializer> _customSerializers = {};

  /// Validates that a value can be safely serialized to the expected format.
  /// 
  /// Throws [StateSerializationException] if validation fails.
  bool validateSerialization<T>(T value, {String? schemaId}) {
    try {
      if (value == null) return true;

      // Check if we have a registered schema
      if (schemaId != null) {
        final schema = _schemas[schemaId];
        if (schema != null) {
          return _validateWithSchema(value, schema);
        }
      }

      // Validate basic serializability
      return _validateBasicSerialization(value);
    } catch (e) {
      if (e is StateSerializationException) rethrow;
      throw StateSerializationException(
        'Serialization validation failed: $e',
        targetType: T,
        failedValue: value,
        cause: e,
      );
    }
  }

  /// Validates that deserialized data matches the expected type and structure.
  /// 
  /// Throws [StateSerializationException] if validation fails.
  bool validateDeserialization<T>(dynamic data, {String? schemaId}) {
    try {
      if (data == null && null is! T) {
        throw StateSerializationException(
          'Cannot deserialize null to non-nullable type ${T.toString()}',
          targetType: T,
          failedValue: data,
        );
      }

      // Check if we have a registered schema
      if (schemaId != null) {
        final schema = _schemas[schemaId];
        if (schema != null) {
          return _validateDeserializationWithSchema<T>(data, schema);
        }
      }

      // Basic type validation
      return _validateBasicDeserialization<T>(data);
    } catch (e) {
      if (e is StateSerializationException) rethrow;
      throw StateSerializationException(
        'Deserialization validation failed: $e',
        targetType: T,
        failedValue: data,
        cause: e,
      );
    }
  }

  bool _validateWithSchema<T>(T value, SerializationSchema schema) {
    // Validate the value matches the schema structure
    if (!_typeValidator.validateSchema(value, schema.validationSchema)) {
      return false;
    }

    // Test actual serialization if required
    if (schema.validateSerialization) {
      try {
        final serialized = _serializeValue(value, schema);
        final deserialized = _deserializeValue(serialized, schema);
        
        // Verify round-trip integrity
        if (!_valuesEqual(value, deserialized)) {
          throw StateSerializationException(
            'Round-trip serialization failed: values do not match',
            targetType: T,
            failedValue: value,
            context: {
              'original': value,
              'serialized': serialized,
              'deserialized': deserialized,
            },
          );
        }
      } catch (e) {
        throw StateSerializationException(
          'Serialization test failed: $e',
          targetType: T,
          failedValue: value,
          cause: e,
        );
      }
    }

    return true;
  }

  bool _validateDeserializationWithSchema<T>(dynamic data, SerializationSchema schema) {
    // Validate the raw data structure
    if (!_validateRawData(data, schema)) {
      return false;
    }

    // Attempt deserialization
    try {
      final deserialized = _deserializeValue(data, schema);
      
      // Validate the deserialized result
      if (!_typeValidator.validateType<T>(deserialized)) {
        throw StateSerializationException(
          'Deserialized value does not match expected type',
          targetType: T,
          failedValue: deserialized,
        );
      }

      return true;
    } catch (e) {
      throw StateSerializationException(
        'Deserialization failed: $e',
        targetType: T,
        failedValue: data,
        cause: e,
      );
    }
  }

  bool _validateBasicSerialization<T>(T value) {
    if (value == null) return true;

    final type = value.runtimeType;
    
    // Check for primitive types
    if (_isPrimitiveSerializable(type)) return true;

    // Check for collections
    if (value is List || value is Set || value is Map) {
      return _validateCollectionSerialization(value);
    }

    // Check for custom serializers
    if (_customSerializers.containsKey(type)) return true;

    // Check if object has toJson method
    if (_hasToJsonMethod(value)) return true;

    // Try JSON encoding as final test
    try {
      jsonEncode(value);
      return true;
    } catch (e) {
      throw StateSerializationException(
        'Value is not serializable: $e',
        targetType: T,
        failedValue: value,
        cause: e,
      );
    }
  }

  bool _validateBasicDeserialization<T>(dynamic data) {
    if (data == null) return null is T;

    // For primitive types, check direct compatibility
    if (_isPrimitiveSerializable(T)) {
      return data is T;
    }

    // For complex types, we need more sophisticated checking
    try {
      // This is a basic check - in practice, you'd want more specific validation
      return true;
    } catch (e) {
      return false;
    }
  }

  bool _validateCollectionSerialization(dynamic collection) {
    if (collection is List) {
      return collection.every((item) => _validateBasicSerialization(item));
    } else if (collection is Set) {
      return collection.every((item) => _validateBasicSerialization(item));
    } else if (collection is Map) {
      return collection.entries.every((entry) =>
          _validateBasicSerialization(entry.key) &&
          _validateBasicSerialization(entry.value));
    }
    return false;
  }

  bool _validateRawData(dynamic data, SerializationSchema schema) {
    if (data == null) return schema.validationSchema.nullable;

    // Validate against the raw data schema
    try {
      return _typeValidator.validateSchema(data, schema.rawDataSchema);
    } catch (e) {
      return false;
    }
  }

  dynamic _serializeValue<T>(T value, SerializationSchema schema) {
    final customSerializer = _customSerializers[T];
    if (customSerializer != null) {
      return customSerializer.serialize(value);
    }

    // Default JSON serialization
    return jsonDecode(jsonEncode(value));
  }

  dynamic _deserializeValue(dynamic data, SerializationSchema schema) {
    final customSerializer = _customSerializers[schema.targetType];
    if (customSerializer != null) {
      return customSerializer.deserialize(data);
    }

    // Default deserialization - this would need to be more sophisticated
    // for complex types in a real implementation
    return data;
  }

  bool _valuesEqual(dynamic a, dynamic b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return a == b;
    
    // For collections, do deep comparison
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (int i = 0; i < a.length; i++) {
        if (!_valuesEqual(a[i], b[i])) return false;
      }
      return true;
    }
    
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final key in a.keys) {
        if (!b.containsKey(key) || !_valuesEqual(a[key], b[key])) {
          return false;
        }
      }
      return true;
    }

    return a == b;
  }

  bool _isPrimitiveSerializable(Type type) {
    return type == int ||
           type == double ||
           type == String ||
           type == bool ||
           type == num;
  }

  bool _hasToJsonMethod(dynamic object) {
    try {
      // Simple check - try to call toJson and see if it exists
      (object as dynamic).toJson();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Registers a serialization schema for validation.
  void registerSchema(String schemaId, SerializationSchema schema) {
    _schemas[schemaId] = schema;
  }

  /// Registers a custom serializer for a specific type.
  void registerSerializer<T>(Serializer<T> serializer) {
    _customSerializers[T] = serializer;
  }

  /// Gets a registered schema by ID.
  SerializationSchema? getSchema(String schemaId) {
    return _schemas[schemaId];
  }

  /// Validates schema migration from one version to another.
  bool validateMigration(
    String fromSchemaId,
    String toSchemaId,
    dynamic data,
  ) {
    final fromSchema = _schemas[fromSchemaId];
    final toSchema = _schemas[toSchemaId];

    if (fromSchema == null || toSchema == null) {
      throw StateSerializationException(
        'Migration schemas not found',
        context: {
          'fromSchema': fromSchemaId,
          'toSchema': toSchemaId,
          'fromExists': fromSchema != null,
          'toExists': toSchema != null,
        },
      );
    }

    try {
      // Validate data against source schema
      if (!_validateRawData(data, fromSchema)) {
        return false;
      }

      // Apply migration if available
      dynamic migratedData = data;
      if (fromSchema.migrationTo.containsKey(toSchemaId)) {
        final migration = fromSchema.migrationTo[toSchemaId]!;
        migratedData = migration(data);
      }

      // Validate migrated data against target schema
      return _validateRawData(migratedData, toSchema);
    } catch (e) {
      throw StateSerializationException(
        'Schema migration validation failed: $e',
        cause: e,
        context: {
          'fromSchema': fromSchemaId,
          'toSchema': toSchemaId,
          'data': data,
        },
      );
    }
  }

  /// Clears all registered schemas and serializers.
  void clearRegistrations() {
    _schemas.clear();
    _customSerializers.clear();
  }
}

/// Defines serialization validation rules and migration paths.
class SerializationSchema {
  final String id;
  final int version;
  final Type targetType;
  final ValidationSchema validationSchema;
  final ValidationSchema rawDataSchema;
  final bool validateSerialization;
  final Map<String, dynamic Function(dynamic)> migrationTo;
  final Map<String, dynamic Function(dynamic)> migrationFrom;

  const SerializationSchema({
    required this.id,
    required this.version,
    required this.targetType,
    required this.validationSchema,
    required this.rawDataSchema,
    this.validateSerialization = false,
    this.migrationTo = const {},
    this.migrationFrom = const {},
  });

  /// Creates a simple schema for primitive types.
  static SerializationSchema primitive(
    Type targetType, {
    required String id,
    int version = 1,
    bool validateSerialization = false,
  }) {
    final schema = ValidationSchema.primitive(targetType);
    return SerializationSchema(
      id: id,
      version: version,
      targetType: targetType,
      validationSchema: schema,
      rawDataSchema: schema,
      validateSerialization: validateSerialization,
    );
  }

  /// Creates a schema for object types with property validation.
  static SerializationSchema object(
    Type targetType, {
    required String id,
    int version = 1,
    required Map<String, ValidationSchema> properties,
    Map<String, ValidationSchema> rawProperties = const {},
    bool validateSerialization = true,
    Map<String, dynamic Function(dynamic)> migrationTo = const {},
  }) {
    return SerializationSchema(
      id: id,
      version: version,
      targetType: targetType,
      validationSchema: ValidationSchema.object(targetType, properties: properties),
      rawDataSchema: ValidationSchema.object(
        Map<String, dynamic>,
        properties: rawProperties.isNotEmpty ? rawProperties : properties,
      ),
      validateSerialization: validateSerialization,
      migrationTo: migrationTo,
    );
  }
}

/// Interface for custom serializers.
abstract class Serializer<T> {
  dynamic serialize(T value);
  T deserialize(dynamic data);
}