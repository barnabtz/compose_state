# Design Document

## Overview

The compose_state package has a well-designed architecture but is missing a critical `ObservableState<T>` interface that serves as the foundation for all state types. The design will create this missing interface and fix all related compilation errors while maintaining backward compatibility and the existing API.

## Architecture

### Core Interface Design

The `ObservableState<T>` interface will serve as the base contract for all observable state types in the package. It will extend Flutter's `Listenable` interface to provide change notification capabilities.

```dart
abstract interface class ObservableState<T> extends Listenable {
  T get value;
  set value(T newValue);
}
```

### Class Hierarchy

The corrected class hierarchy will be:

```
Listenable (Flutter)
├── ChangeNotifier (Flutter)
│   ├── MutableState<T> implements ObservableState<T>
│   ├── PersistableState<T> implements ObservableState<T>
│   ├── SignalState<T> implements ObservableState<T>
│   └── HistoryState<T> extends MutableState<T>
└── ObservableState<T> extends Listenable
    ├── DerivedState<T> implements ObservableState<T>
    ├── StateDebugger<T> implements ObservableState<T>
    └── ApiState<T> extends MutableState<UiState<T>>
```

## Components and Interfaces

### 1. ObservableState Interface
- **Location**: `lib/src/observable_state.dart` (new file)
- **Purpose**: Define the contract for all observable state types
- **Methods**:
  - `T get value` - Get current state value
  - `set value(T newValue)` - Set new state value
  - Inherits `addListener`/`removeListener` from `Listenable`

### 2. MutableState Fixes
- **Issue**: Incorrect override annotations
- **Solution**: Remove `@override` annotations since it's implementing, not overriding
- **Maintains**: All existing functionality and API

### 3. HistoryState Fixes
- **Issue**: Accessing private `_value` field from parent class
- **Solution**: Use public `value` property or create proper getter/setter
- **Maintains**: Undo/redo functionality

### 4. PersistableState Fixes
- **Issue**: Incorrect override annotations
- **Solution**: Remove `@override` annotations for interface implementation
- **Maintains**: Persistence and history integration

### 5. DerivedState Fixes
- **Issue**: Missing import for `VoidCallback` and incorrect interface usage
- **Solution**: Add proper imports and implement interface correctly
- **Maintains**: Reactive computation functionality

### 6. Other State Types
- **SignalState**: Remove incorrect override annotations
- **ApiState**: Already extends MutableState correctly
- **StateDebugger**: Implement interface properly
- **StreamState**: Remove incorrect override annotations

## Data Models

### ObservableState Interface
```dart
abstract interface class ObservableState<T> extends Listenable {
  /// The current value of the state
  T get value;
  
  /// Sets a new value for the state
  set value(T newValue);
}
```

### Type Registry (for PersistableState)
The existing type registry system for dynamic list persistence will remain unchanged:
```dart
Map<String, Serializable Function(String)> typeRegistry
```

## Error Handling

### Compilation Error Resolution
1. **Missing Interface**: Create `ObservableState<T>` interface
2. **Type Errors**: Fix all class declarations to properly implement the interface
3. **Override Warnings**: Remove incorrect `@override` annotations
4. **Import Issues**: Add missing imports for `VoidCallback` and other Flutter types

### Runtime Error Prevention
- Maintain existing null safety patterns
- Preserve existing error handling in persistence operations
- Keep existing validation in state transitions

## Testing Strategy

### Existing Test Preservation
- All existing tests must continue to pass
- No changes to public APIs that would break existing usage
- Maintain backward compatibility

### New Test Requirements
- Verify `ObservableState<T>` interface contract is properly implemented
- Test that all state types can be used polymorphically through the interface
- Ensure compilation succeeds without warnings

### Test Categories
1. **Unit Tests**: Verify each state type implements the interface correctly
2. **Integration Tests**: Test state types work together (e.g., PersistableState with HistoryState)
3. **Compilation Tests**: Ensure package compiles without errors or warnings

## Implementation Approach

### Phase 1: Create Core Interface
1. Create `lib/src/observable_state.dart` with the interface definition
2. Export the interface in the main library file

### Phase 2: Fix State Implementations
1. Update all state classes to properly implement `ObservableState<T>`
2. Remove incorrect override annotations
3. Fix access to private members in inheritance hierarchies

### Phase 3: Fix Imports and Dependencies
1. Add missing imports for `VoidCallback` and other Flutter types
2. Ensure all files have proper import statements
3. Update export statements if needed

### Phase 4: Validation
1. Run `flutter analyze` to ensure no compilation errors
2. Run existing tests to ensure backward compatibility
3. Verify all state types work correctly with `StateBuilder<T>`

## Design Decisions and Rationales

### Interface vs Abstract Class
**Decision**: Use `abstract interface class` for `ObservableState<T>`
**Rationale**: 
- Provides clear contract without implementation details
- Allows multiple inheritance patterns
- Modern Dart 3.0+ syntax for better type safety

### Extending Listenable
**Decision**: Extend Flutter's `Listenable` interface
**Rationale**:
- Integrates naturally with Flutter's change notification system
- Provides standard `addListener`/`removeListener` methods
- Allows use with Flutter's built-in widgets like `ListenableBuilder`

### Minimal API Changes
**Decision**: Keep all existing public APIs unchanged
**Rationale**:
- Maintains backward compatibility
- Reduces migration burden for existing users
- Focuses on fixing compilation issues without feature changes

### File Organization
**Decision**: Create separate file for `ObservableState<T>` interface
**Rationale**:
- Clear separation of concerns
- Easier to import just the interface when needed
- Follows Dart package organization conventions