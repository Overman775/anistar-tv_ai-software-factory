// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

/// Available video qualities on AniStar.
///
/// AniStar provides only two quality options:.
/// - 360p: Lower quality, smaller file size.
/// - 720p: HD quality (default and recommended).
@JsonEnum()
enum QualityTypeDto {
  @JsonValue('360')
  value360('360'),
  @JsonValue('720')
  value720('720'),

  /// Default value for all unparsed values, allows backward compatibility when adding new values on the backend.
  $unknown(null);

  const QualityTypeDto(this.json);

  factory QualityTypeDto.fromJson(String json) =>
      values.firstWhere((e) => e.json == json, orElse: () => $unknown);

  final String? json;

  @override
  String toString() => json?.toString() ?? super.toString();

  /// Returns all defined enum values excluding the $unknown value.
  static List<QualityTypeDto> get $valuesDefined =>
      values.where((value) => value != $unknown).toList();
}
