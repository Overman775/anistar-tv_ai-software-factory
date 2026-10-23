import 'dart:async';

import 'package:anistar_tv/packages/features/auth/auth_providers.dart';
import 'package:anistar_tv/packages/features/catalog/catalog_providers.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/anime_page.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/anime_summary.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/mobile/mobile_anime_card.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/screens/catalog_screen.dart';
import 'package:anistar_tv/packages/features/favorites/favorites_providers.dart';
import 'package:anistar_tv/packages/features/home/presentation/screens/home_screen.dart';
import 'package:core/data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../mocks/features/catalog/fake_catalog_screen_repository.dart';
import '../../../../../mocks/features/favorites/fake_favorites_repository.dart';
import '../../../../../support/test_app.dart';

// Each read samples widget state or geometry after a different gesture/response.
// ignore_for_file: prefer-moving-to-variable

Future<void> pull(WidgetTester tester, Finder scroll) async {
  await tester.drag(scroll, const Offset(0, 350));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
  await tester.pump();
}

AnimePage page(List<int> ids, {bool hasNext = false, int number = 1}) => AnimePage(
  items: [for (final id in ids) AnimeSummary(id: id, slug: '$id-test', title: 'Аниме $id', posterUri: Uri())],
  page: number,
  hasNext: hasNext,
);

