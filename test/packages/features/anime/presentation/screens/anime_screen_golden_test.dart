import 'dart:async';

import 'package:anistar_tv/packages/features/anime/anime_providers.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_details.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_screen_data.dart';
import 'package:anistar_tv/packages/features/anime/presentation/screens/anime_screen.dart';
import 'package:core/data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../mocks/features/anime/fake_anime_screen_repository.dart';
import '../../../../../support/test_app.dart';

void main() {
  for (final (name, size) in [('compact', compactTvSize), ('wide', wideTvSize)]) {
    for (final loading in [true, false]) {
      testWidgets('anime ${loading ? 'loading' : 'long content'} at $name viewport', (tester) async {
        final pending = Completer<Result<AnimeScreenData, Failure>>();
        final initial = (await const FakeAnimeScreenRepository().getAnime(
          id: 1,
          slug: 'test',
        )).when(failure: (failure) => throw failure, success: (data) => data);
        final data = AnimeScreenData(
          details: AnimeDetails(
            id: 1,
            slug: 'test',
            title: 'Пожалуйста, простите моих младших братьев / Please Forgive My Younger Brothers',
            genres: const ['Комедия', 'Повседневность', 'Романтика'],
            isOngoing: true,
            posterUri: Uri(),
            isFavorite: false,
            year: '2026',
            seriesInfo: '14 серий',
            voiceover: 'Озвучивание: AniStar',
            description: List.filled(8, 'История о семье, дружбе и неожиданных приключениях.').join(' '),
          ),
          episodes: initial.episodes,
        );
        await pumpTvApp(
          tester,
          MediaQuery(
            data: MediaQueryData(size: size, disableAnimations: true),
            child: AnimeScreen(
              animeId: 1,
              slug: 'test',
              fallbackTitle: data.details.title,
              onEpisodeTap: (_) => fail('Unexpected episode activation'),
            ),
          ),
          size: size,
          wrapInScaffold: false,
          overrides: [
            animeRepositoryProvider.overrideWithValue(
              FakeAnimeScreenRepository(load: (_, _) => loading ? pending.future : Future.value(Result.success(data))),
            ),
          ],
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/anime_${loading ? 'loading' : 'ready'}_$name.png'),
        );
      }, tags: ['golden']);
    }
  }
}
