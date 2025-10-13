import 'state_exceptions.dart';

/// Handles generic type preservation and validation across serialization boundaries.
/// 
/// This class provides utilities for maintaining type information when working
/// with generic types, especially during serialization and deserialization operations.
class GenericTypeHandler {
  static final GenericTypeHandler _instance = GenericTypeHandler._internal();
  static GenericTypeHandler get instance => _instance;
  
  GenericTypeHandler._internal();

  final Map<String, TypeToken> _typeTokens = {};
  final Map<Type, GenericTypeInfo> _genericTypeCache = {};

  /// Registers a type token for a generic type.
  /// 
  /// Type tokens allow preservation of generic type information
  /// across serialization boundaries.
  void registerTypeToken<T>(String identifier) {
    _typeTokens[identifier] = TypeToken<T>();
  }

  /// Gets a registered type token by identifier.
  TypeToken<T>? getTypeToken<T>(String identifier) {
    final token = _typeTokens[identifier];
    if (token != null && token.type == T) {
      return token as TypeToken<T>;
    }
    return null;
  }

  /// Creates type metadata for a generic type.
  GenericTypeInfo createTypeInfo<T>() {
    final type = T;
    return _genericTypeCache.putIfAbsent(type, () => _analyzeGenericType<T>());
  }

  GenericTypeInfo _analyzeGenericType<T>() {
    // Without mirrors, we'll analyze the type string
    final typeString = T.toString();
    final isGeneric = typeString.contains('<') && typeString.contains('>');
    
    List<Type> typeArguments = [];
    List<String> typeArgumentNames = [];
    
    if (isGeneric) {
      // Extract type arguments from string (simplified approach)
      final startIndex = typeString.indexOf('<');
      final endIndex = typeString.lastIndexOf('>');
      if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
        final argsString = typeString.substring(startIndex + 1, endIndex);
        typeArgumentNames = argsString.split(',').map((s) => s.trim()).toList();
        // Note: We can't easily convert string type names back to Type objects
        // without mirrors, so typeArguments will remain empty
      }
    }
    
