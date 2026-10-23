import 'dart:convert';
import 'dart:io' as io;

import 'package:anistar/html.dart';
import 'package:anistar_tv/app/app_device_profile_resolver.dart';
import 'package:anistar_tv/runner/runner.dart';
import 'package:app_logging/app_logging.dart';
import 'package:app_logging/providers.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:networking/networking.dart';
import 'package:networking/providers.dart';
import 'package:storage/storage.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:video_player/video_player.dart';

import 'localhost_certificate.dart';

final class E2eHarness {
  final Uri origin = AnistarMirrorConfig.baseUri;
  late final Dio _control;

  E2eHarness() {
    if (origin.host != 'localhost') {
      throw StateError('E2E requires the local fixture origin; use scripts/e2e.sh.');
    }
    _control = _transport(Logger(level: Level.off));
  }

  Future<void> configure({
    bool catalogError = false,
    String videoMode = 'normal',
    bool reset = true,
    bool favoriteError = false,
    String? favorites,
  }) async {
    await _control.get<void>(
      reset ? '/__test/reset' : '/__test/config',
      queryParameters: {
        'catalog_error': '$catalogError',
        'video_mode': videoMode,
        'favorite_error': '$favoriteError',
        'favorites': ?favorites,
      },
    );
  }

  Future<Map<String, Object?>> state() async {
    final response = await _control.get<Object?>('/__test/state');
    final data = response.data;
    if (data is! Map<String, Object?>) {
      throw const FormatException('Invalid fixture state');
    }

    return data;
  }

  Future<void> expireSession() async {
    await _control.get<void>('/__test/expire');
  }

