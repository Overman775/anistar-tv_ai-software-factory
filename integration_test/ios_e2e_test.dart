import 'dart:io';

import 'package:anistar_tv/packages/features/auth/presentation/login_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ui_kit/ui_kit.dart';

import 'mobile_e2e_test.dart' as mobile;
import 'support/e2e_harness.dart';

/// Opt-in native Keychain/AVFoundation fixture suite. No fake storage or player.
void main() {
  const profile = String.fromEnvironment('ANISTAR_IOS_DIAGNOSTIC_PROFILE', defaultValue: 'mobile');
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    expect(Platform.isIOS, isTrue, reason: 'Use the explicit iOS Simulator runner.');
    expect(profile, isIn(['mobile', 'tv']));
  });
  if (profile == 'mobile') {
    // The shared touch suite covers native session restore/logout, catalog,
    // HLS headers/refresh, seek/quality/episode, rotation and lifecycle.
    mobile.main();

    return;
  }
  E2eHarness.testCase('iPad explicit TV profile layout diagnostic', (tester) async {
    final fixture = E2eHarness();
    addTearDown(fixture.close);
    await fixture.configure();
    await fixture.launch(tester, autoLogin: false, deviceProfile: AppDeviceProfile.tv);
    await E2eHarness.waitFor(tester, () => find.byType(LoginScreen).evaluate().isNotEmpty, 'TV diagnostic login');
    expect(AppLayoutScope.profileOf(tester.element(find.byType(LoginScreen))), AppDeviceProfile.tv);
    expect(tester.takeException(), isNull, reason: 'TV diagnostic layout');
  }, profile: AppDeviceProfile.tv);
}
