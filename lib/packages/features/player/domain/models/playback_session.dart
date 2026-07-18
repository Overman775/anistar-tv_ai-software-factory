import 'playback_quality.dart';

final class PlaybackSession {
  final List<PlaybackQuality> availableQualities;
  final Uri manifestUri;
  final PlaybackQuality requestedQuality;
  final PlaybackQuality selectedQuality;
  final Duration tokenTtl;

  const PlaybackSession({
    required this.manifestUri,
    required this.requestedQuality,
    required this.selectedQuality,
    required this.availableQualities,
    required this.tokenTtl,
  });
}
