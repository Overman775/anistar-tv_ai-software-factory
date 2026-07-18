// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quality_type.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const QualityType _$n360 = const QualityType._('n360');
const QualityType _$n720 = const QualityType._('n720');

QualityType _$valueOf(String name) {
  switch (name) {
    case 'n360':
      return _$n360;
    case 'n720':
      return _$n720;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<QualityType> _$values =
    BuiltSet<QualityType>(const <QualityType>[
  _$n360,
  _$n720,
]);

class _$QualityTypeMeta {
  const _$QualityTypeMeta();
  QualityType get n360 => _$n360;
  QualityType get n720 => _$n720;
  QualityType valueOf(String name) => _$valueOf(name);
  BuiltSet<QualityType> get values => _$values;
}

abstract class _$QualityTypeMixin {
  // ignore: non_constant_identifier_names
  _$QualityTypeMeta get QualityType => const _$QualityTypeMeta();
}

Serializer<QualityType> _$qualityTypeSerializer = _$QualityTypeSerializer();

class _$QualityTypeSerializer implements PrimitiveSerializer<QualityType> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'n360': '360',
    'n720': '720',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    '360': 'n360',
    '720': 'n720',
  };

  @override
  final Iterable<Type> types = const <Type>[QualityType];
  @override
  final String wireName = 'QualityType';

  @override
  Object serialize(Serializers serializers, QualityType object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  QualityType deserialize(Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      QualityType.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
