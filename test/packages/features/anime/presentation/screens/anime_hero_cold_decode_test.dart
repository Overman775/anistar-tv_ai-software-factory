import 'dart:async';
import 'dart:ui' as ui;

import 'package:anistar_tv/packages/features/anime/anime_providers.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_details.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_episode.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_screen_data.dart';
import 'package:anistar_tv/packages/features/anime/presentation/screens/anime_screen.dart';
import 'package:anistar_tv/packages/features/auth/auth_providers.dart';
import 'package:app_logging/app_logging.dart';
import 'package:app_logging/providers.dart';
// This route-level regression controls the first image decode.
// ignore: depend_on_referenced_packages
import 'package:cached_network_image/cached_network_image.dart';
import 'package:core/data.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../../../mocks/features/anime/fake_anime_screen_repository.dart';
import '../../../../../support/test_app.dart';

const _sourceUrl = 'https://fixture.test/source.png';
const _replacementUrl = 'https://fixture.test/replacement.png';
const _captureKey = ValueKey<String>('anime-hero-capture');
const _sourceColor = Color(0xff2458d3);
const _replacementColor = Color(0xffc2363e);

void main() {
  testWidgets('Hero route keeps source poster pixels until a cold replacement decodes', (tester) async {
    final pendingDetails = Completer<Result<AnimeScreenData, Failure>>();
    final pendingReplacement = Completer<ImageInfo>();
    final source = await _solidTestImage(tester, _sourceColor);
    final replacement = await _solidTestImage(tester, _replacementColor);
    _installImages(source: source, replacement: pendingReplacement.future);
    await _pumpRoute(tester, pendingDetails.future);

    await _openDetails(tester);
    await _expectPosterPixel(tester, _sourceColor);
    pendingDetails.complete(Result.success(_readyData()));
    for (var frame = 0; frame < 8; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      await _expectPosterPixel(tester, _sourceColor);
    }
    pendingReplacement.complete(ImageInfo(image: replacement));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 320));
    await _expectPosterPixel(tester, _replacementColor);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Hero route keeps source poster pixels when the cold replacement fails', (tester) async {
    final pendingDetails = Completer<Result<AnimeScreenData, Failure>>();
    final pendingReplacement = Completer<ImageInfo>();
    final source = await _solidTestImage(tester, _sourceColor);
    final reportedErrors = <Object>[];
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) => reportedErrors.add(details.exception);
    addTearDown(() => FlutterError.onError = previousOnError);
    _installImages(source: source, replacement: pendingReplacement.future);
    await _pumpRoute(tester, pendingDetails.future);

    await _openDetails(tester);
    pendingDetails.complete(Result.success(_readyData()));
    await tester.pump();
    await _expectPosterPixel(tester, _sourceColor);
    pendingReplacement.completeError(StateError('replacement unavailable'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 320));
    await _expectPosterPixel(tester, _sourceColor);
    expect(reportedErrors.whereType<StateError>(), isNotEmpty);
  });

  testWidgets('back during a cold detail load retains the source route and ignores the late result', (tester) async {
    final pendingDetails = Completer<Result<AnimeScreenData, Failure>>();
    final source = await _solidTestImage(tester, _sourceColor);
    _installImages(
      source: source,
      replacement: Future<ImageInfo>.value(ImageInfo(image: source)),
    );
    await _pumpRoute(tester, pendingDetails.future);

    await _openDetails(tester);
    Navigator.of(tester.element(find.byType(AnimeScreen))).pop();
    await tester.pumpAndSettle();
    pendingDetails.complete(Result.success(_readyData()));
    await tester.pump(const Duration(milliseconds: 32));
    expect(find.byType(AnimeScreen), findsNothing);
    await _expectPosterPixel(tester, _sourceColor);
    expect(tester.takeException(), isNull);
  });
}

