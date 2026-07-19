import 'package:anistar_tv/packages/core/core.dart';
import 'package:app_logger/app_logger.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

void main() {
  final config = NetworkConfig(baseUri: Uri.parse('https://parser.test/base/'));

  test('DioClient applies the parser endpoint and timeouts', () {
    final dio = DioClient.create(
      config: config,
      logger: Logger(level: Level.off),
    );

    expect(dio.options.baseUrl, 'https://parser.test/base/');
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

    await client.get('health');

    expect(requestedUri, Uri.parse('https://parser.test/base/health'));
  });

  test('does not retry a non-idempotent playback request', () async {
    final dio = DioClient.create(
      config: config,
      logger: Logger(level: Level.off),
    );
    final adapter = DioAdapter(dio: dio);
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
