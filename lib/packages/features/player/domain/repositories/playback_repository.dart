import 'package:core/data.dart';

import '../models/playback_quality.dart';
import '../models/playback_session.dart';

// Repository identity is required for DI and interchangeable implementations.
abstract interface class PlaybackRepository {
  Future<Result<PlaybackSession, Failure>> createSession({
    required int animeId,
    required int episodeNumber,
    PlaybackQuality quality = PlaybackQuality.high,
  });
}
