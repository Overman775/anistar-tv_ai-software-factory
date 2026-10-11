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
}
