import 'package:app_logging/app_logging.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:networking/networking.dart';

import '../../mocks/app_logging/capturing_log_output.dart';

void main() {
  test('signed paths, queries, credentials and upstream error messages stay out of diagnostics', () async {
    final output = CapturingLogOutput();
    Logger.level = Level.all;
    addTearDown(() => Logger.level = Level.off);
    final logger = Logger(output: output);
    addTearDown(logger.close);
    final dio = Dio()..interceptors.add(DioLoggingInterceptor(logger));
    addTearDown(() => dio.close(force: true));
    const url = 'https://user:password@cdn.test/key=secret-token,end=123/video.mp4?token=query-secret';
    DioAdapter(dio: dio).onGet(
      url,
      (server) => server.throws(
        403,
        DioException(
          requestOptions: RequestOptions(path: url),
          message: 'upstream $url',
          type: DioExceptionType.badResponse,
        ),
      ),
    );
    await expectLater(dio.get<void>(url), throwsA(isA<DioException>()));
    final diagnostics = '${output.messages} ${output.errors}';
    expect(diagnostics, contains('cdn.test'));
    for (final secret in ['secret-token', 'query-secret', 'password', 'upstream']) {
      expect(diagnostics, isNot(contains(secret)));
    }
  });

  test('redacts headers outside the transport allowlist', () async {
    final output = CapturingLogOutput();
    Logger.level = Level.all;
    addTearDown(() => Logger.level = Level.off);
    final dio = Dio(BaseOptions(baseUrl: 'https://site.test'))
      ..interceptors.add(DioLoggingInterceptor(Logger(output: output)));
    addTearDown(() => dio.close(force: true));
    DioAdapter(dio: dio).onGet('/catalog', (server) => server.reply(200, const <String, Object?>{}));
    await dio.get<void>(
      '/catalog',
      options: Options(headers: const {'Accept': 'application/json', 'X-Api-Key': 'secret'}),
    );
    final requestMessage = output.messages.firstWhere(
      (message) => message is String && message.startsWith('Dio request'),
    );
    expect(requestMessage, contains('X-Api-Key: <redacted>'));
    expect(requestMessage, isNot(contains('secret')));
  });
}
