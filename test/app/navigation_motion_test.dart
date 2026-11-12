import 'dart:async';
import 'dart:ui' as ui;

import 'package:anistar_tv/app/app_navigation_page.dart';
import 'package:anistar_tv/app/app_router.dart';
import 'package:anistar_tv/app/app_routes.dart';
import 'package:anistar_tv/packages/features/anime/anime_providers.dart';
import 'package:anistar_tv/packages/features/anime/data/repositories/anistar_anime_repository.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_details.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_screen_data.dart';
import 'package:anistar_tv/packages/features/anime/presentation/widgets/anime_hero.dart';
import 'package:anistar_tv/packages/features/anime/presentation/widgets/anime_skeleton.dart';
import 'package:anistar_tv/packages/features/auth/auth_providers.dart';
import 'package:anistar_tv/packages/features/catalog/catalog_providers.dart';
import 'package:anistar_tv/packages/features/catalog/data/repositories/anistar_catalog_repository.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/anime_page.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/anime_summary.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/mobile/mobile_anime_card.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/screens/catalog_screen.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/widgets/anime_card.dart';
import 'package:anistar_tv/packages/features/favorites/favorites_providers.dart';
import 'package:app_logging/app_logging.dart';
// These regressions seed the UI kit's real cached image provider.
// ignore: depend_on_referenced_packages
import 'package:cached_network_image/cached_network_image.dart';
import 'package:core/data.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../mocks/anistar/anistar_fixtures.dart';
import '../mocks/anistar/test_anistar_client.dart';
import '../mocks/features/anime/fake_anime_screen_repository.dart';
import '../mocks/features/catalog/fake_catalog_screen_repository.dart';
import '../mocks/features/favorites/fake_favorites_repository.dart';
import '../mocks/networking/html_fixture_adapter.dart';
import '../support/test_app.dart';

