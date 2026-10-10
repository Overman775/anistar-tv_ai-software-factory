import 'package:anistar_tv/packages/features/anime/anime_providers.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_details.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_episode.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_screen_data.dart';
import 'package:anistar_tv/packages/features/anime/presentation/screens/anime_screen.dart';
import 'package:anistar_tv/packages/features/anime/presentation/widgets/anime_hero.dart';
import 'package:anistar_tv/packages/features/anime/presentation/widgets/episode_card.dart';
import 'package:core/data.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../../../mocks/features/anime/fake_anime_screen_repository.dart';
import '../../../../../support/test_app.dart';

// Focus is mutable: each assertion reads the result of the preceding key event.
// ignore_for_file: prefer-moving-to-variable

void main() {
  testWidgets('poster layout enters the latest episode and restores visible hero focus from a long grid', (
    tester,
  ) async {
    final key = tester.sendKeyEvent;
    final settle = tester.pumpAndSettle;
    String? focusedLabel() => FocusManager.instance.primaryFocus?.debugLabel;
    int? opened;
    await pumpTvApp(
      tester,
      AnimeScreen(
        animeId: 1,
        slug: 'anime',
        fallbackTitle: 'Аниме',
        onEpisodeTap: (episode) => opened = episode.number,
      ),
      size: wideTvSize,
      wrapInScaffold: false,
      overrides: [
        animeRepositoryProvider.overrideWithValue(
          FakeAnimeScreenRepository(
            load: (_, _) async => Result.success(
              AnimeScreenData(
                details: AnimeDetails(
                  id: 1,
                  slug: 'anime',
                  title: 'Аниме',
                  genres: const [],
                  isOngoing: false,
                  posterUri: Uri.parse('https://image.test/poster.jpg'),
                  isFavorite: false,
                ),
                episodes: List.generate(32, (index) => AnimeEpisode(number: index + 1, title: 'Серия ${index + 1}')),
              ),
            ),
          ),
        ),
      ],
    );
    await settle();
    await key(LogicalKeyboardKey.arrowRight);
    await settle();
    expect(focusedLabel(), 'Избранное сериала');
    await key(LogicalKeyboardKey.arrowDown);
    await settle();
    await key(LogicalKeyboardKey.select);
    expect(opened, 32);
    for (var row = 0; row < 5; row++) {
      await key(LogicalKeyboardKey.arrowDown);
      await settle();
    }
    final focus = FocusManager.instance.primaryFocus;
    final cardContext = focus?.context?.findAncestorWidgetOfExactType<EpisodeCard>();
    expect(cardContext?.episode.number, lessThan(32));
    for (var row = 0; row < 6; row++) {
      await key(LogicalKeyboardKey.arrowUp);
      await settle();
    }
    expect(focusedLabel(), 'Смотреть первую серию');
    final scroll = tester.widget<CustomScrollView>(find.byType(CustomScrollView)).controller;
    expect(scroll?.offset, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('changing route parameters loads the new anime in the existing State', (tester) async {
    final requests = <int>[];
    final repository = FakeAnimeScreenRepository(
      load: (id, slug) {
        requests.add(id);

        return const FakeAnimeScreenRepository().getAnime(id: id, slug: slug);
      },
    );
    AnimeScreen screen(int id) => AnimeScreen(
      animeId: id,
      slug: '$id-anime',
      fallbackTitle: 'Аниме $id',
      onEpisodeTap: (episode) => expect(episode.number, isPositive),
    );
    final pumpAndSettle = tester.pumpAndSettle;
    final screenFinder = find.byType(AnimeScreen);
    final stateOf = tester.state;
    final overrides = [animeRepositoryProvider.overrideWithValue(repository)];
    await pumpTvApp(tester, screen(1), wrapInScaffold: false, overrides: overrides);
    await pumpAndSettle();
    final state = stateOf(screenFinder);
    await pumpTvApp(tester, screen(2), wrapInScaffold: false, overrides: overrides);
    await pumpAndSettle();
    expect(stateOf(screenFinder), same(state));
    expect(requests, [1, 2]);
    expect(find.byType(AnimeHero), findsOneWidget);
  });

  testWidgets('keeps the hero action visible and moves focus to episodes on a compact TV', (tester) async {
    int? openedEpisode;
    await pumpTvApp(
      tester,
      AnimeScreen(
        animeId: 1,
        slug: 'test-anime',
        fallbackTitle: 'Тестовое аниме',
        onEpisodeTap: (episode) => openedEpisode = episode.number,
      ),
      wrapInScaffold: false,
      overrides: [animeRepositoryProvider.overrideWithValue(const FakeAnimeScreenRepository())],
    );
    final pumpAndSettle = tester.pumpAndSettle;
    final sendKeyEvent = tester.sendKeyEvent;
    await pumpAndSettle();
    final playButton = find.widgetWithText(FilledButton, 'Смотреть серию 1');
    expect(playButton, findsOneWidget);
    expect(tester.getBottomRight(playButton).dy, lessThanOrEqualTo(540));
    expect(tester.takeException(), isNull);
    await sendKeyEvent(LogicalKeyboardKey.select);
    expect(openedEpisode, 1);
    await sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await pumpAndSettle();
    expect(tester.widgetList<EpisodeCard>(find.byType(EpisodeCard)).map((card) => card.episode.number), [3, 2, 1]);
    await sendKeyEvent(LogicalKeyboardKey.select);
    expect(openedEpisode, 3);
    await sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(AppMotion.fast);
    await sendKeyEvent(LogicalKeyboardKey.select);
    expect(openedEpisode, 2);
  });
}
