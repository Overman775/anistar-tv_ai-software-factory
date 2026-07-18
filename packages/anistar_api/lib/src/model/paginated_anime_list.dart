//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:anistar_api/src/model/anime_list_item.dart';
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'paginated_anime_list.g.dart';

/// Paginated response for anime list.
///
/// Properties:
/// * [items]
/// * [currentPage] - Current page number
/// * [hasNext] - Whether next page exists
/// * [hasPrev] - Whether previous page exists
@BuiltValue()
abstract class PaginatedAnimeList
    implements Built<PaginatedAnimeList, PaginatedAnimeListBuilder> {
  @BuiltValueField(wireName: r'items')
  BuiltList<AnimeListItem>? get items;

  /// Current page number
  @BuiltValueField(wireName: r'current_page')
  int get currentPage;

  /// Whether next page exists
  @BuiltValueField(wireName: r'has_next')
  bool get hasNext;

  /// Whether previous page exists
  @BuiltValueField(wireName: r'has_prev')
  bool get hasPrev;

  PaginatedAnimeList._();

  factory PaginatedAnimeList([void updates(PaginatedAnimeListBuilder b)]) =
      _$PaginatedAnimeList;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(PaginatedAnimeListBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<PaginatedAnimeList> get serializer =>
      _$PaginatedAnimeListSerializer();
}

class _$PaginatedAnimeListSerializer
    implements PrimitiveSerializer<PaginatedAnimeList> {
  @override
  final Iterable<Type> types = const [PaginatedAnimeList, _$PaginatedAnimeList];

  @override
  final String wireName = r'PaginatedAnimeList';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    PaginatedAnimeList object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    if (object.items != null) {
      yield r'items';
      yield serializers.serialize(
        object.items,
        specifiedType: const FullType(BuiltList, [FullType(AnimeListItem)]),
      );
    }
    yield r'current_page';
    yield serializers.serialize(
      object.currentPage,
      specifiedType: const FullType(int),
    );
    yield r'has_next';
    yield serializers.serialize(
      object.hasNext,
      specifiedType: const FullType(bool),
    );
    yield r'has_prev';
    yield serializers.serialize(
      object.hasPrev,
      specifiedType: const FullType(bool),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    PaginatedAnimeList object, {
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
    required PaginatedAnimeListBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'items':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(AnimeListItem)]),
          ) as BuiltList<AnimeListItem>;
          result.items.replace(valueDes);
          break;
        case r'current_page':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.currentPage = valueDes;
          break;
        case r'has_next':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.hasNext = valueDes;
          break;
        case r'has_prev':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.hasPrev = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  PaginatedAnimeList deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = PaginatedAnimeListBuilder();
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