  Future<void> launch(
    WidgetTester tester, {
    bool autoLogin = true,
    bool resetSession = true,
    AppDeviceProfile? deviceProfile,
    Size? size,
  }) async {
    // Flutter resets lifecycleState to null between tests while the same native
    // Activity stays resumed. Restore the fixture's actual foreground state.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    if (resetSession) {
      final session = AnistarSession(origin, SecureStorage());
      await session.clear();
      await session.close();
    }
    final previousObserver = Bloc.observer;
    addTearDown(() => Bloc.observer = previousObserver);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final previousFrameworkError = FlutterError.onError;
    final previousPlatformError = PlatformDispatcher.instance.onError;
    try {
      await runApplication(
        deviceProfile: deviceProfile,
        logger: AppLogger.initForTest(),
        overrides: [
          dioProvider.overrideWith((ref) {
            final dio = _transport(ref.watch(loggerProvider));
            ref.onDispose(() => dio.close(force: true));

            return dio;
          }),
        ],
      );
    } finally {
      // The runner installs logging handlers; framework failures must remain
      // visible to the integration binding rather than a silent test logger.
      FlutterError.onError = previousFrameworkError;
      PlatformDispatcher.instance.onError = previousPlatformError;
    }
    await tester.pump();
    if (autoLogin) {
      await login(tester);
    }
  }

  static Future<void> login(WidgetTester tester, {String password = 'пароль'}) async {
    final mobile = await AppDeviceProfileResolver.resolve() == AppDeviceProfile.mobile;
    await openSignIn(tester, mobile: mobile);
    final submit = find.byKey(const ValueKey('login_submit'));
    await waitFor(tester, () => submit.evaluate().isNotEmpty && !tester.widget<AppButton>(submit).busy, 'login ready');
    await tester.enterText(find.byKey(const ValueKey('login_username')), 'тест');
    await tester.enterText(find.byKey(const ValueKey('login_password')), password);
    if (mobile) {
      FocusManager.instance.primaryFocus?.unfocus();
      await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
      await tester.tap(submit.hitTestable());
      await tester.pump();

      return;
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(
      FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<AppButton>()?.key,
      const ValueKey('login_submit'),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
  }

  /// Opens Intro's explicit sign-in choice, or keeps an already-open form.
  static Future<void> openSignIn(WidgetTester tester, {required bool mobile}) async {
    final signIn = find.byKey(const ValueKey('intro_sign_in'));
    final submit = find.byKey(const ValueKey('login_submit'));
    await waitFor(
      tester,
      () => signIn.evaluate().isNotEmpty || submit.evaluate().isNotEmpty,
      'authentication entry ready',
    );
    if (signIn.evaluate().isEmpty) {
      return;
    }
    await waitFor(tester, () => signIn.hitTestable().evaluate().length == 1, 'intro sign-in ready');
    if (mobile) {
      await tester.tap(signIn.hitTestable());
    } else {
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
    }
    await tester.pump();
  }

  void close() => _control.close(force: true);

  /// Dispose the app while the test binding still permits pumping, including
  /// when an assertion fails. Android keeps the Activity between test cases.
  static void testCase(String name, Future<void> Function(WidgetTester) body, {required AppDeviceProfile? profile}) =>
      testWidgets(name, (tester) async {
        try {
          await body(tester);
        } finally {
          try {
            // A failed background assertion may leave frame scheduling paused.
            // Restore it before pumping disposal, not only after disposal.
            tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump();
            await expectScreenAwake(tester, false);
          } finally {
            tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
            final restoredProfile = profile ?? await AppDeviceProfileResolver.resolve();
            await SystemChrome.setPreferredOrientations(
              restoredProfile == AppDeviceProfile.tv
                  ? [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]
                  : [],
            );
            if (restoredProfile == AppDeviceProfile.tv) {
              await SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
            } else {
              await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
            }
          }
        }
      });

  static Future<void> expectScreenAwake(WidgetTester tester, bool expected) async {
    const channel = MethodChannel('anistar_tv/playback_screen_awake');
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    bool? actual;
    while (DateTime.now().isBefore(deadline)) {
      expect(tester.binding.framesEnabled, isTrue, reason: 'Screen flag polling with pump requires active frames');
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull, reason: 'Android screen awake');
      actual = await channel.invokeMethod<bool>('isEnabled');
      if (actual == expected) {
        return;
      }
    }
    expect(actual, expected, reason: 'actual Android FLAG_KEEP_SCREEN_ON');
  }

  static VideoPlayerController? player(WidgetTester tester) {
    final finder = find.byType(VideoPlayer);

    return finder.evaluate().isEmpty ? null : tester.widget<VideoPlayer>(finder).controller;
  }

  static VideoPlayerController requirePlayer(WidgetTester tester) =>
      player(tester) ?? (throw TestFailure('Expected a native VideoPlayer'));

  static Future<void> waitFor(
    WidgetTester tester,
    bool Function() condition,
    String step, {
    String Function()? diagnostics,
    Duration timeout = const Duration(seconds: 45),
  }) async {
    debugPrint('E2E: $step');
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      expect(
        tester.binding.framesEnabled,
        isTrue,
        reason: '$step: lifecycle=${tester.binding.lifecycleState}; use polling without pump while frames are disabled',
      );
      await tester.pump(const Duration(milliseconds: 100));
      // Fail at the originating framework error instead of waiting for a UI
      // state that cannot be reached after a failed build/layout.
      expect(tester.takeException(), isNull, reason: step);
      if (condition()) {
        return;
      }
    }
    fail(
      'Timed out: $step; ${diagnostics?.call() ?? ''}; '
      'focus: ${FocusManager.instance.primaryFocus?.debugLabel}; '
      'native error: ${player(tester)?.value.errorDescription}',
    );
  }

  Dio _transport(Logger logger) {
    final context = io.SecurityContext()..setTrustedCertificatesBytes(utf8.encode(localhostCertificate));
    final dio = DioClient.create(
      config: NetworkConfig(baseUri: origin),
      logger: logger,
    )..httpClientAdapter = IOHttpClientAdapter(createHttpClient: () => io.HttpClient(context: context));

    return dio;
  }
}
