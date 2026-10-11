import 'package:anistar/html.dart';
import 'package:anistar_tv/app/app_device_profile_resolver.dart';
import 'package:anistar_tv/packages/features/auth/auth_providers.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/bloc/catalog_bloc.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/bloc/catalog_state.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/widgets/catalog_navigation_rail.dart';
import 'package:anistar_tv/runner/runner.dart';
import 'package:app_logging/app_logging.dart';
import 'package:core/data.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:networking/networking.dart';
import 'package:networking/providers.dart';
import 'package:storage/storage.dart';
import 'package:ui_kit/ui_kit.dart';

/// Real site transport; the observer counts methods without retaining request data.
final class LiveHarness {
  static const username = String.fromEnvironment('ANISTAR_TEST_USERNAME');
  static const password = String.fromEnvironment('ANISTAR_TEST_PASSWORD');
  int loginPosts = 0;

  Future<void> resetSession() async {
    if (username.isEmpty || password.isEmpty) {
      fail('Live credentials are required; see docs/05_development_and_testing.md#9-проверка-с-живым-аккаунтом.');
    }
    final mirrors = AnistarMirrorManager(
      initial: AnistarMirrorConfig.baseUri,
      storage: SharedPreferencesStorage(),
      probe: DioClient.create(
        config: NetworkConfig(baseUri: AnistarMirrorConfig.baseUri),
        logger: AppLogger.logger,
        enableRetry: false,
      ),
    );
    await mirrors.initialize();
    final session = AnistarSession(mirrors.current, SecureStorage());
    try {
      await session.clear();
    } finally {
      await session.close();
      await mirrors.close();
    }
  }

  Future<void> launch(WidgetTester tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final previousObserver = Bloc.observer;
    addTearDown(() => Bloc.observer = previousObserver);
    final logger = AppLogger.initForTest();
    final previousFrameworkError = FlutterError.onError;
    final previousPlatformError = PlatformDispatcher.instance.onError;
    try {
      await runApplication(
        logger: logger,
        overrides: [
          dioProvider.overrideWith((ref) {
            final dio = DioClient.create(config: ref.watch(networkConfigProvider), logger: logger);
            dio.interceptors.add(
              InterceptorsWrapper(
                onRequest: (options, handler) {
                  if (options.method == 'POST') {
                    loginPosts++;
                  }
                  handler.next(options);
                },
              ),
            );
            ref.onDispose(() => dio.close(force: true));

            return dio;
          }),
        ],
      );
    } finally {
      // The production runner installs logging handlers. Keep the integration
      // binding's handlers so framework failures still fail the live test.
      FlutterError.onError = previousFrameworkError;
      PlatformDispatcher.instance.onError = previousPlatformError;
    }
    await tester.pump();
  }

  static Future<void> login(WidgetTester tester) async {
    final submit = find.byKey(const ValueKey('login_submit'));
    await wait(
      tester,
      () => submit.evaluate().isNotEmpty && tester.widget<FilledButton>(submit).onPressed != null,
      'login form ready',
    );
    await tester.enterText(find.byKey(const ValueKey('login_username')), username);
    await tester.enterText(find.byKey(const ValueKey('login_password')), password);
    if (await AppDeviceProfileResolver.resolve() == AppDeviceProfile.mobile) {
      FocusManager.instance.primaryFocus?.unfocus();
      await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
      await tester.tap(submit.hitTestable());
    } else {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(
        FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<FilledButton>()?.key,
        const ValueKey('login_submit'),
        reason: 'TV login must reach Submit through remote focus',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
    }
    await tester.pump();
  }

  static Future<void> wait(WidgetTester tester, bool Function() condition, String step) async {
    debugPrint('Live E2E: $step');
    for (var attempt = 0; attempt < 100; attempt++) {
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull, reason: 'Live E2E: $step');
      if (condition()) {
        return;
      }
    }
    final login = find.byKey(const ValueKey('login_submit'));
    if (login.evaluate().isNotEmpty) {
      final container = ProviderScope.containerOf(tester.element(login));
      final error = container.read(authControllerProvider).error;
      if (error is Failure) {
        fail('Timed out waiting for $step: ${error.message}');
      }
    }
    final tabs = find.byType(CatalogNavigationRail);
    if (tabs.evaluate().isNotEmpty) {
      final state = tester.element(tabs).read<CatalogBloc>().state;
      final favorites = tester
          .widget<CatalogNavigationRail>(tabs)
          .items
          .any((item) => item.key == const ValueKey('catalog-tab-true') && item.selected);
      fail(
        'Timed out waiting for $step: favorites=$favorites, state=${state.runtimeType}, '
        'IDs=${state.items.map((item) => item.id).join(',')}, '
        'error=${state is CatalogFailure ? state.message : 'none'}',
      );
    }
    fail('Timed out waiting for $step');
  }
}
