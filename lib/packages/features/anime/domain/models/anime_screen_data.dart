import 'anime_details.dart';
import 'anime_episode.dart';

final class AnimeScreenData {
  final AnimeDetails details;
  final List<AnimeEpisode> episodes;

  AnimeScreenData({required this.details, required List<AnimeEpisode> episodes})
    : episodes = List.unmodifiable(episodes);
}
