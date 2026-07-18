// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

part 'episode_info_dto.freezed.dart';
part 'episode_info_dto.g.dart';

/// Episode information.
@Freezed()
abstract class EpisodeInfoDto with _$EpisodeInfoDto {
  const factory EpisodeInfoDto({
    /// Episode number
    @JsonKey(name: 'episode_number') required int episodeNumber,

    /// Episode title
    required String title,

    /// API-relative JSON playback endpoint for this episode
    @JsonKey(name: 'playback_path') required String playbackPath,

    /// Preview image URL
    @JsonKey(name: 'preview_url') String? previewUrl,
  }) = _EpisodeInfoDto;

  factory EpisodeInfoDto.fromJson(Map<String, Object?> json) =>
      _$EpisodeInfoDtoFromJson(json);
}
