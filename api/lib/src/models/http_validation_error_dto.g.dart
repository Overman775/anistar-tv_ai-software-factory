// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'http_validation_error_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_HttpValidationErrorDto _$HttpValidationErrorDtoFromJson(
  Map<String, dynamic> json,
) => _HttpValidationErrorDto(
  detail: (json['detail'] as List<dynamic>?)
      ?.map((e) => ValidationErrorDto.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$HttpValidationErrorDtoToJson(
  _HttpValidationErrorDto instance,
) => <String, dynamic>{'detail': instance.detail};
