import 'dart:async';

import 'package:anistar_tv/app/app_router.dart';
import 'package:anistar_tv/app/app_routes.dart';
import 'package:anistar_tv/packages/features/anime/anime_providers.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_details.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_episode.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_part.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_screen_data.dart';
import 'package:anistar_tv/packages/features/auth/auth_providers.dart';
import 'package:anistar_tv/packages/features/auth/presentation/login_screen.dart';
import 'package:anistar_tv/packages/features/catalog/catalog_providers.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/anime_page.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/anime_summary.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/catalog_filter.dart';
import 'package:anistar_tv/packages/features/favorites/favorites_providers.dart';
import 'package:anistar_tv/packages/features/home/presentation/screens/home_screen.dart';
import 'package:app_logging/app_logging.dart';
import 'package:core/data.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../mocks/features/anime/fake_anime_screen_repository.dart';
import '../mocks/features/auth/fake_auth_repository.dart';
import '../mocks/features/catalog/fake_catalog_browse_repository.dart';
import '../mocks/features/catalog/fake_catalog_screen_repository.dart';
import '../mocks/features/favorites/fake_favorites_repository.dart';
import '../support/decoded_fixture_image.dart';
import '../support/test_app.dart';

final _page = AnimePage(
  page: 1,
  hasNext: false,
  items: [
    AnimeSummary(
      id: 1,
      slug: '1-fixture',
      title: 'Путешествие через незнакомые города',
      posterUri: Uri.parse(decodedFixtureUrl),
      year: '2026',
      genreText: 'Приключения, Драма',
      rating: 8.7,
      description: 'Друзья отправляются в путь и постепенно узнают историю своей семьи.',
      updateMessage: 'Добавлена 4 серия',
      publicationDate: 'Вчера, 23:59',
      isFavorite: true,
    ),
    const AnimeSummary(id: 2, slug: '2-fixture', title: 'История без дополнительных сведений'),
    for (var index = 3; index <= 12; index++)
      AnimeSummary(id: index, slug: '$index-fixture', title: 'История $index', rating: index == 3 ? 0 : null),
  ],
);

final _details = AnimeScreenData(
  details: AnimeDetails(
    id: 1,
    slug: '1-fixture',
    title: 'Путешествие через незнакомые города / A Journey Through Unknown Cities',
    genres: const ['Приключения', 'Драма'],
    filters: const [
      CatalogFilter(label: '2026', path: '/filter/year/2026/'),
      CatalogFilter(label: 'Режиссёр: Полное имя', path: '/filter/director/%C8%EC%FF/'),
    ],
    isOngoing: true,
    isFavorite: false,
    posterUri: Uri.parse(decodedFixtureUrl),
    year: '2026',
    rating: 0,
    director: 'Полное имя режиссёра',
    seriesInfo: '12 серий',
    voiceover: 'Озвучивание: AniStar',
    description: 'Друзья отправляются в путь. История семьи помогает им найти дорогу домой.',
    updateMessage: 'Добавлена 4 серия',
    publicationDate: 'Вчера, 23:59',
    parts: [
      AnimePart(
        label: 'Первый сезон — текущая часть',
        uri: Uri.parse('https://fixture.test/1-fixture.html'),
        id: 1,
        slug: '1-fixture',
      ),
      AnimePart(
        label: 'Второй сезон с полной подписью',
        uri: Uri.parse('https://fixture.test/2-fixture.html'),
        id: 2,
        slug: '2-fixture',
      ),
      AnimePart(label: 'Дополнительная часть без доступной ссылки', uri: Uri.parse('https://foreign.test/part')),
    ],
  ),
  episodes: const [
    AnimeEpisode(number: 1, title: 'Серия 1', isWatched: true),
    AnimeEpisode(number: 3, title: 'Очень длинное собственное название серии о возвращении домой', isWatched: true),
    AnimeEpisode(number: 5, title: 'Серия 5'),
  ],
);

