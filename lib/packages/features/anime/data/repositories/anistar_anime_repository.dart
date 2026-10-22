import 'package:anistar/anistar.dart';
import 'package:core/data.dart';
import 'package:networking/networking.dart';

import '../../../catalog/data/mapping/anistar_catalog_mapping.dart';
import '../../../common/data/anistar_errors.dart';
import '../../domain/models/anime_details.dart';
import '../../domain/models/anime_episode.dart';
import '../../domain/models/anime_part.dart';
import '../../domain/models/anime_screen_data.dart';
import '../../domain/repositories/anime_repository.dart';

final class AnistarAnimeRepository extends BaseRepository implements AnimeRepository {
  final AnistarClient _client;
  final bool Function() _canUseAccount;

  AnistarAnimeRepository(this._client, [super.logger, bool Function()? canUseAccount])
    : _canUseAccount = canUseAccount ?? (() => false);

  @override
  Future<Result<AnimeScreenData, Failure>> getAnime({required int id, required String slug}) => makeApiCall(
    () => mapAnistarErrors(() async {
      if (id <= 0) {
        throw const RequestFailure(message: 'Некорректный номер аниме.');
      }
      // Future.wait preserves the first original failure for the repository
      // boundary; record.wait would wrap it in ParallelWaitError.
      final results = await Future.wait<Object>([_client.details(slug), _client.episodes(id)]);
      final detail = results[0] as AnistarAnimeDetailsDto;
      final episodes = results[1] as List<AnistarEpisodeDto>;
      if (detail.id != id || detail.slug.isEmpty || detail.title.trim().isEmpty) {
        throw const RequestFailure(message: 'Адрес карточки не соответствует выбранному аниме.');
      }

      final numbers = <int>{};
      if (episodes.any((episode) => episode.number <= 0 || !numbers.add(episode.number))) {
        throw const RequestFailure(message: 'Некорректные номера серий.');
      }
      final ordered = episodes.toList()..sort((a, b) => a.number.compareTo(b.number));
      final rating = detail.rating;

      return AnimeScreenData(
        details: AnimeDetails(
          id: detail.id,
          isFavorite: _canUseAccount() ? detail.isFavorite : null,
          slug: detail.slug,
          title: detail.title,
          genres: detail.genres,
          filters: detail.filters.map(mapCatalogFilter).toList(growable: false),
          isOngoing: detail.isOngoing,
          description: detail.description,
          posterUri: detail.posterUri,
          seriesInfo: detail.seriesInfo,
          voiceover: detail.voiceover,
          year: detail.year,
          rating: rating != null && rating.isFinite && rating >= 0 && rating <= 10 ? rating : null,
          director: detail.director,
          updateMessage: detail.updateMessage,
          publicationDate: detail.publicationDate,
          parts: detail.parts
              .map((part) => AnimePart(label: part.label, uri: part.uri, id: part.id, slug: part.slug))
              .toList(growable: false),
        ),
        episodes: ordered
            .map(
              (episode) => AnimeEpisode(
                number: episode.number,
                title: episode.title,
                previewUri: episode.previewUri,
                isWatched: _canUseAccount() && episode.isWatched,
              ),
            )
            .toList(growable: false),
      );
    }),
  );
}
