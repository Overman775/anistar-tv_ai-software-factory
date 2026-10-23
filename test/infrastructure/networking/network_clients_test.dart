import 'dart:typed_data';

import 'package:app_logging/app_logging.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:networking/networking.dart';

void main() {
  final config = NetworkConfig(baseUri: Uri.parse('https://site.test/base/'));

  test('DioClient applies the endpoint and timeouts without site policy', () {
    final dio = DioClient.create(
      config: config,
      logger: Logger(level: Level.off),
    );
    addTearDown(() => dio.close(force: true));

    expect(dio.options.baseUrl, 'https://site.test/base/');
    final headers = dio.options.headers;
    expect(headers.containsKey('User-Agent'), isFalse);
    expect(headers.containsKey('Accept'), isFalse);
    expect(dio.options.connectTimeout, const Duration(seconds: 8));
    expect(dio.options.receiveTimeout, const Duration(seconds: 20));
    expect(dio.interceptors, hasLength(3));
    expect(dio.interceptors, contains(isA<DioLoggingInterceptor>()));
  });

  test('DioClient installs session/header interceptors before logging', () async {
    final headers = InterceptorsWrapper(
      onRequest: (options, handler) {
        options.headers['Accept'] = 'text/html';
        handler.next(options);
      },
    );
    final dio = DioClient.create(
      config: config,
      logger: Logger(level: Level.off),
      interceptors: [headers],
    );
    addTearDown(() => dio.close(force: true));
    expect(dio.interceptors.last, isA<DioLoggingInterceptor>());
    final session = InterceptorsWrapper();
    DioClient.addInterceptors(dio, [session]);
    expect(dio.interceptors.indexOf(session), lessThan(dio.interceptors.length - 1));
  });

  test('mirror probes can disable retry and use the same logging factory', () async {
    final dio = DioClient.create(
      config: config,
      logger: Logger(level: Level.off),
      enableRetry: false,
    );
    addTearDown(() => dio.close(force: true));
    var requests = 0;
    DioClient.addInterceptors(dio, [
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests++;
          handler.next(options);
        },
      ),
    ]);
    DioAdapter(dio: dio).onGet('/anime/', (server) => server.reply(503, 'Unavailable'));
    await expectLater(dio.get<String>('/anime/'), throwsA(isA<DioException>()));
    expect(requests, 1);
    expect(dio.interceptors.last, isA<DioLoggingInterceptor>());
  });

  test('does not retry a non-idempotent playback request', () async {
    final dio = DioClient.create(
      config: config,
      logger: Logger(level: Level.off),
    );
    final adapter = DioAdapter(dio: dio);
    addTearDown(() => dio.close(force: true));
    var requests = 0;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests++;
          handler.next(options);
        },
      ),
    );
    adapter.onPost('/playback', (server) => server.reply(503, const <String, Object?>{}));

    await expectLater(dio.post<void>('/playback'), throwsA(isA<DioException>()));

    expect(requests, 1);
  });

  testWidgets('retries an idempotent request until a local adapter succeeds', (tester) async {
    final dio = DioClient.create(
      config: config,
      logger: Logger(level: Level.off),
    );
    final adapter = NetworkClientsTest((attempt) => attempt == 1 ? 503 : 200);
    dio.httpClientAdapter = adapter;
    addTearDown(() => dio.close(force: true));

    final response = dio.get<String>('/retry');
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(((await response).statusCode, adapter.attempts), (200, 2));
  });

  testWidgets('stops retrying after the documented attempt limit', (tester) async {
    final dio = DioClient.create(
      config: config,
      logger: Logger(level: Level.off),
    );
    final adapter = NetworkClientsTest((_) => 503);
    dio.httpClientAdapter = adapter;
    addTearDown(() => dio.close(force: true));

    final response = dio.get<String>('/retry-limit');
    final failure = expectLater(response, throwsA(isA<DioException>()));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    await failure;

    expect(adapter.attempts, 3);
  });

  testWidgets('does not retry after cancellation during a retryable local response', (tester) async {
    final dio = DioClient.create(
      config: config,
      logger: Logger(level: Level.off),
    );
    final adapter = NetworkClientsTest((_) => 503);
    dio.httpClientAdapter = adapter;
    final cancellation = CancelToken();
    addTearDown(() => dio.close(force: true));
    final response = dio.get<String>('/cancel-retry', cancelToken: cancellation);
    final failure = expectLater(response, throwsA(isA<DioException>()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(adapter.attempts, 1);
    cancellation.cancel('user cancelled');
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    await failure;

    expect(adapter.attempts, 1);
  });
}

final class NetworkClientsTest implements HttpClientAdapter {
  NetworkClientsTest(this._statusAt);

  final int Function(int attempt) _statusAt;
  int attempts = 0;
  var _closed = false;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) {
    if (_closed) {
      return Future.error(StateError('The test adapter is closed.'));
    }
    attempts++;
    final status = _statusAt(attempts);
    return Future.value(ResponseBody.fromString(status == 200 ? 'ready' : 'unavailable', status));
  }

  @override
  void close({bool force = false}) {
    _closed = true;
  }
}
