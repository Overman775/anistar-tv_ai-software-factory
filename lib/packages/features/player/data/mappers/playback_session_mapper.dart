import 'package:api/api.dart';

import '../../domain/models/playback_quality.dart';
import '../../domain/models/playback_session.dart';

extension PlaybackSessionMapper on PlaybackInfoDto {
  PlaybackSession toDomain(Uri baseUri) => PlaybackSession(
    manifestUri: baseUri.resolve(manifestPath),
    requestedQuality: _toDomainQuality(requestedQuality),
    selectedQuality: _toDomainQuality(selectedQuality),
    availableQualities: availableQualities.map(_toDomainQuality).toList(growable: false),
    tokenTtl: Duration(seconds: segmentTokenTtlSeconds),
  );
}

PlaybackQuality _toDomainQuality(QualityTypeDto quality) =>
    quality == QualityTypeDto.value360 ? PlaybackQuality.low : PlaybackQuality.high;

QualityTypeDto toApiQuality(PlaybackQuality quality) =>
    quality == PlaybackQuality.low ? QualityTypeDto.value360 : QualityTypeDto.value720;
