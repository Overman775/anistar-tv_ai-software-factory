import 'dart:convert';
import 'dart:io';

import 'package:anistar/anistar.dart';
import 'package:anistar/html.dart';
import 'package:app_logging/app_logging.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:networking/networking.dart';

import '../../test/mocks/storage/memory_preferences_storage.dart';
import '../../test/mocks/storage/memory_secure_storage.dart';

/// Explicit live diagnostic, outside the offline unit-test directory.
/// Checks login and read operations without changing favorites/history.
void main() {
  test('live Dio mirror check, login, catalog and restore', () async {
    final logger = Logger(level: Level.off);
    addTearDown(logger.close);
    final origin = AnistarMirrorConfig.baseUri;
    final probe = DioClient.create(
      config: NetworkConfig(
        baseUri: origin,
        connectTimeout: const Duration(seconds: 4),
        receiveTimeout: const Duration(seconds: 4),
        sendTimeout: const Duration(seconds: 4),
      ),
      logger: logger,
      enableRetry: false,
    );
    final mirrors = AnistarMirrorManager(initial: origin, storage: MemoryPreferencesStorage(), probe: probe);
    addTearDown(mirrors.close);
    await mirrors.initialize();
    await _step('mirror availability', mirrors.ensureAvailable);
    debugPrint('Live mirror: ${mirrors.current.host}');
    final session = AnistarSession(mirrors.current, MemorySecureStorage());
    addTearDown(session.close);
    final dio = DioClient.create(
      config: NetworkConfig(baseUri: mirrors.current),
      logger: logger,
      interceptors: [AnistarSessionInterceptor(session)],
    );
    addTearDown(() => dio.close(force: true));
    final client = HtmlAnistarClient(dio, session, ensureMirror: mirrors.ensureAvailable);
    final page = await _step('anonymous catalog', () => client.catalog(1));
    debugPrint('Live catalog: ${page.items.length} items');
    const credentialsPath = String.fromEnvironment(
      'ANISTAR_LIVE_CREDENTIALS_FILE',
      defaultValue: 'env/live-test.local.json',
    );
    final credentials = await _step('local credentials', () async {
      final Object? decoded = jsonDecode(await File(credentialsPath).readAsString());
      if (decoded is! Map<String, Object?>) {
        throw const FormatException('Invalid local credentials');
      }

      return decoded;
    });
    final username = credentials['ANISTAR_TEST_USERNAME'];
    final password = credentials['ANISTAR_TEST_PASSWORD'];
    if (username is! String || password is! String) {
      fail('Local test credentials must contain a username and password');
    }
    expect(username.isNotEmpty && password.isNotEmpty, isTrue, reason: 'Local test credentials are required');
    final account = await _step('login', () => client.signIn(username, password));
    expect(account == username.trim(), isTrue);
    await _step('authenticated catalog', () => client.catalog(1));
    final restored = await _step('restore', client.restore);
    expect(restored == account, isTrue);
    await client.signOut();
    debugPrint('Live login, catalog and restore passed; local test session cleared');
  }, timeout: const Timeout(Duration(minutes: 2)));
}

Future<T> _step<T>(String name, Future<T> Function() operation) async {
  try {
    return await operation();
  } on DioException catch (error) {
    fail(
      '$name: ${error.type.name}; status=${error.response?.statusCode}; '
      'host=${error.requestOptions.uri.host}; challenge=${error.response?.headers.value('cf-mitigated')}',
    );
  } on AnistarClientException catch (error) {
    fail('$name: ${error.message}');
  } on Object catch (error) {
    fail('$name: ${error.runtimeType}');
  }
}
