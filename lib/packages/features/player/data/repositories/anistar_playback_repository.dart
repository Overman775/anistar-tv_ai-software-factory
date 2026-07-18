import 'package:anistar_api/anistar_api.dart';
import 'package:anistar_tv/packages/core/api/anistar_api_exception.dart';
import 'package:dio/dio.dart';

import '../../domain/models/playback_quality.dart';
import '../../domain/models/playback_session.dart';
import '../../domain/repositories/playback_repository.dart';

final class AnistarPlaybackRepository implements PlaybackRepository {
  final VideoApi _api;
  final Uri _baseUri;

  const AnistarPlaybackRepository(this._api, this._baseUri);

  @override
  Future<PlaybackSession> createSession({
    required int animeId,
    required int episodeNumber,
    PlaybackQuality quality = PlaybackQuality.high,
  }) async {
    try {
      final response = await _api.getPlaybackInfo(
        animeId: animeId,
        episodeNumber: episodeNumber,
        quality: _toApiQuality(quality),
      );
      final data = response.data;
      if (data == null) {
        throw const AnistarApiException(message: 'Parser не создал сессию просмотра.');
      }

      return PlaybackSession(
        manifestUri: _baseUri.resolve(data.manifestPath),
        requestedQuality: _fromApiQuality(data.requestedQuality),
        selectedQuality: _fromApiQuality(data.selectedQuality),
        availableQualities: data.availableQualities.map(_fromApiQuality).toList(growable: false),
        tokenTtl: Duration(seconds: data.segmentTokenTtlSeconds),
      );
    } on DioException catch (error) {
      Error.throwWithStackTrace(AnistarApiException.fromDio(error), error.stackTrace);
    }
  }

  static PlaybackQuality _fromApiQuality(QualityType quality) =>
      quality == QualityType.n360 ? PlaybackQuality.low : PlaybackQuality.high;

  static QualityType _toApiQuality(PlaybackQuality quality) =>
      quality == PlaybackQuality.low ? QualityType.n360 : QualityType.n720;
}
