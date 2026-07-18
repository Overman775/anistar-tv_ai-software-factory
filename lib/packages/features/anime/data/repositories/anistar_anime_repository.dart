import 'package:anistar_api/anistar_api.dart';
import 'package:anistar_tv/packages/core/api/anistar_api_exception.dart';
import 'package:dio/dio.dart';

import '../../domain/models/anime_details.dart';
import '../../domain/models/anime_episode.dart';
import '../../domain/models/anime_screen_data.dart';
import '../../domain/repositories/anime_repository.dart';

final class AnistarAnimeRepository implements AnimeRepository {
  final AnimeApi _api;

  const AnistarAnimeRepository(this._api);

  @override
  Future<AnimeScreenData> getAnime({required int id, required String slug}) async {
    try {
      final responses = await Future.wait([_api.getAnimeDetail(slug: slug), _api.listAnimeEpisodes(animeId: id)]);
      final detail = responses[0].data as AnimeDetail?;
      final episodes = responses[1].data as Iterable<EpisodeInfo>?;
      if (detail == null || episodes == null) {
        throw const AnistarApiException(message: 'Parser вернул неполные данные об аниме.');
      }

      return AnimeScreenData(
        details: AnimeDetails(
          id: detail.id,
          slug: detail.slug,
          title: detail.title,
          year: detail.year,
          genres: detail.genres?.toList(growable: false) ?? const [],
          voiceover: detail.voiceover,
          seriesInfo: detail.seriesInfo,
          description: detail.description,
          isOngoing: detail.isOngoing ?? false,
          posterUri: _optionalUri(detail.posterUrl),
        ),
        episodes: _mapEpisodes(episodes),
      );
    } on DioException catch (error) {
      Error.throwWithStackTrace(AnistarApiException.fromDio(error), error.stackTrace);
    }
  }

  static List<AnimeEpisode> _mapEpisodes(Iterable<EpisodeInfo> episodes) {
    final numbers = <int>{};
    final result = episodes
        .where((episode) => numbers.add(episode.episodeNumber))
        .map(
          (episode) => AnimeEpisode(
            number: episode.episodeNumber,
            title: episode.title.trim().isEmpty ? 'Серия ${episode.episodeNumber}' : episode.title,
            previewUri: _optionalUri(episode.previewUrl),
          ),
        )
        .toList();
    result.sort((left, right) => left.number.compareTo(right.number));

    return List.unmodifiable(result);
  }

  static Uri? _optionalUri(String? value) {
    final uri = Uri.tryParse(value?.trim() ?? '');
    if (uri == null || !uri.hasScheme || uri.scheme != 'http' && uri.scheme != 'https') return null;

    return uri;
  }
}