void main() {
  for (final favoritesOnly in [false, true]) {
    for (final empty in [false, true]) {
      testWidgets(
        'pull refresh ${favoritesOnly ? 'favorites' : 'home'} ${empty ? 'empty' : 'short'} retains content, awaits network and retries',
        (tester) async {
          final requests = <int>[];
          var pending = Completer<Result<AnimePage, Failure>>();
          Future<Result<AnimePage, Failure>> load(int number) {
            requests.add(number);

            return requests.length == 1 ? Future.value(Result.success(page(empty ? [] : [1]))) : pending.future;
          }

          final favorites = FakeFavoritesRepository()..load = load;
          await pumpMobileApp(
            tester,
            const HomeScreen(onAnimeTap: ignoreAnime),
            wrapInScaffold: false,
            overrides: [
              authAccessProvider.overrideWithValue(const AuthenticatedAccess('test')),
              favoritesAccountProvider.overrideWithValue('test'),
              catalogRepositoryProvider.overrideWithValue(FakeCatalogScreenRepository(load: load)),
              favoritesRepositoryProvider.overrideWithValue(favorites),
            ],
          );
          await tester.pumpAndSettle();
          if (favoritesOnly) {
            // The unvisited tab makes its own first request.
            requests.clear();
            await tester.tap(find.byType(NavigationDestination).at(2));
            await tester.pumpAndSettle();
          }
          final tab = find.byType(CatalogScreen);
          final scroll = find.descendant(of: tab, matching: find.byType(Scrollable)).first;
          final chrome = find.byKey(const ValueKey('mobile-account'));
          final navigation = find.byType(NavigationBar);
          final bottomTop = tester.getTopLeft(navigation);
          await pull(tester, scroll);
          expect(requests, [1, 1]);
          expect(find.byType(RefreshProgressIndicator), findsOneWidget);
          expect(
            find.descendant(of: tab, matching: find.byType(MobileAnimeCard)),
            empty ? findsNothing : findsOneWidget,
          );
          expect(chrome.hitTestable(), findsOneWidget);
          expect(tester.getTopLeft(navigation), bottomTop);
          await pull(tester, scroll);
          expect(requests.length, 2, reason: 'a second gesture must not duplicate the pending request');
          pending.complete(const Result.failure(UnknownFailure()));
          await tester.pumpAndSettle();
          expect(find.byType(RefreshProgressIndicator), findsNothing);
          if (empty) {
            expect(find.text(favoritesOnly ? 'Избранное недоступно' : 'Каталог недоступен'), findsOneWidget);
          } else {
            expect(find.text('Аниме 1'), findsOneWidget);
            expect(find.textContaining('Не удалось обновить.'), findsOneWidget);
          }
          pending = Completer<Result<AnimePage, Failure>>();
          final retryScroll = find.descendant(of: tab, matching: find.byType(Scrollable)).first;
          await pull(tester, retryScroll);
          expect(requests, [1, 1, 1]);
          pending.complete(Result.success(page([2])));
          await tester.pumpAndSettle();
          expect(find.text('Аниме 2'), findsOneWidget);
          expect(find.descendant(of: tab, matching: find.text('Аниме 1')), findsNothing);
          // Check dismissal independently after failure and then after recovery.
          // ignore: avoid-duplicate-test-assertions
          expect(find.byType(RefreshProgressIndicator), findsNothing);
          expect(find.text('Обновить контент'), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('pagination completing during a pull cannot stop the indicator or append old data', (tester) async {
    final pagination = Completer<Result<AnimePage, Failure>>();
    final refreshed = Completer<Result<AnimePage, Failure>>();
    final requests = <int>[];
    await pumpMobileApp(
      tester,
      const CatalogScreen(onAnimeTap: ignoreAnime),
      wrapInScaffold: false,
      overrides: [
        authAccessProvider.overrideWithValue(const AuthenticatedAccess('test')),
        favoritesAccountProvider.overrideWithValue('test'),
        catalogRepositoryProvider.overrideWithValue(
          FakeCatalogScreenRepository(
            load: (number) {
              requests.add(number);
              if (number == 2) {
                return pagination.future;
              }

              return requests.length == 1
                  ? Future.value(Result.success(page(List.generate(30, (index) => index + 1), hasNext: true)))
                  : refreshed.future;
            },
          ),
        ),
      ],
    );
    await tester.pumpAndSettle();
    final scroll = find.byType(CustomScrollView);
    final controller = tester.widget<CustomScrollView>(scroll).controller;
    if (controller == null) {
      fail('Catalog must retain its controller');
    }
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();
    expect(requests, [1, 2]);
    controller.jumpTo(0);
    await tester.pump();
    await pull(tester, scroll);
    expect(requests, [1, 2, 1]);
    pagination.complete(Result.success(page([99], number: 2)));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(RefreshProgressIndicator), findsOneWidget);
    expect(find.text('Аниме 1'), findsOneWidget);
    refreshed.complete(Result.success(page([101])));
    await tester.pumpAndSettle();
    expect(find.text('Аниме 101'), findsOneWidget);
    expect(find.text('Аниме 99'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('TV catalogs have no pull refresh and a downward drag does not reload', (tester) async {
    final requests = <int>[];
    await pumpTvApp(
      tester,
      const CatalogScreen(onAnimeTap: ignoreAnime),
      wrapInScaffold: false,
      overrides: [
        authAccessProvider.overrideWithValue(const AuthenticatedAccess('test')),
        favoritesAccountProvider.overrideWithValue('test'),
        catalogRepositoryProvider.overrideWithValue(
          FakeCatalogScreenRepository(
            load: (number) async {
              requests.add(number);

              return Result.success(page([1]));
            },
          ),
        ),
      ],
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 350));
    await tester.pumpAndSettle();
    expect(requests, [1]);
    expect(find.byType(RefreshIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed pull after pagination keeps the list and scroll can request the next page', (tester) async {
    final refresh = Completer<Result<AnimePage, Failure>>();
    final pagination = Completer<Result<AnimePage, Failure>>();
    final requests = <int>[];
    await pumpMobileApp(
      tester,
      const CatalogScreen(onAnimeTap: ignoreAnime),
      wrapInScaffold: false,
      overrides: [
        authAccessProvider.overrideWithValue(const AuthenticatedAccess('test')),
        favoritesAccountProvider.overrideWithValue('test'),
        catalogRepositoryProvider.overrideWithValue(
          FakeCatalogScreenRepository(
            load: (number) {
              requests.add(number);
              if (number == 2) {
                return pagination.future;
              }
              if (number == 1 && requests.length > 1) {
                return refresh.future;
              }

              return Future.value(
                Result.success(
                  page(
                    List.generate(30, (index) => (number - 1) * 30 + index + 1),
                    number: number,
                    hasNext: number < 3,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
    await tester.pumpAndSettle();
    final scroll = find.byType(CustomScrollView);
    final controller = tester.widget<CustomScrollView>(scroll).controller;
    if (controller == null) {
      fail('Catalog must retain its controller');
    }
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();
    controller.jumpTo(0);
    pagination.complete(Result.success(page(List.generate(30, (index) => index + 31), number: 2, hasNext: true)));
    await tester.pumpAndSettle();
    await pull(tester, scroll);
    refresh.complete(const Result.failure(UnknownFailure()));
    await tester.pumpAndSettle();
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(requests, [1, 2, 1, 3]);
    expect(tester.takeException(), isNull);
  });
}

// This suite only refreshes the current catalog.
// ignore: no-empty-block
void ignoreAnime(AnimeSummary _) {
  // Refresh tests do not navigate to another route.
}
