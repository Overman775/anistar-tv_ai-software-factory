import 'package:anistar_tv/app/app_device_profile_resolver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui_kit/ui_kit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final platform in TargetPlatform.values.where((platform) => platform != TargetPlatform.android)) {
    test('$platform resolves mobile without an Android platform channel', () async {
      debugDefaultTargetPlatformOverride = platform;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      var calls = 0;
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        ..setMockMethodCallHandler(AppDeviceProfileResolver.channel, (_) async {
          calls++;

          return true;
        });
      addTearDown(() => messenger.setMockMethodCallHandler(AppDeviceProfileResolver.channel, null));
      expect(await AppDeviceProfileResolver.resolve(), AppDeviceProfile.mobile);
      expect(calls, 0);
    });
  }
}
