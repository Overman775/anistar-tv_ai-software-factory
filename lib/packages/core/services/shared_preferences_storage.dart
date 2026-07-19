import 'dart:async';

import 'package:app_logger/app_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesStorage {
  SharedPreferences? _preferences;
  final Logger _logger;

  SharedPreferencesStorage({Logger? logger}) : _logger = logger ?? Logger(level: Level.off);

  /// init storage
  Future<SharedPreferences> init() async {
    final existing = _preferences;
    if (existing != null) return existing;
    _logger.debugFor<SharedPreferencesStorage>('Initializing persistent preferences');
    final prefs = _preferences = await SharedPreferences.getInstance();
    _logger.infoFor<SharedPreferencesStorage>('Persistent preferences initialized');

    return prefs;
  }

  /// Reads a value of [T] type from persistent storage.
  Future<T> get<T>(String key, T defaultValue) async {
    final instance = await init();
    final result = instance.get(key);

    _logger.debugFor<SharedPreferencesStorage>('Read preference (value omitted)');

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
    _logger.debugFor<SharedPreferencesStorage>('Saved preference (key and value omitted)');
  }

  Future<bool> remove(String key) async {
    final instance = await init();

    final removed = await instance.remove(key);
    _logger.debugFor<SharedPreferencesStorage>('Removed preference: $removed');

    return removed;
  }

  Future<bool> containsKey(String key) async {
    final instance = await init();

    final containsKey = instance.containsKey(key);
    _logger.debugFor<SharedPreferencesStorage>('Checked preference presence: $containsKey');

    return containsKey;
  }

  Future<bool> clear() async {
    final instance = await init();

    final cleared = await instance.clear();
    _logger.warningFor<SharedPreferencesStorage>('Cleared all preferences: $cleared');

    return cleared;
  }
}
