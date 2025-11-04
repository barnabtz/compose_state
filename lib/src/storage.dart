import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// An abstract interface for a key-value storage system.
///
/// This interface defines a generic contract for saving, loading, and deleting
/// data, allowing `PersistableState` to be decoupled from a specific
/// storage implementation.
abstract class Storage {
  /// Saves a [value] with the given [key].
  ///
  /// The value is encoded before being saved.
  Future<void> write<T>(String key, T value);

  /// Loads a value of type [T] for the given [key].
  ///
  /// Returns the decoded value, or `null` if the key is not found.
  Future<T?> read<T>(String key);

  /// Deletes the value associated with the given [key].
  Future<void> delete(String key);

  /// Deletes all key-value pairs.
  Future<void> clear();
}

/// A `Storage` implementation that uses the `shared_preferences` package.
///
/// This class handles the encoding and decoding of primitive types, lists,
/// and maps to and from JSON strings.
class SharedPreferencesStorage implements Storage {
  @override
  Future<void> write<T>(String key, T value) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(value);
    await prefs.setString(key, jsonString);
  }

  @override
  Future<T?> read<T>(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(key);
    if (jsonString == null) {
      return null;
    }
    return jsonDecode(jsonString) as T?;
  }

  @override
  Future<void> delete(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}