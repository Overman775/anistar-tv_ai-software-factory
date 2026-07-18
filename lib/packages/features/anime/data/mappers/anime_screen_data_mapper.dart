import 'package:api/api.dart';

import '../../domain/models/anime_details.dart';
import '../../domain/models/anime_episode.dart';
import '../../domain/models/anime_screen_data.dart';

AnimeScreenData toAnimeScreenData(AnimeDetailDto detail, List<EpisodeInfoDto> episodes) {
  final episodeNumbers = <int>{};
  final mappedEpisodes = episodes.where((episode) => episodeNumbers.add(episode.episodeNumber)).map((episode) {
    final title = episode.title.trim();

    return AnimeEpisode(
      number: episode.episodeNumber,
      title: title.isEmpty ? 'Серия ${episode.episodeNumber}' : title,
      previewUri: _optionalUri(episode.previewUrl),
    );
  }).toList()..sort((left, right) => left.number.compareTo(right.number));

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
      isOngoing: detail.isOngoing,
      posterUri: _optionalUri(detail.posterUrl),
    ),
    episodes: List.unmodifiable(mappedEpisodes),
  );
}

Uri? _optionalUri(String? value) {
  final uri = Uri.tryParse(value?.trim() ?? '');

  return uri != null && (uri.scheme == 'http' || uri.scheme == 'https') ? uri : null;
}
