import 'dart:async';

import 'package:anistar_tv/packages/features/auth/auth_providers.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/screens/catalog_screen.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/widgets/anime_card.dart';
import 'package:anistar_tv/packages/features/favorites/favorites_providers.dart';
import 'package:anistar_tv/packages/features/favorites/favorites_state.dart';
import 'package:anistar_tv/packages/features/favorites/presentation/favorite_actions_sheet.dart';
import 'package:anistar_tv/packages/features/favorites/presentation/favorite_button.dart';
import 'package:core/data.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../mocks/features/favorites/fake_favorites_repository.dart';
import '../../../support/test_app.dart';

void main() {
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
    expect(repository.writes, [true]);
    pending.complete(const Result.failure(UnknownFailure()));
    expect(await change, failureMatcher);
    final state = container.read(favoritesControllerProvider);
    expect(state.known[1], isFalse);
    expect(state.updatingAnimeId, isNull);
    expect(state.revision, 0);
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
      const FavoriteButton(animeId: 1, slug: '1-test', title: 'Аниме 1'),
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
      const FavoriteButton(animeId: 1, slug: '1-test', title: 'Аниме 1'),
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
