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
  @override
  void initState() {
    super.initState();
    widget.state.addListener(_update);
  }

  @override
  void dispose() {
    widget.state.removeListener(_update);
    super.dispose();
  }

  void _update() => setState(() {});

  @override
  Widget build(BuildContext context) => widget.builder(context, widget.state.value);
}