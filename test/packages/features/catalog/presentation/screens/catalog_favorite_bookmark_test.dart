import 'dart:async';

import 'package:anistar_tv/packages/features/auth/auth_providers.dart';
import 'package:anistar_tv/packages/features/catalog/catalog_providers.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/anime_page.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/anime_summary.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/screens/catalog_screen.dart';
import 'package:anistar_tv/packages/features/favorites/favorites_providers.dart';
import 'package:anistar_tv/packages/features/home/presentation/home_destination.dart';
import 'package:anistar_tv/packages/features/home/presentation/screens/home_screen.dart';
import 'package:core/data.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../../../mocks/features/catalog/fake_catalog_screen_repository.dart';
import '../../../../../mocks/features/favorites/fake_favorites_repository.dart';
import '../../../../../support/test_app.dart';

final _account = NotifierProvider<_CatalogFavoriteBookmarkTest, String?>(_CatalogFavoriteBookmarkTest.new);

class _CatalogFavoriteBookmarkTest extends Notifier<String?> {
  @override
  String? build() => null;
  String? get account => state;
  set account(String? account) => state = account;
}

const _anime = AnimeSummary(id: 1, slug: 'anime', title: 'Anime');

AnimePage _page(int page, {bool containsAnime = false, bool hasNext = false}) =>
    AnimePage(items: containsAnime ? [_anime] : [], page: page, hasNext: hasNext);

