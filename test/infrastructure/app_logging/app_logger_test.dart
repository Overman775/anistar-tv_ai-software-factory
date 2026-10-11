import 'dart:async';
import 'dart:io';

import 'package:app_logging/app_logging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../mocks/app_logging/capturing_log_output.dart';

void main() {
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  const levels = [Level.trace, Level.debug, Level.info, Level.warning, Level.error, Level.fatal];
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('anistar-app-logger-test-');
    final frameworkHandler = FlutterError.onError;
    final dispatcherHandler = PlatformDispatcher.instance.onError;
    final defaultFilter = Logger.defaultFilter;
    // The runtime must configure its own filter: the package default depends
    // on assertions and would silently drop profile/release messages.
    Logger.defaultFilter = () => throw StateError('Runtime must select an explicit filter');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      pathProviderChannel,
      (call) async => call.method == 'getApplicationCacheDirectory' ? directory.path : null,
    );
    addTearDown(() async {
      FlutterError.onError = frameworkHandler;
      PlatformDispatcher.instance.onError = dispatcherHandler;
      Logger.defaultFilter = defaultFilter;
      AppLogger.initForTest();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        pathProviderChannel,
        null,
      );
      await directory.delete(recursive: true);
    });
  });

  test('development sends every level to the console and file, including early messages', () async {
    final console = <String>[];
    await runZoned(() async {
      final logger = AppLogger.init(isDevelopment: true);
      addTearDown(logger.close);
      for (final level in levels) {
        logger.log(level, 'dev-${level.name}-message');
      }
      await logger.init;
      await logger.close();
    }, zoneSpecification: ZoneSpecification(print: (_, _, _, line) => console.add(line)));

    final files = await FileLogOutput.getLogFiles();
    expect(files, hasLength(1));
    final content = await FileLogOutput.getLogContent(files.single);
    final consoleContent = console.join('\n');
    for (final level in levels) {
      final marker = 'dev-${level.name}-message';
      final hasMarker = contains(marker);
      expect(consoleContent, hasMarker);
      expect(content, hasMarker);
    }
  });

  test('production sends only error and fatal to the console without creating log files', () async {
    final console = <String>[];
    await runZoned(() async {
      final logger = AppLogger.init(isDevelopment: false);
      addTearDown(logger.close);
      await logger.init;
      for (final level in levels) {
        logger.log(level, 'prod-${level.name}-message');
      }
      await logger.close();
    }, zoneSpecification: ZoneSpecification(print: (_, _, _, line) => console.add(line)));

    final content = console.join('\n');
    for (final level in levels) {
      expect(
        content,
        level >= Level.error ? contains('prod-${level.name}-message') : isNot(contains('prod-${level.name}-message')),
      );
    }
    expect(await directory.list().toList(), isEmpty);
  });

  test('framework, platform and zone failures share the fatal UNHANDLED marker and original stack', () async {
    final output = CapturingLogOutput();
    final logger = Logger(filter: ProductionFilter(), level: Level.error, output: output);
    addTearDown(logger.close);
    await logger.init;
    AppLogger.installErrorHandlers(logger);
    final error = StateError('unhandled failure');
    final stack = StackTrace.current;
    FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack));
    final platformHandler = PlatformDispatcher.instance.onError;
    if (platformHandler == null) {
      fail('Platform error handler was not installed');
    }
    expect(platformHandler(error, stack), isTrue);
    AppLogger.reportUnhandled(error, stack, logger: logger);

    expect(output.messages, [
      '[UNHANDLED] FlutterError.onError',
      '[UNHANDLED] PlatformDispatcher.onError',
      '[UNHANDLED] Uncaught app exception',
    ]);
    for (final event in output.events) {
      expect(event.origin.level, Level.fatal);
      expect(event.origin.error, same(error));
      expect(event.origin.stackTrace, same(stack));
    }
  });
}
