import 'playback_quality.dart';

final class PlaybackSession {
  final List<PlaybackQuality> availableQualities;
  final Uri manifestUri;
  final PlaybackQuality requestedQuality;
  final PlaybackQuality selectedQuality;
  final Map<String, String> httpHeaders;
  final List<int> episodeNumbers;
  final Set<int> watchedEpisodes;
  final DateTime? expiresAt;

  PlaybackSession({
    required this.manifestUri,
    required this.requestedQuality,
    required this.selectedQuality,
    required List<PlaybackQuality> availableQualities,
    Map<String, String> httpHeaders = const {},
    List<int> episodeNumbers = const [],
    Set<int> watchedEpisodes = const {},
    this.expiresAt,
  }) : availableQualities = List.unmodifiable(availableQualities),
       httpHeaders = Map.unmodifiable(httpHeaders),
       episodeNumbers = List.unmodifiable(episodeNumbers),
       watchedEpisodes = Set.unmodifiable(watchedEpisodes);

  int? previousEpisode(int current) => (episodeNumbers.where((number) => number < current).toList()..sort()).lastOrNull;

  int? nextEpisode(int current) => (episodeNumbers.where((number) => number > current).toList()..sort()).firstOrNull;
}
