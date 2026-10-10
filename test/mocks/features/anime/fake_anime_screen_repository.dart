import 'package:anistar_tv/packages/features/anime/domain/models/anime_details.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_episode.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_screen_data.dart';
import 'package:anistar_tv/packages/features/anime/domain/repositories/anime_repository.dart';
import 'package:core/data.dart';

final class FakeAnimeScreenRepository implements AnimeRepository {
  final Future<Result<AnimeScreenData, Failure>> Function(int, String)? load;

  const FakeAnimeScreenRepository({this.load});

  @override
  Future<Result<AnimeScreenData, Failure>> getAnime({required int id, required String slug}) async {
    final loader = load;
    if (loader != null) {
      return loader(id, slug);
    }

    return Result.success(
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
}
