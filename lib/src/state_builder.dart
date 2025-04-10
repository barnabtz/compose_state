import 'package:flutter/widgets.dart';
import 'mutable_state.dart';

class StateBuilder<T> extends StatefulWidget {
  final MutableState<T> state;
  final Widget Function(BuildContext, T) builder;

  const StateBuilder({super.key, required this.state, required this.builder});

  @override
  State<StateBuilder<T>> createState() => _StateBuilderState<T>();
}

class _StateBuilderState<T> extends State<StateBuilder<T>> {
  late T _currentValue;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.state.value;
    widget.state.addListener(_update);
  }

  @override
  void didUpdateWidget(StateBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      oldWidget.state.removeListener(_update);
      widget.state.addListener(_update);
    }
    _currentValue = widget.state.value;
  }

  @override
  void dispose() {
    widget.state.removeListener(_update);
    super.dispose();
  }

  void _update() {
    if (mounted) {
      setState(() {
        _currentValue = widget.state.value;
      });
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _currentValue);
}