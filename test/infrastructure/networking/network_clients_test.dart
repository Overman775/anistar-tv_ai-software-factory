import 'package:app_logging/app_logging.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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

  test('HttpClient resolves a relative path against the configured endpoint', () async {
    Uri? requestedUri;
    final delegate = MockClient((request) async {
      requestedUri = request.url;

      return http.Response('', 200);
    });
    final client = HttpClient(config: config, client: delegate);
    addTearDown(client.close);

    await client.get('health');

    expect(requestedUri, Uri.parse('https://site.test/base/health'));
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
