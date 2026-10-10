import 'dart:async';

import 'package:storage/storage.dart';

final class MemoryPreferencesStorage extends SharedPreferencesStorage {
  final Map<String, Object> values = {};
  bool failRead = false;
  bool failWrite = false;
  Completer<void>? writeGate;
  int writes = 0;

  @override
  Future<T> get<T>(String key, T defaultValue) async {
    if (failRead) {
      throw StateError('read failed');
    }
    final value = values[key];

    return value is T ? value : defaultValue;
  }

  @override
  Future<void> set(String key, Object value) async {
    writes++;
    await writeGate?.future;
    if (failWrite) {
      throw StateError('write failed');
    }
    values[key] = value;
  }
}
