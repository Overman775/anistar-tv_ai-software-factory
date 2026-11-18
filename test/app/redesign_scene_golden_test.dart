import 'dart:async';

import 'package:anistar_tv/app/app_router.dart';
import 'package:anistar_tv/app/app_routes.dart';
import 'package:anistar_tv/packages/features/anime/anime_providers.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_details.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_episode.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_part.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_screen_data.dart';
import 'package:anistar_tv/packages/features/anime/presentation/screens/anime_screen.dart';
import 'package:anistar_tv/packages/features/auth/auth_providers.dart';
import 'package:anistar_tv/packages/features/auth/presentation/login_screen.dart';
import 'package:anistar_tv/packages/features/catalog/catalog_providers.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/anime_page.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/anime_summary.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/catalog_filter.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/widgets/catalog_layout.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/widgets/catalog_poster_rail.dart';
import 'package:anistar_tv/packages/features/favorites/favorites_providers.dart';
import 'package:anistar_tv/packages/features/home/presentation/home_destination.dart';
import 'package:anistar_tv/packages/features/home/presentation/screens/home_screen.dart';
import 'package:anistar_tv/packages/features/search/search_providers.dart';
import 'package:app_logging/app_logging.dart';
// The fixture seeds the public image provider used by the poster.
// ignore: depend_on_referenced_packages
import 'package:cached_network_image/cached_network_image.dart';
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
import '../mocks/features/search/fake_search_repository.dart';
import '../support/catalog_backdrop.dart';
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
  // in features/player; these scenes exercise actual nullable domain metadata.
  for (final scene in ['home', 'favorites', 'genres', 'browse', 'search', 'menu', 'detail']) {
    testWidgets('rich redesign $scene tv', (tester) async {
      await _runRedesignScene(tester, scene: scene, profile: GoldenProfile.tv, textScale: GoldenTextScale.normal);
    }, tags: ['golden']);
  }
  for (final scene in ['login', 'home', 'favorites', 'genres', 'browse', 'detail']) {
    testWidgets('rich redesign $scene phone portrait', (tester) async {
      await _runRedesignScene(
        tester,
        scene: scene,
        profile: GoldenProfile.phonePortrait,
        textScale: GoldenTextScale.normal,
      );
    }, tags: ['golden']);
  }
  testWidgets('rich redesign detail tv error', (tester) async {
    var calls = 0;
    await pumpScreenGolden(
      tester,
      AnimeScreen(
        animeId: 1,
        slug: '1-fixture',
        fallbackTitle: 'Аниме',
        onEpisodeTap: (_) => fail('Unexpected episode'),
      ),
      wrapInScaffold: false,
      overrides: [
        animeRepositoryProvider.overrideWithValue(
          FakeAnimeScreenRepository(
            load: (_, _) async {
              calls++;
              return const Result.failure(UnknownFailure());
            },
          ),
        ),
      ],
    );
    await tester.pumpAndSettle();
    expect(find.text('Повторить').hitTestable(), findsOneWidget);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'Повторить');
    await expectScreenGolden('redesign_detail_error');
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(tester.takeException(), isNull);
  }, tags: ['golden']);
  testWidgets('rich home at phone portrait 200%', (tester) async {
    await cacheDecodedFixtureImage(tester);
    await testScreenGolden(
      tester,
      'redesign_home',
      profile: GoldenProfile.phonePortrait,
      textScale: GoldenTextScale.large,
      screen: HomeScreen(
        onAnimeTap: (_) => fail('Unexpected navigation'),
        onOpenGenres: () => fail('Unexpected genres'),
        onOpenLogs: () => fail('Unexpected logs'),
        onSignOut: () => fail('Unexpected logout'),
        accountName: 'Тестовый пользователь',
      ),
      wrapInScaffold: false,
      overrides: [
        catalogRepositoryProvider.overrideWithValue(
          FakeCatalogScreenRepository(load: (_) async => Result.success(_page)),
        ),
      ],
    );
  }, tags: ['golden']);
}

