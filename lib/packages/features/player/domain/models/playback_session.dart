import 'playback_episode.dart';
import 'playback_quality.dart';

final class PlaybackSession {
  final List<PlaybackQuality> availableQualities;
  final Uri manifestUri;
  final PlaybackQuality requestedQuality;
  final PlaybackQuality selectedQuality;
  final Map<String, String> httpHeaders;
  final List<PlaybackEpisode> episodes;
  final DateTime? expiresAt;

  PlaybackSession({
    required this.manifestUri,
    required this.requestedQuality,
    required this.selectedQuality,
    required List<PlaybackQuality> availableQualities,
    required List<PlaybackEpisode> episodes,
    Map<String, String> httpHeaders = const {},
    this.expiresAt,
  }) : availableQualities = List.unmodifiable(availableQualities),
       httpHeaders = Map.unmodifiable(httpHeaders),
       episodes = List.unmodifiable(episodes);

  List<int> get episodeNumbers => List.unmodifiable(episodes.map((episode) => episode.number));

  Set<int> get watchedEpisodes =>
      Set.unmodifiable(episodes.where((episode) => episode.isWatched).map((episode) => episode.number));

  int? previousEpisode(int current) {
    int? previous;
    for (final episode in episodes) {
      final number = episode.number;
      if (number < current && (previous == null || number > previous)) previous = number;
    }
    return previous;
  }

  int? nextEpisode(int current) {
    int? next;
    for (final episode in episodes) {
      final number = episode.number;
      if (number > current && (next == null || number < next)) next = number;
    }
    return next;
  }
}
