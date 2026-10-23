import 'package:anistar_tv/app/app_device_profile_resolver.dart';
import 'package:anistar_tv/app/authenticated_app.dart';
import 'package:anistar_tv/packages/features/auth/auth_providers.dart';
import 'package:anistar_tv/packages/features/auth/presentation/login_screen.dart';
import 'package:anistar_tv/packages/features/catalog/catalog_providers.dart';
import 'package:core/data.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../mocks/features/auth/fake_auth_repository.dart';
import '../mocks/features/catalog/fake_catalog_screen_repository.dart';
import '../support/test_app.dart';

void main() {
  test('Android profile comes from UI mode instead of screen width', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var television = true;
    const resolveProfile = AppDeviceProfileResolver.resolve;
    messenger.setMockMethodCallHandler(AppDeviceProfileResolver.channel, (call) async {
      expect(call.method, 'isTelevision');

      return television;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(AppDeviceProfileResolver.channel, null));
    expect(await resolveProfile(), AppDeviceProfile.tv);
    television = false;
    expect(await resolveProfile(), AppDeviceProfile.mobile);
    messenger.setMockMethodCallHandler(AppDeviceProfileResolver.channel, (_) async => throw MissingPluginException());
    // Missing-plugin fallback must be verified separately from the successful mobile response.
    expect(await resolveProfile(), AppDeviceProfile.mobile);
  });

  testWidgets('Sizer follows logical window metrics and rotation keeps the mobile role', (tester) async {
    Size? window;
    double? inset;
    AppDeviceProfile? profile;
    await pumpMobileApp(
      tester,
      Builder(
        builder: (context) {
          final scope = context.dependOnInheritedWidgetOfExactType<AppLayoutScope>();
          window = scope?.viewportSize;
          inset = AppLayoutScope.horizontalPaddingOf(context);
          profile = AppLayoutScope.profileOf(context);

          return const SizedBox.shrink();
        },
      ),
      devicePixelRatio: 3,
    );
    expect(window, const Size(390, 844));
    expect(inset, 16);
    tester.view.physicalSize = const Size(844, 390) * 3;
    await tester.pumpAndSettle();
    expect(window, const Size(844, 390));
    expect(inset, 24);
    expect(profile, AppDeviceProfile.mobile);
  });

  testWidgets('rotation of authenticated app does not override player immersive mode', (tester) async {
    final auth = FakeAuthRepository()..restoreResult = const Result.success('viewer');
    addTearDown(auth.close);
    final calls = <MethodCall>[];
    final settle = tester.pumpAndSettle;
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    void setPlatformHandler(Future<Object?> Function(MethodCall)? handler) =>
        messenger.setMockMethodCallHandler(SystemChannels.platform, handler);
    setPlatformHandler((call) async {
      calls.add(call);

      return null;
    });
    addTearDown(() => setPlatformHandler(null));
    await pumpMobileApp(
      tester,
      const AuthenticatedApp(),
      wrapInScaffold: false,
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        catalogRepositoryProvider.overrideWithValue(const FakeCatalogScreenRepository()),
      ],
    );
    await settle();
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    calls.clear();
    tester.view.physicalSize = const Size(844, 390);
    await settle();
    expect(calls.where((call) => call.method == 'SystemChrome.setEnabledSystemUIMode'), isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('mobile sheet accommodates large text and restores underlying route on Back', (tester) async {
    final settle = tester.pumpAndSettle;
    final sheet = find.byType(BottomSheet);
    await pumpMobileApp(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showAppActionSheet<void>(
            context: context,
            builder: (_) => AppActionSheet(
              title: 'Очень длинное название выбранного сериала',
              expandChild: true,
              child: ListView(
                children: [
                  // This fixture only tests sheet geometry and dismissal, not retry behavior.
                  // ignore: no-empty-block
                  TextButton(onPressed: () {}, child: const Text('Повторить')),
                ],
              ),
            ),
          ),
          child: const Text('Открыть'),
        ),
      ),
      size: const Size(320, 360),
      textScale: 2,
    );
    await tester.tap(find.text('Открыть'));
    await settle();
    expect(sheet, findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.binding.handlePopRoute();
    await settle();
    expect(sheet, findsNothing);
  });

  testWidgets('mobile login remains usable with keyboard insets and 200% text', (tester) async {
    final settle = tester.pumpAndSettle;
    final username = find.byKey(const ValueKey('login_username'));
    final password = find.byKey(const ValueKey('login_password'));
    final submit = find.byKey(const ValueKey('login_submit'));
    final auth = FakeAuthRepository();
    addTearDown(auth.close);
    await pumpMobileApp(
      tester,
      const LoginScreen(),
      size: const Size(320, 640),
      textScale: 2,
      wrapInScaffold: false,
      overrides: [authRepositoryProvider.overrideWithValue(auth)],
    );
    await settle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await settle();
    await tester.ensureVisible(username);
    await tester.enterText(username, 'viewer');
    await tester.ensureVisible(password);
    await tester.enterText(password, 'password');
    await tester.ensureVisible(submit);
    await settle();
    expect(submit.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(320, 640), const Size(390, 844)]) {
    testWidgets('mobile login golden ${size.width}', (tester) async {
      final auth = FakeAuthRepository();
      addTearDown(auth.close);
      await pumpMobileApp(
        tester,
        const LoginScreen(),
        size: size,
        wrapInScaffold: false,
        overrides: [authRepositoryProvider.overrideWithValue(auth)],
      );
      await tester.pumpAndSettle();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/mobile_login_${size.width.toInt()}.png'));
    }, tags: ['golden']);
  }
}
