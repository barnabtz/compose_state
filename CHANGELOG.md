# Changelog

All notable changes to the `compose_state` package will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0-dev.1] - 2025-10-23

### Added
- `SignalState`: Granular reactivity for fine-grained rebuilds (inspired by Flutter Signals).
- `OfflinePersistableState`: Queued saves for offline support using SharedPreferences.
- `Storage<T>` abstraction for modular persistence (e.g., SharedPreferencesStorage).
- `StateDebugger<T>` for logging state changes during development.
- Basic unit tests in `test/` for core components (MutableState, HistoryState, ApiState, PersistableState, SignalState).

### Changed
- `ApiState`: Added exponential backoff retry for robust async handling.
- `HistoryState`: Improved recursion-proofing with `_inSetValue` flag.
- `PersistableState`: Supports `Storage<T>` for cross-platform flexibility (e.g., in-memory for web).
- Updated docs with CodePen embeds for interactive examples.

### Fixed
- Type mismatches with `ObservableState` setter enforcement.
- Linter warnings (unnecessary overrides, missing `@override`).

## [0.2.0] - 2025-10-12

### Added
- `SignalState`: Granular reactivity for fine-grained rebuilds (inspired by Flutter Signals).
- `OfflinePersistableState`: Queued saves for offline support using SharedPreferences.
- `Storage<T>` abstraction for modular persistence (e.g., SharedPreferencesStorage).
- `StateDebugger<T>` for logging state changes during development.
- Basic unit tests in `test/` for core components (MutableState, HistoryState, ApiState, PersistableState, SignalState).

### Changed
- `ApiState`: Added exponential backoff retry for robust async handling.
- `HistoryState`: Improved recursion-proofing with `_inSetValue` flag.
- `PersistableState`: Supports `Storage<T>` for cross-platform flexibility (e.g., in-memory for web).
- Updated docs with CodePen embeds for interactive examples.

### Fixed
- Type mismatches with `ObservableState` setter enforcement.
- Linter warnings (unnecessary overrides, missing `@override`).

[0.2.0-dev.1]: https://github.com/yourusername/compose_state/releases/tag/v0.2.0-dev.1
[0.2.0]: https://github.com/yourusername/compose_state/releases/tag/v0.2.0

## [0.1.0] - 2025-04-12

### Added
- Initial release of `compose_state`, a lightweight state management solution for Flutter.
- Core components: `MutableState`, `PersistableState`, `HistoryState`, `ApiState`, `DerivedState`, `StateBuilder`, `UiStateBuilder`.
- `ViewModelScope` for MVVM architecture.
- Example apps in documentation: Simple Counter, Persistent Counter, Async Weather App with Open-Meteo, Todo App with Firebase.
- Comprehensive HTML documentation with code snippets, tutorials, and best practices.

### Fixed
- N/A (initial release).

[0.1.0]: https://github.com/yourusername/compose_state/releases/tag/v0.1.0