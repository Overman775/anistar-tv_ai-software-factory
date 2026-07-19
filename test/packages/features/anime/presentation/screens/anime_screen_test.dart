import 'package:anistar_tv/app/app_providers.dart';
import 'package:anistar_tv/packages/core/domain/either.dart';
import 'package:anistar_tv/packages/core/domain/failure.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_details.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_episode.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_screen_data.dart';
import 'package:anistar_tv/packages/features/anime/domain/repositories/anime_repository.dart';
import 'package:anistar_tv/packages/features/anime/presentation/screens/anime_screen.dart';
import 'package:app_logger/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui_kit/ui_kit.dart';

void main() {
  testWidgets('keeps the hero action visible and moves focus to episodes on a compact TV', (tester) async {
    final view = tester.view;
    final pumpAndSettle = tester.pumpAndSettle;
    final sendKeyEvent = tester.sendKeyEvent;
    view
      ..physicalSize = const Size(960, 540)
      ..devicePixelRatio = 1;
    addTearDown(view.reset);
    int? openedEpisode;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          animeRepositoryProvider.overrideWithValue(const AnimeScreenTest()),
          loggerProvider.overrideWithValue(Logger(level: Level.off)),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: AnimeScreen(
            animeId: 1,
            slug: 'test-anime',
            fallbackTitle: 'Тестовое аниме',
            onEpisodeTap: (episode) => openedEpisode = episode.number,
          ),
        ),
      ),
    );
    await pumpAndSettle();

    final playButton = find.widgetWithText(FilledButton, 'Смотреть серию 1');
    expect(playButton, findsOneWidget);
    expect(tester.getBottomRight(playButton).dy, lessThanOrEqualTo(540));
    expect(tester.takeException(), isNull);
    await sendKeyEvent(LogicalKeyboardKey.select);
    expect(openedEpisode, 1);

    await sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await pumpAndSettle();
    await sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(AppMotion.fast);
    await sendKeyEvent(LogicalKeyboardKey.select);
    expect(openedEpisode, 2);
  });
}

final class AnimeScreenTest implements AnimeRepository {
  const AnimeScreenTest();

  @override
  Future<Either<Failure, AnimeScreenData>> getAnime({required int id, required String slug}) async => Either.right(
    AnimeScreenData(
      details: const AnimeDetails(
        id: 1,
        slug: 'test-anime',
        title: 'Тестовое аниме',
        genres: ['Приключения'],
        isOngoing: true,
        description: 'Короткое описание, которое должно оставаться видимым при открытии экрана.',
        seriesInfo: '3 серии',
        year: '2026',
      ),
      episodes: List.generate(
        3,
        (index) => AnimeEpisode(number: index + 1, title: 'Серия ${index + 1}'),
        growable: false,
      ),
    ),
  );
}
