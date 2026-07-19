import 'package:app_logger/app_logger.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

void main() {
  test('adds the source type to a diagnostic message', () {
    final output = _CapturingOutput();
    Logger.level = Level.all;
    addTearDown(() => Logger.level = Level.off);
    final logger = Logger(output: output);

    logger.infoFor<TypedLoggerExtensionTest>('Session created');

    expect(output.messages, ['[TypedLoggerExtensionTest] Session created']);
  });

  test('redacts headers outside the transport allowlist', () async {
    final output = _CapturingOutput();
    Logger.level = Level.all;
    addTearDown(() => Logger.level = Level.off);
    final dio = Dio(BaseOptions(baseUrl: 'https://parser.test'));
    dio.interceptors.add(DioLoggingInterceptor(Logger(output: output)));
    final adapter = DioAdapter(dio: dio);
    adapter.onGet('/catalog', (server) => server.reply(200, const <String, Object?>{}));

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

final class TypedLoggerExtensionTest {}

final class _CapturingOutput extends LogOutput {
  final messages = <Object?>[];

  @override
  void output(OutputEvent event) => messages.add(event.origin.message);
}
