// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

part 'validation_error_dto.freezed.dart';
part 'validation_error_dto.g.dart';

@Freezed()
abstract class ValidationErrorDto with _$ValidationErrorDto {
  const factory ValidationErrorDto({
    required List<dynamic> loc,
    required String msg,
    required String type,
    dynamic input,
    dynamic ctx,
  }) = _ValidationErrorDto;

  factory ValidationErrorDto.fromJson(Map<String, Object?> json) =>
      _$ValidationErrorDtoFromJson(json);
}
