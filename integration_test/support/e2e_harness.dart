import 'dart:convert';
import 'dart:io' as io;

import 'package:anistar/anistar.dart';
import 'package:anistar_tv/runner/runner.dart';
import 'package:app_logging/app_logging.dart';
import 'package:app_logging/providers.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:networking/networking.dart';
import 'package:networking/providers.dart';
import 'package:storage/storage.dart';
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

  Future<void> launch(WidgetTester tester, {bool autoLogin = true, bool resetSession = true}) async {
    if (resetSession) {
      final session = AnistarSession(origin, SecureStorage());
      await session.clear();
      await session.close();
    }
    final previousObserver = Bloc.observer;
    addTearDown(() => Bloc.observer = previousObserver);
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await runApplication(
      logger: AppLogger.initForTest(),
      overrides: [
        dioProvider.overrideWith((ref) {
          final dio = _transport(ref.watch(loggerProvider));
          ref.onDispose(() => dio.close(force: true));

          return dio;
        }),
      ],
    );
    await tester.pump();
    if (autoLogin) {
      await login(tester);
    }
  }

  static Future<void> login(WidgetTester tester, {String password = 'пароль'}) async {
    final submit = find.byKey(const ValueKey('login_submit'));
    await waitFor(
      tester,
      () => submit.evaluate().isNotEmpty && tester.widget<FilledButton>(submit).onPressed != null,
      'login ready',
    );
    await tester.enterText(find.byKey(const ValueKey('login_username')), 'тест');
    await tester.enterText(find.byKey(const ValueKey('login_password')), password);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(
      FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<FilledButton>()?.key,
      const ValueKey('login_submit'),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
  }

  void close() => _control.close(force: true);

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
  }) async {
    debugPrint('E2E: $step');
    final deadline = DateTime.now().add(const Duration(seconds: 45));
    while (DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 100));
      if (condition()) {
        expect(tester.takeException(), isNull, reason: step);

        return;
      }
    }
    fail('Timed out: $step; ${diagnostics?.call() ?? ''}; native error: ${player(tester)?.value.errorDescription}');
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
