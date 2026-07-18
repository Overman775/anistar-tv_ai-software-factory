//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'anime_list_item.g.dart';

/// Anime list item with minimal information from mobile site.
///
/// Properties:
/// * [id] - Anime ID on website
/// * [slug] - URL slug for detail page (e.g., '10247-title-here')
/// * [title] - Full title
/// * [year] - Release date
/// * [posterUrl] - Poster image URL
@BuiltValue()
abstract class AnimeListItem
    implements Built<AnimeListItem, AnimeListItemBuilder> {
  /// Anime ID on website
  @BuiltValueField(wireName: r'id')
  int get id;

  /// URL slug for detail page (e.g., '10247-title-here')
  @BuiltValueField(wireName: r'slug')
  String get slug;

  /// Full title
  @BuiltValueField(wireName: r'title')
  String get title;

  /// Release date
  @BuiltValueField(wireName: r'year')
  String? get year;

  /// Poster image URL
  @BuiltValueField(wireName: r'poster_url')
  String get posterUrl;

  AnimeListItem._();

  factory AnimeListItem([void updates(AnimeListItemBuilder b)]) =
      _$AnimeListItem;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(AnimeListItemBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<AnimeListItem> get serializer =>
      _$AnimeListItemSerializer();
}

class _$AnimeListItemSerializer implements PrimitiveSerializer<AnimeListItem> {
  @override
  final Iterable<Type> types = const [AnimeListItem, _$AnimeListItem];

  @override
  final String wireName = r'AnimeListItem';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    AnimeListItem object, {
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
    yield r'poster_url';
    yield serializers.serialize(
      object.posterUrl,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    AnimeListItem object, {
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
    required AnimeListItemBuilder result,
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
        case r'poster_url':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
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
  AnimeListItem deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = AnimeListItemBuilder();
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
