// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'validation_error_dto.dart';

part 'http_validation_error_dto.freezed.dart';
part 'http_validation_error_dto.g.dart';

@Freezed()
abstract class HttpValidationErrorDto with _$HttpValidationErrorDto {
  const factory HttpValidationErrorDto({List<ValidationErrorDto>? detail}) =
      _HttpValidationErrorDto;

  factory HttpValidationErrorDto.fromJson(Map<String, Object?> json) =>
      _$HttpValidationErrorDtoFromJson(json);
}
