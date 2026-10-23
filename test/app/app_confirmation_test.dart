import 'dart:async';

import 'package:anistar_tv/app/app_confirmation.dart';
import 'package:anistar_tv/packages/features/auth/auth_providers.dart';
import 'package:anistar_tv/packages/features/catalog/catalog_providers.dart';
import 'package:anistar_tv/packages/features/home/presentation/home_destination.dart';
import 'package:anistar_tv/packages/features/home/presentation/screens/home_screen.dart';
import 'package:anistar_tv/packages/features/home/presentation/screens/tv_route_shell.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../mocks/features/catalog/fake_catalog_screen_repository.dart';
import '../support/test_app.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform root exit preserves account and requires Android confirmation', (tester) async {
      var exits = 0;
      final settle = tester.pumpAndSettle;
      final sendKey = tester.sendKeyEvent;
      final rootAction = find.text('Root Back');
      final title = find.text('Выйти из приложения?');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'SystemNavigator.pop') {
          exits++;
        }

        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await pumpTvApp(
        tester,
        Builder(
          builder: (context) => AppButton(label: 'Root Back', onPressed: () => confirmAppExit(context)),
        ),
      );
      await tester.tap(rootAction);
      await settle();
      if (platform == TargetPlatform.iOS) {
        expect(title, findsNothing);
        expect(exits, 0);
      } else {
        expect(title, findsOneWidget);
        expect(focusedControlLabel(tester), 'Отмена подтверждения');
        await sendKey(LogicalKeyboardKey.select);
        await settle();
        expect(exits, 0);
        expect(title, findsNothing);
        await tester.tap(rootAction);
        await settle();
        await sendKey(LogicalKeyboardKey.arrowDown);
        await sendKey(LogicalKeyboardKey.select);
        await settle();
        expect(exits, 1);
      }
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant({platform}));
  }

  testWidgets('large-text confirmation can scroll to message and both actions without confirming on Back', (
    tester,
  ) async {
    bool? result;
    final settle = tester.pumpAndSettle;
    final sendKey = tester.sendKeyEvent;
    await pumpMobileApp(
      tester,
      Builder(
        builder: (context) => AppButton(
          label: 'Открыть',
          onPressed: () {
            unawaited(
              showAppConfirmation(
                context,
                title: 'Выйти?',
                message: 'Аккаунт будет сохранён. Вы сможете продолжить после следующего запуска.',
                confirmLabel: 'Подтвердить',
              ).then((value) {
                result = value;
              }),
            );
          },
        ),
      ),
      size: const Size(320, 568),
      textScale: 2,
    );
    await tester.tap(find.text('Открыть'));
    await settle();
    final cancel = find.byKey(const ValueKey('confirmation-cancel'));
    expect(cancel.hitTestable(), findsOneWidget);
    await sendKey(LogicalKeyboardKey.arrowUp);
    await settle();
    final list = tester.state<ScrollableState>(find.byType(Scrollable).last).position;
    expect(list.pixels, lessThan(list.maxScrollExtent));
    await tester.binding.handlePopRoute();
    await settle();
    expect(result, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('root exit confirmation keeps Stay focused through idle, key release and route changes', (tester) async {
    var exits = 0;
    final settle = tester.pumpAndSettle;
    final handlePopRoute = tester.binding.handlePopRoute;
    final sendKey = tester.sendKeyEvent;
    final title = find.text('Выйти из приложения?');
    void expectOpenWithCancelFocus() {
      expect(title, findsOneWidget);
      expect(focusedControlLabel(tester), 'Отмена подтверждения');
    }

    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemNavigator.pop') {
        exits++;
      }

      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await pumpTvApp(
      tester,
      const _AppConfirmationTest(),
      wrapInScaffold: false,
      overrides: [
        authAccessProvider.overrideWithValue(const AuthenticatedAccess('test')),
        catalogRepositoryProvider.overrideWithValue(const FakeCatalogScreenRepository()),
      ],
    );
    await settle();
    final shell = find.byType(TvRouteShell);
    final harness = tester.state<_AppConfirmationTestState>(find.byType(_AppConfirmationTest));

    await handlePopRoute();
    await settle();
    expect(focusedControlLabel(tester), 'Главная');
    await handlePopRoute();
    await settle();
    expectOpenWithCancelFocus();

    await tester.pump(const Duration(seconds: 2));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expectOpenWithCancelFocus();

    harness.select(HomeDestination.genres);
    await settle();
    expectOpenWithCancelFocus();
    expect(tester.widget<TvRouteShell>(shell).destination, HomeDestination.genres);

    await sendKey(LogicalKeyboardKey.select);
    await settle();
    expect(title, findsNothing);
    expect(exits, 0);

    harness.select(HomeDestination.home);
    await settle();
    await handlePopRoute();
    await settle();
    await handlePopRoute();
    await settle();
    await sendKey(LogicalKeyboardKey.arrowDown);
    await sendKey(LogicalKeyboardKey.select);
    await settle();
    expect(exits, 1);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}

class _AppConfirmationTest extends StatefulWidget {
  const _AppConfirmationTest();

  @override
  State<_AppConfirmationTest> createState() => _AppConfirmationTestState();
}

class _AppConfirmationTestState extends State<_AppConfirmationTest> {
  HomeDestination _destination = HomeDestination.home;

  void select(HomeDestination destination) => setState(() => _destination = destination);

  @override
  Widget build(BuildContext context) => HomeScreen(
    destination: _destination,
    onDestinationSelected: select,
    onAnimeTap: (_) => fail('Unexpected details'),
    onRootBack: () => confirmAppExit(context),
  );
}
