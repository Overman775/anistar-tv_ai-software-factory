import 'package:anistar_tv/runner/runner.dart';
import 'package:app_logging/app_logging.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('startup failure reaches the caller instead of hanging in the guarded zone', () async {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'SystemChrome.setPreferredOrientations') {
          throw PlatformException(code: 'StartupError');
        }

        return null;
      });
    addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await expectLater(runApplication(logger: AppLogger.logger), throwsA(isA<PlatformException>()));
  });
}
