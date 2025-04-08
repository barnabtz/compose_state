# Compose State

A Flutter state management package inspired by Jetpack Compose, providing a reactive, declarative approach to UI state management with centralized ViewModel scoping, API integration, and persistence.

## Features
- **Reactive State**: `MutableState` and `StateBuilder` for real-time UI updates.
- **Centralized Scoping**: `ViewModelScope` manages multiple ViewModels.
- **State Hoisting**: Supports hoisting state to ViewModels or directly via `MutableState.setValue`.
- **Derived State**: `DerivedState` for computed values.
- **Stream Support**: `StreamState` for asynchronous data.
- **UI States**: `UiState` with `Loading`, `Success`, and `Error`.
- **API Handling**: `ApiState` for simplified API calls.
- **Persistence**: `Persistable` mixin for storing data.

## Installation

Add to your `pubspec.yaml`:
```yaml
dependencies:
  compose_state:
    git:
      url: https://github.com/barnabtz/state_compose.git
      ref: main