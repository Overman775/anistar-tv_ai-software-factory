// Each finder observes successive startup/auth states.

import 'dart:async';

import 'package:anistar_tv/app/app.dart';
import 'package:anistar_tv/packages/features/auth/auth_providers.dart';
import 'package:anistar_tv/packages/features/auth/presentation/intro_screen.dart';
import 'package:anistar_tv/packages/features/auth/presentation/login_screen.dart';
import 'package:anistar_tv/packages/features/auth/presentation/startup_screen.dart';
import 'package:anistar_tv/packages/features/catalog/catalog_providers.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/screens/catalog_screen.dart';
import 'package:core/data.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../mocks/features/auth/fake_auth_repository.dart';
import '../../../mocks/features/catalog/fake_catalog_screen_repository.dart';
import '../../../support/test_app.dart';

void main() {
  for (final account in [null, 'test']) {
    testWidgets('startup checks site then session before routing account=$account', (tester) async {
      final site = Completer<void>();
      final session = Completer<Result<String?, Failure>>();
      final repository = FakeAuthRepository()
        ..pendingSiteCheck = site
        ..pendingRestore = session;
      addTearDown(repository.close);
      await pumpTvApp(
        tester,
        const App(),
        wrapInScaffold: false,
        overrides: [
          authRepositoryProvider.overrideWithValue(repository),
          catalogRepositoryProvider.overrideWithValue(const FakeCatalogScreenRepository()),
        ],
      );
      expect(find.byType(StartupScreen), findsOneWidget);
      expect(find.text('Проверяем доступность AniStar…'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      site.complete();
      await tester.pump();
      expect(find.text('Проверяем сохранённую сессию…'), findsOneWidget);
      expect(find.byType(CatalogScreen), findsNothing);
      session.complete(Result.success(account));
      await tester.pumpAndSettle();
      expect(find.byType(StartupScreen), findsNothing);
      expect(find.byType(account == null ? IntroScreen : CatalogScreen), findsOneWidget);
      if (account == null) {
        expect(find.byType(TextFormField), findsNothing);
        expect(
          FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<AppButton>()?.key,
          const ValueKey('intro_sign_in'),
        );
      }
      expect(repository.loginCalls, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('intro separates guest choice from the form and form cancellation returns to intro', (tester) async {
    final repository = FakeAuthRepository();
    addTearDown(repository.close);
    await pumpTvApp(
      tester,
      const App(),
      wrapInScaffold: false,
      overrides: [
        authRepositoryProvider.overrideWithValue(repository),
        catalogRepositoryProvider.overrideWithValue(const FakeCatalogScreenRepository()),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.byType(IntroScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.text('Продолжить без входа'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);

    await tester.tap(find.byKey(const ValueKey('intro_sign_in')));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Продолжить без входа'), findsNothing);
    expect(find.text('Отмена'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    // Recheck both replacement widgets after the form cancellation transition.
    expect(find.byType(IntroScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);

    await tester.tap(find.byKey(const ValueKey('intro_guest')));
    await tester.pumpAndSettle();
    expect(find.byType(CatalogScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('intro sign-in success opens the home shell without replaying a protected action', (tester) async {
    final repository = FakeAuthRepository()..loginResult = const Result.success('viewer');
    addTearDown(repository.close);
    await pumpTvApp(
      tester,
      const App(),
      wrapInScaffold: false,
      overrides: [
        authRepositoryProvider.overrideWithValue(repository),
        catalogRepositoryProvider.overrideWithValue(const FakeCatalogScreenRepository()),
      ],
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('intro_sign_in')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('login_username')), 'viewer');
    await tester.enterText(find.byKey(const ValueKey('login_password')), 'fixture-password');
    await tester.tap(find.byKey(const ValueKey('login_submit')));
    await tester.pumpAndSettle();

    expect(repository.loginCalls, 1);
    expect(find.byType(CatalogScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final siteFailed in [true, false]) {
    testWidgets('startup error keeps credentials hidden and retries by remote; site=$siteFailed', (tester) async {
      final repository = FakeAuthRepository()
        ..siteFailure = siteFailed ? const UnknownFailure() : null
        ..restoreResult = const Result.failure(UnknownFailure());
      addTearDown(repository.close);
      await pumpTvApp(
        tester,
        const App(),
        wrapInScaffold: false,
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
      );
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      final retry = find.byKey(const ValueKey('startup_retry'));
      expect(repository.restoreCalls, 1);
      expect(
        FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<AppButton>()?.key,
        const ValueKey('startup_retry'),
      );
      final nextSite = Completer<void>();
      repository
        ..siteFailure = null
        ..restoreResult = const Result.success(null)
        ..pendingSiteCheck = nextSite;
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pump();
      expect(repository.restoreCalls, 2);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(retry, findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      nextSite.complete();
      await tester.pumpAndSettle();
      expect(find.byType(IntroScreen), findsOneWidget);
      // Recheck after completion and a second OK during the pending restore.
      expect(repository.restoreCalls, 2);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('rejected login remains on the form and does not restart session restore', (tester) async {
    final repository = FakeAuthRepository()
      ..loginResult = const Result.failure(UnknownFailure())
      ..pendingLogin = Completer<Result<String, Failure>>();
    addTearDown(repository.close);
    await pumpTvApp(
      tester,
      const App(),
      wrapInScaffold: false,
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('intro_sign_in')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('login_username')), 'test');
    await tester.enterText(find.byKey(const ValueKey('login_password')), 'wrong');
    await tester.tap(find.byKey(const ValueKey('login_submit')));
    await tester.pump();
    expect(find.byType(StartupScreen), findsNothing);
    expect(find.byType(LoginScreen), findsOneWidget);
    repository.pendingLogin?.complete(const Result.failure(UnknownFailure()));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('login_error')), findsOneWidget);
    expect(find.text('Повторить проверку сессии'), findsNothing);
    expect(repository.restoreCalls, 1);
    expect(tester.takeException(), isNull);
  });

  test('expiry during restoration ignores the previous account response', () async {
    final previous = Completer<Result<String?, Failure>>();
    final repository = FakeAuthRepository()..pendingRestore = previous;
    addTearDown(repository.close);
    final container = ProviderContainer(overrides: [authRepositoryProvider.overrideWithValue(repository)]);
    addTearDown(container.dispose);
    container.read(authControllerProvider);
    await Future<void>.delayed(Duration.zero);
    repository
      ..pendingRestore = null
      ..expire();
    await Future<void>.delayed(Duration.zero);
    previous.complete(const Result.success('expired-account'));
    expect((await container.read(authControllerProvider.future)).access, isA<UnauthenticatedAccess>());
    expect(container.read(authStartupStageProvider), AuthStartupStage.complete);
  });

  testWidgets('unexpected startup errors do not show exception details', (tester) async {
    final site = Completer<void>();
    final repository = FakeAuthRepository()..pendingSiteCheck = site;
    addTearDown(repository.close);
    await pumpTvApp(
      tester,
      const App(),
      wrapInScaffold: false,
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    site.completeError(StateError('private-cookie'));
    await tester.pumpAndSettle();
    expect(find.text('Не удалось завершить проверку. Повторите попытку.'), findsOneWidget);
    expect(find.textContaining('private-cookie'), findsNothing);
    expect(find.byType(LoginScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
