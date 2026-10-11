import 'dart:async';
import 'dart:ui' as ui;

import 'package:anistar_tv/app/app_navigation_page.dart';
import 'package:anistar_tv/app/app_router.dart';
import 'package:anistar_tv/packages/features/anime/anime_providers.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_details.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_screen_data.dart';
import 'package:anistar_tv/packages/features/anime/presentation/widgets/anime_hero.dart';
import 'package:anistar_tv/packages/features/anime/presentation/widgets/anime_skeleton.dart';
import 'package:anistar_tv/packages/features/catalog/catalog_providers.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/anime_page.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/anime_summary.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/widgets/anime_card.dart';
import 'package:anistar_tv/packages/features/favorites/favorites_providers.dart';
import 'package:app_logging/app_logging.dart';
// These regressions seed the UI kit's real cached image provider.
// ignore: depend_on_referenced_packages
import 'package:cached_network_image/cached_network_image.dart';
import 'package:core/data.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../mocks/features/anime/fake_anime_screen_repository.dart';
import '../mocks/features/catalog/fake_catalog_screen_repository.dart';
import '../mocks/features/favorites/fake_favorites_repository.dart';
import '../support/test_app.dart';

void main() {
  for (final favorites in [false, true]) {
    testWidgets('poster flies from ${favorites ? 'favorites' : 'home'} before details load and returns on Back', (
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
      // A real Hero flight replaces the source image with its placeholder and
      // renders an image in the navigator overlay, even before HTTP completes.
      expect(ModalRoute.of(tester.element(card))?.offstage, isFalse);
      expect(imagesInCard, findsNothing);
      expect(find.byType(AppNetworkImage), findsWidgets);
      pending.complete(await const FakeAnimeScreenRepository().getAnime(id: 1, slug: '1-test'));
      await tester.pump();
      expect(heroFinder, findsNothing);
      await settle();
      expect(heroFinder, findsOneWidget);
      router.router.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(imagesInCard, findsNothing);
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
    testWidgets('decoded poster stays visible through flight and skeleton; early=$earlyResponse', (tester) async {
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
      final cache = PaintingBinding.instance.imageCache
        ..putIfAbsent(
          const CachedNetworkImageProvider(url),
          () => OneFrameImageStreamCompleter(Future.value(ImageInfo(image: image))),
        );
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
        expectPoster();
      }
      if (!earlyResponse) {
        expect(find.byType(AnimeSkeleton), findsOneWidget);
        pending.complete(detailResult);
      }
      for (var frame = 0; frame < 3; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        expectPoster();
      }
      await settle();
      expect(find.byType(AnimeHero), findsOneWidget);
      expectPoster();
      router.router.pop();
      await tester.pump();
      for (var frame = 0; frame < 15; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        expectPoster();
      }
      await settle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
