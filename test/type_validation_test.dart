import 'package:flutter_test/flutter_test.dart';
import 'package:compose_state/compose_state.dart';

void main() {
  group('Runtime Type Validation System', () {
    late TypeValidator validator;
    late SerializationValidator serializationValidator;
    late GenericTypeHandler genericHandler;

    setUp(() {
      validator = TypeValidator.instance;
      serializationValidator = SerializationValidator.instance;
      genericHandler = GenericTypeHandler.instance;
      
      // Clear any cached data
      validator.clearCache();
      serializationValidator.clearRegistrations();
      genericHandler.clearCache();
    });

    group('TypeValidator', () {
      test('validates basic types correctly', () {
        expect(() => validator.validateType<String>("hello"), returnsNormally);
        expect(() => validator.validateType<int>(42), returnsNormally);
        expect(() => validator.validateType<bool>(true), returnsNormally);
        
        expect(
          () => validator.validateType<String>(42),
          throwsA(isA<StateValidationException>()),
        );
      });

      test('validates nullable types correctly', () {
        expect(() => validator.validateType<String?>(null), returnsNormally);
        expect(() => validator.validateType<String?>("hello"), returnsNormally);
        
        expect(
          () => validator.validateType<String>(null),
          throwsA(isA<StateValidationException>()),
        );
      });

      test('validates with custom schema', () {
        final schema = ValidationSchema.primitive(
          String,
          validators: [(value) => value.toString().length > 3],
        );
        
        validator.registerSchema('min_length_string', schema);
        
        expect(
          () => validator.validateSchema("hello", schema),
          returnsNormally,
        );
        
        expect(
          () => validator.validateSchema("hi", schema),
          throwsA(isA<StateValidationException>()),
        );
      });

      test('validates collections with schema', () {
        final itemSchema = ValidationSchema.primitive(int);
        final listSchema = ValidationSchema.collection(
          List<int>,
          minLength: 2,
          maxLength: 5,
          itemSchema: itemSchema,
        );
        
        expect(
          () => validator.validateSchema([1, 2, 3], listSchema),
          returnsNormally,
        );
        
        expect(
          () => validator.validateSchema([1], listSchema),
          throwsA(isA<StateValidationException>()),
        );
        
        expect(
          () => validator.validateSchema([1, 2, 3, 4, 5, 6], listSchema),
          throwsA(isA<StateValidationException>()),
        );
      });
    });

    group('SerializationValidator', () {
      test('validates basic serialization', () {
        expect(
          () => serializationValidator.validateSerialization<String>("hello"),
          returnsNormally,
        );
        
        expect(
          () => serializationValidator.validateSerialization<int>(42),
          returnsNormally,
        );
        
        expect(
          () => serializationValidator.validateSerialization<List<int>>([1, 2, 3]),
          returnsNormally,
        );
      });

      test('validates deserialization', () {
        expect(
          () => serializationValidator.validateDeserialization<String>("hello"),
          returnsNormally,
        );
        
        expect(
          () => serializationValidator.validateDeserialization<int>(42),
          returnsNormally,
        );
      });

      test('works with registered schemas', () {
        final schema = SerializationSchema.primitive(
          String,
          id: 'string_schema',
        );
        
        serializationValidator.registerSchema('string_schema', schema);
        
        expect(
          () => serializationValidator.validateSerialization<String>(
            "hello",
            schemaId: 'string_schema',
          ),
          returnsNormally,
        );
      });
    });

    group('GenericTypeHandler', () {
      test('analyzes generic types', () {
        final typeInfo = genericHandler.createTypeInfo<List<String>>();
        
        expect(typeInfo.baseType, equals(List<String>));
        expect(typeInfo.isGeneric, isTrue);
        expect(typeInfo.isListType, isTrue);
      });

      test('validates generic collections', () {
        expect(
          () => genericHandler.validateGenericType<List<String>>(["hello", "world"]),
          returnsNormally,
        );
        
        expect(
          () => genericHandler.validateGenericType<List<int>>([1, 2, 3]),
          returnsNormally,
        );
        
        expect(
          () => genericHandler.validateGenericType<Map<String, int>>({"count": 42}),
          returnsNormally,
        );
      });

      test('serializes and validates type information', () {
        final typeInfo = genericHandler.serializeTypeInfo<List<String>>();
        
        expect(typeInfo, isA<Map<String, dynamic>>());
        expect(typeInfo['baseType'], contains('List'));
        expect(typeInfo['isGeneric'], isTrue);
        
        expect(
          genericHandler.validateSerializedTypeInfo<List<String>>(typeInfo),
          isTrue,
        );
      });

      test('registers and retrieves type tokens', () {
        genericHandler.registerTypeToken<List<String>>('string_list');
        
        final token = genericHandler.getTypeToken<List<String>>('string_list');
        expect(token, isNotNull);
        expect(token!.type, equals(List<String>));
      });
    });

    group('ValidationMixin Integration', () {
      test('works with validated state', () {
        final state = ValidatedMutableState<String>(
          "initial",
          validator: (value) => value.length > 3,
          errorMessage: "Value must be longer than 3 characters",
        );
        
        expect(state.value, equals("initial"));
        
        state.value = "hello";
        expect(state.value, equals("hello"));
        
        expect(
          () => state.value = "hi",
          throwsA(isA<StateValidationException>()),
        );
        
        state.dispose();
      });

      test('supports custom validation schemas', () {
        final state = ValidatedMutableState<String>("initial");
        
        final schema = ValidationSchema.primitive(
          String,
          validators: [(value) => value.toString().contains('@')],
        );
        
        state.setCustomValidationSchema(schema);
        
        expect(
          () => state.value = "user@example.com",
          returnsNormally,
        );
        
        expect(
          () => state.value = "invalid-email",
          throwsA(isA<StateValidationException>()),
        );
        
        state.dispose();
      });
    });
  });
}

/// Test implementation of a validated state
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