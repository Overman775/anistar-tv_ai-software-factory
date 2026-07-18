//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_import

import 'package:one_of_serializer/any_of_serializer.dart';
import 'package:one_of_serializer/one_of_serializer.dart';
import 'package:built_collection/built_collection.dart';
import 'package:built_value/json_object.dart';
import 'package:built_value/serializer.dart';
import 'package:built_value/standard_json_plugin.dart';
import 'package:built_value/iso_8601_date_time_serializer.dart';
import 'package:anistar_api/src/date_serializer.dart';
import 'package:anistar_api/src/model/date.dart';

import 'package:anistar_api/src/model/anime_detail.dart';
import 'package:anistar_api/src/model/anime_list_item.dart';
import 'package:anistar_api/src/model/episode_info.dart';
import 'package:anistar_api/src/model/error_response.dart';
import 'package:anistar_api/src/model/http_validation_error.dart';
import 'package:anistar_api/src/model/liveness_response.dart';
import 'package:anistar_api/src/model/location_inner.dart';
import 'package:anistar_api/src/model/paginated_anime_list.dart';
import 'package:anistar_api/src/model/playback_info.dart';
import 'package:anistar_api/src/model/quality_type.dart';
import 'package:anistar_api/src/model/readiness_response.dart';
import 'package:anistar_api/src/model/validation_error.dart';

part 'serializers.g.dart';

@SerializersFor([
  AnimeDetail,
  AnimeListItem,
  EpisodeInfo,
  ErrorResponse,
  HTTPValidationError,
  LivenessResponse,
  LocationInner,
  PaginatedAnimeList,
  PlaybackInfo,
  QualityType,
  ReadinessResponse,
  ValidationError,
])
Serializers serializers = (_$serializers.toBuilder()
      ..addBuilderFactory(
        const FullType(BuiltList, [FullType(EpisodeInfo)]),
        () => ListBuilder<EpisodeInfo>(),
      )
      ..add(const OneOfSerializer())
      ..add(const AnyOfSerializer())
      ..add(const DateSerializer())
      ..add(Iso8601DateTimeSerializer()))
    .build();

Serializers standardSerializers =
    (serializers.toBuilder()..addPlugin(StandardJsonPlugin())).build();
