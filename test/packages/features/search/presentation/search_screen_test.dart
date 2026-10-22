import 'dart:async';

import 'package:anistar_tv/app/app_router.dart';
import 'package:anistar_tv/app/app_routes.dart';
import 'package:anistar_tv/packages/features/auth/auth_providers.dart';
import 'package:anistar_tv/packages/features/catalog/catalog_providers.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/anime_page.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/anime_summary.dart';
import 'package:anistar_tv/packages/features/home/presentation/home_destination.dart';
import 'package:anistar_tv/packages/features/home/presentation/screens/home_screen.dart';
import 'package:anistar_tv/packages/features/search/presentation/search_screen.dart';
import 'package:anistar_tv/packages/features/search/search_providers.dart';
import 'package:app_logging/app_logging.dart';
import 'package:core/data.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../../mocks/features/auth/fake_auth_repository.dart';
import '../../../../mocks/features/catalog/fake_catalog_screen_repository.dart';
import '../../../../mocks/features/search/fake_search_repository.dart';
import '../../../../support/test_app.dart';

void main() {
  final query = find.byKey(const ValueKey('search-query'));
  final submit = find.byKey(const ValueKey('search-submit'));
  final clear = find.byKey(const ValueKey('search-clear'));
  final feedbackActions = find.descendant(of: find.byType(TvStateView), matching: find.byType(AppButton));

  testWidgets('routed TV search has a Material content ancestor and preserves editing Back', (tester) async {
    final auth = FakeAuthRepository();
    addTearDown(auth.close);
    final router = AppRouter(AppLogger.logger);
    addTearDown(router.dispose);
    await pumpTvApp(
      tester,
      MaterialApp.router(routerConfig: router.router, theme: AppTheme.darkTheme),
      wrapInScaffold: false,
      overrides: [
        authAccessProvider.overrideWithValue(const AnonymousAccess()),
        authRepositoryProvider.overrideWithValue(auth),
        catalogRepositoryProvider.overrideWithValue(const FakeCatalogScreenRepository()),
        searchRepositoryProvider.overrideWithValue(FakeSearchRepository()),
        searchHistoryRepositoryProvider.overrideWithValue(FakeSearchHistoryRepository()),
      ],
    );
    final settle = tester.pumpAndSettle;
    await settle();
    const HomeRoute(destination: HomeDestination.search).go(tester.element(find.byType(HomeScreen)));
    await settle();
    final fieldContext = tester.element(query);
    expect(fieldContext.findAncestorWidgetOfExactType<Material>(), isNotNull);
    expect(fieldContext.findAncestorWidgetOfExactType<TvBackdrop>(), isNotNull);
    expect(tester.widget<TextField>(query).focusNode?.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    await tester.enterText(query, 'Наруто');
    await tester.binding.handlePopRoute();
    await settle();
    final field = tester.widget<TextField>(query);
    expect(field.readOnly, isTrue);
    expect(field.controller?.text, 'Наруто');
    expect(field.focusNode?.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('TV form separates remote navigation, editing and explicit submit without focus theft', (tester) async {
    final settle = tester.pumpAndSettle;
    final pump = tester.pump;
    final key = tester.sendKeyEvent;
    TextField readField() => tester.widget<TextField>(query);
    final repository = FakeSearchRepository();
    var menuOpened = 0;
    await pumpTvApp(
      tester,
      SearchScreen(onAnimeTap: (_) => fail('Unexpected detail'), onOpenNavigation: () => menuOpened++),
      overrides: [
        authAccessProvider.overrideWithValue(const AnonymousAccess()),
        searchRepositoryProvider.overrideWithValue(repository),
        searchHistoryRepositoryProvider.overrideWithValue(FakeSearchHistoryRepository()),
      ],
    );
    await settle();
    final field = readField();
    expect(field.readOnly, isTrue);
    expect(field.decoration?.hintText, isNull);
    final fieldNode = field.focusNode;
    await key(LogicalKeyboardKey.arrowRight);
    await pump();
    expect(tester.widget<AppButton>(submit).focusNode?.hasFocus, isTrue);
    await key(LogicalKeyboardKey.arrowLeft);
    await key(LogicalKeyboardKey.select);
    await pump();
    final editing = readField();
    expect(editing.readOnly, isFalse);
    await tester.enterText(query, 'Наруто');
    expect(repository.requests, isEmpty);
    await key(LogicalKeyboardKey.escape);
    await pump();
    final afterBack = readField();
    expect(afterBack.controller?.text, 'Наруто');
    expect(afterBack.readOnly, isTrue);
    await key(LogicalKeyboardKey.arrowRight);
    await pump();
    expect(tester.widget<IconButton>(clear).focusNode?.hasFocus, isTrue);
    await key(LogicalKeyboardKey.arrowRight);
    await key(LogicalKeyboardKey.select);
    await settle();
    expect(repository.requests.single.query, 'Наруто');
    expect(find.text('Ничего не найдено'), findsOneWidget);
    expect(FocusManager.instance.primaryFocus, same(fieldNode));
    expect(find.text('Повторить загрузку'), findsNothing);
    await key(LogicalKeyboardKey.arrowLeft);
    expect(menuOpened, 1);
  });

  for (final size in [const Size(320, 640), const Size(390, 844), const Size(844, 390)]) {
    testWidgets('touch search keeps a single-row form at doubled text $size', (tester) async {
      final settle = tester.pumpAndSettle;
      TextField readField() => tester.widget<TextField>(query);
      final repository = FakeSearchRepository();
      await pumpMobileApp(
        tester,
        SearchScreen(onAnimeTap: (_) => fail('Unexpected detail')),
        size: size,
        textScale: 2,
        overrides: [
          authAccessProvider.overrideWithValue(const AnonymousAccess()),
          searchRepositoryProvider.overrideWithValue(repository),
          searchHistoryRepositoryProvider.overrideWithValue(FakeSearchHistoryRepository()),
        ],
      );
      await settle();
      final mobileField = readField();
      expect(mobileField.readOnly, isFalse);
      final fieldRect = tester.getRect(query);
      final buttonRect = tester.getRect(submit);
      expect(fieldRect.top, buttonRect.top);
      expect(fieldRect.right, lessThan(buttonRect.left));
      expect(buttonRect.right, lessThanOrEqualTo(size.width));
      await tester.enterText(query, 'Наруто');
      expect(repository.requests, isEmpty);
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await settle();
      expect(repository.requests.single.query, 'Наруто');
      await tester.tap(clear);
      await tester.pump();
      expect(mobileField.controller?.text, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('TV remote reaches pagination retry and retains cards through repeated failure', (tester) async {
    final pendingRetry = Completer<Result<AnimePage, Failure>>();
    var pageTwoCalls = 0;
    final repository = FakeSearchRepository(
      load: (request) async {
        if (request.page == 1) {
          return Result.success(
            AnimePage(
              items: List.generate(
                24,
                (index) => AnimeSummary(id: index + 1, slug: '${index + 1}-anime', title: 'Аниме ${index + 1}'),
              ),
              page: 1,
              hasNext: true,
            ),
          );
        }
        pageTwoCalls++;
        if (pageTwoCalls == 2) {
          return pendingRetry.future;
        }

        return const Result.failure(UnknownFailure());
      },
    );
    await pumpTvApp(
      tester,
      SearchScreen(onAnimeTap: (_) => fail('Unexpected detail')),
      overrides: [
        authAccessProvider.overrideWithValue(const AnonymousAccess()),
        searchRepositoryProvider.overrideWithValue(repository),
        searchHistoryRepositoryProvider.overrideWithValue(FakeSearchHistoryRepository()),
      ],
    );
    final settle = tester.pumpAndSettle;
    final key = tester.sendKeyEvent;
    await settle();
    await key(LogicalKeyboardKey.select);
    await tester.pump();
    await tester.enterText(query, 'Наруто');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await settle();
    final allCards = find.byType(MediaCard);
    void expectFocus(FocusNode? target) => expect(FocusManager.instance.primaryFocus, same(target));
    void expectRetainedCards() => expect(allCards, findsNWidgets(24));
    final requestedPages = repository.requests.map((request) => request.page);
    final top = tester.getTopLeft(allCards.first).dy;
    final columns = allCards
        .evaluate()
        .where((element) => tester.getTopLeft(find.byWidget(element.widget)).dy == top)
        .length;
    await key(LogicalKeyboardKey.arrowDown);
    await settle();
    var selected = 0;
    while (selected < 23) {
      final down = selected + columns < 24;
      await key(down ? LogicalKeyboardKey.arrowDown : LogicalKeyboardKey.arrowRight);
      selected += down ? columns : 1;
      await settle();
    }
    final last = tester.widget<MediaCard>(find.byKey(const ValueKey('search-card-24'))).focusNode;
    expectFocus(last);
    expect(requestedPages, [1, 2]);
    final retry = find.byKey(const ValueKey('search-pagination-retry'));
    final retryNode = tester.widget<TextButton>(retry).focusNode;
    final scroll = tester.widget<SingleChildScrollView>(find.byKey(const PageStorageKey('search-results'))).controller;
    final cardOffset = scroll?.offset;
    expect(cardOffset, greaterThan(0));
    await key(LogicalKeyboardKey.arrowDown);
    await settle();
    expectFocus(retryNode);
    await key(LogicalKeyboardKey.arrowUp);
    await settle();
    expectFocus(last);
    expect(scroll?.offset, cardOffset);
    await key(LogicalKeyboardKey.arrowDown);
    await settle();
    await key(LogicalKeyboardKey.select);
    await tester.pump();
    await key(LogicalKeyboardKey.select);
    await tester.pump();
    expect(pageTwoCalls, 2);
    expectFocus(retryNode);
    expectRetainedCards();
    pendingRetry.complete(const Result.failure(UnknownFailure()));
    await settle();
    expectFocus(retryNode);
    await key(LogicalKeyboardKey.arrowUp);
    await settle();
    expectFocus(last);
    await key(LogicalKeyboardKey.arrowDown);
    await settle();
    expectFocus(retryNode);
    expect(requestedPages, [1, 2, 2]);
    expect(tester.widget<TextField>(query).controller?.text, 'Наруто');
    expectRetainedCards();
    expect(tester.takeException(), isNull);
  });

  testWidgets('detail pop retains query, result snapshot, poster focus and scroll', (tester) async {
    final settle = tester.pumpAndSettle;
    final key = tester.sendKeyEvent;
    final repository = FakeSearchRepository(
      load: (_) async => Result.success(
        AnimePage(
          items: List.generate(
            24,
            (index) => AnimeSummary(id: index + 1, slug: '${index + 1}-anime', title: 'Аниме ${index + 1}'),
          ),
          page: 1,
          hasNext: false,
        ),
      ),
    );
    await pumpTvApp(
      tester,
      Builder(
        builder: (context) => SearchScreen(
          onAnimeTap: (anime) =>
              Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => Scaffold(body: Text(anime.title)))),
        ),
      ),
      overrides: [
        authAccessProvider.overrideWithValue(const AnonymousAccess()),
        searchRepositoryProvider.overrideWithValue(repository),
        searchHistoryRepositoryProvider.overrideWithValue(FakeSearchHistoryRepository()),
      ],
    );
    await settle();
    await key(LogicalKeyboardKey.select);
    await tester.pump();
    await tester.enterText(query, 'Наруто');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await settle();
    await key(LogicalKeyboardKey.arrowDown);
    await key(LogicalKeyboardKey.arrowDown);
    await settle();
    final selected = FocusManager.instance.primaryFocus;
    final scroll = tester.widget<SingleChildScrollView>(find.byKey(const PageStorageKey('search-results'))).controller;
    final offset = scroll?.offset;
    expect(offset, greaterThan(0));
    await key(LogicalKeyboardKey.select);
    await settle();
    await tester.binding.handlePopRoute();
    await settle();
    expect(FocusManager.instance.primaryFocus, same(selected));
    expect(scroll?.offset, offset);
    expect(tester.widget<TextField>(query).controller?.text, 'Наруто');
    expect(repository.requests, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty and error share an action-free feedback surface and retain field focus', (tester) async {
    final settle = tester.pumpAndSettle;
    final repository = FakeSearchRepository(load: (_) async => const Result.failure(UnknownFailure()));
    await pumpTvApp(
      tester,
      SearchScreen(onAnimeTap: (_) => fail('Unexpected detail')),
      overrides: [
        authAccessProvider.overrideWithValue(const AnonymousAccess()),
        searchRepositoryProvider.overrideWithValue(repository),
        searchHistoryRepositoryProvider.overrideWithValue(FakeSearchHistoryRepository()),
      ],
    );
    await settle();
    await tester.tap(submit);
    await settle();
    expect(find.text('Ничего не найдено'), findsOneWidget);
    expect(feedbackActions, findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    await tester.enterText(query, 'Наруто');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await settle();
    expect(find.text('Поиск недоступен'), findsOneWidget);
    expect(tester.widget<TextField>(query).focusNode?.hasFocus, isTrue);
    expect(feedbackActions, findsNothing);
  });
}
