import 'playback_episode.dart';
import 'playback_quality.dart';

final class PlaybackSession {
  final List<PlaybackQuality> availableQualities;
  final Uri manifestUri;
  final PlaybackQuality requestedQuality;
  final PlaybackQuality selectedQuality;
  final Map<String, String> httpHeaders;
  final List<PlaybackEpisode> episodes;
  final List<int> episodeNumbers;
  final Set<int> watchedEpisodes;
  final DateTime? expiresAt;

  PlaybackSession({
    required this.manifestUri,
    required this.requestedQuality,
    required this.selectedQuality,
    required List<PlaybackQuality> availableQualities,
    Map<String, String> httpHeaders = const {},
    List<PlaybackEpisode> episodes = const [],
    List<int> episodeNumbers = const [],
    Set<int> watchedEpisodes = const {},
    this.expiresAt,
  }) : availableQualities = List.unmodifiable(availableQualities),
       httpHeaders = Map.unmodifiable(httpHeaders),
       episodes = List.unmodifiable(
         episodes.isNotEmpty
             ? episodes
             : episodeNumbers.map((number) => PlaybackEpisode(number: number, title: '')).toList(growable: false),
       ),
       episodeNumbers = List.unmodifiable(
         episodes.isNotEmpty ? episodes.map((episode) => episode.number).toList(growable: false) : episodeNumbers,
       ),
       watchedEpisodes = Set.unmodifiable({
         ...watchedEpisodes,
         ...episodes.where((episode) => episode.isWatched).map((episode) => episode.number),
       });

  int? previousEpisode(int current) => (episodeNumbers.where((number) => number < current).toList()..sort()).lastOrNull;

  int? nextEpisode(int current) => (episodeNumbers.where((number) => number > current).toList()..sort()).firstOrNull;
}
