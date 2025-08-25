import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  late final FlutterSecureStorage _storage;

  SecureStorage() {
    _storage = const FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));
  }

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

  Future<bool> containsKey(String key) {
    return _storage.containsKey(key: key);
  }

  Future<void> clear() {
    return _storage.deleteAll(aOptions: const AndroidOptions(resetOnError: true));
  }
}
