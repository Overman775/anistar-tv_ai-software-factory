// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'episode_info_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_EpisodeInfoDto _$EpisodeInfoDtoFromJson(Map<String, dynamic> json) =>
    _EpisodeInfoDto(
      episodeNumber: (json['episode_number'] as num).toInt(),
      title: json['title'] as String,
      playbackPath: json['playback_path'] as String,
      previewUrl: json['preview_url'] as String?,
    );

Map<String, dynamic> _$EpisodeInfoDtoToJson(_EpisodeInfoDto instance) =>
    <String, dynamic>{
      'episode_number': instance.episodeNumber,
      'title': instance.title,
      'playback_path': instance.playbackPath,
      'preview_url': instance.previewUrl,
    };
