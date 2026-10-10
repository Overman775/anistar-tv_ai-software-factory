import 'package:anistar_tv/packages/features/anime/anime_providers.dart';
import 'package:anistar_tv/packages/features/anime/presentation/screens/anime_screen.dart';
import 'package:anistar_tv/packages/features/anime/presentation/widgets/anime_hero.dart';
import 'package:anistar_tv/packages/features/anime/presentation/widgets/episode_card.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../../../mocks/features/anime/fake_anime_screen_repository.dart';
import '../../../../../support/test_app.dart';

void main() {
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
