import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:ui_kit/ui_kit.dart';

/// Resolve the Android device role before setting orientation or building UI.
abstract final class AppDeviceProfileResolver {
  static const channel = MethodChannel('anistar_tv/device_profile');

  static Future<AppDeviceProfile> resolve() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return AppDeviceProfile.mobile;
    }
    try {
      final television = await channel.invokeMethod<bool>('isTelevision');

      return television == true ? AppDeviceProfile.tv : AppDeviceProfile.mobile;
    } on MissingPluginException {
      return AppDeviceProfile.mobile;
    } on PlatformException {
      return AppDeviceProfile.mobile;
    }
  }
}
