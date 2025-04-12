# Changelog

All notable changes to the `compose_state` package will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2025-04-12

### Added
- Initial release of `compose_state`, a lightweight state management solution for Flutter.
- Core components:
  - `MutableState`: Reactive state holder for simple state management.
  - `PersistableState`: Persists state across app restarts using shared preferences.
  - `HistoryState`: Supports undo/redo for `PersistableState`.
  - `ApiState`: Manages asynchronous data fetching with loading/success/error states.
  - `DerivedState`: Computes state based on other states for reactive updates.
  - `StateBuilder`: Widget to rebuild UI on state changes.
  - `UiStateBuilder`: Widget to handle async states (loading, success, error).
- `ViewModelScope` for MVVM architecture, separating business logic from UI.
- Example apps in documentation:
  - Simple Counter using `MutableState` and `StateBuilder`.
  - Persistent Counter with `PersistableState` and undo/redo.
  - Async Weather App using `ApiState`, `DerivedState`, and Open-Meteo API.
  - Todo App with Firebase Auth/Firestore, Clean Architecture, and MVVM.
- Comprehensive HTML documentation with code snippets, tutorials, and best practices.

### Fixed
- N/A (initial release).

### Changed
- N/A (initial release).

[0.1.0]: https://github.com/yourusername/compose_state/releases/tag/v0.1.0