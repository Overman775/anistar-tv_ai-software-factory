//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'episode_info.g.dart';

/// Episode information.
///
/// Properties:
/// * [episodeNumber] - Episode number
/// * [title] - Episode title
/// * [previewUrl] - Preview image URL
/// * [playbackPath] - API-relative JSON playback endpoint for this episode
@BuiltValue()
abstract class EpisodeInfo implements Built<EpisodeInfo, EpisodeInfoBuilder> {
  /// Episode number
  @BuiltValueField(wireName: r'episode_number')
  int get episodeNumber;

  /// Episode title
  @BuiltValueField(wireName: r'title')
  String get title;

  /// Preview image URL
  @BuiltValueField(wireName: r'preview_url')
  String? get previewUrl;

  /// API-relative JSON playback endpoint for this episode
  @BuiltValueField(wireName: r'playback_path')
  String get playbackPath;

  EpisodeInfo._();

  factory EpisodeInfo([void updates(EpisodeInfoBuilder b)]) = _$EpisodeInfo;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(EpisodeInfoBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<EpisodeInfo> get serializer => _$EpisodeInfoSerializer();
}

class _$EpisodeInfoSerializer implements PrimitiveSerializer<EpisodeInfo> {
  @override
  final Iterable<Type> types = const [EpisodeInfo, _$EpisodeInfo];

  @override
  final String wireName = r'EpisodeInfo';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    EpisodeInfo object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'episode_number';
    yield serializers.serialize(
      object.episodeNumber,
      specifiedType: const FullType(int),
    );
    yield r'title';
    yield serializers.serialize(
      object.title,
      specifiedType: const FullType(String),
    );
    if (object.previewUrl != null) {
      yield r'preview_url';
      yield serializers.serialize(
        object.previewUrl,
        specifiedType: const FullType.nullable(String),
      );
    }
    yield r'playback_path';
    yield serializers.serialize(
      object.playbackPath,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    EpisodeInfo object, {
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
    required EpisodeInfoBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'episode_number':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.episodeNumber = valueDes;
          break;
        case r'title':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.title = valueDes;
          break;
        case r'preview_url':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.previewUrl = valueDes;
          break;
        case r'playback_path':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.playbackPath = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  EpisodeInfo deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = EpisodeInfoBuilder();
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
