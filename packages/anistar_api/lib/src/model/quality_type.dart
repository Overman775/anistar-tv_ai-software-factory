//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'quality_type.g.dart';

class QualityType extends EnumClass {
  /// Available video qualities on AniStar.  AniStar provides only two quality options: - 360p: Lower quality, smaller file size - 720p: HD quality (default and recommended)
  @BuiltValueEnumConst(wireName: r'360')
  static const QualityType n360 = _$n360;

  /// Available video qualities on AniStar.  AniStar provides only two quality options: - 360p: Lower quality, smaller file size - 720p: HD quality (default and recommended)
  @BuiltValueEnumConst(wireName: r'720')
  static const QualityType n720 = _$n720;

  static Serializer<QualityType> get serializer => _$qualityTypeSerializer;

  const QualityType._(String name) : super(name);

  static BuiltSet<QualityType> get values => _$values;
  static QualityType valueOf(String name) => _$valueOf(name);
}

/// Optionally, enum_class can generate a mixin to go with your enum for use
/// with Angular. It exposes your enum constants as getters. So, if you mix it
/// in to your Dart component class, the values become available to the
/// corresponding Angular template.
///
/// Trigger mixin generation by writing a line like this one next to your enum.
abstract class QualityTypeMixin = Object with _$QualityTypeMixin;
