import 'package:anistar_tv/runner/runner.dart';
import 'package:app_logging/app_logging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../mocks/app_logging/capturing_log_output.dart';

void main() {
  test('startup failure reaches the caller instead of hanging in the guarded zone', () async {
    final frameworkHandler = FlutterError.onError;
    final dispatcherHandler = PlatformDispatcher.instance.onError;
    addTearDown(() {
      FlutterError.onError = frameworkHandler;
      PlatformDispatcher.instance.onError = dispatcherHandler;
    });
    final output = CapturingLogOutput();
    final logger = Logger(filter: ProductionFilter(), level: Level.all, output: output);
    addTearDown(logger.close);
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'SystemChrome.setPreferredOrientations') {
          throw PlatformException(code: 'StartupError');
        }

        return null;
      });
    addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await expectLater(runApplication(logger: logger), throwsA(isA<PlatformException>()));
    final failure = output.events.singleWhere((event) => event.origin.level == Level.fatal);
    expect(failure.origin.message, '[UNHANDLED] Uncaught app exception');
    expect(failure.origin.error, isA<PlatformException>());
    expect(failure.origin.stackTrace, isNotNull);
  });
}
