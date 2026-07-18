// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

part 'anime_list_item_dto.freezed.dart';
part 'anime_list_item_dto.g.dart';

/// Anime list item with minimal information from mobile site.
@Freezed()
abstract class AnimeListItemDto with _$AnimeListItemDto {
  const factory AnimeListItemDto({
    /// Anime ID on website
    required int id,

    /// URL slug for detail page (e.g., '10247-title-here')
    required String slug,

    /// Full title
    required String title,

    /// Poster image URL
    @JsonKey(name: 'poster_url') required String posterUrl,

    /// Release date
    String? year,
  }) = _AnimeListItemDto;

  factory AnimeListItemDto.fromJson(Map<String, Object?> json) =>
      _$AnimeListItemDtoFromJson(json);
}
