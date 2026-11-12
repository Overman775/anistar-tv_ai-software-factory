import 'dart:async';

import 'package:anistar_tv/app/app_router.dart';
import 'package:anistar_tv/app/app_routes.dart';
import 'package:anistar_tv/packages/features/auth/auth_providers.dart';
import 'package:anistar_tv/packages/features/catalog/catalog_providers.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/anime_page.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/anime_summary.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/catalog_filter.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/widgets/anime_card.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/widgets/catalog_inspector.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/widgets/catalog_poster_rail.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/widgets/catalog_tail.dart';
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

  testWidgets(
    'new TV search entry attaches its input client before requesting IME and keeps arrows out of navigation',
    (tester) async {
      final settle = tester.pumpAndSettle;
      final pump = tester.pump;
      final key = tester.sendKeyEvent;
      TextField readField() => tester.widget<TextField>(query);
      final repository = FakeSearchRepository();
      var menuOpened = 0;
      final textInputCalls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.textInput,
        (call) async {
          textInputCalls.add(call);

          return null;
        },
      );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.textInput,
          null,
        ),
      );
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
      expect(field.readOnly, isFalse);
      expect(field.decoration?.hintText, isNull);
      final fieldNode = field.focusNode;
      final clientAttach = textInputCalls.indexWhere((call) => call.method == 'TextInput.setClient');
      final firstShow = textInputCalls.indexWhere((call) => call.method == 'TextInput.show');
      expect(clientAttach, greaterThanOrEqualTo(0));
      expect(firstShow, greaterThan(clientAttach));
      await tester.enterText(query, 'Наруто');
      expect(repository.requests, isEmpty);
      await key(LogicalKeyboardKey.arrowLeft);
      await key(LogicalKeyboardKey.arrowRight);
      await pump();
      expect(menuOpened, isZero);
      expect(readField().focusNode?.hasFocus, isTrue);
      await key(LogicalKeyboardKey.escape);
      await pump();
      final afterBack = readField();
      expect(afterBack.controller?.text, 'Наруто');
      expect(afterBack.readOnly, isTrue);
      await key(LogicalKeyboardKey.arrowLeft);
      expect(menuOpened, 1);
      final passiveInputClients = textInputCalls.where((call) => call.method == 'TextInput.setClient').length;
      await key(LogicalKeyboardKey.select);
      await pump();
      await pump();
      expect(readField().readOnly, isFalse);
      expect(readField().focusNode?.hasFocus, isTrue);
      expect(
        textInputCalls.where((call) => call.method == 'TextInput.setClient').length,
        greaterThan(passiveInputClients),
      );
      await key(LogicalKeyboardKey.escape);
      await pump();
      expect(readField().readOnly, isTrue);
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
    },
  );

  testWidgets('explicit submit enforces Unicode code point boundaries and blank stays local', (tester) async {
    final repository = FakeSearchRepository();
    final history = FakeSearchHistoryRepository();
    await pumpMobileApp(
      tester,
      SearchScreen(onAnimeTap: (_) => fail('Unexpected detail')),
      overrides: [
        authAccessProvider.overrideWithValue(const AnonymousAccess()),
        searchRepositoryProvider.overrideWithValue(repository),
        searchHistoryRepositoryProvider.overrideWithValue(history),
      ],
    );
    await tester.pumpAndSettle();
    Future<void> submitText(String text) async {
      await tester.enterText(query, text);
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
    }

    await submitText('   ');
    expect(repository.requests, isEmpty);
    await submitText('😀' * 3);
    expect(repository.requests, isEmpty);
    expect(find.textContaining('4'), findsWidgets);
    await tester.enterText(query, '😀' * 4);
    await tester.pump();
    expect(repository.requests, isEmpty, reason: 'editing alone never submits');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(repository.requests.map((request) => request.query), ['😀' * 4]);
    await submitText('😀' * 120);
    expect(repository.requests.last.query, '😀' * 120);
    await submitText('😀' * 121);
    expect(repository.requests, hasLength(2));
    expect(tester.widget<TextField>(query).controller?.text.runes.length, 121);
    expect(history.writes.last, ['😀' * 120, '😀' * 4]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('duplicate pending submit sends once and response does not steal focus', (tester) async {
    final pending = Completer<Result<AnimePage, Failure>>();
    final repository = FakeSearchRepository(load: (_) => pending.future);
    await pumpTvApp(
      tester,
      SearchScreen(onAnimeTap: (_) => fail('Unexpected detail')),
      overrides: [
        authAccessProvider.overrideWithValue(const AnonymousAccess()),
        searchRepositoryProvider.overrideWithValue(repository),
        searchHistoryRepositoryProvider.overrideWithValue(FakeSearchHistoryRepository()),
      ],
    );
    await tester.pumpAndSettle();
    await tester.enterText(query, 'Наруто');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    await tester.tap(submit);
    await tester.pump();
    expect(repository.requests, hasLength(1));
    final focus = FocusManager.instance.primaryFocus;
    pending.complete(
      Result.success(
        AnimePage(
          items: const [AnimeSummary(id: 1, slug: '1-test', title: 'Тест')],
          page: 1,
          hasNext: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus, same(focus));
    expect(find.byKey(const ValueKey('search-card-1')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('leaving search cancels a pending query and ignores its late result', (tester) async {
    final pending = Completer<Result<AnimePage, Failure>>();
    final repository = FakeSearchRepository(load: (_) => pending.future);
    var active = true;
    late StateSetter update;
    await pumpTvApp(
      tester,
      StatefulBuilder(
        builder: (_, setState) {
          update = setState;
          return SearchScreen(active: active, onAnimeTap: (_) => fail('Unexpected detail'));
        },
      ),
      overrides: [
        authAccessProvider.overrideWithValue(const AnonymousAccess()),
        searchRepositoryProvider.overrideWithValue(repository),
        searchHistoryRepositoryProvider.overrideWithValue(FakeSearchHistoryRepository()),
      ],
    );
    await tester.pumpAndSettle();
    await tester.enterText(query, 'Наруто');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    expect(repository.requests, hasLength(1));
    update(() => active = false);
    await tester.pump();
    expect(repository.requests.single.cancellation?.isCancelled, isTrue);
    pending.complete(
      Result.success(
        AnimePage(
          items: const [AnimeSummary(id: 99, slug: '99-old', title: 'Старый ответ')],
          page: 1,
          hasNext: false,
        ),
      ),
    );
    await tester.pump();
    update(() => active = true);
    await tester.pumpAndSettle();
    expect(find.text('Старый ответ'), findsNothing);
    expect(repository.requests, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('TV rail focus cancels a pending editable search reset', (tester) async {
    final repository = FakeSearchRepository();
    await pumpTvApp(
      tester,
      HomeScreen(destination: HomeDestination.search, onAnimeTap: (_) => fail('Unexpected detail')),
      overrides: [
        authAccessProvider.overrideWithValue(const AnonymousAccess()),
        catalogRepositoryProvider.overrideWithValue(const FakeCatalogScreenRepository()),
        searchRepositoryProvider.overrideWithValue(repository),
        searchHistoryRepositoryProvider.overrideWithValue(FakeSearchHistoryRepository()),
      ],
    );
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(query).readOnly, isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(tester.widget<TextField>(query).readOnly, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    await tester.pump();

    expect(focusedControlLabel(tester), 'Поиск');
    expect(tester.widget<TextField>(query).readOnly, isTrue);
  });

  testWidgets('TV rail focus cancels passive search focus restoration after Back', (tester) async {
    final repository = FakeSearchRepository();
    await pumpTvApp(
      tester,
      HomeScreen(destination: HomeDestination.search, onAnimeTap: (_) => fail('Unexpected detail')),
      overrides: [
        authAccessProvider.overrideWithValue(const AnonymousAccess()),
        catalogRepositoryProvider.overrideWithValue(const FakeCatalogScreenRepository()),
        searchRepositoryProvider.overrideWithValue(repository),
        searchHistoryRepositoryProvider.overrideWithValue(FakeSearchHistoryRepository()),
      ],
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);

    await tester.binding.handlePopRoute();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    await tester.pump();

    expect(focusedControlLabel(tester), 'Поиск');
    expect(tester.widget<TextField>(query).readOnly, isTrue);
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

  testWidgets('new mobile search entry requests IME without submitting text', (tester) async {
    final repository = FakeSearchRepository();
    final textInputCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.textInput,
      (call) async {
        textInputCalls.add(call);

        return null;
      },
    );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.textInput,
        null,
      ),
    );
    await pumpMobileApp(
      tester,
      SearchScreen(onAnimeTap: (_) => fail('Unexpected detail')),
      overrides: [
        authAccessProvider.overrideWithValue(const AnonymousAccess()),
        searchRepositoryProvider.overrideWithValue(repository),
        searchHistoryRepositoryProvider.overrideWithValue(FakeSearchHistoryRepository()),
      ],
    );
    await tester.pumpAndSettle();
    await tester.enterText(query, 'Наруто');
    expect(textInputCalls.where((call) => call.method == 'TextInput.show'), isNotEmpty);
    expect(repository.requests, isEmpty);
  });

  testWidgets('deactivated search does not request another IME show and hides the active input', (tester) async {
    var active = true;
    late void Function(void Function()) update;
    final textInputCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.textInput,
      (call) async {
        textInputCalls.add(call);

        return null;
      },
    );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.textInput,
        null,
      ),
    );
    await pumpTvApp(
      tester,
      StatefulBuilder(
        builder: (_, setState) {
          update = setState;

          return SearchScreen(active: active, onAnimeTap: (_) => fail('Unexpected detail'));
        },
      ),
      overrides: [
        authAccessProvider.overrideWithValue(const AnonymousAccess()),
        searchRepositoryProvider.overrideWithValue(FakeSearchRepository()),
        searchHistoryRepositoryProvider.overrideWithValue(FakeSearchHistoryRepository()),
      ],
    );
    await tester.pumpAndSettle();
    final entryImeRequests = textInputCalls.where((call) => call.method == 'TextInput.show').length;
    expect(entryImeRequests, greaterThanOrEqualTo(1));
    update(() => active = false);
    await tester.pump();
    await tester.pump();
    expect(textInputCalls.where((call) => call.method == 'TextInput.show'), hasLength(entryImeRequests));
    expect(textInputCalls.where((call) => call.method == 'TextInput.hide'), isNotEmpty);
  });

  testWidgets('Search cards use profile-specific caption, bookmark and inspector contracts', (tester) async {
    final settle = tester.pumpAndSettle;
    final enterText = tester.enterText;
    final submitQuery = tester.testTextInput.receiveAction;
    final authenticated = authAccessProvider.overrideWithValue(const AuthenticatedAccess('tester'));
    final history = searchHistoryRepositoryProvider.overrideWithValue(FakeSearchHistoryRepository());
    final searchCard = find.byKey(const ValueKey('search-card-1'));
    final page = AnimePage(
      items: const [AnimeSummary(id: 1, slug: 'anime', title: 'Аниме', year: '2026', rating: 9.1, isFavorite: true)],
      page: 1,
      hasNext: false,
    );
    final mobileRepository = FakeSearchRepository(load: (_) async => Result.success(page));
    await pumpMobileApp(
      tester,
      SearchScreen(onAnimeTap: (_) => fail('Unexpected detail')),
      overrides: [authenticated, searchRepositoryProvider.overrideWithValue(mobileRepository), history],
    );
    await settle();
    await enterText(query, 'Наруто');
    await submitQuery(TextInputAction.search);
    await settle();
    final mobileCard = tester.widget<MediaCard>(searchCard);
    expect(mobileCard.showCaption, isFalse);
    expect(mobileCard.showBookmark, isTrue);
    expect(mobileCard.badges, isEmpty);
    expect(find.text('2026'), findsNothing);

    final tvRepository = FakeSearchRepository(load: (_) async => Result.success(page));
    await pumpTvApp(
      tester,
      SearchScreen(onAnimeTap: (_) => fail('Unexpected detail')),
      overrides: [authenticated, searchRepositoryProvider.overrideWithValue(tvRepository), history],
    );
    await settle();
    await enterText(query, 'Наруто');
    await submitQuery(TextInputAction.search);
    await settle();
    final tvCard = tester.widget<MediaCard>(find.descendant(of: searchCard, matching: find.byType(MediaCard)));
    expect(tvCard.showCaption, isTrue);
    expect(tvCard.caption, isNull);
    expect(tvCard.ratingLabel, '9,1');
    expect(tvCard.showBookmark, isTrue);
    expect(tvCard.badges, isEmpty);
    expect(find.byType(CatalogInspector), findsOneWidget);
    expect(find.text('Результаты для «Наруто» · Найдено: 1'), findsOneWidget);
  });

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
    void expectFocus(FocusNode? target) => expect(FocusManager.instance.primaryFocus, same(target));
    void expectRetainedCards() => expect(find.byKey(const ValueKey('search-card-24')), findsOneWidget);
    final requestedPages = repository.requests.map((request) => request.page);
    await key(LogicalKeyboardKey.arrowDown);
    await settle();
    for (var index = 1; index < 24; index++) {
      await key(LogicalKeyboardKey.arrowRight);
      await settle();
    }
    final last = tester.widget<AnimeCard>(find.byKey(const ValueKey('search-card-24'))).focusNode;
    expectFocus(last);
    expect(requestedPages, [1, 2]);
    final retry = find.byKey(const ValueKey('search-pagination-retry'));
    final retryNode = tester.widget<CatalogTail>(retry).focusNode;
    final scroll = tester.widget<CatalogPosterRail>(find.byType(CatalogPosterRail)).controller;
    final cardOffset = scroll.offset;
    expect(cardOffset, greaterThan(0));
    await key(LogicalKeyboardKey.arrowRight);
    await settle();
    expectFocus(retryNode);
    await key(LogicalKeyboardKey.arrowUp);
    await settle();
    expectFocus(last);
    expect(scroll.offset, cardOffset);
    await key(LogicalKeyboardKey.arrowRight);
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
    await key(LogicalKeyboardKey.arrowRight);
    await settle();
    expectFocus(retryNode);
    expect(requestedPages, [1, 2, 2]);
    expect(tester.widget<TextField>(query).controller?.text, 'Наруто');
    expectRetainedCards();
    expect(tester.takeException(), isNull);
  });

  for (final leaveAnchor in [false, true]) {
    testWidgets('visible search continuation transfers only while the anchor stays focused; leave=$leaveAnchor', (
      tester,
    ) async {
      final pending = Completer<Result<AnimePage, Failure>>();
      final repository = FakeSearchRepository(
        load: (request) async {
          if (request.page == 2) return pending.future;
          return Result.success(
            AnimePage(
              items: List.generate(
                24,
                (index) => AnimeSummary(id: index + 1, slug: '${index + 1}-test', title: 'Аниме ${index + 1}'),
              ),
              page: 1,
              hasNext: true,
            ),
          );
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
      await tester.pumpAndSettle();
      await tester.enterText(query, 'Наруто');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(repository.requests.map((request) => request.page), [
        1,
      ], reason: 'cached but offscreen continuation is not visible');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump(const Duration(milliseconds: 100));
      for (var i = 0; i < 30 && FocusManager.instance.primaryFocus?.debugLabel != 'Поиск: Аниме 24'; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump(const Duration(milliseconds: 120));
      }
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'Поиск: Аниме 24');
      expect(repository.requests.map((request) => request.page), [1, 2]);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      if (leaveAnchor) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pump();
      }
      final before = FocusManager.instance.primaryFocus;
      pending.complete(
        Result.success(
          AnimePage(
            items: const [AnimeSummary(id: 25, slug: '25-test', title: 'Аниме 25')],
            page: 2,
            hasNext: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (leaveAnchor) {
        expect(FocusManager.instance.primaryFocus, same(before));
      } else {
        expect(FocusManager.instance.primaryFocus?.debugLabel, 'Поиск: Аниме 25');
      }
      expect(repository.requests.map((request) => request.page), [1, 2]);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('search cached continuation waits for viewport overlap', (tester) async {
    final pending = Completer<Result<AnimePage, Failure>>();
    final repository = FakeSearchRepository(
      load: (request) async => request.page == 1
          ? Result.success(
              AnimePage(
                items: List.generate(8, (i) => AnimeSummary(id: i + 1, slug: '${i + 1}-test', title: 'Аниме ${i + 1}')),
                page: 1,
                hasNext: true,
              ),
            )
          : pending.future,
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
    await tester.pumpAndSettle();
    await tester.enterText(query, 'Наруто');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    final slot = find.byKey(const ValueKey('tv-catalog-unloaded-slot'), skipOffstage: false).first;
    final viewport = find.byKey(const ValueKey('tv-catalog-poster-rail'));
    expect(slot, findsOneWidget);
    expect(tester.getRect(slot).overlaps(tester.getRect(viewport)), isFalse);
    expect(repository.requests.map((request) => request.page), [1]);
    tester.widget<CatalogPosterRail>(find.byType(CatalogPosterRail)).controller.jumpTo(300);
    await tester.pump();
    await tester.pump();
    expect(repository.requests.map((request) => request.page), [1, 2]);
    expect(find.byKey(const ValueKey('tv-catalog-loading-slot')), findsWidgets);
    pending.complete(Result.success(AnimePage(items: const [], page: 2, hasNext: false)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('covered search does not chain continuation or move focus', (tester) async {
    final pending = Completer<Result<AnimePage, Failure>>();
    final repository = FakeSearchRepository(
      load: (request) async {
        if (request.page == 2) return pending.future;
        return Result.success(
          AnimePage(
            items: List.generate(
              24,
              (index) => AnimeSummary(id: index + 1, slug: '${index + 1}-test', title: 'Аниме ${index + 1}'),
            ),
            page: 1,
            hasNext: true,
          ),
        );
      },
    );
    await pumpTvApp(
      tester,
      Builder(
        builder: (context) => SearchScreen(
          onAnimeTap: (_) {
            unawaited(Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => const Text('Detail route'))));
          },
        ),
      ),
      overrides: [
        authAccessProvider.overrideWithValue(const AnonymousAccess()),
        searchRepositoryProvider.overrideWithValue(repository),
        searchHistoryRepositoryProvider.overrideWithValue(FakeSearchHistoryRepository()),
      ],
    );
    await tester.pumpAndSettle();
    await tester.enterText(query, 'Наруто');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump(const Duration(milliseconds: 120));
    for (var i = 0; i < 30 && FocusManager.instance.primaryFocus?.debugLabel != 'Поиск: Аниме 24'; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump(const Duration(milliseconds: 120));
    }
    expect(repository.requests.map((request) => request.page), [1, 2]);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(find.text('Detail route'), findsOneWidget);
    pending.complete(
      Result.success(
        AnimePage(
          items: const [AnimeSummary(id: 25, slug: '25-test', title: 'Аниме 25')],
          page: 2,
          hasNext: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(repository.requests.map((request) => request.page), [1, 2]);
    expect(find.text('Detail route'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Search remote traverses poster, Watch, genres, form and Favorite', (tester) async {
    const genre = CatalogFilter(label: 'Комедия', path: '/anime/comedy/');
    final repository = FakeSearchRepository(
      load: (_) async => Result.success(
        AnimePage(
          items: [
            AnimeSummary.withGenreFilters(
              id: 1,
              slug: '1-test',
              title: 'Аниме',
              genreText: genre.label,
              genreFilters: [genre],
            ),
          ],
          page: 1,
          hasNext: false,
        ),
      ),
    );
    await pumpTvApp(
      tester,
      SearchScreen(onAnimeTap: (_) => fail('Unexpected detail'), onFilterSelected: (_) => fail('Unexpected filter')),
      overrides: [
        authAccessProvider.overrideWithValue(const AuthenticatedAccess('test')),
        searchRepositoryProvider.overrideWithValue(repository),
        searchHistoryRepositoryProvider.overrideWithValue(FakeSearchHistoryRepository()),
      ],
    );
    await tester.pumpAndSettle();
    await tester.enterText(query, 'Наруто');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    Future<void> key(LogicalKeyboardKey value) async {
      await tester.sendKeyEvent(value);
      await tester.pumpAndSettle();
    }

    await key(LogicalKeyboardKey.arrowDown);
    final poster = FocusManager.instance.primaryFocus;
    expect(poster?.debugLabel, 'Поиск: Аниме');
    await key(LogicalKeyboardKey.arrowUp);
    expect(focusedControlLabel(tester), 'Смотреть');
    await key(LogicalKeyboardKey.arrowUp);
    expect(focusedControlLabel(tester), 'Комедия');
    await key(LogicalKeyboardKey.arrowUp);
    expect(tester.widget<TextField>(query).focusNode?.hasFocus, isTrue);
    await key(LogicalKeyboardKey.arrowDown);
    await key(LogicalKeyboardKey.arrowUp);
    await key(LogicalKeyboardKey.arrowRight);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'Избранное тайтла');
    await key(LogicalKeyboardKey.arrowDown);
    expect(FocusManager.instance.primaryFocus, same(poster));
    expect(repository.requests, hasLength(1));
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
    for (var i = 0; i < 8; i++) {
      await key(LogicalKeyboardKey.arrowRight);
      await settle();
    }
    final selected = FocusManager.instance.primaryFocus;
    final scroll = tester.widget<CatalogPosterRail>(find.byType(CatalogPosterRail)).controller;
    scroll.jumpTo(scroll.offset + 17);
    await tester.pump();
    final offset = scroll.offset;
    expect(offset, greaterThan(0));
    await key(LogicalKeyboardKey.arrowUp);
    await settle();
    expect(focusedControlLabel(tester), 'Смотреть');
    await key(LogicalKeyboardKey.select);
    await settle();
    await tester.binding.handlePopRoute();
    await settle();
    final queryField = tester.widget<TextField>(query);
    expect(FocusManager.instance.primaryFocus, same(selected));
    expect(scroll.offset, offset);
    expect(queryField.controller?.text, 'Наруто');
    expect(queryField.readOnly, isTrue);
    expect(repository.requests, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty and error share an action-free feedback surface and retain field focus', (tester) async {
    final settle = tester.pumpAndSettle;
    var attempts = 0;
    final repository = FakeSearchRepository(
      load: (_) async {
        attempts++;
        return attempts == 1
            ? const Result.failure(UnknownFailure())
            : Result.success(
                AnimePage(
                  items: const [AnimeSummary(id: 1, slug: '1-test', title: 'Результат')],
                  page: 1,
                  hasNext: false,
                ),
              );
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
    expect(attempts, 1);
    await tester.tap(submit);
    await settle();
    expect(attempts, 2);
    expect(repository.requests.map((request) => request.query), ['Наруто', 'Наруто']);
    expect(find.byKey(const ValueKey('search-card-1')), findsOneWidget);
  });
}
