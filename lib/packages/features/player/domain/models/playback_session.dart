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

  const PlaybackSession({
    required this.manifestUri,
    required this.requestedQuality,
    required this.selectedQuality,
    required this.availableQualities,
    this.httpHeaders = const {},
    this.episodeNumbers = const [],
    this.watchedEpisodes = const {},
    this.expiresAt,
  });
}
