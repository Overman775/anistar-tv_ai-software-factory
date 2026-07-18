// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

part 'error_response_dto.freezed.dart';
part 'error_response_dto.g.dart';

/// Error response.
@Freezed()
abstract class ErrorResponseDto with _$ErrorResponseDto {
  const factory ErrorResponseDto({
    /// Error type
    required String error,

    /// Error detail message
    required String detail,

    /// Request path
    required String path,
  }) = _ErrorResponseDto;

  factory ErrorResponseDto.fromJson(Map<String, Object?> json) =>
      _$ErrorResponseDtoFromJson(json);
}
