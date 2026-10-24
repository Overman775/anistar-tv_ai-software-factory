import 'package:storage/storage.dart';

final class MemorySecureStorage extends SecureStorage {
  final Map<String, String> values = {};
  bool failRead = false;
  bool failWrite = false;
  bool failDelete = false;

  @override
  Future<String?> get(String key) async {
    if (failRead) {
      throw StateError('Injected secure read failure');
    }

    return values[key];
  }

  @override
  Future<void> set(String key, String value) async {
    if (failWrite) {
      throw StateError('Injected secure write failure');
    }
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    if (failDelete) {
      throw StateError('Injected secure delete failure');
    }
    values.remove(key);
  }
}
