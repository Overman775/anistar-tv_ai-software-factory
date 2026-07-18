import '../models/playback_quality.dart';
import '../models/playback_session.dart';

abstract interface class PlaybackRepository {
  Future<PlaybackSession> createSession({
    required int animeId,
    required int episodeNumber,
    PlaybackQuality quality = PlaybackQuality.high,
  });
}
