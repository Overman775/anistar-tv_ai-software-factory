import 'package:anistar/anistar.dart';
import 'package:anistar_tv/packages/features/auth/auth_providers.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/bloc/catalog_bloc.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/bloc/catalog_state.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/widgets/catalog_tabs.dart';
import 'package:anistar_tv/runner/runner.dart';
import 'package:app_logging/app_logging.dart';
import 'package:core/data.dart';
import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:networking/networking.dart';
import 'package:networking/providers.dart';
import 'package:storage/storage.dart';

/// Real site transport; the observer counts methods without retaining request data.
final class LiveHarness {
  static const username = String.fromEnvironment('ANISTAR_TEST_USERNAME');
  static const password = String.fromEnvironment('ANISTAR_TEST_PASSWORD');
  int loginPosts = 0;

  Future<void> resetSession() async {
    if (username.isEmpty || password.isEmpty) {
      fail('Live credentials are required; see docs/05_development_and_testing.md#9-проверка-с-живым-аккаунтом.');
    }
    final mirrors = AnistarMirrorManager(initial: AnistarMirrorConfig.baseUri, storage: SharedPreferencesStorage());
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
    final logger = AppLogger.initForTest();
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
    await tester.tap(submit);
  }

  static Future<void> wait(WidgetTester tester, bool Function() condition, String step) async {
    debugPrint('Live E2E: $step');
    for (var attempt = 0; attempt < 100; attempt++) {
      await tester.pump(const Duration(milliseconds: 500));
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
    final tabs = find.byType(CatalogTabs);
    if (tabs.evaluate().isNotEmpty) {
      final state = tester.element(tabs).read<CatalogBloc>().state;
      final favorites = tester.widget<CatalogTabs>(tabs).favoritesOnly;
      fail(
        'Timed out waiting for $step: favorites=$favorites, state=${state.runtimeType}, '
        'IDs=${state.items.map((item) => item.id).join(',')}, '
        'error=${state is CatalogFailure ? state.message : 'none'}',
      );
    }
    fail('Timed out waiting for $step');
  }
}
