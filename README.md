# compose_state

A lightweight, reactive state management solution for Flutter inspired by Jetpack Compose.

## Features
- **MutableState**: Reactive state holder.
- **PersistableState**: Built-in persistence with SharedPreferences.
- **HistoryState**: Undo/redo support.
- **ApiState**: Async data fetching with retry.
- **DerivedState**: Reactive computed states.
- **SignalState**: Granular reactivity.
- **OfflinePersistableState**: Queued saves for offline use.
- **StateBuilder & UiStateBuilder**: Targeted UI rebuilds.
- **ViewModelScope**: MVVM state hoisting.

## Installation
```yaml
dependencies:
  compose_state: ^0.2.0