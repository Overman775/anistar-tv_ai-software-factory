import 'package:app_logging/app_logging.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:networking/networking.dart';

import '../../mocks/app_logging/capturing_log_output.dart';

void main() {
  test('shared Dio logs the prepared request and correlates an HTML response without its body', () async {
    final output = CapturingLogOutput();
    final logger = Logger(filter: ProductionFilter(), level: Level.all, output: output);
    addTearDown(logger.close);
    final dio = DioClient.create(
      config: NetworkConfig(baseUri: Uri.parse('https://site.test/'), loggablePaths: const {'/anime/'}),
      logger: logger,
      interceptors: [
        InterceptorsWrapper(
          onRequest: (options, handler) {
            options.headers.addAll({'Accept': 'text/html', 'Cookie': 'session=secret-cookie'});
            handler.next(options);
          },
        ),
      ],
    );
    addTearDown(() => dio.close(force: true));
    DioAdapter(dio: dio).onGet(
      '/anime/',
      (server) => server.reply(
        200,
        '<html>private-user-data</html>',
        headers: {
          'content-type': ['text/html'],
        },
      ),
    );
    await dio.get<String>('/anime/');
    expect(output.messages, hasLength(2));
    final request = output.messages.first;
    final response = output.messages.last;
    final diagnostics = output.messages.join();
    expect(request, contains('GET https://site.test/anime/ [#1]'));
    expect(request, contains('Accept: text/html'));
    expect(request, contains('Cookie: <redacted>'));
    expect(response, contains('Dio response 200 GET https://site.test/anime/ [#1]'));
    expect(response, contains('content-type=text/html'));
    expect(diagnostics, isNot(contains('private-user-data')));
    expect(diagnostics, isNot(contains('secret-cookie')));
  });

  test('request cancellation is a debug diagnostic rather than a production error', () async {
    final output = CapturingLogOutput();
    final logger = Logger(filter: ProductionFilter(), level: Level.all, output: output);
    addTearDown(logger.close);
    final dio = DioClient.create(
      config: NetworkConfig(baseUri: Uri.parse('https://site.test/')),
      logger: logger,
      enableRetry: false,
    );
    addTearDown(() => dio.close(force: true));
    DioAdapter(dio: dio).onGet(
      '/anime/',
      (server) => server.throws(
        0,
        DioException(
          requestOptions: RequestOptions(path: '/anime/'),
          type: DioExceptionType.cancel,
        ),
      ),
    );
    await expectLater(dio.get<String>('/anime/'), throwsA(isA<DioException>()));
    expect(output.events.last.origin.level, Level.debug);
    expect(output.messages.last, contains('Dio error cancel'));
  });

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
