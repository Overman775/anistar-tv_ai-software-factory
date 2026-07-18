// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'liveness_response_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_LivenessResponseDto _$LivenessResponseDtoFromJson(Map<String, dynamic> json) =>
    _LivenessResponseDto(
      service: json['service'] as String,
      timestamp: json['timestamp'] as String,
      status: json['status'] as String? ?? 'ok',
    );

Map<String, dynamic> _$LivenessResponseDtoToJson(
  _LivenessResponseDto instance,
) => <String, dynamic>{
  'service': instance.service,
  'timestamp': instance.timestamp,
  'status': instance.status,
};
