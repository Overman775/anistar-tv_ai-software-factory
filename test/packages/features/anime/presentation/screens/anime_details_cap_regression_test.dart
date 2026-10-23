import 'package:anistar_tv/packages/features/anime/anime_providers.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_details.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_episode.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_screen_data.dart';
import 'package:anistar_tv/packages/features/anime/presentation/screens/anime_screen.dart';
import 'package:anistar_tv/packages/features/anime/presentation/widgets/anime_detail_filter_actions.dart';
import 'package:anistar_tv/packages/features/anime/presentation/widgets/anime_detail_filter_groups.dart';
import 'package:anistar_tv/packages/features/auth/auth_providers.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/catalog_filter.dart';
import 'package:anistar_tv/packages/features/favorites/presentation/favorite_button.dart';
import 'package:core/data.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../../../mocks/features/anime/fake_anime_screen_repository.dart';
import '../../../../../support/test_app.dart';

void main() {
  test('metadata groups consume matching filters once and retain unmatched paths', () {
    const year = CatalogFilter(label: '2026', path: '/year/2026/');
    const comedy = CatalogFilter(label: 'Комедия', path: '/genre/comedy/');
    const fantasy = CatalogFilter(label: 'Фэнтези', path: '/genre/fantasy/');
    const director = CatalogFilter(label: 'Режиссёр: Наоко Ямада', path: '/director/yamada/');
    const studio = CatalogFilter(label: 'Студия Kyoto Animation', path: '/studio/kyoani/');
    final groups = AnimeDetailFilterGroups.fromDetails(
      AnimeDetails(
        id: 1,
        slug: 'details',
        title: 'Детали',
        genres: const ['Комедия', 'Фэнтези'],
        isOngoing: false,
        year: '2026',
        director: 'Наоко Ямада',
      ),
      const [year, comedy, fantasy, director, studio],
    );

    expect(groups.year, same(year));
    expect(groups.genres, [comedy, fantasy]);
    expect(groups.director, same(director));
    expect(groups.genreText, isEmpty);
    expect(groups.directorText, isNull);
    expect(groups.remaining, [studio]);
    expect(groups.indices, {year.path: 0, comedy.path: 1, fantasy.path: 2, director.path: 3, studio.path: 4});
  });

  testWidgets('metadata filters keep their source paths, icons, and unmatched category', (tester) async {
    const year = CatalogFilter(label: '2026', path: '/year/2026/');
    const comedy = CatalogFilter(label: 'Комедия', path: '/genre/comedy/');
    const director = CatalogFilter(label: 'Режиссёр: Наоко Ямада', path: '/director/yamada/');
    const studio = CatalogFilter(label: 'Студия Kyoto Animation', path: '/studio/kyoani/');
    CatalogFilter? selected;
    final focusNodes = <String, FocusNode>{};
    var focusedIndex = -1;
    final groups = AnimeDetailFilterGroups.fromDetails(
      AnimeDetails(
        id: 1,
        slug: 'details',
        title: 'Детали',
        genres: const ['Комедия'],
        isOngoing: false,
        year: '2026',
        director: 'Наоко Ямада',
      ),
      const [year, comedy, director, studio],
    );
    await pumpTvApp(
      tester,
      SingleChildScrollView(
        child: AnimeDetailFilterActions(
          groups: groups,
          focusNodes: focusNodes,
          onSelected: (filter) => selected = filter,
          onFocused: (index) => focusedIndex = index,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Жанры'), findsOneWidget);
    expect(find.text('Режиссёр'), findsOneWidget);
    expect(find.text('Категории'), findsOneWidget);
    expect(find.text('2026'), findsNothing);
    expect(find.text('Комедия'), findsOneWidget);
    expect(find.text('Режиссёр: Наоко Ямада'), findsOneWidget);
    expect(find.text('Студия Kyoto Animation'), findsOneWidget);
    expect(find.byType(AppIcon), findsNWidgets(3));
    await tester.tap(find.text('Комедия'));
    expect(selected, same(comedy));
    expect(focusedIndex, 1);
    expect(tester.takeException(), isNull);
  });

  for (final mobile in [false, true]) {
    testWidgets('${mobile ? 'mobile' : 'TV'} uses actual nonconsecutive episode count and compact episode cards', (
      tester,
    ) async {
      final pumpAndSettle = tester.pumpAndSettle;
      final opened = <int>[];
      final data = _detailsData(
        episodes: const [
          AnimeEpisode(number: 1, title: 'Первая'),
          AnimeEpisode(number: 3, title: 'Третья'),
          AnimeEpisode(number: 8, title: 'Восьмая'),
        ],
      );
      final screen = AnimeScreen(
        animeId: 1,
        slug: 'details',
        fallbackTitle: 'Детали',
        onEpisodeTap: (episode) => opened.add(episode.number),
      );
      final overrides = [
        authAccessProvider.overrideWithValue(const AnonymousAccess()),
        animeRepositoryProvider.overrideWithValue(
          FakeAnimeScreenRepository(load: (_, _) async => Result.success(data)),
        ),
      ];
      if (mobile) {
        await pumpMobileApp(tester, screen, textScale: 2, wrapInScaffold: false, overrides: overrides);
      } else {
        await pumpTvApp(tester, screen, wrapInScaffold: false, overrides: overrides);
      }
      await pumpAndSettle();

      expect(find.text('В списке: 3'), findsOneWidget);
      expect(find.byType(FavoriteButton), findsNothing);
      final episodeCards = tester
          .widgetList<MediaCard>(find.byType(MediaCard))
          .where((card) => card.variant == MediaCardVariant.episode);
      expect(episodeCards.map((card) => card.showEpisodeTrailing), everyElement(isFalse));
      if (mobile) {
        final firstEpisode = find.byKey(const ValueKey('mobile-episode-8'));
        final scrollable = find.byType(Scrollable).first;
        await tester.scrollUntilVisible(firstEpisode, 160, scrollable: scrollable);
        for (final number in [8, 3, 1]) {
          final row = find.byKey(ValueKey('mobile-episode-$number'));
          await tester.scrollUntilVisible(row, 160, scrollable: scrollable);
          expect(row, findsOneWidget);
        }
        await tester.scrollUntilVisible(firstEpisode, -160, scrollable: scrollable);
        await tester.tap(firstEpisode);
      } else {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await pumpAndSettle();
        final grid = tester.widget<SliverGrid>(find.byType(SliverGrid));
        expect((grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount).crossAxisCount, 3);
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
      }
      expect(opened, [8]);
      expect(tester.takeException(), isNull);
    });
  }

  for (final mobile in [false, true]) {
    testWidgets('${mobile ? 'mobile' : 'TV'} guest empty details hide favorite and expose retry fallback', (
      tester,
    ) async {
      const screen = AnimeScreen(
        animeId: 1,
        slug: 'details',
        fallbackTitle: 'Детали',
        onEpisodeTap: _unexpectedEpisode,
      );
      final overrides = [
        authAccessProvider.overrideWithValue(const AnonymousAccess()),
        animeRepositoryProvider.overrideWithValue(
          FakeAnimeScreenRepository(load: (_, _) async => Result.success(_detailsData())),
        ),
      ];
      if (mobile) {
        await pumpMobileApp(tester, screen, wrapInScaffold: false, overrides: overrides);
      } else {
        await pumpTvApp(tester, screen, wrapInScaffold: false, overrides: overrides);
      }
      await tester.pumpAndSettle();

      expect(find.text('В списке: 0'), findsOneWidget);
      expect(find.byType(FavoriteButton), findsNothing);
      expect(find.text('В избранное'), findsNothing);
      final retry = find.text('Обновить серии');
      if (mobile) {
        await tester.scrollUntilVisible(retry, 160, scrollable: find.byType(Scrollable).first);
        expect(retry.hitTestable(), findsOneWidget);
      } else {
        expect(FocusManager.instance.primaryFocus?.debugLabel, 'Обновить серии');
        expect(retry.hitTestable(), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }
}

AnimeScreenData _detailsData({List<AnimeEpisode> episodes = const []}) => AnimeScreenData(
  details: AnimeDetails(id: 1, slug: 'details', title: 'Детали', genres: const [], isOngoing: false),
  episodes: episodes,
);

void _unexpectedEpisode(AnimeEpisode episode) => fail('Unexpected episode ${episode.number}');
