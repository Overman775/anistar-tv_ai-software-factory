import 'package:anistar_tv/packages/core/core.dart';
import 'package:app_logger/app_logger.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

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
}
