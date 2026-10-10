import 'package:anistar/anistar.dart';
import 'package:core/data.dart';
import 'package:networking/networking.dart';

import '../../domain/models/anime_details.dart';
import '../../domain/models/anime_episode.dart';
import '../../domain/models/anime_screen_data.dart';
import '../../domain/repositories/anime_repository.dart';

final class AnistarAnimeRepository extends BaseRepository implements AnimeRepository {
  final AnistarSource _source;

  AnistarAnimeRepository(this._source, [super.logger]);

  @override
  Future<Result<AnimeScreenData, Failure>> getAnime({required int id, required String slug}) => makeApiCall(() async {
    // Future.wait preserves the first original failure for the repository
    // boundary; record.wait would wrap it in ParallelWaitError.
    final results = await Future.wait<Object>([_source.details(slug), _source.episodes(id)]);
    final detail = results[0] as DirectAnime;
    final episodes = results[1] as List<DirectEpisode>;
    if (detail.id != id) {
      throw const AnistarFailure(message: 'Адрес карточки не соответствует выбранному аниме.');
    }

    return AnimeScreenData(
      details: AnimeDetails(
        id: detail.id,
        isFavorite: detail.isFavorite,
        slug: detail.slug,
        title: detail.title,
        genres: detail.genres,
        isOngoing: detail.isOngoing,
        description: detail.description,
        posterUri: detail.posterUri,
        seriesInfo: detail.seriesInfo,
        voiceover: detail.voiceover,
        year: detail.year,
      ),
      episodes: episodes
          .map(
            (episode) => AnimeEpisode(
              number: episode.number,
              title: episode.title,
              previewUri: episode.previewUri,
              isWatched: episode.isWatched,
            ),
          )
          .toList(growable: false),
    );
  });
}
