// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'quality_type_dto.dart';

part 'playback_info_dto.freezed.dart';
part 'playback_info_dto.g.dart';

/// Flutter-friendly description of an HLS playback session.
@Freezed()
abstract class PlaybackInfoDto with _$PlaybackInfoDto {
  const factory PlaybackInfoDto({
    @JsonKey(name: 'anime_id') required int animeId,
    @JsonKey(name: 'episode_number') required int episodeNumber,
    @JsonKey(name: 'requested_quality')
    required QualityTypeDto requestedQuality,
    @JsonKey(name: 'selected_quality') required QualityTypeDto selectedQuality,
    @JsonKey(name: 'available_qualities')
    required List<QualityTypeDto> availableQualities,

    /// API-relative HLS manifest path; resolve it against the configured API base URL
    @JsonKey(name: 'manifest_path') required String manifestPath,
    @JsonKey(name: 'segment_token_ttl_seconds')
    required int segmentTokenTtlSeconds,
  }) = _PlaybackInfoDto;

  factory PlaybackInfoDto.fromJson(Map<String, Object?> json) =>
      _$PlaybackInfoDtoFromJson(json);
}
