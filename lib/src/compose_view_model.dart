import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class ComposeViewModel extends ChangeNotifier {
  @override
  void dispose() => super.dispose();
}

abstract class Serializable {
  Map<String, dynamic> toJson();
  factory Serializable.fromJson(Map<String, dynamic> json) => throw UnimplementedError();
}

mixin Persistable on ComposeViewModel {
  Future<void> persist<T>(String key, T value, {String Function(T)? toJson}) async {
    final prefs = await SharedPreferences.getInstance();
    if (value == null) {
      await prefs.remove(key);
      return;
    }
    if (toJson != null) {
      await prefs.setString(key, toJson(value));
    } else if (value is Serializable) {
      await prefs.setString(key, jsonEncode(value.toJson()));
    } else if (value is int) {
      await prefs.setInt(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    } else if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is double) {
      await prefs.setDouble(key, value);
    } else if (value is List<String>) {
      await prefs.setStringList(key, value);
    } else {
      final json = jsonEncode(value);
      await prefs.setString(key, '$json|dynamic');
    }
  }

  Future<T?> restore<T>(String key, {T Function(String)? fromJson}) async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(key)) return null;
    if (fromJson != null) {
      final json = prefs.getString(key);
      return json != null ? fromJson(json) : null;
    }
    if (T == int) return prefs.getInt(key) as T?;
    if (T == String) return prefs.getString(key) as T?;
    if (T == bool) return prefs.getBool(key) as T?;
    if (T == double) return prefs.getDouble(key) as T?;
    if (T == List<String>) return prefs.getStringList(key) as T?;
    final raw = prefs.getString(key);
    if (raw != null && raw.endsWith('|dynamic')) {
      final json = raw.substring(0, raw.length - '|dynamic'.length);
      return jsonDecode(json) as T;
    }
    return null;
  }

  Future<void> persistDynamicList(String key, List<dynamic> values) async {
    final tagged = values.map((v) {
      if (v is Serializable) {
        return {'type': v.runtimeType.toString(), 'data': jsonEncode(v.toJson())};
      }
      return {'type': 'dynamic', 'data': jsonEncode(v)};
    }).toList();
    await persist(key, tagged);
  }

  Future<List<dynamic>> restoreDynamicList(String key, Map<String, Serializable Function(String)> typeRegistry) async {
    final List<dynamic>? raw = await restore(key);
    if (raw == null) return [];
    return raw.map((item) {
      final type = item['type'] as String;
      final data = item['data'] as String;
      final factory = typeRegistry[type];
      return factory != null ? factory(data) : jsonDecode(data);
    }).toList();
  }
}

class ViewModelScope extends StatefulWidget {
  final Map<Type, ComposeViewModel> viewModels;
  final Widget child;

  const ViewModelScope({super.key, required this.viewModels, required this.child});

  static T of<T extends ComposeViewModel>(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_InheritedViewModelScope>();
    if (scope == null) throw Exception('No ViewModelScope found in context');
    final viewModel = scope.viewModels[T];
    if (viewModel == null) throw Exception('No ViewModel of type $T found in scope');
    return viewModel as T;
  }

  @override
  State<ViewModelScope> createState() => _ViewModelScopeState();
}

class _ViewModelScopeState extends State<ViewModelScope> {
  @override
  void dispose() {
    for (final vm in widget.viewModels.values) {
      vm.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _InheritedViewModelScope(
      viewModels: widget.viewModels,
      child: widget.child,
    );
  }
}

class _InheritedViewModelScope extends InheritedWidget {
  final Map<Type, ComposeViewModel> viewModels;

  const _InheritedViewModelScope({
    required this.viewModels,
    required super.child,
  });

  @override
  bool updateShouldNotify(_InheritedViewModelScope oldWidget) => viewModels != oldWidget.viewModels;
}