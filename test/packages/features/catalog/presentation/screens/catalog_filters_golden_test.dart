// Each snapshot captures a different screen and focus state.

import 'package:anistar_tv/packages/features/anime/anime_providers.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_details.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_episode.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_screen_data.dart';
import 'package:anistar_tv/packages/features/anime/presentation/screens/anime_screen.dart';
import 'package:anistar_tv/packages/features/auth/auth_providers.dart';
import 'package:anistar_tv/packages/features/catalog/catalog_providers.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/catalog_filter.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/screens/catalog_screen.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/screens/genres_screen.dart';
import 'package:anistar_tv/packages/features/favorites/favorites_providers.dart';
import 'package:core/data.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../mocks/features/anime/fake_anime_screen_repository.dart';
import '../../../../../mocks/features/catalog/fake_catalog_browse_repository.dart';
import '../../../../../mocks/features/catalog/fake_catalog_screen_repository.dart';
import '../../../../../support/test_app.dart';

void main() {
  final genres = [
    'Боевики',
    'Вампиры',
    'Детектив',
    'Драма',
    'История',
    'Киберпанк',
    'Комедия',
    'Махо-седзе',
    'Меха',
    'Пародии',
    'Сёнен',
    'Спорт',
    'Мистика',
    'Музыкальное',
    'Повседневность',
    'Приключения',
    'Романтика',
    'Сёдзе',
    'Сёнен-ай',
    'Триллер',
    'Ужасы',
    'Фантастика',
    'Фэнтези',
    'Школа',
    'Эччи',
  ];
  for (final (name, size) in [('compact', compactTvSize), ('wide', wideTvSize)]) {
    testWidgets('genre picker and filtered catalog at $name', (tester) async {
      final repository = FakeCatalogBrowseRepository(
        genres: () async => Result.success([
          for (var i = 0; i < genres.length; i++) CatalogFilter(label: genres[i], path: '/genre-$i/'),
        ]),
        load: (_, page) => const FakeCatalogScreenRepository().getPage(page),
      );
      final overrides = [catalogBrowseRepositoryProvider.overrideWithValue(repository)];
      await pumpTvApp(
        tester,
        GenresScreen(onSelected: (_) => fail('Unexpected selection')),
        size: size,
        wrapInScaffold: false,
        overrides: overrides,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/genres_$name.png'));
      await pumpTvApp(
        tester,
        CatalogScreen(
          filter: comedyFilter,
          onAnimeTap: (_) => fail('Unexpected selection'),
          onBack: () => fail('Unexpected Back'),
          onOpenGenres: () => fail('Unexpected genres'),
        ),
        size: size,
        wrapInScaffold: false,
        overrides: overrides,
      );
      await tester.pumpAndSettle();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/filtered_catalog_$name.png'));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/catalog_sort_$name.png'));
    }, tags: ['golden']);

    testWidgets('anime filter focus at $name', (tester) async {
      await pumpTvApp(
        tester,
        AnimeScreen(
          animeId: 1,
          slug: '1-test',
          fallbackTitle: 'Карточка аниме',
          onEpisodeTap: (_) => fail('Unexpected episode'),
          onFilterTap: (_) => fail('Unexpected filter'),
        ),
        size: size,
        wrapInScaffold: false,
        overrides: [
          authAccessProvider.overrideWithValue(const AuthenticatedAccess('test')),
          favoritesAccountProvider.overrideWithValue('test'),
          animeRepositoryProvider.overrideWithValue(
            FakeAnimeScreenRepository(
              load: (_, _) async => Result.success(
                AnimeScreenData(
                  details: AnimeDetails(
                    id: 1,
                    slug: '1-test',
                    title: 'История о семье, дружбе и приключениях',
                    genres: const ['Комедия'],
                    isOngoing: true,
                    posterUri: Uri(),
                    year: '2026',
                    description:
                        'Неожиданная встреча меняет жизнь героев. Вместе они отправляются навстречу приключениям.',
                    filters: const [
                      ongoingFilter,
                      CatalogFilter(label: 'Аниме', path: '/anime/'),
                      comedyFilter,
                      CatalogFilter(label: 'Повседневность', path: '/anime/everyday-life/'),
                    ],
                  ),
                  episodes: const [AnimeEpisode(number: 1, title: 'Серия 1')],
                ),
              ),
            ),
          ),
        ],
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/anime_filter_focus_$name.png'));
    }, tags: ['golden']);
  }
}
