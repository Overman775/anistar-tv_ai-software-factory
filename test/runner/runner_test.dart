import 'dart:async';

import 'package:anistar_tv/packages/features/auth/auth_providers.dart';
import 'package:anistar_tv/runner/runner.dart';
import 'package:app_logging/app_logging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ui_kit/ui_kit.dart';

import '../mocks/app_logging/capturing_log_output.dart';
import '../mocks/features/auth/fake_auth_repository.dart';

void main() {
  testWidgets('startup recovery retries a failed platform initialization', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final frameworkHandler = FlutterError.onError;
    final dispatcherHandler = PlatformDispatcher.instance.onError;
    var attempts = 0;
    final pendingRetry = Completer<void>();
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'SystemChrome.setPreferredOrientations') {
          attempts++;
          if (attempts == 1) throw PlatformException(code: 'StartupError');
          if (attempts == 2) {
            await pendingRetry.future;
            throw PlatformException(code: 'StartupError');
          }
        }
        return null;
      })
      ..setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (_) async => null,
      );
    addTearDown(() {
      FlutterError.onError = frameworkHandler;
      PlatformDispatcher.instance.onError = dispatcherHandler;
      messenger
        ..setMockMethodCallHandler(SystemChannels.platform, null)
        ..setMockMethodCallHandler(const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'), null);
    });
    final logger = Logger(level: Level.off);
    addTearDown(logger.close);
    await runApplication(
      logger: logger,
      deviceProfile: AppDeviceProfile.tv,
      recoverStartup: true,
      overrides: [
        authControllerProvider.overrideWithBuild((_, _) async => const AuthSessionState(UnauthenticatedAccess())),
      ],
    );
    FlutterError.onError = frameworkHandler;
    PlatformDispatcher.instance.onError = dispatcherHandler;
    await tester.pump();
    expect(find.text('Не удалось запустить приложение.'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    FlutterError.onError = frameworkHandler;
    PlatformDispatcher.instance.onError = dispatcherHandler;
    await tester.pump();
    expect(attempts, 2);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    expect(attempts, 2, reason: 'a pending retry must not be duplicated');
    pendingRetry.complete();
    await tester.pump();
    await tester.pump();
    expect(find.text('Не удалось запустить приложение.'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    FlutterError.onError = frameworkHandler;
    PlatformDispatcher.instance.onError = dispatcherHandler;
    for (var i = 0; i < 20 && find.byType(AppResponsiveRoot).evaluate().isEmpty; i++) {
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    }
    expect(attempts, 3);
    expect(find.text('Не удалось запустить приложение.'), findsNothing);
    expect(find.byType(AppResponsiveRoot), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

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

  for (final profile in AppDeviceProfile.values) {
    testWidgets('runner mounts $profile startup with platform and storage mocks only', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final platformCalls = <MethodCall>[];
      final frameworkHandler = FlutterError.onError;
      final dispatcherHandler = PlatformDispatcher.instance.onError;
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        ..setMockMethodCallHandler(SystemChannels.platform, (call) async {
          platformCalls.add(call);

          return null;
        })
        ..setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (_) async => null,
        );
      addTearDown(() {
        FlutterError.onError = frameworkHandler;
        PlatformDispatcher.instance.onError = dispatcherHandler;
        messenger
          ..setMockMethodCallHandler(SystemChannels.platform, null)
          ..setMockMethodCallHandler(const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'), null);
      });
      final logger = Logger(level: Level.off);
      addTearDown(logger.close);
      final auth = FakeAuthRepository();
      addTearDown(auth.close);

      await tester.pumpWidget(const SizedBox.shrink());
      await runApplication(
        logger: logger,
        deviceProfile: profile,
        overrides: [authRepositoryProvider.overrideWithValue(auth)],
      );
      FlutterError.onError = frameworkHandler;
      PlatformDispatcher.instance.onError = dispatcherHandler;
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      final orientations = platformCalls.singleWhere((call) => call.method == 'SystemChrome.setPreferredOrientations');
      expect(
        orientations.arguments,
        profile == AppDeviceProfile.tv
            ? ['DeviceOrientation.landscapeLeft', 'DeviceOrientation.landscapeRight']
            : <String>[],
      );
      final systemUi = platformCalls.singleWhere((call) => call.method.startsWith('SystemChrome.setEnabledSystemUI'));
      expect(
        systemUi.method,
        profile == AppDeviceProfile.tv
            ? 'SystemChrome.setEnabledSystemUIOverlays'
            : 'SystemChrome.setEnabledSystemUIMode',
      );
      expect(systemUi.arguments, profile == AppDeviceProfile.tv ? isEmpty : 'SystemUiMode.edgeToEdge');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }
}
