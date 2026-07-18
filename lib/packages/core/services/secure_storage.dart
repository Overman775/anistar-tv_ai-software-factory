import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  final FlutterSecureStorage _storage;

  SecureStorage({FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage();

  Future<String?> get(String key, {String? defaultValue}) async {
    final result = await _storage.read(key: key);

    return result ?? defaultValue;
  }

  Future<void> set(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  Future<void> remove(String key) async {
    await _storage.delete(key: key);
  }

  Future<bool> containsKey(String key) => _storage.containsKey(key: key);

  Future<void> clear() => _storage.deleteAll(aOptions: const AndroidOptions(resetOnError: true));
}
