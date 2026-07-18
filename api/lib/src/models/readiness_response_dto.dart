// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'anistar_dto.dart';
import 'status_dto.dart';

part 'readiness_response_dto.freezed.dart';
part 'readiness_response_dto.g.dart';

/// Dependency-aware readiness state.
@Freezed()
abstract class ReadinessResponseDto with _$ReadinessResponseDto {
  const factory ReadinessResponseDto({
    required StatusDto status,
    required String service,
    required AnistarDto anistar,
    required String timestamp,
  }) = _ReadinessResponseDto;

  factory ReadinessResponseDto.fromJson(Map<String, Object?> json) =>
      _$ReadinessResponseDtoFromJson(json);
}
