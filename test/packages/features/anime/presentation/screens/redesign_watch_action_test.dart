import 'package:anistar_tv/packages/features/anime/anime_providers.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_details.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_episode.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_part.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_screen_data.dart';
import 'package:anistar_tv/packages/features/anime/presentation/screens/anime_screen.dart';
import 'package:anistar_tv/packages/features/anime/presentation/widgets/anime_watch_order.dart';
import 'package:anistar_tv/packages/features/anime/presentation/widgets/episode_card.dart';
import 'package:core/data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../../../mocks/features/anime/fake_anime_screen_repository.dart';
import '../../../../../support/test_app.dart';

void main() {
  for (final mobile in [false, true]) {
    for (final (numbers, watched, target) in <(List<int>, Set<int>, int)>[
      ([1, 2, 3], {}, 1),
      ([1, 2, 3, 4, 5], {2, 3}, 4),
      ([1, 3, 5], {3}, 5),
      ([1, 2, 3], {1, 2, 3}, 1),
      ([1, 3, 5], {5}, 1),
    ]) {
      testWidgets('${mobile ? 'mobile' : 'TV'} selected episode $target opens independently of watched $watched', (
        tester,
      ) async {
        final opened = <int>[];
        final settle = tester.pumpAndSettle;
        final data = AnimeScreenData(
          details: AnimeDetails(
            id: 1,
            slug: '1-fixture',
            title: 'Fixture',
            genres: const [],
            isOngoing: false,
            isFavorite: false,
          ),
          episodes: numbers
              .map(
                (number) => AnimeEpisode(number: number, title: 'Серия $number', isWatched: watched.contains(number)),
              )
              .toList(),
        );
        final screen = AnimeScreen(
          animeId: 1,
          slug: '1-fixture',
          fallbackTitle: 'Fixture',
          onEpisodeTap: (episode) => opened.add(episode.number),
        );
        final overrides = [
          animeRepositoryProvider.overrideWithValue(
            FakeAnimeScreenRepository(load: (_, _) async => Result.success(data)),
          ),
        ];
        if (mobile) {
          await pumpMobileApp(tester, screen, wrapInScaffold: false, overrides: overrides);
        } else {
          await pumpTvApp(tester, screen, wrapInScaffold: false, overrides: overrides);
        }
        await settle();
        final action = find.byWidgetPredicate((widget) => widget is EpisodeCard && widget.episode.number == target);
        await tester.ensureVisible(action);
        await settle();
        await tester.tap(action);
        expect(opened, [target]);
        final card = tester.widget<EpisodeCard>(action);
        expect(card.episode.isWatched, watched.contains(target));
        expect(find.widgetWithText(AppButton, 'Смотреть серию $target'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('watch-order keeps full labels and current or unsafe entries do not open another route', (tester) async {
    final opened = <AnimePart>[];
    final settle = tester.pumpAndSettle;
    final parts = [
      AnimePart(
        label: 'Текущий полный сезон',
        uri: Uri.parse('https://fixture.test/1-current.html'),
        id: 1,
        slug: '1-current',
      ),
      AnimePart(
        label: 'Следующий полный сезон',
        uri: Uri.parse('https://fixture.test/2-next.html'),
        id: 2,
        slug: '2-next',
      ),
      AnimePart(label: 'Неподдерживаемая часть', uri: Uri.parse('https://foreign.test/3-other.html')),
    ];
    await pumpTvApp(
      tester,
      SingleChildScrollView(
        child: AnimeWatchOrder(parts: parts, currentId: 1, onSelected: opened.add),
      ),
    );
    await settle();
    expect(find.text('Текущий полный сезон, Открыто'), findsOneWidget);
    await tester.tap(find.text('Текущий полный сезон, Открыто'));
    final afterCurrent = opened.length;
    await tester.tap(find.text('Неподдерживаемая часть'));
    final afterUnsupported = opened.length;
    expect((afterCurrent, afterUnsupported), (0, 0));
    await tester.tap(find.text('Следующий полный сезон'));
    expect(opened, [same(parts[1])]);
    expect(tester.takeException(), isNull);
  });
}
