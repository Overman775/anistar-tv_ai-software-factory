import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesStorage {
  SharedPreferences? _preferences;

  /// init storage
  Future<SharedPreferences> init() async {
    final prefs = _preferences ??= await SharedPreferences.getInstance();

    return prefs;
  }

  /// Reads a value of [T] type from persistent storage.
  Future<T> get<T>(String key, T defaultValue) async {
    final instance = await init();
    final result = instance.get(key);

    return result is T ? result : defaultValue;
  }

  /// Saves a [value] to persistent storage in the background.
  Future<void> set(String key, Object value) async {
    final instance = await init();

    if (value is bool) {
      await instance.setBool(key, value);
    } else if (value is int) {
      await instance.setInt(key, value);
    } else if (value is double) {
      await instance.setDouble(key, value);
    } else if (value is String) {
      await instance.setString(key, value);
    } else if (value is List<String>) {
      await instance.setStringList(key, value);
    } else {
      throw UnsupportedError('Unsupported preference type: ${value.runtimeType}.');
    }
  }

  Future<bool> remove(String key) async {
    final instance = await init();

    return instance.remove(key);
  }

  Future<bool> containsKey(String key) async {
    final instance = await init();

    return instance.containsKey(key);
  }

  Future<bool> clear() async {
    final instance = await init();

    return instance.clear();
  }
}
