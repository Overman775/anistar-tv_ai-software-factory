import 'dart:async';

import 'package:anistar_tv/packages/features/auth/auth_providers.dart';
import 'package:anistar_tv/packages/features/catalog/catalog_providers.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/anime_page.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/anime_summary.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/screens/catalog_screen.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/widgets/anime_card.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/widgets/catalog_inspector_copy.dart';
import 'package:anistar_tv/packages/features/favorites/favorites_providers.dart';
import 'package:anistar_tv/packages/features/favorites/favorites_state.dart';
import 'package:anistar_tv/packages/features/favorites/presentation/favorite_actions_sheet.dart';
import 'package:anistar_tv/packages/features/favorites/presentation/favorite_button.dart';
import 'package:anistar_tv/packages/features/home/presentation/screens/home_screen.dart';
import 'package:anistar_tv/packages/features/search/presentation/search_screen.dart';
import 'package:anistar_tv/packages/features/search/search_providers.dart';
import 'package:core/data.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../mocks/features/catalog/fake_catalog_screen_repository.dart';
import '../../../mocks/features/favorites/fake_favorites_repository.dart';
import '../../../mocks/features/search/fake_search_repository.dart';
import '../../../support/test_app.dart';

void main() {
  testWidgets('guest favorite panel keeps its sign-in action at intrinsic TV control height', (tester) async {
    await pumpTvApp(
      tester,
      const FavoriteActionsSheet(animeId: 1, slug: '1-test', title: 'Аниме 1'),
      overrides: [authAccessProvider.overrideWithValue(const AnonymousAccess())],
    );
    final signIn = find.widgetWithText(AppButton, 'Войти, чтобы добавить в избранное');

    expect(find.byType(TvSideSheet), findsOneWidget);
    expect(tester.getSize(signIn).height, AppSizes.tvControl);
    expect(tester.takeException(), isNull);
  });

  for (final key in [LogicalKeyboardKey.select, LogicalKeyboardKey.enter]) {
    testWidgets('first held $key opens one panel and close leaves pending write alive', (tester) async {
      final pending = Completer<Result<bool, Failure>>();
      final favorites = FakeFavoritesRepository()..change = (_) => pending.future;
      await pumpTvApp(
        tester,
        HomeScreen(onAnimeTap: (_) => fail('Held activation opened details')),
        wrapInScaffold: false,
        overrides: [
          authAccessProvider.overrideWithValue(const AuthenticatedAccess('test')),
          favoritesAccountProvider.overrideWithValue('test'),
          catalogRepositoryProvider.overrideWithValue(const FakeCatalogScreenRepository()),
          favoritesRepositoryProvider.overrideWithValue(favorites),
        ],
      );
      await tester.pumpAndSettle();
      final selected = FocusManager.instance.primaryFocus;
      await tester.sendKeyDownEvent(key);
      await tester.sendKeyRepeatEvent(key);
      await tester.pumpAndSettle();
      expect(find.byType(FavoriteActionsSheet), findsOneWidget);
      await tester.sendKeyRepeatEvent(key);
      await tester.sendKeyUpEvent(key);
      await tester.pumpAndSettle();
      expect(favorites.writes, isEmpty);
      await tester.sendKeyEvent(key);
      await tester.pump();
      expect(favorites.writes, [true]);
      expect(find.text('Обновляем избранное…'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(FavoriteActionsSheet), findsNothing);
      expect(FocusManager.instance.primaryFocus, same(selected));
      final container = ProviderScope.containerOf(tester.element(find.byType(CatalogScreen)));
      pending.complete(const Result.success(true));
      await tester.pumpAndSettle();
      expect(container.read(favoritesControllerProvider).known[1], isTrue);
      expect(favorites.writes, [true]);
      expect(FocusManager.instance.primaryFocus, same(selected));
      expect(tester.takeException(), isNull);
    });
  }

  for (final mobile in [false, true]) {
    for (final guest in [false, true]) {
      testWidgets('search bookmark uses shared confirmed override mobile=$mobile guest=$guest', (tester) async {
        final repository = FakeSearchRepository(
          load: (_) async => Result.success(
            AnimePage(
              items: const [AnimeSummary(id: 1, slug: '1-test', title: 'Аниме', isFavorite: true)],
              page: 1,
              hasNext: false,
            ),
          ),
        );
        final favorites = FakeFavoritesRepository()..ids.add(1);
        final overrides = [
          authAccessProvider.overrideWithValue(guest ? const AnonymousAccess() : const AuthenticatedAccess('test')),
          favoritesAccountProvider.overrideWithValue(guest ? null : 'test'),
          favoritesRepositoryProvider.overrideWithValue(favorites),
          searchRepositoryProvider.overrideWithValue(repository),
          searchHistoryRepositoryProvider.overrideWithValue(FakeSearchHistoryRepository()),
        ];
        final screen = SearchScreen(onAnimeTap: (_) => fail('Unexpected detail'));
        if (mobile) {
          await pumpMobileApp(tester, screen, overrides: overrides);
        } else {
          await pumpTvApp(tester, screen, overrides: overrides);
        }
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const ValueKey('search-query')), 'Наруто');
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pumpAndSettle();
        expect(find.byType(MediaCardBookmark), guest ? findsNothing : findsOneWidget);
        if (!guest) {
          final container = ProviderScope.containerOf(tester.element(find.byType(SearchScreen)));
          container.read(favoritesControllerProvider.notifier).observe(1, false);
          await tester.pumpAndSettle();
          expect(find.byType(MediaCardBookmark), findsNothing);
        } else {
          expect(favorites.writes, isEmpty);
          expect(favorites.pages, isEmpty);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('inspector disables mismatched actions until Up synchronizes selection', (tester) async {
    final repository = FakeFavoritesRepository();
    await pumpTvApp(
      tester,
      CatalogScreen(onAnimeTap: (_) => fail('Unexpected detail')),
      wrapInScaffold: false,
      overrides: [
        authAccessProvider.overrideWithValue(const AuthenticatedAccess('test')),
        favoritesAccountProvider.overrideWithValue('test'),
        catalogRepositoryProvider.overrideWithValue(const FakeCatalogScreenRepository()),
        favoritesRepositoryProvider.overrideWithValue(repository),
      ],
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    final copy = find.byType(CatalogInspectorCopy);
    expect(tester.widget<CatalogInspectorCopy>(copy).anime.id, 1);
    final disabled = find.descendant(
      of: copy,
      matching: find.byWidgetPredicate((widget) => widget is IgnorePointer && widget.ignoring),
    );
    expect(disabled, findsWidgets);
    final action = find.byKey(const ValueKey('favorite-button-2'));
    await tester.tapAt(tester.getCenter(action));
    await tester.pump();
    expect(repository.writes, isEmpty);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(tester.widget<CatalogInspectorCopy>(copy).anime.id, 2);
    expect(focusedControlLabel(tester), 'Смотреть');
    expect(repository.writes, isEmpty);
    expect(tester.takeException(), isNull);
  });

  test('serializes writes and keeps the last confirmed value on failure', () async {
    final pending = Completer<Result<bool, Failure>>();
    final repository = FakeFavoritesRepository()..change = (_) => pending.future;
    final transitions = <FavoritesState>[];
    final container = ProviderContainer(
      overrides: [
        authAccessProvider.overrideWithValue(const AuthenticatedAccess('test')),
        favoritesAccountProvider.overrideWithValue('test'),
        favoritesRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen<FavoritesState>(
      favoritesControllerProvider,
      (_, next) => transitions.add(next),
    );
    addTearDown(subscription.close);
    final controller = container.read(favoritesControllerProvider.notifier)..observe(1, false);
    final change = controller.setFavorite(animeId: 1, slug: '1-test', favorite: true);
    final before = container.read(favoritesControllerProvider);
    expect(before.known[1], isFalse);
    final failureMatcher = isA<Failure>();
    expect(await controller.setFavorite(animeId: 2, slug: '2-test', favorite: true), failureMatcher);
    expect(await controller.setFavorite(animeId: 1, slug: '1-test', favorite: true), failureMatcher);
    expect(repository.writes, [true]);
    pending.complete(const Result.failure(UnknownFailure()));
    expect(await change, failureMatcher);
    final state = container.read(favoritesControllerProvider);
    expect(state.known[1], isFalse);
    expect(state.updatingAnimeId, isNull);
    expect(state.revision, 0);
  });

  test('mismatched confirmation keeps last confirmed state and needs explicit retry', () async {
    final repository = FakeFavoritesRepository()..change = (_) async => const Result.success(false);
    final container = ProviderContainer(
      overrides: [
        authAccessProvider.overrideWithValue(const AuthenticatedAccess('test')),
        favoritesAccountProvider.overrideWithValue('test'),
        favoritesRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(favoritesControllerProvider.notifier)..observe(1, false);
    expect(await controller.setFavorite(animeId: 1, slug: '1-test', favorite: true), isA<Failure>());
    expect(container.read(favoritesControllerProvider).known[1], isFalse);
    expect(repository.writes, [true]);
    repository.change = (_) async => const Result.success(true);
    expect(await controller.setFavorite(animeId: 1, slug: '1-test', favorite: true), isNull);
    expect(container.read(favoritesControllerProvider).known[1], isTrue);
    expect(repository.writes, [true, true]);
  });

  test('origin repository replacement discards an in-flight old write', () async {
    final pending = Completer<Result<bool, Failure>>();
    final oldRepository = FakeFavoritesRepository()..change = (_) => pending.future;
    final nextRepository = FakeFavoritesRepository();
    List<Override> overrides(FakeFavoritesRepository repository) => [
      authAccessProvider.overrideWithValue(const AuthenticatedAccess('test')),
      favoritesAccountProvider.overrideWithValue('test'),
      favoritesRepositoryProvider.overrideWithValue(repository),
    ];
    final container = ProviderContainer(overrides: overrides(oldRepository));
    addTearDown(container.dispose);
    final controller = container.read(favoritesControllerProvider.notifier)..observe(1, false);
    final write = controller.setFavorite(animeId: 1, slug: '1-test', favorite: true);
    container.updateOverrides(overrides(nextRepository));
    pending.complete(const Result.success(true));
    expect(await write, isA<Failure>());
    expect(container.read(favoritesControllerProvider).known[1], isNull);
    expect(nextRepository.writes, isEmpty);
  });

  test('disposing a session discards its display cache and ignores a late write result', () async {
    final pending = Completer<Result<bool, Failure>>();
    final repository = FakeFavoritesRepository()..change = (_) => pending.future;
    final transitions = <FavoritesState>[];
    final container = ProviderContainer(
      overrides: [
        authAccessProvider.overrideWithValue(const AuthenticatedAccess('test')),
        favoritesAccountProvider.overrideWithValue('test'),
        favoritesRepositoryProvider.overrideWithValue(repository),
      ],
    )..listen<FavoritesState>(favoritesControllerProvider, (_, next) => transitions.add(next));
    final change = container
        .read(favoritesControllerProvider.notifier)
        .setFavorite(animeId: 1, slug: '1-test', favorite: true);
    container.dispose();
    pending.complete(const Result.success(true));
    expect(await change, isNull);
    final restored = ProviderContainer();
    addTearDown(restored.dispose);
    expect(restored.read(favoritesControllerProvider).known, isEmpty);
  });

  testWidgets('direct button reads unknown status and updates only after server confirmation', (tester) async {
    final settle = tester.pumpAndSettle;
    final inFavorites = find.text('В избранном');
    final pending = Completer<Result<bool, Failure>>();
    final repository = FakeFavoritesRepository()..change = (_) => pending.future;
    await pumpTvApp(
      tester,
      const FavoriteButton(animeId: 1, slug: '1-test'),
      overrides: [
        authAccessProvider.overrideWithValue(const AuthenticatedAccess('test')),
        favoritesAccountProvider.overrideWithValue('test'),
        favoritesRepositoryProvider.overrideWithValue(repository),
      ],
    );
    await tester.tap(find.text('Проверить избранное'));
    await settle();
    expect(find.text('В избранное'), findsOneWidget);
    await tester.tap(find.text('В избранное'));
    await tester.pump();
    expect(find.text('Сохраняем…'), findsOneWidget);
    expect(repository.ids, isEmpty);
    expect(find.byType(FavoriteActionsSheet), findsNothing);
    await tester.tap(find.byType(FavoriteButton));
    expect(repository.writes, [true]);
    pending.complete(const Result.success(true));
    await settle();
    expect(inFavorites, findsOneWidget);
    repository.change = (_) async => const Result.failure(UnknownFailure());
    await tester.tap(inFavorites);
    await settle();
    expect(inFavorites, findsOneWidget);
    expect(repository.writes, [true, false]);
  });

  testWidgets('unknown status and rejected changes show a retry without a false success', (tester) async {
    final pumpAndSettle = tester.pumpAndSettle;
    final add = find.text('Добавить в избранное');
    final retry = find.text('Обновить статус');
    final repository = FakeFavoritesRepository()..statusFailure = const UnknownFailure();
    await pumpTvApp(
      tester,
      const FavoriteActionsSheet(animeId: 1, slug: '1-test', title: 'Аниме 1'),
      overrides: [
        authAccessProvider.overrideWithValue(const AuthenticatedAccess('test')),
        favoritesAccountProvider.overrideWithValue('test'),
        favoritesRepositoryProvider.overrideWithValue(repository),
      ],
    );
    await pumpAndSettle();
    expect(add, findsNothing);
    repository
      ..statusFailure = null
      ..change = (_) async => const Result.failure(UnknownFailure());
    await tester.tap(retry);
    await pumpAndSettle();
    await tester.tap(add);
    await pumpAndSettle();
    expect(retry, findsOneWidget);
    expect(repository.ids, isEmpty);
  });

  testWidgets('remote OK retries a failed status without needing to search for focus', (tester) async {
    final repository = FakeFavoritesRepository()..statusFailure = const UnknownFailure();
    await pumpTvApp(
      tester,
      const FavoriteButton(animeId: 1, slug: '1-test'),
      overrides: [
        authAccessProvider.overrideWithValue(const AuthenticatedAccess('test')),
        favoritesAccountProvider.overrideWithValue('test'),
        favoritesRepositoryProvider.overrideWithValue(repository),
      ],
    );
    final settle = tester.pumpAndSettle;
    await tester.tap(find.text('Проверить избранное'));
    await settle();
    repository.statusFailure = null;
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await settle();
    expect(find.text('В избранное'), findsOneWidget);
    expect(repository.writes, isEmpty);
  });

  testWidgets('a detail mutation removes the server row from the favorites tab', (tester) async {
    final pumpAndSettle = tester.pumpAndSettle;
    final cards = find.byType(AnimeCard);
    final repository = FakeFavoritesRepository()..ids.add(1);
    await pumpTvApp(
      tester,
      CatalogScreen(favoritesOnly: true, onAnimeTap: (_) => fail('Unexpected navigation')),
      wrapInScaffold: false,
      overrides: [
        authAccessProvider.overrideWithValue(const AuthenticatedAccess('test')),
        favoritesAccountProvider.overrideWithValue('test'),
        favoritesRepositoryProvider.overrideWithValue(repository),
      ],
    );
    await pumpAndSettle();
    expect(cards, findsOneWidget);
    final context = tester.element(find.byType(CatalogScreen));
    final controller = ProviderScope.containerOf(context).read(favoritesControllerProvider.notifier);
    await controller.setFavorite(animeId: 1, slug: '1-test', favorite: false);
    await pumpAndSettle();
    expect(repository.pages, [1, 1]);
    expect(find.text('Избранное пусто'), findsOneWidget);
    expect(cards, findsNothing);
  });
}
