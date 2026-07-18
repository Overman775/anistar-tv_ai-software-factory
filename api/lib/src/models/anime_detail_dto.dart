// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

part 'anime_detail_dto.freezed.dart';
part 'anime_detail_dto.g.dart';

/// Complete anime information from mobile site.
@Freezed()
abstract class AnimeDetailDto with _$AnimeDetailDto {
  const factory AnimeDetailDto({
    /// Anime ID on website
    required int id,

    /// URL slug for detail page (e.g., '10247-title-here')
    required String slug,

    /// Full title
    required String title,

    /// Whether anime is currently airing (ongoing)
    @JsonKey(name: 'is_ongoing') @Default(false) bool isOngoing,

    /// Release year
    String? year,

    /// List of genres
    List<String>? genres,

    /// Voiceover type
    String? voiceover,

    /// Series info as shown on site (e.g. '(52 эп.), 25 мин.')
    @JsonKey(name: 'series_info') String? seriesInfo,

    /// Anime description
    String? description,

    /// Poster image URL (None if not available)
    @JsonKey(name: 'poster_url') String? posterUrl,
  }) = _AnimeDetailDto;

  factory AnimeDetailDto.fromJson(Map<String, Object?> json) =>
      _$AnimeDetailDtoFromJson(json);
}
