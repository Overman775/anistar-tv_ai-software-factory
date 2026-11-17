import 'dart:async';

import 'package:anistar_tv/packages/features/anime/anime_providers.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_details.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_screen_data.dart';
import 'package:anistar_tv/packages/features/anime/presentation/screens/anime_screen.dart';
import 'package:anistar_tv/packages/features/auth/auth_providers.dart';
import 'package:anistar_tv/packages/features/favorites/favorites_providers.dart';
import 'package:core/data.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../../mocks/features/anime/fake_anime_screen_repository.dart';
import '../../../../../support/test_app.dart';

void main() {
  for (final loading in [true, false]) {
    for (final textScale in [GoldenTextScale.normal]) {
      testWidgets('anime ${loading ? 'loading' : 'long content'} at tv', (tester) async {
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
        await testScreenGolden(
          tester,
          'anime_${loading ? 'loading' : 'ready'}',
          textScale: textScale,
          screen: AnimeScreen(
            animeId: 1,
            slug: 'test',
            fallbackTitle: data.details.title,
            onEpisodeTap: (_) => fail('Unexpected episode activation'),
          ),
          wrapInScaffold: false,
          overrides: [
            authAccessProvider.overrideWithValue(const AuthenticatedAccess('test')),
            favoritesAccountProvider.overrideWithValue('test'),
            animeRepositoryProvider.overrideWithValue(
              FakeAnimeScreenRepository(load: (_, _) => loading ? pending.future : Future.value(Result.success(data))),
            ),
          ],
        );
      }, tags: ['golden']);
    }
  }
}