void _installImages({required ui.Image source, required Future<ImageInfo> replacement}) {
  final cache = PaintingBinding.instance.imageCache
    ..clear()
    ..clearLiveImages()
    ..putIfAbsent(
      const CachedNetworkImageProvider(_sourceUrl),
      () => OneFrameImageStreamCompleter(Future<ImageInfo>.value(ImageInfo(image: source))),
    )
    ..putIfAbsent(const CachedNetworkImageProvider(_replacementUrl), () => OneFrameImageStreamCompleter(replacement));
  addTearDown(() {
    cache
      ..clear()
      ..clearLiveImages();
  });
}

Future<void> _pumpRoute(WidgetTester tester, Future<Result<AnimeScreenData, Failure>> details) async {
  setTvView(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        loggerProvider.overrideWithValue(AppLogger.logger),
        authAccessProvider.overrideWithValue(const AnonymousAccess()),
        animeRepositoryProvider.overrideWithValue(FakeAnimeScreenRepository(load: (_, _) => details)),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        builder: (context, child) => RepaintBoundary(key: _captureKey, child: child),
        home: const AnimeHeroColdDecodeTest(),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 32));
}

Future<void> _openDetails(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey<String>('open-anime-details')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 320));
}

Future<void> _expectPosterPixel(WidgetTester tester, Color expected) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_captureKey));
  final hero = find.byType(TvPosterHero).last;
  final point = tester.getCenter(hero);
  final actual = await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData();
    final width = image.width;
    final height = image.height;
    image.dispose();
    final data = bytes ?? (throw StateError('Screenshot bytes are unavailable'));
    final x = point.dx.round().clamp(0, width - 1);
    final y = point.dy.round().clamp(0, height - 1);
    final offset = (y * width + x) * 4;

    return Color.fromARGB(
      data.getUint8(offset + 3),
      data.getUint8(offset),
      data.getUint8(offset + 1),
      data.getUint8(offset + 2),
    );
  });
  final visibleColor = actual ?? (throw StateError('Screenshot is unavailable'));

  const colorTolerance = 2 / 255;
  final redDifference = (visibleColor.r - expected.r).abs();
  final greenDifference = (visibleColor.g - expected.g).abs();
  final blueDifference = (visibleColor.b - expected.b).abs();
  final withinTolerance = lessThanOrEqualTo(colorTolerance);
  expect(redDifference, withinTolerance);
  expect(greenDifference, withinTolerance);
  expect(blueDifference, withinTolerance);
}

AnimeScreenData _readyData() => AnimeScreenData(
  details: AnimeDetails(
    id: 1,
    slug: 'details',
    title: 'Детали',
    genres: const [],
    isOngoing: false,
    posterUri: Uri.parse(_replacementUrl),
  ),
  episodes: const [AnimeEpisode(number: 1, title: 'Первая')],
);

Future<ui.Image> _solidTestImage(WidgetTester tester, Color color) =>
    tester.runAsync(() => _solidImage(color)).then((image) => image ?? (throw StateError('Image is unavailable')));

Future<ui.Image> _solidImage(Color color) async {
  final recorder = ui.PictureRecorder();
  _drawSolidImage(recorder, color);
  final picture = recorder.endRecording();
  final image = await picture.toImage(8, 8);
  picture.dispose();

  return image;
}

void _drawSolidImage(ui.PictureRecorder recorder, Color color) {
  final canvas = ui.Canvas(recorder);
  final paint = ui.Paint()..color = color;
  canvas.drawRect(const ui.Rect.fromLTWH(0, 0, 8, 8), paint);
}

class AnimeHeroColdDecodeTest extends StatelessWidget {
  const AnimeHeroColdDecodeTest({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: SizedBox(
        width: 160,
        child: MediaCard(
          key: const ValueKey<String>('open-anime-details'),
          label: 'Детали',
          imageUrl: _sourceUrl,
          heroTag: 'anime-poster-1',
          onPressed: () => Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => AnimeScreen(
                animeId: 1,
                slug: 'details',
                fallbackTitle: 'Детали',
                fallbackPosterUri: Uri(scheme: 'https', host: 'fixture.test', path: '/source.png'),
                onEpisodeTap: _unexpectedEpisode,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void _unexpectedEpisode(AnimeEpisode episode) => fail('Unexpected episode ${episode.number}');