void main() {
  // Player's seventh scene and its panels use the native-controller fixture goldens
  // in features/player; these six scenes exercise actual nullable domain metadata.
  for (final mobile in [false, true]) {
    for (final scene in ['login', 'home', 'favorites', 'genres', 'browse', 'detail']) {
      testWidgets('rich redesign $scene ${mobile ? 'mobile' : 'tv'}', (tester) async {
        final decoded = await cacheDecodedFixtureImage(tester);
        final settle = tester.pumpAndSettle;
        const capture = expectLater;
        final app = find.byType(MaterialApp).first;
        final auth = FakeAuthRepository()
          ..restoreResult = scene == 'login'
              ? const Result.success(null)
              : const Result.success('Тестовый пользователь');
        addTearDown(auth.close);
        final router = AppRouter(AppLogger.logger);
        addTearDown(router.dispose);
        final overrides = <Override>[
          authRepositoryProvider.overrideWithValue(auth),
          catalogRepositoryProvider.overrideWithValue(
            FakeCatalogScreenRepository(load: (_) async => Result.success(_page)),
          ),
          catalogBrowseRepositoryProvider.overrideWithValue(
            FakeCatalogBrowseRepository(
              load: (_, _) async => Result.success(_page),
              genres: () async => const Result.success([
                CatalogFilter(label: 'Приключения', path: '/adventure/'),
                CatalogFilter(label: 'Драма', path: '/drama/'),
                CatalogFilter(label: 'Комедия', path: '/comedy/'),
              ]),
            ),
          ),
          favoritesRepositoryProvider.overrideWithValue(
            FakeFavoritesRepository()
              ..load = (_) async =>
                  Result.success(AnimePage(page: 1, hasNext: false, items: _page.items.take(1).toList())),
          ),
          animeRepositoryProvider.overrideWithValue(
            FakeAnimeScreenRepository(load: (_, _) async => Result.success(_details)),
          ),
        ];
        final Widget screen = scene == 'login'
            ? const LoginScreen()
            : MaterialApp.router(
                routerConfig: router.router,
                debugShowCheckedModeBanner: false,
                theme: mobile ? AppTheme.mobileDarkTheme : AppTheme.darkTheme,
              );
        if (mobile) {
          await pumpMobileApp(tester, screen, wrapInScaffold: false, disableAnimations: true, overrides: overrides);
        } else {
          await pumpTvApp(tester, screen, size: wideTvSize, wrapInScaffold: false, overrides: overrides);
        }
        await settle();
        if (scene == 'browse' || scene == 'detail') {
          final context = tester.element(find.byType(HomeScreen));
          if (scene == 'browse') {
            unawaited(FilterRoute(path: comedyFilter.path, title: comedyFilter.label).push<void>(context));
          } else {
            AnimeRoute(animeId: 1, slug: '1-fixture', title: _details.details.title).go(context);
          }
          await settle();
        }
        if (scene == 'favorites' || scene == 'genres') {
          if (mobile) {
            final navigation = find.byKey(const ValueKey('mobile-navigation'));
            final destination = find.descendant(
              of: navigation,
              matching: find.text(scene == 'genres' ? 'Жанры' : 'Избранное'),
            );
            await tester.tap(destination);
          } else {
            final destination = find.byKey(ValueKey(scene == 'genres' ? 'catalog-genres' : 'catalog-tab-true'));
            tester.widget<TextButton>(destination).focusNode?.requestFocus();
            await tester.pump();
            await tester.sendKeyEvent(LogicalKeyboardKey.select);
          }
          await settle();
        }
        final sceneError = tester.takeException();
        expect(sceneError, isNull, reason: sceneError is Error ? '${sceneError.stackTrace}' : null);
        if (!mobile && scene == 'home') {
          final grid = tester.widget<SliverGrid>(find.byType(SliverGrid));
          expect((grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount).crossAxisCount, 4);
        }
        if (['home', 'favorites', 'browse', 'detail'].contains(scene)) {
          expect(
            tester.widgetList<RawImage>(find.byType(RawImage)).any((raw) => raw.image?.isCloneOf(decoded) ?? false),
            isTrue,
            reason: 'the bundled poster must render successfully alongside nullable image fallbacks',
          );
        }
        await capture(app, matchesGoldenFile('goldens/redesign_${scene}_${mobile ? 'mobile' : 'tv'}.png'));
        if (scene == 'detail') {
          final part = find.text('Второй сезон с полной подписью');
          await tester.scrollUntilVisible(part, 180, scrollable: find.byType(Scrollable).first);
          await settle();
          expect(part.hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
          await capture(app, matchesGoldenFile('goldens/redesign_parts_${mobile ? 'mobile' : 'tv'}.png'));
        }
        await tester.pumpWidget(const SizedBox.shrink());
      }, tags: ['golden']);
    }
  }
  for (final size in [const Size(360, 800), const Size(430, 932)]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('rich home at width ${size.width} text $scale', (tester) async {
        await cacheDecodedFixtureImage(tester);
        await pumpMobileApp(
          tester,
          HomeScreen(
            onAnimeTap: (_) => fail('Unexpected navigation'),
            onOpenGenres: () => fail('Unexpected genres'),
            onOpenLogs: () => fail('Unexpected logs'),
            onSignOut: () => fail('Unexpected logout'),
            accountName: 'Тестовый пользователь',
          ),
          size: size,
          textScale: scale,
          disableAnimations: true,
          wrapInScaffold: false,
          overrides: [
            catalogRepositoryProvider.overrideWithValue(
              FakeCatalogScreenRepository(load: (_) async => Result.success(_page)),
            ),
          ],
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/redesign_home_${size.width.toInt()}_${scale.toInt()}.png'),
        );
      }, tags: ['golden']);
    }
  }
}
