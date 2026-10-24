import 'anime_episode.dart';

typedef AnimeWatchAction = ({AnimeEpisode? episode, bool rewatch});

AnimeWatchAction selectAnimeWatchAction(Iterable<AnimeEpisode> episodes, Set<int> watchedEpisodeNumbers) {
  final ascending = episodes.toList()..sort((left, right) => left.number.compareTo(right.number));
  final confirmed = {
    ...watchedEpisodeNumbers,
    ...ascending.where((episode) => episode.isWatched).map((episode) => episode.number),
  };
  final maximumWatched = confirmed.isEmpty ? null : confirmed.reduce((left, right) => left > right ? left : right);
  final next = ascending.where((episode) => maximumWatched == null || episode.number > maximumWatched).firstOrNull;

  return (episode: next ?? ascending.firstOrNull, rewatch: ascending.isNotEmpty && next == null);
}
