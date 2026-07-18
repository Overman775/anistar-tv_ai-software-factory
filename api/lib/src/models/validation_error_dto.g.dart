// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'validation_error_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ValidationErrorDto _$ValidationErrorDtoFromJson(Map<String, dynamic> json) =>
    _ValidationErrorDto(
      loc: json['loc'] as List<dynamic>,
      msg: json['msg'] as String,
      type: json['type'] as String,
      input: json['input'],
      ctx: json['ctx'],
    );

Map<String, dynamic> _$ValidationErrorDtoToJson(_ValidationErrorDto instance) =>
    <String, dynamic>{
      'loc': instance.loc,
      'msg': instance.msg,
      'type': instance.type,
      'input': instance.input,
      'ctx': instance.ctx,
    };
