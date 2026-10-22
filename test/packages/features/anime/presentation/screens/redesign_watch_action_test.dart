import 'package:anistar_tv/packages/features/anime/anime_providers.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_details.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_episode.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_part.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_screen_data.dart';
import 'package:anistar_tv/packages/features/anime/presentation/screens/anime_screen.dart';
import 'package:anistar_tv/packages/features/anime/presentation/widgets/anime_watch_order.dart';
import 'package:core/data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../../../mocks/features/anime/fake_anime_screen_repository.dart';
import '../../../../../support/test_app.dart';

void main() {
  for (final mobile in [false, true]) {
    for (final (numbers, watched, target, rewatch) in <(List<int>, Set<int>, int?, bool)>[
      ([1, 2, 3], {}, 1, false),
      ([1, 2, 3, 4, 5], {2, 3}, 4, false),
      ([1, 3, 5], {3}, 5, false),
      ([1, 2, 3], {1, 2, 3}, 1, true),
      ([1, 3, 5], {5}, 1, true),
      ([], {}, null, false),
    ]) {
      testWidgets('${mobile ? 'mobile' : 'TV'} watch uses $numbers after $watched', (tester) async {
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
        final label = switch (target) {
          null => 'Нет доступных серий',
          _ when rewatch => 'Посмотреть снова',
          _ => 'Смотреть серию $target',
        };
        final action = find.byWidgetPredicate((widget) => widget is AppButton && widget.label == label);
        if (target == null) {
          if (mobile) {
            expect(action, findsNothing);
            final explanation = find.textContaining('Серии не найдены');
            await tester.scrollUntilVisible(explanation, 250, scrollable: find.byType(Scrollable).first);
            expect(explanation, findsOneWidget);
          } else {
            expect(action, findsOneWidget);
            expect(tester.widget<AppButton>(action).enabled, isFalse);
          }
          expect(opened, isEmpty);
        } else {
          expect(action, findsOneWidget);
          await tester.ensureVisible(action);
          await settle();
          await tester.tap(action);
          expect(opened, [target]);
        }
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
