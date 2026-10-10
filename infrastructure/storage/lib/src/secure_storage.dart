import 'dart:async';

import 'package:app_logging/app_logging.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  final FlutterSecureStorage _storage;
  final Logger _logger;

  SecureStorage({FlutterSecureStorage? storage, Logger? logger})
    : _storage = storage ?? const FlutterSecureStorage(),
      _logger = logger ?? Logger(level: Level.off);

  Future<String?> get(String key, {String? defaultValue}) async {
    final result = await _storage.read(key: key);
    _logger.debugFor<SecureStorage>('Read secure value (key and value omitted)');

    return result ?? defaultValue;
  }

  Future<void> set(String key, String value) async {
    await _storage.write(key: key, value: value);
    _logger.debugFor<SecureStorage>('Saved secure value (key and value omitted)');
  }

  Future<void> remove(String key) async {
    await _storage.delete(key: key);
    _logger.debugFor<SecureStorage>('Removed secure value (key omitted)');
  }

  Future<bool> containsKey(String key) async {
    final containsKey = await _storage.containsKey(key: key);
    _logger.debugFor<SecureStorage>('Checked secure value presence: $containsKey');

    return containsKey;
  }

  Future<void> clear() async {
    await _storage.deleteAll(aOptions: AndroidOptions.defaultOptions);
    _logger.warningFor<SecureStorage>('Cleared all secure values');
  }
}
