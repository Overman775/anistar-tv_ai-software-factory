// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'anime_list_item_dto.dart';

part 'paginated_anime_list_dto.freezed.dart';
part 'paginated_anime_list_dto.g.dart';

/// Paginated response for anime list.
@Freezed()
abstract class PaginatedAnimeListDto with _$PaginatedAnimeListDto {
  const factory PaginatedAnimeListDto({
    /// Current page number
    @JsonKey(name: 'current_page') required int currentPage,

    /// Whether next page exists
    @JsonKey(name: 'has_next') required bool hasNext,

    /// Whether previous page exists
    @JsonKey(name: 'has_prev') required bool hasPrev,
    List<AnimeListItemDto>? items,
  }) = _PaginatedAnimeListDto;

  factory PaginatedAnimeListDto.fromJson(Map<String, Object?> json) =>
      _$PaginatedAnimeListDtoFromJson(json);
}
