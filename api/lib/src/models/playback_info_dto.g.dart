// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'playback_info_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PlaybackInfoDto _$PlaybackInfoDtoFromJson(
  Map<String, dynamic> json,
) => _PlaybackInfoDto(
  animeId: (json['anime_id'] as num).toInt(),
  episodeNumber: (json['episode_number'] as num).toInt(),
  requestedQuality: QualityTypeDto.fromJson(
    json['requested_quality'] as String,
  ),
  selectedQuality: QualityTypeDto.fromJson(json['selected_quality'] as String),
  availableQualities: (json['available_qualities'] as List<dynamic>)
      .map((e) => QualityTypeDto.fromJson(e as String))
      .toList(),
  manifestPath: json['manifest_path'] as String,
  segmentTokenTtlSeconds: (json['segment_token_ttl_seconds'] as num).toInt(),
);

Map<String, dynamic> _$PlaybackInfoDtoToJson(_PlaybackInfoDto instance) =>
    <String, dynamic>{
      'anime_id': instance.animeId,
      'episode_number': instance.episodeNumber,
      'requested_quality': _$QualityTypeDtoEnumMap[instance.requestedQuality]!,
      'selected_quality': _$QualityTypeDtoEnumMap[instance.selectedQuality]!,
      'available_qualities': instance.availableQualities
          .map((e) => _$QualityTypeDtoEnumMap[e]!)
          .toList(),
      'manifest_path': instance.manifestPath,
      'segment_token_ttl_seconds': instance.segmentTokenTtlSeconds,
    };

const _$QualityTypeDtoEnumMap = {
  QualityTypeDto.value360: '360',
  QualityTypeDto.value720: '720',
  QualityTypeDto.$unknown: r'$unknown',
};