    return GenericTypeInfo(
      baseType: T,
      isGeneric: isGeneric,
      typeArguments: typeArguments,
      typeArgumentNames: typeArgumentNames,
      originalDeclaration: null,
    );
  }

  /// Validates that a value matches the expected generic type structure.
  bool validateGenericType<T>(dynamic value, {String? context}) {
    try {
      if (value == null) return null is T;

      final typeInfo = createTypeInfo<T>();
      
      // For non-generic types, use simple type check
      if (!typeInfo.isGeneric) {
        return value is T;
      }

      // For generic types, validate structure
      return _validateGenericStructure(value, typeInfo, context);
    } catch (e) {
      throw StateValidationException(
        'Generic type validation failed: $e',
        fieldName: context,
        actualValue: value,
        expectedValue: T,
        cause: e,
      );
    }
  }

  bool _validateGenericStructure(dynamic value, GenericTypeInfo typeInfo, String? context) {
    // Handle common generic types
    if (typeInfo.isListType) {
      return _validateGenericList(value, typeInfo, context);
    } else if (typeInfo.isMapType) {
      return _validateGenericMap(value, typeInfo, context);
    } else if (typeInfo.isSetType) {
      return _validateGenericSet(value, typeInfo, context);
    }

    // For other generic types, do basic validation
    return value.runtimeType.toString().startsWith(typeInfo.baseTypeName);
  }

  bool _validateGenericList(dynamic value, GenericTypeInfo typeInfo, String? context) {
    if (value is! List) return false;

    // If we have type arguments, validate each element
    if (typeInfo.typeArguments.isNotEmpty) {
      final elementType = typeInfo.typeArguments.first;
      for (int i = 0; i < value.length; i++) {
        if (!_isValueOfType(value[i], elementType)) {
          throw StateValidationException(
            'List element type mismatch at index $i',
            fieldName: context,
            actualValue: value[i]?.runtimeType,
            expectedValue: elementType,
          );
        }
      }
    }

    return true;
  }

  bool _validateGenericMap(dynamic value, GenericTypeInfo typeInfo, String? context) {
    if (value is! Map) return false;

    // If we have type arguments, validate keys and values
    if (typeInfo.typeArguments.length >= 2) {
      final keyType = typeInfo.typeArguments[0];
      final valueType = typeInfo.typeArguments[1];

      for (final entry in value.entries) {
        if (!_isValueOfType(entry.key, keyType)) {
          throw StateValidationException(
            'Map key type mismatch',
            fieldName: context,
            actualValue: entry.key?.runtimeType,
            expectedValue: keyType,
          );
        }

        if (!_isValueOfType(entry.value, valueType)) {
          throw StateValidationException(
            'Map value type mismatch',
            fieldName: context,
            actualValue: entry.value?.runtimeType,
            expectedValue: valueType,
          );
        }
      }
    }

    return true;
  }

  bool _validateGenericSet(dynamic value, GenericTypeInfo typeInfo, String? context) {
    if (value is! Set) return false;

    // If we have type arguments, validate each element
    if (typeInfo.typeArguments.isNotEmpty) {
      final elementType = typeInfo.typeArguments.first;
      for (final element in value) {
        if (!_isValueOfType(element, elementType)) {
          throw StateValidationException(
            'Set element type mismatch',
            fieldName: context,
            actualValue: element?.runtimeType,
            expectedValue: elementType,
          );
        }
      }
    }

    return true;
  }

  bool _isValueOfType(dynamic value, Type expectedType) {
    if (value == null) {
      // Check if the expected type is nullable
      return expectedType.toString().endsWith('?') || expectedType == Null;
    }

    return value.runtimeType == expectedType || 
           _isSubtypeOf(value.runtimeType, expectedType);
  }

  bool _isSubtypeOf(Type subtype, Type supertype) {
    // Without mirrors, we'll do basic subtype checking
    if (subtype == supertype) return true;
    
    // Basic inheritance checks for common types
    if (supertype == num && (subtype == int || subtype == double)) return true;
    if (supertype == Object) return true;
    
    // Check for nullable types
    final subtypeString = subtype.toString();
    final supertypeString = supertype.toString();
    
    if (supertypeString.endsWith('?') && 
        subtypeString == supertypeString.substring(0, supertypeString.length - 1)) {
      return true;
    }
    
    return false;
  }

  /// Creates a serializable representation of generic type information.
  Map<String, dynamic> serializeTypeInfo<T>() {
    final typeInfo = createTypeInfo<T>();
    return {
      'baseType': typeInfo.baseType.toString(),
      'isGeneric': typeInfo.isGeneric,
      'typeArguments': typeInfo.typeArgumentNames,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Validates that serialized type information matches the expected type.
  bool validateSerializedTypeInfo<T>(Map<String, dynamic> serializedInfo) {
    try {
      final expectedInfo = createTypeInfo<T>();
      final serializedBaseType = serializedInfo['baseType'] as String?;
      final serializedIsGeneric = serializedInfo['isGeneric'] as bool?;
      final serializedTypeArgs = serializedInfo['typeArguments'] as List<dynamic>?;

      if (serializedBaseType != expectedInfo.baseType.toString()) {
        return false;
      }

      if (serializedIsGeneric != expectedInfo.isGeneric) {
        return false;
      }

      if (expectedInfo.isGeneric) {
        final expectedTypeArgNames = expectedInfo.typeArgumentNames;
        final actualTypeArgNames = serializedTypeArgs?.cast<String>() ?? [];
        
        if (expectedTypeArgNames.length != actualTypeArgNames.length) {
          return false;
        }

        for (int i = 0; i < expectedTypeArgNames.length; i++) {
          if (expectedTypeArgNames[i] != actualTypeArgNames[i]) {
            return false;
          }
        }
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Clears all cached type information.
  void clearCache() {
    _typeTokens.clear();
    _genericTypeCache.clear();
  }
}

/// Represents a type token for preserving generic type information.
class TypeToken<T> {
  Type get type => T;
  
  @override
  String toString() => 'TypeToken<$T>';
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TypeToken && runtimeType == other.runtimeType && type == other.type;
  
  @override
  int get hashCode => type.hashCode;
}

/// Contains information about a generic type.
class GenericTypeInfo {
  final Type baseType;
  final bool isGeneric;
  final List<Type> typeArguments;
  final List<String> typeArgumentNames;
  final Type? originalDeclaration;

  const GenericTypeInfo({
    required this.baseType,
    required this.isGeneric,
    required this.typeArguments,
    required this.typeArgumentNames,
    this.originalDeclaration,
  });

  /// Gets the base type name without generic parameters.
  String get baseTypeName {
    final typeString = baseType.toString();
    final genericIndex = typeString.indexOf('<');
    return genericIndex != -1 ? typeString.substring(0, genericIndex) : typeString;
  }

  /// Checks if this is a List type.
  bool get isListType => baseTypeName == 'List';

  /// Checks if this is a Map type.
  bool get isMapType => baseTypeName == 'Map';

  /// Checks if this is a Set type.
  bool get isSetType => baseTypeName == 'Set';

  /// Checks if this is an Iterable type.
  bool get isIterableType => baseTypeName == 'Iterable' || isListType || isSetType;

  @override
  String toString() {
    return 'GenericTypeInfo(baseType: $baseType, isGeneric: $isGeneric, '
           'typeArguments: $typeArguments)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GenericTypeInfo &&
          runtimeType == other.runtimeType &&
          baseType == other.baseType &&
          isGeneric == other.isGeneric &&
          _listEquals(typeArguments, other.typeArguments);

  @override
  int get hashCode => Object.hash(baseType, isGeneric, Object.hashAll(typeArguments));

  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}