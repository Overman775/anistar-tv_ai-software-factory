//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'liveness_response.g.dart';

/// Process health independent of AniStar availability.
///
/// Properties:
/// * [status]
/// * [service]
/// * [timestamp]
@BuiltValue()
abstract class LivenessResponse
    implements Built<LivenessResponse, LivenessResponseBuilder> {
  @BuiltValueField(wireName: r'status')
  LivenessResponseStatusEnum? get status;
  // enum statusEnum {  ok,  };

  @BuiltValueField(wireName: r'service')
  String get service;

  @BuiltValueField(wireName: r'timestamp')
  String get timestamp;

  LivenessResponse._();

  factory LivenessResponse([void updates(LivenessResponseBuilder b)]) =
      _$LivenessResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(LivenessResponseBuilder b) =>
      b..status = LivenessResponseStatusEnum.valueOf('ok');

  @BuiltValueSerializer(custom: true)
  static Serializer<LivenessResponse> get serializer =>
      _$LivenessResponseSerializer();
}

class _$LivenessResponseSerializer
    implements PrimitiveSerializer<LivenessResponse> {
  @override
  final Iterable<Type> types = const [LivenessResponse, _$LivenessResponse];

  @override
  final String wireName = r'LivenessResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    LivenessResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    if (object.status != null) {
      yield r'status';
      yield serializers.serialize(
        object.status,
        specifiedType: const FullType(LivenessResponseStatusEnum),
      );
    }
    yield r'service';
    yield serializers.serialize(
      object.service,
      specifiedType: const FullType(String),
    );
    yield r'timestamp';
    yield serializers.serialize(
      object.timestamp,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    LivenessResponse object, {
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
    required LivenessResponseBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'status':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(LivenessResponseStatusEnum),
          ) as LivenessResponseStatusEnum;
          result.status = valueDes;
          break;
        case r'service':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.service = valueDes;
          break;
        case r'timestamp':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.timestamp = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  LivenessResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = LivenessResponseBuilder();
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

class LivenessResponseStatusEnum extends EnumClass {
  @BuiltValueEnumConst(wireName: r'ok')
  static const LivenessResponseStatusEnum ok = _$livenessResponseStatusEnum_ok;

  static Serializer<LivenessResponseStatusEnum> get serializer =>
      _$livenessResponseStatusEnumSerializer;

  const LivenessResponseStatusEnum._(String name) : super(name);

  static BuiltSet<LivenessResponseStatusEnum> get values =>
      _$livenessResponseStatusEnumValues;
  static LivenessResponseStatusEnum valueOf(String name) =>
      _$livenessResponseStatusEnumValueOf(name);
}
