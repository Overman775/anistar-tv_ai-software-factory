// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'paginated_anime_list_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PaginatedAnimeListDto _$PaginatedAnimeListDtoFromJson(
  Map<String, dynamic> json,
) => _PaginatedAnimeListDto(
  currentPage: (json['current_page'] as num).toInt(),
  hasNext: json['has_next'] as bool,
  hasPrev: json['has_prev'] as bool,
  items: (json['items'] as List<dynamic>?)
      ?.map((e) => AnimeListItemDto.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$PaginatedAnimeListDtoToJson(
  _PaginatedAnimeListDto instance,
) => <String, dynamic>{
  'current_page': instance.currentPage,
  'has_next': instance.hasNext,
  'has_prev': instance.hasPrev,
  'items': instance.items,
};
