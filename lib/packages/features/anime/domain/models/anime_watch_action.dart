import 'anime_episode.dart';

typedef AnimeWatchAction = ({AnimeEpisode? episode, bool rewatch});

AnimeWatchAction selectAnimeWatchAction(
  Iterable<AnimeEpisode> episodes,
  Set<int> watchedEpisodeNumbers, {
  bool includeEpisodeMarks = true,
}) {
  final ascending = episodes.where((episode) => episode.number > 0).toList()
    ..sort((left, right) => left.number.compareTo(right.number));
  final confirmed = {
    ...watchedEpisodeNumbers,
    if (includeEpisodeMarks) ...ascending.where((episode) => episode.isWatched).map((episode) => episode.number),
  };
  final maximumWatched = confirmed.isEmpty ? null : confirmed.reduce((left, right) => left > right ? left : right);
  final next = ascending.where((episode) => maximumWatched == null || episode.number > maximumWatched).firstOrNull;

  return (episode: next ?? ascending.firstOrNull, rewatch: ascending.isNotEmpty && next == null);
}
