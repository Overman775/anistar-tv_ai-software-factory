import 'package:anistar_tv/packages/features/player/data/mappers/playback_session_mapper.dart';
import 'package:anistar_tv/packages/features/player/domain/models/playback_quality.dart';
import 'package:api/api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps the playback contract and resolves a relative HLS manifest', () {
    const dto = PlaybackInfoDto(
      animeId: 17,
      episodeNumber: 4,
      requestedQuality: QualityTypeDto.value720,
      selectedQuality: QualityTypeDto.value360,
      availableQualities: [QualityTypeDto.value360, QualityTypeDto.value720],
      manifestPath: '/api/video/17/episodes/4/manifest.m3u8',
      segmentTokenTtlSeconds: 300,
    );

    final session = dto.toDomain(Uri.parse('https://parser.test/base/'));

    expect(session.manifestUri, Uri.parse('https://parser.test/api/video/17/episodes/4/manifest.m3u8'));
    expect(session.requestedQuality, PlaybackQuality.high);
    expect(session.selectedQuality, PlaybackQuality.low);
    expect(session.availableQualities, [PlaybackQuality.low, PlaybackQuality.high]);
    expect(session.tokenTtl, const Duration(minutes: 5));
    expect(toApiQuality(PlaybackQuality.low), QualityTypeDto.value360);
  });
}
