// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

part 'liveness_response_dto.freezed.dart';
part 'liveness_response_dto.g.dart';

/// Process health independent of AniStar availability.
@Freezed()
abstract class LivenessResponseDto with _$LivenessResponseDto {
  const factory LivenessResponseDto({
    required String service,
    required String timestamp,
    @Default('ok') String status,
  }) = _LivenessResponseDto;

  factory LivenessResponseDto.fromJson(Map<String, Object?> json) =>
      _$LivenessResponseDtoFromJson(json);
}