Future<void> _runRedesignScene(
  WidgetTester tester, {
  required String scene,
  required GoldenProfile profile,
  required GoldenTextScale textScale,
}) async {
  final mobile = profile != GoldenProfile.tv;
  final decoded = await cacheDecodedFixtureImage(
    tester,
    filePath: scene == 'home' || scene == 'browse' ? 'prototype/assets/frieren.jpg' : null,
  );
  final size = profile.logicalSize;
  if (mobile) {
    final padding = (size.width * 0.04).clamp(16.0, 24.0);
    final available = size.width - 2 * padding;
    final columns = CatalogLayout.mobileColumnCount(available, textScale.factor, landscape: size.width > size.height);
    final width = ((available - (columns - 1) * CatalogLayout.mobilePosterGap) / columns).ceil();
    for (final cacheWidth in {width, 240}) {
      final resized = ResizeImage.resizeIfNeeded(cacheWidth, null, const CachedNetworkImageProvider(decodedFixtureUrl));
      final key = await resized.obtainKey(ImageConfiguration.empty);
      PaintingBinding.instance.imageCache.putIfAbsent(
        key,
        () => OneFrameImageStreamCompleter(Future.value(ImageInfo(image: decoded.clone()))),
      );
    }
  } else {
    final backdrop =
        AppNetworkImage.providerFor(decodedFixtureUrl, cacheHeight: size.height.ceil()) ?? fail('Invalid fixture URL');
    final backdropKey = await backdrop.obtainKey(ImageConfiguration.empty);
    PaintingBinding.instance.imageCache.putIfAbsent(
      backdropKey,
      () => OneFrameImageStreamCompleter(Future.value(ImageInfo(image: decoded.clone()))),
    );
    for (final width in [
      (size.height * 0.17).clamp(92, 232).ceil(),
      size.width.toInt() - 72,
      (size.width * 0.22).clamp(140, 240).ceil(),
    ]) {
      final resized = ResizeImage.resizeIfNeeded(width, null, const CachedNetworkImageProvider(decodedFixtureUrl));
      final key = await resized.obtainKey(ImageConfiguration.empty);
      PaintingBinding.instance.imageCache.putIfAbsent(
        key,
        () => OneFrameImageStreamCompleter(Future.value(ImageInfo(image: decoded.clone()))),
      );
    }
  }
  final settle = tester.pumpAndSettle;
  final auth = FakeAuthRepository()
    ..restoreResult = scene == 'login' ? const Result.success(null) : const Result.success('Тестовый пользователь');
  addTearDown(auth.close);
  final router = AppRouter(AppLogger.logger);
  addTearDown(router.dispose);
  final overrides = <Override>[
    authRepositoryProvider.overrideWithValue(auth),
    catalogRepositoryProvider.overrideWithValue(FakeCatalogScreenRepository(load: (_) async => Result.success(_page))),
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
        ..load = (_) async => Result.success(AnimePage(page: 1, hasNext: false, items: _page.items.take(1).toList())),
    ),
    searchRepositoryProvider.overrideWithValue(FakeSearchRepository(load: (_) async => Result.success(_page))),
    searchHistoryRepositoryProvider.overrideWithValue(FakeSearchHistoryRepository()),
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
  await pumpScreenGolden(
    tester,
    screen,
    profile: profile,
    textScale: textScale,
    wrapInScaffold: false,
    overrides: overrides,
  );
  await settle();
  if (scene == 'browse' || scene == 'detail') {
    final context = tester.element(find.byType(HomeScreen));
    if (scene == 'browse') {
      unawaited(
        const FilterRoute(path: '/xfsearch/author/%c8%ec%ff/', title: 'Автор с длинным именем').push<void>(context),
      );
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
  if (!mobile && scene == 'search') {
    const HomeRoute(destination: HomeDestination.search).go(tester.element(find.byType(HomeScreen)));
    await settle();
    await tester.enterText(find.byKey(const ValueKey('search-query')), 'Наруто');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await settle();
  }
  if (!mobile && scene == 'menu') {
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await settle();
  }
  if (!mobile && ['home', 'favorites', 'browse', 'search', 'menu'].contains(scene)) {
    await pumpUntilCatalogBackdrop(tester);
  }
  final sceneError = tester.takeException();
  expect(sceneError, isNull, reason: sceneError is Error ? '${sceneError.stackTrace}' : null);
  if (!mobile && scene == 'home') {
    expect(find.byType(CatalogPosterRail), findsOneWidget);
  }
  if (['home', 'favorites', 'browse'].contains(scene)) {
    expect(
      tester.widgetList<RawImage>(find.byType(RawImage)).any((raw) => raw.image?.isCloneOf(decoded) ?? false),
      isTrue,
      reason: 'the bundled poster must render successfully alongside nullable image fallbacks',
    );
  }
  if (scene == 'home' || scene == 'browse') {
    expect(find.byType(MediaCardBookmark), findsOneWidget);
  }
  await expectScreenGolden('redesign_$scene', profile: profile, textScale: textScale);
  if (scene == 'detail') {
    if (mobile) {
      await tester.tap(find.text('Подробнее'));
      await settle();
    }
    if (!mobile) {
      expect(find.text('Второй сезон с полной подписью'), findsNothing);
      await tester.tap(find.text('Подробнее'));
      await settle();
      expect(
        tester.widgetList<RawImage>(find.byType(RawImage)).any((raw) => raw.image?.isCloneOf(decoded) ?? false),
        isTrue,
        reason: 'expanded details must show the decoded poster',
      );
      await expectScreenGolden('redesign_detail_expanded', profile: profile, textScale: textScale);
    }
    final part = find.text('Второй сезон с полной подписью');
    await tester.scrollUntilVisible(part, 180, scrollable: find.byType(Scrollable).first);
    await settle();
    expect(part.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectScreenGolden('redesign_parts', profile: profile, textScale: textScale);
  }
  await tester.pumpWidget(const SizedBox.shrink());
}
