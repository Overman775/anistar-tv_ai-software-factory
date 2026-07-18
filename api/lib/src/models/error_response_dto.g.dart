// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'error_response_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ErrorResponseDto _$ErrorResponseDtoFromJson(Map<String, dynamic> json) =>
    _ErrorResponseDto(
      error: json['error'] as String,
      detail: json['detail'] as String,
      path: json['path'] as String,
    );

Map<String, dynamic> _$ErrorResponseDtoToJson(_ErrorResponseDto instance) =>
    <String, dynamic>{
      'error': instance.error,
      'detail': instance.detail,
      'path': instance.path,
    };
