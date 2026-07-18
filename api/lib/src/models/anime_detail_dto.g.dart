// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'anime_detail_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AnimeDetailDto _$AnimeDetailDtoFromJson(Map<String, dynamic> json) =>
    _AnimeDetailDto(
      id: (json['id'] as num).toInt(),
      slug: json['slug'] as String,
      title: json['title'] as String,
      isOngoing: json['is_ongoing'] as bool? ?? false,
      year: json['year'] as String?,
      genres: (json['genres'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      voiceover: json['voiceover'] as String?,
      seriesInfo: json['series_info'] as String?,
      description: json['description'] as String?,
      posterUrl: json['poster_url'] as String?,
    );

Map<String, dynamic> _$AnimeDetailDtoToJson(_AnimeDetailDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'slug': instance.slug,
      'title': instance.title,
      'is_ongoing': instance.isOngoing,
      'year': instance.year,
      'genres': instance.genres,
      'voiceover': instance.voiceover,
      'series_info': instance.seriesInfo,
      'description': instance.description,
      'poster_url': instance.posterUrl,
    };
