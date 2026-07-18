//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'anime_detail.g.dart';

/// Complete anime information from mobile site.
///
/// Properties:
/// * [id] - Anime ID on website
/// * [slug] - URL slug for detail page (e.g., '10247-title-here')
/// * [title] - Full title
/// * [year] - Release year
/// * [genres] - List of genres
/// * [voiceover] - Voiceover type
/// * [seriesInfo] - Series info as shown on site (e.g. '(52 эп.), 25 мин.')
/// * [description] - Anime description
/// * [isOngoing] - Whether anime is currently airing (ongoing)
/// * [posterUrl] - Poster image URL (None if not available)
@BuiltValue()
abstract class AnimeDetail implements Built<AnimeDetail, AnimeDetailBuilder> {
  /// Anime ID on website
  @BuiltValueField(wireName: r'id')
  int get id;

  /// URL slug for detail page (e.g., '10247-title-here')
  @BuiltValueField(wireName: r'slug')
  String get slug;

  /// Full title
  @BuiltValueField(wireName: r'title')
  String get title;

  /// Release year
  @BuiltValueField(wireName: r'year')
  String? get year;

  /// List of genres
  @BuiltValueField(wireName: r'genres')
  BuiltList<String>? get genres;

  /// Voiceover type
  @BuiltValueField(wireName: r'voiceover')
  String? get voiceover;

  /// Series info as shown on site (e.g. '(52 эп.), 25 мин.')
  @BuiltValueField(wireName: r'series_info')
  String? get seriesInfo;

  /// Anime description
  @BuiltValueField(wireName: r'description')
  String? get description;

  /// Whether anime is currently airing (ongoing)
  @BuiltValueField(wireName: r'is_ongoing')
  bool? get isOngoing;

  /// Poster image URL (None if not available)
  @BuiltValueField(wireName: r'poster_url')
  String? get posterUrl;

  AnimeDetail._();

  factory AnimeDetail([void updates(AnimeDetailBuilder b)]) = _$AnimeDetail;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(AnimeDetailBuilder b) => b..isOngoing = false;

  @BuiltValueSerializer(custom: true)
  static Serializer<AnimeDetail> get serializer => _$AnimeDetailSerializer();
}

class _$AnimeDetailSerializer implements PrimitiveSerializer<AnimeDetail> {
  @override
  final Iterable<Type> types = const [AnimeDetail, _$AnimeDetail];

  @override
  final String wireName = r'AnimeDetail';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    AnimeDetail object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'id';
    yield serializers.serialize(
      object.id,
      specifiedType: const FullType(int),
    );
    yield r'slug';
    yield serializers.serialize(
      object.slug,
      specifiedType: const FullType(String),
    );
    yield r'title';
    yield serializers.serialize(
      object.title,
      specifiedType: const FullType(String),
    );
    if (object.year != null) {
      yield r'year';
      yield serializers.serialize(
        object.year,
        specifiedType: const FullType.nullable(String),
      );
    }
    if (object.genres != null) {
      yield r'genres';
      yield serializers.serialize(
        object.genres,
        specifiedType: const FullType(BuiltList, [FullType(String)]),
      );
    }
    if (object.voiceover != null) {
      yield r'voiceover';
      yield serializers.serialize(
        object.voiceover,
        specifiedType: const FullType.nullable(String),
      );
    }
    if (object.seriesInfo != null) {
      yield r'series_info';
      yield serializers.serialize(
        object.seriesInfo,
        specifiedType: const FullType.nullable(String),
      );
    }
    if (object.description != null) {
      yield r'description';
      yield serializers.serialize(
        object.description,
        specifiedType: const FullType.nullable(String),
      );
    }
    if (object.isOngoing != null) {
      yield r'is_ongoing';
      yield serializers.serialize(
        object.isOngoing,
        specifiedType: const FullType(bool),
      );
    }
    if (object.posterUrl != null) {
      yield r'poster_url';
      yield serializers.serialize(
        object.posterUrl,
        specifiedType: const FullType.nullable(String),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    AnimeDetail object, {
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
    required AnimeDetailBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.id = valueDes;
          break;
        case r'slug':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.slug = valueDes;
          break;
        case r'title':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.title = valueDes;
          break;
        case r'year':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.year = valueDes;
          break;
        case r'genres':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(String)]),
          ) as BuiltList<String>;
          result.genres.replace(valueDes);
          break;
        case r'voiceover':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.voiceover = valueDes;
          break;
        case r'series_info':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.seriesInfo = valueDes;
          break;
        case r'description':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.description = valueDes;
          break;
        case r'is_ongoing':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.isOngoing = valueDes;
          break;
        case r'poster_url':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.posterUrl = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  AnimeDetail deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = AnimeDetailBuilder();
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
