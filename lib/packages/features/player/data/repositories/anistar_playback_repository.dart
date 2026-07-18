import 'package:api/api.dart';
import '../../../../core/core.dart';
import '../../domain/models/playback_quality.dart';
import '../../domain/models/playback_session.dart';
import '../../domain/repositories/playback_repository.dart';
import '../mappers/playback_session_mapper.dart';

final class AnistarPlaybackRepository extends BaseRepository implements PlaybackRepository {
  final VideoClient _api;
  final Uri _baseUri;

  AnistarPlaybackRepository(this._api, this._baseUri, [super.logger]);

  @override
  Future<Either<Failure, PlaybackSession>> createSession({
    required int animeId,
    required int episodeNumber,
    PlaybackQuality quality = PlaybackQuality.high,
  }) => makeApiCall(() async {
    final data = await _api.getApiVideoAnimeIdEpisodesEpisodeNumberPlayback(
      animeId: animeId,
      episodeNumber: episodeNumber,
      quality: toApiQuality(quality),
    );

    return data.toDomain(_baseUri);
  });
}
