//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:anistar_api/src/model/quality_type.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'playback_info.g.dart';

/// Flutter-friendly description of an HLS playback session.
///
/// Properties:
/// * [animeId]
/// * [episodeNumber]
/// * [requestedQuality]
/// * [selectedQuality]
/// * [availableQualities]
/// * [manifestPath] - API-relative HLS manifest path; resolve it against the configured API base URL
/// * [segmentTokenTtlSeconds]
@BuiltValue()
abstract class PlaybackInfo
    implements Built<PlaybackInfo, PlaybackInfoBuilder> {
  @BuiltValueField(wireName: r'anime_id')
  int get animeId;

  @BuiltValueField(wireName: r'episode_number')
  int get episodeNumber;

  @BuiltValueField(wireName: r'requested_quality')
  QualityType get requestedQuality;
  // enum requestedQualityEnum {  360,  720,  };

  @BuiltValueField(wireName: r'selected_quality')
  QualityType get selectedQuality;
  // enum selectedQualityEnum {  360,  720,  };

  @BuiltValueField(wireName: r'available_qualities')
  BuiltList<QualityType> get availableQualities;

  /// API-relative HLS manifest path; resolve it against the configured API base URL
  @BuiltValueField(wireName: r'manifest_path')
  String get manifestPath;

  @BuiltValueField(wireName: r'segment_token_ttl_seconds')
  int get segmentTokenTtlSeconds;

  PlaybackInfo._();

  factory PlaybackInfo([void updates(PlaybackInfoBuilder b)]) = _$PlaybackInfo;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(PlaybackInfoBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<PlaybackInfo> get serializer => _$PlaybackInfoSerializer();
}

class _$PlaybackInfoSerializer implements PrimitiveSerializer<PlaybackInfo> {
  @override
  final Iterable<Type> types = const [PlaybackInfo, _$PlaybackInfo];

  @override
  final String wireName = r'PlaybackInfo';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    PlaybackInfo object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'anime_id';
    yield serializers.serialize(
      object.animeId,
      specifiedType: const FullType(int),
    );
    yield r'episode_number';
    yield serializers.serialize(
      object.episodeNumber,
      specifiedType: const FullType(int),
    );
    yield r'requested_quality';
    yield serializers.serialize(
      object.requestedQuality,
      specifiedType: const FullType(QualityType),
    );
    yield r'selected_quality';
    yield serializers.serialize(
      object.selectedQuality,
      specifiedType: const FullType(QualityType),
    );
    yield r'available_qualities';
    yield serializers.serialize(
      object.availableQualities,
      specifiedType: const FullType(BuiltList, [FullType(QualityType)]),
    );
    yield r'manifest_path';
    yield serializers.serialize(
      object.manifestPath,
      specifiedType: const FullType(String),
    );
    yield r'segment_token_ttl_seconds';
    yield serializers.serialize(
      object.segmentTokenTtlSeconds,
      specifiedType: const FullType(int),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    PlaybackInfo object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object,
            specifiedType: specifiedType)
        .toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required PlaybackInfoBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'anime_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.animeId = valueDes;
          break;
        case r'episode_number':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.episodeNumber = valueDes;
          break;
        case r'requested_quality':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(QualityType),
          ) as QualityType;
          result.requestedQuality = valueDes;
          break;
        case r'selected_quality':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(QualityType),
          ) as QualityType;
          result.selectedQuality = valueDes;
          break;
        case r'available_qualities':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(QualityType)]),
          ) as BuiltList<QualityType>;
          result.availableQualities.replace(valueDes);
          break;
        case r'manifest_path':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.manifestPath = valueDes;
          break;
        case r'segment_token_ttl_seconds':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.segmentTokenTtlSeconds = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  PlaybackInfo deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = PlaybackInfoBuilder();
    final serializedList = (serialized as Iterable<Object?>).toList();
    final unhandled = <Object?>[];
    _deserializeProperties(
      serializers,
      serialized,
      specifiedType: specifiedType,
      serializedList: serializedList,
      unhandled: unhandled,
      result: result,
    );
    return result.build();
  }
}
