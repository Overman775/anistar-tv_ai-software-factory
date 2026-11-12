import 'dart:async';
import 'dart:ui' as ui;

import 'package:anistar_tv/packages/features/anime/anime_providers.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_details.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_episode.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_screen_data.dart';
import 'package:anistar_tv/packages/features/anime/presentation/screens/anime_screen.dart';
import 'package:anistar_tv/packages/features/anime/presentation/widgets/anime_hero.dart';
import 'package:anistar_tv/packages/features/anime/presentation/widgets/episode_card.dart';
import 'package:anistar_tv/packages/features/anime/presentation/widgets/mobile_anime_poster_header.dart';
// Seed the UI kit image provider at its actual decode size.
// ignore: depend_on_referenced_packages
import 'package:cached_network_image/cached_network_image.dart';
import 'package:core/data.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../../../mocks/features/anime/fake_anime_screen_repository.dart';
import '../../../../../support/test_app.dart';

void main() {
  for (final mobile in [false, true]) {
    for (final fails in [false, true]) {
      testWidgets('${mobile ? 'mobile' : 'TV'} poster uses fallback and primary natural ratios failure=$fails', (
        tester,
      ) async {
        const source = 'https://fixture.test/source-ratio.png';
        const primary = 'https://fixture.test/primary-ratio.png';
        final images = await tester.runAsync(() async {
          Future<ui.Image> make(int width, int height) async {
            final recorder = ui.PictureRecorder();
            ui.Canvas(recorder).drawColor(const ui.Color(0xffaa22bb), ui.BlendMode.src);
            final picture = recorder.endRecording();
            final image = await picture.toImage(width, height);
            picture.dispose();
            return image;
          }

          return [await make(400, 300), await make(300, 300)];
        });
        final decoded = images ?? (throw StateError('Fixture decode did not complete'));
        final fallback = decoded[0];
        final square = decoded[1];
        final pending = Completer<ImageInfo>();
        final cache = PaintingBinding.instance.imageCache;
        final width = mobile ? 240 : 180;
        final sourceKey = await ResizeImage(
          const CachedNetworkImageProvider(source),
          width: width,
        ).obtainKey(ImageConfiguration.empty);
        final primaryKey = await ResizeImage(
          const CachedNetworkImageProvider(primary),
          width: width,
        ).obtainKey(ImageConfiguration.empty);
        cache
          ..putIfAbsent(sourceKey, () => OneFrameImageStreamCompleter(Future.value(ImageInfo(image: fallback))))
          ..putIfAbsent(primaryKey, () => OneFrameImageStreamCompleter(pending.future));
        addTearDown(() {
          cache
            ..clear()
            ..clearLiveImages();
        });
        final poster = SizedBox(
          width: 180,
          child: AnimeDetailsPoster(
            title: 'Постер',
            posterUri: Uri.parse(primary),
            fallbackPosterUri: Uri.parse(source),
            maxWidth: 180,
          ),
        );
        if (mobile) {
          await pumpMobileApp(
            tester,
            SingleChildScrollView(
              child: MobileAnimePosterHeader(
                title: 'Постер',
                posterUri: Uri.parse(primary),
                fallbackPosterUri: Uri.parse(source),
                metadata: const Text('Метаданные'),
              ),
            ),
          );
        } else {
          await pumpTvApp(tester, poster);
        }
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        final fallbackImage = find.byWidgetPredicate(
          (widget) => widget is RawImage && (widget.image?.isCloneOf(fallback) ?? false),
        );
        expect(fallbackImage, findsOneWidget);
        final fallbackSize = tester.getSize(fallbackImage);
        expect(fallbackSize.width / fallbackSize.height, closeTo(4 / 3, 0.01));
        if (fails) {
          pending.completeError(StateError('fixture image failure'));
        } else {
          pending.complete(ImageInfo(image: square));
        }
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        final primaryImage = find.byWidgetPredicate(
          (widget) => widget is RawImage && (widget.image?.isCloneOf(square) ?? false),
        );
        if (fails) {
          expect(primaryImage, findsNothing);
          expect(fallbackImage, findsOneWidget);
          expect(tester.getSize(fallbackImage).aspectRatio, closeTo(4 / 3, 0.01));
        } else {
          expect(primaryImage, findsOneWidget);
          expect(tester.getSize(primaryImage).aspectRatio, closeTo(1, 0.01));
        }
        if (mobile) {
          final image = fails ? fallbackImage : primaryImage;
          final height = fails ? 180.0 : 240.0;
          final portrait = tester.getRect(image);
          expect(portrait.size, Size(240, height));
          expect(portrait.center.dx, 195);
          tester.view.physicalSize = const Size(844, 390);
          await tester.pumpAndSettle();
          final landscape = tester.getRect(image);
          expect(landscape.size, Size(240, height));
          expect(landscape.center.dx, 422);
          expect(landscape.bottom, lessThan(tester.getTopLeft(find.text('Метаданные')).dy));
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('cold route shows the known title and no poster Hero on cold entry or success', (tester) async {
    final pending = Completer<Result<AnimeScreenData, Failure>>();
    await _openDetails(tester, pending.future);

    expect(find.text('Известное название'), findsOneWidget);
    expect(find.byType(TvSkeleton), findsOneWidget);
    expect(find.byType(Hero), findsNothing);
    expect(find.byType(EpisodeCard), findsNothing);

    pending.complete(Result.success(_readyData()));
    await tester.pumpAndSettle();
    expect(find.text('Полное название'), findsOneWidget);
    expect(find.byType(TvSkeleton), findsNothing);
    expect(find.byType(Hero), findsNothing);
    expect(find.byType(AnimeHero), findsNothing);
    expect(find.byType(EpisodeCard), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final mobile in [false, true]) {
    testWidgets('${mobile ? 'mobile' : 'TV'} unavailable poster keeps bounded 2:3 geometry', (tester) async {
      const poster = SizedBox(
        width: 180,
        child: AnimeDetailsPoster(title: 'Постер', posterUri: null, fallbackPosterUri: null, maxWidth: 180),
      );
      if (mobile) {
        await pumpMobileApp(tester, poster);
      } else {
        await pumpTvApp(tester, poster);
      }
      await tester.pump();
      final size = tester.getSize(find.byType(AnimeDetailsPoster));
      expect(size.width, 180);
      expect(size.aspectRatio, closeTo(2 / 3, 0.01));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('first Back closes details and second Back returns to the source', (tester) async {
    await _openDetails(tester, Future.value(Result.success(_readyData())));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(tester.widget<AnimeDisclosure>(find.byType(AnimeDisclosure)).expanded, isTrue);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(AnimeScreen), findsOneWidget);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'Подробнее');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(AnimeScreen), findsNothing);
    expect(find.text('Исходный каталог').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Back during a cold detail load returns to the source and ignores the late result', (tester) async {
    final pending = Completer<Result<AnimeScreenData, Failure>>();
    await _openDetails(tester, pending.future);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    pending.complete(Result.success(_readyData()));
    await tester.pump();
    expect(find.byType(AnimeScreen), findsNothing);
    expect(find.text('Исходный каталог').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _openDetails(WidgetTester tester, Future<Result<AnimeScreenData, Failure>> response) async {
  await pumpTvApp(
    tester,
    Builder(
      builder: (context) => AppButton(
        label: 'Исходный каталог',
        onPressed: () => unawaited(
          Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => AnimeScreen(
                animeId: 1,
                slug: 'details',
                fallbackTitle: 'Известное название',
                fallbackPosterUri: Uri.parse('https://fixture.test/source.png'),
                onEpisodeTap: (episode) => fail('Unexpected episode ${episode.number}'),
              ),
            ),
          ),
        ),
      ),
    ),
    disableAnimations: true,
    overrides: [animeRepositoryProvider.overrideWithValue(FakeAnimeScreenRepository(load: (_, _) => response))],
  );
  await tester.tap(find.text('Исходный каталог'));
  await tester.pumpAndSettle();
}

AnimeScreenData _readyData() => AnimeScreenData(
  details: AnimeDetails(
    id: 1,
    slug: 'details',
    title: 'Полное название',
    genres: const [],
    isOngoing: false,
    posterUri: Uri.parse('https://fixture.test/replacement.png'),
  ),
  episodes: const [AnimeEpisode(number: 1, title: 'Первая')],
);
