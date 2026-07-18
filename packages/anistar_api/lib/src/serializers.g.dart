// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'serializers.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

Serializers _$serializers = (Serializers().toBuilder()
      ..add(AnimeDetail.serializer)
      ..add(AnimeListItem.serializer)
      ..add(EpisodeInfo.serializer)
      ..add(ErrorResponse.serializer)
      ..add(HTTPValidationError.serializer)
      ..add(LivenessResponse.serializer)
      ..add(LivenessResponseStatusEnum.serializer)
      ..add(LocationInner.serializer)
      ..add(PaginatedAnimeList.serializer)
      ..add(PlaybackInfo.serializer)
      ..add(QualityType.serializer)
      ..add(ReadinessResponse.serializer)
      ..add(ReadinessResponseAnistarEnum.serializer)
      ..add(ReadinessResponseStatusEnum.serializer)
      ..add(ValidationError.serializer)
      ..addBuilderFactory(
          const FullType(BuiltList, const [const FullType(AnimeListItem)]),
          () => ListBuilder<AnimeListItem>())
      ..addBuilderFactory(
          const FullType(BuiltList, const [const FullType(LocationInner)]),
          () => ListBuilder<LocationInner>())
      ..addBuilderFactory(
          const FullType(BuiltList, const [const FullType(QualityType)]),
          () => ListBuilder<QualityType>())
      ..addBuilderFactory(
          const FullType(BuiltList, const [const FullType(String)]),
          () => ListBuilder<String>())
      ..addBuilderFactory(
          const FullType(BuiltList, const [const FullType(ValidationError)]),
          () => ListBuilder<ValidationError>()))
    .build();

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