void main() {
  for (final mobile in [false, true]) {
    testWidgets('inactive retained home does not scan on routed section change mobile=$mobile', (tester) async {
      final destination = ValueNotifier(HomeDestination.home);
      addTearDown(destination.dispose);
      final favorites = FakeFavoritesRepository()..ids.add(1);
      final catalog = FakeCatalogScreenRepository(load: (_) async => Result.success(_page(1, containsAnime: true)));
      final screen = ValueListenableBuilder<HomeDestination>(
        valueListenable: destination,
        builder: (context, current, child) => HomeScreen(
          destination: current,
          onDestinationSelected: (value) => destination.value = value,
          onAnimeTap: (_) => fail('Unexpected activation'),
        ),
      );
      final overrides = [
        authAccessProvider.overrideWithValue(const AuthenticatedAccess('first')),
        favoritesAccountProvider.overrideWithValue('first'),
        catalogRepositoryProvider.overrideWithValue(catalog),
        favoritesRepositoryProvider.overrideWithValue(favorites),
      ];
      if (mobile) {
        await pumpMobileApp(tester, screen, overrides: overrides, wrapInScaffold: false);
      } else {
        await pumpTvApp(tester, screen, overrides: overrides, wrapInScaffold: false);
      }
      await tester.pumpAndSettle();
      expect(favorites.pages, [1]);
      expect(find.byType(MediaCardBookmark), findsOneWidget);
      destination.value = HomeDestination.favorites;
      await tester.pumpAndSettle();
      expect(favorites.pages, [1, 1]);
      expect(find.byType(MediaCardBookmark), findsNothing);
      destination.value = HomeDestination.home;
      await tester.pumpAndSettle();
      expect(find.byType(MediaCardBookmark), findsOneWidget);
    });

    testWidgets('account transition uses positive paginated evidence mobile=$mobile', (tester) async {
      final secondPage = Completer<Result<AnimePage, Failure>>();
      final favorites = FakeFavoritesRepository()
        ..load = (page) async => page == 1 ? Result.success(_page(1, hasNext: true)) : secondPage.future;
      final catalog = FakeCatalogScreenRepository(load: (_) async => Result.success(_page(1, containsAnime: true)));
      final screen = CatalogScreen(onAnimeTap: (_) => fail('Unexpected activation'));
      final overrides = [
        authAccessProvider.overrideWith((ref) {
          final account = ref.watch(_account);
          return account == null ? const AnonymousAccess() : AuthenticatedAccess(account);
        }),
        favoritesAccountProvider.overrideWith((ref) => ref.watch(_account)),
        catalogRepositoryProvider.overrideWithValue(catalog),
        favoritesRepositoryProvider.overrideWithValue(favorites),
      ];
      if (mobile) {
        await pumpMobileApp(tester, screen, overrides: overrides, wrapInScaffold: false);
      } else {
        await pumpTvApp(tester, screen, overrides: overrides, wrapInScaffold: false);
      }
      await tester.pumpAndSettle();
      expect(find.byType(MediaCardBookmark), findsNothing);
      expect(favorites.pages, isEmpty);
      final container = ProviderScope.containerOf(tester.element(find.byType(CatalogScreen)));
      container.read(_account.notifier).account = 'first';
      await tester.pumpAndSettle();
      expect(favorites.pages, [1, 2]);
      expect(find.byType(MediaCardBookmark), findsNothing);
      secondPage.complete(Result.success(_page(2, containsAnime: true)));
      await tester.pumpAndSettle();
      expect(find.byType(MediaCardBookmark), findsOneWidget);
      await container
          .read(favoritesControllerProvider.notifier)
          .setFavorite(animeId: 1, slug: 'anime', favorite: false);
      await tester.pumpAndSettle();
      expect(find.byType(MediaCardBookmark), findsNothing);
      container.read(_account.notifier).account = null;
      await tester.pumpAndSettle();
      expect(find.byType(MediaCardBookmark), findsNothing);
    });

    testWidgets('failed later page retains earlier positive evidence mobile=$mobile', (tester) async {
      final favorites = FakeFavoritesRepository()
        ..load = (page) async => page == 1
            ? Result.success(_page(1, containsAnime: true, hasNext: true))
            : const Result.failure(UnknownFailure());
      final catalog = FakeCatalogScreenRepository(load: (_) async => Result.success(_page(1, containsAnime: true)));
      final screen = CatalogScreen(onAnimeTap: (_) => fail('Unexpected activation'));
      final overrides = [
        authAccessProvider.overrideWithValue(const AuthenticatedAccess('first')),
        favoritesAccountProvider.overrideWithValue('first'),
        catalogRepositoryProvider.overrideWithValue(catalog),
        favoritesRepositoryProvider.overrideWithValue(favorites),
      ];
      if (mobile) {
        await pumpMobileApp(tester, screen, overrides: overrides, wrapInScaffold: false);
      } else {
        await pumpTvApp(tester, screen, overrides: overrides, wrapInScaffold: false);
      }
      await tester.pumpAndSettle();
      expect(favorites.pages, [1, 2]);
      expect(find.byType(MediaCardBookmark), findsOneWidget);
    });

    testWidgets('late previous account response cannot decorate current account mobile=$mobile', (tester) async {
      final oldResponse = Completer<Result<AnimePage, Failure>>();
      var requests = 0;
      final favorites = FakeFavoritesRepository()
        ..load = (_) {
          requests++;
          return requests == 1 ? oldResponse.future : Future.value(Result.success(_page(1)));
        };
      final catalog = FakeCatalogScreenRepository(load: (_) async => Result.success(_page(1, containsAnime: true)));
      final screen = CatalogScreen(onAnimeTap: (_) => fail('Unexpected activation'));
      final overrides = [
        authAccessProvider.overrideWith((ref) {
          final account = ref.watch(_account);
          return account == null ? const AnonymousAccess() : AuthenticatedAccess(account);
        }),
        favoritesAccountProvider.overrideWith((ref) => ref.watch(_account)),
        catalogRepositoryProvider.overrideWithValue(catalog),
        favoritesRepositoryProvider.overrideWithValue(favorites),
      ];
      if (mobile) {
        await pumpMobileApp(tester, screen, overrides: overrides, wrapInScaffold: false);
      } else {
        await pumpTvApp(tester, screen, overrides: overrides, wrapInScaffold: false);
      }
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(tester.element(find.byType(CatalogScreen)));
      container.read(_account.notifier).account = 'first';
      await tester.pumpAndSettle();
      container.read(_account.notifier).account = 'second';
      await tester.pumpAndSettle();
      oldResponse.complete(Result.success(_page(1, containsAnime: true)));
      await tester.pumpAndSettle();
      expect(requests, 2);
      expect(find.byType(MediaCardBookmark), findsNothing);
    });

    testWidgets('favorites page suppresses bookmark mobile=$mobile', (tester) async {
      final favorites = FakeFavoritesRepository()..ids.add(1);
      final screen = CatalogScreen(favoritesOnly: true, onAnimeTap: (_) => fail('Unexpected activation'));
      final overrides = [
        authAccessProvider.overrideWithValue(const AuthenticatedAccess('first')),
        favoritesAccountProvider.overrideWithValue('first'),
        favoritesRepositoryProvider.overrideWithValue(favorites),
      ];
      if (mobile) {
        await pumpMobileApp(tester, screen, overrides: overrides, wrapInScaffold: false);
      } else {
        await pumpTvApp(tester, screen, overrides: overrides, wrapInScaffold: false);
      }
      await tester.pumpAndSettle();
      expect(find.text('Аниме 1'), findsWidgets);
      expect(find.byType(MediaCardBookmark), findsNothing);
      expect(favorites.pages, [1]);
    });
  }
}