void main() {
  testWidgets('parsed detail author opens the typed filter and continues with confirmed alphabetical sort', (
    tester,
  ) async {
    const author = 'Синохара Тиэ';
    const path = '/filter/author/%f1%e8%ed%ee%f5%e0%f0%e0+%f2%e8%fd/';
    const continuation = '${path}page/2/';
    const defaultActive =
        '<form id="news_set_sort"><a class="sort-actv" onclick="dle_change_sort(\'date\',\'asc\');">sort</a></form>';
    const active =
        '<form id="news_set_sort"><a class="sort-actv" onclick="dle_change_sort(\'title\',\'desc\');">sort</a></form>';
    const cookie = 'dle_sort_xfsearch=title; dle_direction_xfsearch=asc; dle_no_cache=1';
    final firstPage = [
      for (var id = 1; id <= 12; id++)
        '<div class="news"><div class="title_left"><a href="/$id-fixture.html">Аниме $id</a></div></div>',
    ].join();
    final adapter = HtmlFixtureAdapter({
      '/10938-test.html': detailHtml.replaceFirst('</ul>', '<li><b>Автор:</b> <a href="$path">$author</a></li></ul>'),
      '/test/player2/videoas_p2p_new.php': playerHtml,
      Uri.parse(path).path: '$defaultActive$firstPage',
      Uri.parse(continuation).path:
          '$active<div class="news"><div class="title_left"><a href="/99-next.html">Явное продолжение</a></div></div>',
    });
    final dio = Dio(BaseOptions(baseUrl: 'https://v30.astar.bz/'))..httpClientAdapter = adapter;
    addTearDown(() => dio.close(force: true));
    final client = createTestAnistarClient(dio);
    final router = AppRouter(AppLogger.logger);
    addTearDown(router.dispose);
    await pumpMobileApp(
      tester,
      MaterialApp.router(routerConfig: router.router, theme: AppTheme.mobileDarkTheme),
      wrapInScaffold: false,
      overrides: [
        authAccessProvider.overrideWithValue(const AnonymousAccess()),
        catalogRepositoryProvider.overrideWithValue(const FakeCatalogScreenRepository()),
        catalogBrowseRepositoryProvider.overrideWithValue(AnistarCatalogRepository(client)),
        animeRepositoryProvider.overrideWithValue(AnistarAnimeRepository(client)),
      ],
    );
    await tester.pumpAndSettle();
    unawaited(
      const AnimeRoute(
        animeId: 10938,
        slug: '10938-test',
        title: 'Тестовое аниме',
      ).push<void>(tester.element(find.byType(CatalogScreen))),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Подробнее'));
    await tester.pumpAndSettle();
    final authorChip = find.text(author);
    await tester.scrollUntilVisible(authorChip, 140, scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
    await tester.tap(authorChip);
    await tester.pumpAndSettle();
    final resultScreen = find.byType(CatalogScreen);
    expect(
      GoRouterState.of(tester.element(resultScreen)).uri.toString(),
      const FilterRoute(path: path, title: author).location,
    );
    expect(tester.widget<CatalogScreen>(resultScreen).filter?.path, path);
    expect(adapter.requests.last.path, path.substring(1));
    expect(
      adapter.requests.last.headers['Cookie'],
      'dle_sort_xfsearch=date; dle_direction_xfsearch=desc; dle_no_cache=1',
    );

    adapter.responses[Uri.parse(path).path] = '$active$firstPage<div class="pages"><a href="$continuation">2</a></div>';
    await tester.tap(find.byKey(const ValueKey('catalog-sort')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('По алфавиту'));
    await tester.pump();
    final ascending = find.text('А → Я');
    await tester.ensureVisible(ascending);
    await tester.tap(ascending);
    final apply = find.text('Применить');
    await tester.ensureVisible(apply);
    await tester.tap(apply);
    await tester.pumpAndSettle();
    expect(adapter.requests.last.path, path.substring(1));
    expect(adapter.requests.last.headers['Cookie'], cookie);
    final catalog = find.descendant(of: find.byType(CatalogScreen), matching: find.byType(Scrollable));
    final next = find.byKey(const ValueKey(99));
    await tester.scrollUntilVisible(next, 300, scrollable: catalog);
    await tester.pumpAndSettle();
    expect(next.hitTestable(), findsOneWidget);
    expect(tester.widget<MobileAnimeCard>(next).anime.title, 'Явное продолжение');
    expect(
      adapter.requests.where((request) => request.path.startsWith('filter/author/')).map((request) => request.path),
      [path.substring(1), path.substring(1), continuation.substring(1)],
    );
    expect(adapter.requests.last.headers['Cookie'], cookie);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(authorChip.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final favorites in [false, true]) {
    testWidgets('page transitions from ${favorites ? 'favorites' : 'home'} before details load and returns on Back', (
      tester,
    ) async {
      final router = AppRouter(AppLogger.logger);
      addTearDown(router.dispose);
      final pending = Completer<Result<AnimeScreenData, Failure>>();
      final favoritesRepository = FakeFavoritesRepository()..ids.add(1);
      await pumpTvApp(
        tester,
        MaterialApp.router(routerConfig: router.router, theme: AppTheme.darkTheme),
        wrapInScaffold: false,
        overrides: [
          authAccessProvider.overrideWithValue(const AuthenticatedAccess('test')),
          favoritesAccountProvider.overrideWithValue('test'),
          catalogRepositoryProvider.overrideWithValue(const FakeCatalogScreenRepository()),
          favoritesRepositoryProvider.overrideWithValue(favoritesRepository),
          animeRepositoryProvider.overrideWithValue(FakeAnimeScreenRepository(load: (_, _) => pending.future)),
        ],
      );
      final settle = tester.pumpAndSettle;
      await settle();
      if (favorites) {
        await tester.tap(find.byKey(const ValueKey('catalog-tab-true')));
        await settle();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await settle();
      }
      final heroFinder = find.byType(AnimeHero);
      final card = find.byType(AnimeCard).first;
      final imagesInCard = find.descendant(of: card, matching: find.byType(AppNetworkImage));
      expect(imagesInCard, findsOneWidget);
      await tester.tap(card);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.byType(AnimeSkeleton), findsOneWidget);
      expect(ModalRoute.of(tester.element(card))?.offstage, isFalse);
      expect(imagesInCard, findsOneWidget);
      expect(find.byType(AnimeHero), findsNothing);
      pending.complete(await const FakeAnimeScreenRepository().getAnime(id: 1, slug: '1-test'));
      await tester.pump();
      expect(heroFinder, findsNothing);
      await settle();
      expect(heroFinder, findsNothing);
      router.router.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(imagesInCard, findsOneWidget);
      await settle();
      expect(find.byType(AnimeCard), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  decodedPosterTests();

  testWidgets('rapid Back discards unfinished details without a stranded hero', (tester) async {
    final router = AppRouter(AppLogger.logger);
    addTearDown(router.dispose);
    final pending = Completer<Result<AnimeScreenData, Failure>>();
    final settle = tester.pumpAndSettle;
    await pumpTvApp(
      tester,
      MaterialApp.router(routerConfig: router.router, theme: AppTheme.darkTheme),
      wrapInScaffold: false,
      overrides: [
        authAccessProvider.overrideWithValue(const AuthenticatedAccess('test')),
        favoritesAccountProvider.overrideWithValue('test'),
        catalogRepositoryProvider.overrideWithValue(const FakeCatalogScreenRepository()),
        animeRepositoryProvider.overrideWithValue(FakeAnimeScreenRepository(load: (_, _) => pending.future)),
      ],
    );
    await settle();
    await tester.tap(find.byType(AnimeCard).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    router.router.pop();
    await settle();
    pending.complete(await const FakeAnimeScreenRepository().getAnime(id: 1, slug: '1-test'));
    await settle();
    expect(find.byType(AnimeHero), findsNothing);
    expect(find.byType(AnimeSkeleton), findsNothing);
    expect(find.byType(AnimeCard), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final accessible in [false, true]) {
    testWidgets('reduced motion disables page duration and poster flight; accessible=$accessible', (tester) async {
      final pages = <AppNavigationPage>[];
      await pumpTvApp(
        tester,
        MediaQuery(
          data: MediaQueryData(disableAnimations: !accessible, accessibleNavigation: accessible),
          child: Builder(
            builder: (context) {
              for (final player in [false, true]) {
                pages.add(
                  AppNavigationPage(context: context, key: ValueKey(player), child: const SizedBox(), player: player),
                );
              }

              return const SizedBox.square(
                dimension: 100,
                child: TvPosterHero(tag: 'poster', imageUrl: null, semanticLabel: 'Poster'),
              );
            },
          ),
        ),
      );
      expect(
        pages.every(
          (page) => page.transitionDuration == Duration.zero && page.reverseTransitionDuration == Duration.zero,
        ),
        isTrue,
      );
      expect(tester.widget<HeroMode>(find.byType(HeroMode)).enabled, isFalse);
    });
  }
}

/// Shared with the native Android regression entry point.
void decodedPosterTests() {
  for (final earlyResponse in [true, false]) {
    testWidgets('decoded poster returns after the page transition; early=$earlyResponse', (tester) async {
      const url = 'https://fixture.test/hero-poster.png';
      final image =
          await tester.runAsync(() async {
            final bytes = await rootBundle.load(Assets.images.anistarLauncher.keyName);
            final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
            final frame = await codec.getNextFrame();
            codec.dispose();

            return frame.image;
          }) ??
          (throw StateError('Poster decode did not complete'));
      final settle = tester.pumpAndSettle;
      final resizedKey = await const ResizeImage(
        CachedNetworkImageProvider(url),
        width: 104,
      ).obtainKey(ImageConfiguration.empty);
      final cache = PaintingBinding.instance.imageCache
        ..putIfAbsent(
          const CachedNetworkImageProvider(url),
          () => OneFrameImageStreamCompleter(Future.value(ImageInfo(image: image.clone()))),
        )
        ..putIfAbsent(resizedKey, () => OneFrameImageStreamCompleter(Future.value(ImageInfo(image: image.clone()))));
      addTearDown(() {
        cache
          ..clear()
          ..clearLiveImages();
      });
      final router = AppRouter(AppLogger.logger);
      addTearDown(router.dispose);
      final pending = Completer<Result<AnimeScreenData, Failure>>();
      final result = await const FakeAnimeScreenRepository().getAnime(id: 1, slug: '1-anime');
      const detailUrl = 'https://fixture.test/detail-poster.png';
      final pendingImage = Completer<ImageInfo>();
      if (!earlyResponse) {
        cache.putIfAbsent(
          const CachedNetworkImageProvider(detailUrl),
          () => OneFrameImageStreamCompleter(pendingImage.future),
        );
      }
      final detailResult = earlyResponse
          ? result
          : result.when(
              failure: Result<AnimeScreenData, Failure>.failure,
              success: (data) => Result<AnimeScreenData, Failure>.success(
                AnimeScreenData(
                  details: AnimeDetails(
                    id: 1,
                    slug: '1-anime',
                    title: 'Аниме',
                    genres: data.details.genres,
                    isOngoing: data.details.isOngoing,
                    posterUri: Uri.parse(detailUrl),
                  ),
                  episodes: data.episodes,
                ),
              ),
            );
      final summary = AnimeSummary(id: 1, slug: '1-anime', title: 'Аниме', posterUri: Uri.parse(url));
      await pumpTvApp(
        tester,
        MaterialApp.router(routerConfig: router.router, theme: AppTheme.darkTheme),
        wrapInScaffold: false,
        overrides: [
          authAccessProvider.overrideWithValue(const AuthenticatedAccess('test')),
          favoritesAccountProvider.overrideWithValue('test'),
          catalogRepositoryProvider.overrideWithValue(
            FakeCatalogScreenRepository(
              load: (_) async => Result.success(AnimePage(items: [summary], page: 1, hasNext: false)),
            ),
          ),
          animeRepositoryProvider.overrideWithValue(FakeAnimeScreenRepository(load: (_, _) => pending.future)),
        ],
      );
      await settle();
      void expectPoster() {
        final visibleImages = tester.widgetList<RawImage>(find.byType(RawImage));
        expect(visibleImages.any((raw) => raw.image?.isCloneOf(image) ?? false), isTrue);
      }

      expectPoster();
      await tester.tap(find.byType(AnimeCard).first);
      await tester.pump();
      for (var frame = 0; frame < 20; frame++) {
        if (earlyResponse && frame == 3) {
          pending.complete(detailResult);
        }
        await tester.pump(const Duration(milliseconds: 16));
        expect(find.byType(AnimeHero), findsNothing);
      }
      if (!earlyResponse) {
        expect(find.byType(AnimeSkeleton), findsOneWidget);
        pending.complete(detailResult);
      }
      for (var frame = 0; frame < 3; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(find.byType(AnimeHero), findsNothing);
      }
      await settle();
      expect(find.byType(AnimeHero), findsNothing);
      router.router.pop();
      await tester.pump();
      for (var frame = 0; frame < 15; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      await settle();
      expectPoster();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
