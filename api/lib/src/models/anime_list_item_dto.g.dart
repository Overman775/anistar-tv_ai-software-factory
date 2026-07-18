// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'anime_list_item_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AnimeListItemDto _$AnimeListItemDtoFromJson(Map<String, dynamic> json) =>
    _AnimeListItemDto(
      id: (json['id'] as num).toInt(),
      slug: json['slug'] as String,
      title: json['title'] as String,
      posterUrl: json['poster_url'] as String,
      year: json['year'] as String?,
    );

Map<String, dynamic> _$AnimeListItemDtoToJson(_AnimeListItemDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'slug': instance.slug,
      'title': instance.title,
      'poster_url': instance.posterUrl,
      'year': instance.year,
    };
