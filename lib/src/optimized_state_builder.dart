import 'package:flutter/widgets.dart';
import 'equality_checker.dart';
import 'observable_state.dart';

/// Enhanced StateBuilder that works optimally with batched notifications
/// and provides additional performance optimizations.
class OptimizedStateBuilder<T> extends StatefulWidget {
  final ObservableState<T> state;
  final Widget Function(BuildContext, T) builder;
  final EqualityChecker<T>? equalityChecker;
  final bool enableOptimizations;
  final Widget? child;

  const OptimizedStateBuilder({
    super.key,
    required this.state,
    required this.builder,
    this.equalityChecker,
    this.enableOptimizations = true,
    this.child,
  });

  @override
  State<OptimizedStateBuilder<T>> createState() => _OptimizedStateBuilderState<T>();
}

class _OptimizedStateBuilderState<T> extends State<OptimizedStateBuilder<T>> {
  late T _currentValue;
  late EqualityChecker<T> _equalityChecker;
  int _buildCount = 0;
  int _skippedBuilds = 0;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.state.value;
    _equalityChecker = widget.equalityChecker ?? EqualityChecker<T>();
    widget.state.addListener(_onStateChanged);
  }

  @override
  void didUpdateWidget(OptimizedStateBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (oldWidget.state != widget.state) {
      oldWidget.state.removeListener(_onStateChanged);
      widget.state.addListener(_onStateChanged);
      _currentValue = widget.state.value;
    }
    
    if (oldWidget.equalityChecker != widget.equalityChecker) {
      _equalityChecker = widget.equalityChecker ?? EqualityChecker<T>();
    }
  }

  @override
  void dispose() {
    widget.state.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (!mounted) return;

    final newValue = widget.state.value;
    
    // Use equality checker to avoid unnecessary rebuilds
    if (widget.enableOptimizations && _equalityChecker.equals(_currentValue, newValue)) {
      _skippedBuilds++;
      return;
    }

    setState(() {
      _currentValue = newValue;
      _buildCount++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _currentValue);
  }

  /// Gets performance statistics for this builder.
  Map<String, dynamic> getPerformanceStats() {
    return {
      'buildCount': _buildCount,
      'skippedBuilds': _skippedBuilds,
      'optimizationsEnabled': widget.enableOptimizations,
      'stateType': widget.state.runtimeType.toString(),
      'equalityStats': _equalityChecker.getCacheStats(),
    };
  }
}

/// Multi-state builder that can listen to multiple states efficiently.
class MultiStateBuilder extends StatefulWidget {
  final List<ObservableState> states;
  final Widget Function(BuildContext, List<dynamic>) builder;
  final bool enableOptimizations;

  const MultiStateBuilder({
    super.key,
    required this.states,
    required this.builder,
    this.enableOptimizations = true,
  });

  @override
  State<MultiStateBuilder> createState() => _MultiStateBuilderState();
}

class _MultiStateBuilderState extends State<MultiStateBuilder> {
  late List<dynamic> _currentValues;
  final List<EqualityChecker> _equalityCheckers = [];
  int _buildCount = 0;
  int _skippedBuilds = 0;

  @override
  void initState() {
    super.initState();
    _currentValues = widget.states.map((state) => state.value).toList();
    
    // Create equality checkers for each state
    for (int i = 0; i < widget.states.length; i++) {
      _equalityCheckers.add(EqualityChecker<dynamic>());
      widget.states[i].addListener(() => _onStateChanged(i));
    }
  }

  @override
  void didUpdateWidget(MultiStateBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Handle state list changes
    if (oldWidget.states.length != widget.states.length ||
        !_listsEqual(oldWidget.states, widget.states)) {
      
      // Remove old listeners
      for (int i = 0; i < oldWidget.states.length; i++) {
        oldWidget.states[i].removeListener(() => _onStateChanged(i));
      }
      
      // Clear and rebuild equality checkers
      _equalityCheckers.clear();
      _currentValues = widget.states.map((state) => state.value).toList();
      
      // Add new listeners and equality checkers
      for (int i = 0; i < widget.states.length; i++) {
        _equalityCheckers.add(EqualityChecker<dynamic>());
        widget.states[i].addListener(() => _onStateChanged(i));
      }
    }
  }

  @override
  void dispose() {
    for (int i = 0; i < widget.states.length; i++) {
      widget.states[i].removeListener(() => _onStateChanged(i));
    }
    super.dispose();
  }

  void _onStateChanged(int index) {
    if (!mounted || index >= widget.states.length) return;

    final newValue = widget.states[index].value;
    
    // Use equality checker to avoid unnecessary rebuilds
    if (widget.enableOptimizations && 
        _equalityCheckers[index].equals(_currentValues[index], newValue)) {
      _skippedBuilds++;
      return;
    }

    setState(() {
      _currentValues[index] = newValue;
      _buildCount++;
    });
  }

  bool _listsEqual(List<ObservableState> a, List<ObservableState> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _currentValues);
  }

  /// Gets performance statistics for this multi-state builder.
  Map<String, dynamic> getPerformanceStats() {
    return {
      'buildCount': _buildCount,
      'skippedBuilds': _skippedBuilds,
      'stateCount': widget.states.length,
      'optimizationsEnabled': widget.enableOptimizations,
      'equalityStats': _equalityCheckers.map((checker) => checker.getCacheStats()).toList(),
    };
  }
}

/// Convenience function to create an optimized state builder.
Widget buildOptimizedState<T>(
  ObservableState<T> state,
  Widget Function(BuildContext, T) builder, {
  EqualityChecker<T>? equalityChecker,
  bool enableOptimizations = true,
}) {
  return OptimizedStateBuilder<T>(
    state: state,
    builder: builder,
    equalityChecker: equalityChecker,
    enableOptimizations: enableOptimizations,
  );
}

/// Convenience function to create a multi-state builder.
Widget buildMultiState(
  List<ObservableState> states,
  Widget Function(BuildContext, List<dynamic>) builder, {
  bool enableOptimizations = true,
}) {
  return MultiStateBuilder(
    states: states,
    builder: builder,
    enableOptimizations: enableOptimizations,
  );
}