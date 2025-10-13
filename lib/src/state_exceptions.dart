/// Base class for all state-related exceptions.
/// 
/// This provides a common interface for all exceptions that can occur
/// during state operations, with context information for debugging.
abstract class StateException implements Exception {
  /// The error message describing what went wrong.
  final String message;
  
  /// Additional context information about the error.
  final Map<String, dynamic> context;
  
  /// The original exception that caused this error, if any.
  final Object? cause;
  
  /// The stack trace where this exception occurred.
  final StackTrace? stackTrace;

  const StateException(
    this.message, {
    this.context = const {},
    this.cause,
    this.stackTrace,
  });

  @override
  String toString() {
    final buffer = StringBuffer('$runtimeType: $message');
    
    if (context.isNotEmpty) {
      buffer.write('\nContext: $context');
    }
    
    if (cause != null) {
      buffer.write('\nCaused by: $cause');
    }
    
    return buffer.toString();
  }
}

/// Exception thrown when state serialization operations fail.
/// 
/// This includes errors during JSON encoding/decoding, type conversion,
/// or other serialization-related operations.
class StateSerializationException extends StateException {
  /// The type that failed to serialize/deserialize.
  final Type? targetType;
  
  /// The value that caused the serialization failure.
  final Object? failedValue;

  const StateSerializationException(
    super.message, {
    super.context,
    super.cause,
    super.stackTrace,
    this.targetType,
    this.failedValue,
  });

  @override
  String toString() {
    final buffer = StringBuffer(super.toString());
    
    if (targetType != null) {
      buffer.write('\nTarget type: $targetType');
    }
    
    if (failedValue != null) {
      buffer.write('\nFailed value: $failedValue');
    }
    
    return buffer.toString();
  }
}

/// Exception thrown when state persistence operations fail.
/// 
/// This includes errors during saving to or loading from storage,
/// storage unavailability, or permission issues.
class StatePersistenceException extends StateException {
  /// The storage key that failed.
  final String? storageKey;
  
  /// The operation that failed (save, load, delete, etc.).
  final String? operation;

  const StatePersistenceException(
    super.message, {
    super.context,
    super.cause,
    super.stackTrace,
    this.storageKey,
    this.operation,
  });

  @override
  String toString() {
    final buffer = StringBuffer(super.toString());
    
    if (operation != null) {
      buffer.write('\nOperation: $operation');
    }
    
    if (storageKey != null) {
      buffer.write('\nStorage key: $storageKey');
    }
    
    return buffer.toString();
  }
}

/// Exception thrown when state validation fails.
/// 
/// This includes type validation errors, schema validation failures,
/// or constraint violations.
class StateValidationException extends StateException {
  /// The field or property that failed validation.
  final String? fieldName;
  
  /// The validation rule that was violated.
  final String? violatedRule;
  
  /// The actual value that failed validation.
  final Object? actualValue;
  
  /// The expected value or constraint.
  final Object? expectedValue;

  const StateValidationException(
    super.message, {
    super.context,
    super.cause,
    super.stackTrace,
    this.fieldName,
    this.violatedRule,
    this.actualValue,
    this.expectedValue,
  });

  @override
  String toString() {
    final buffer = StringBuffer(super.toString());
    
    if (fieldName != null) {
      buffer.write('\nField: $fieldName');
    }
    
    if (violatedRule != null) {
      buffer.write('\nViolated rule: $violatedRule');
    }
    
    if (actualValue != null) {
      buffer.write('\nActual value: $actualValue');
    }
    
    if (expectedValue != null) {
      buffer.write('\nExpected: $expectedValue');
    }
    
    return buffer.toString();
  }
}

/// Exception thrown when state consistency is violated.
/// 
/// This includes transaction failures, concurrent modification errors,
/// or dependency constraint violations.
class StateConsistencyException extends StateException {
  /// The states involved in the consistency violation.
  final List<String>? involvedStates;
  
  /// The operation that caused the consistency violation.
  final String? operation;
  
  /// Whether this was caused by concurrent access.
  final bool isConcurrencyIssue;

  const StateConsistencyException(
    super.message, {
    super.context,
    super.cause,
    super.stackTrace,
    this.involvedStates,
    this.operation,
    this.isConcurrencyIssue = false,
  });

  @override
  String toString() {
    final buffer = StringBuffer(super.toString());
    
    if (operation != null) {
      buffer.write('\nOperation: $operation');
    }
    
    if (involvedStates != null && involvedStates!.isNotEmpty) {
      buffer.write('\nInvolved states: ${involvedStates!.join(', ')}');
    }
    
    if (isConcurrencyIssue) {
      buffer.write('\nConcurrency issue detected');
    }
    
    return buffer.toString();
  }
}