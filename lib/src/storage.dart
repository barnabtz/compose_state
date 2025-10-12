import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'compose_view_model.dart';

abstract class Storage<T> {
  Future<void> save(String key, T value);
  Future<T?> load(String key);
}

class SharedPreferencesStorage<T> implements Storage<T> {
  @override
  Future<void> save(String key, T value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is Serializable) {
      await prefs.setString(key, jsonEncode(value.toJson()));
    } else {
      await prefs.setString(key, jsonEncode(value));
    }
  }

  @override
  Future<T?> load(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(key);
    if (json == null) return null;
    final decoded = jsonDecode(json);
    if (T == Serializable) {
      return Serializable.fromJson(decoded as Map<String, dynamic>) as T;
    }
    return decoded as T;
  }
}

class InMemoryStorage<T> implements Storage<T> {
  final Map<String, T> _cache = {};

  @override
  Future<void> save(String key, T value) async {
    _cache[key] = value;
  }

  @override
  Future<T?> load(String key) async {
    return _cache[key];
  }
}