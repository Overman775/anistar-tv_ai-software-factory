import 'anime_details.dart';
import 'anime_episode.dart';

final class AnimeScreenData {
  final AnimeDetails details;
  final List<AnimeEpisode> episodes;

  const AnimeScreenData({required this.details, required this.episodes});
}
