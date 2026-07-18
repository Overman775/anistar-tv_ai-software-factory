// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'readiness_response_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ReadinessResponseDto _$ReadinessResponseDtoFromJson(
  Map<String, dynamic> json,
) => _ReadinessResponseDto(
  status: StatusDto.fromJson(json['status'] as String),
  service: json['service'] as String,
  anistar: AnistarDto.fromJson(json['anistar'] as String),
  timestamp: json['timestamp'] as String,
);

Map<String, dynamic> _$ReadinessResponseDtoToJson(
  _ReadinessResponseDto instance,
) => <String, dynamic>{
  'status': _$StatusDtoEnumMap[instance.status]!,
  'service': instance.service,
  'anistar': _$AnistarDtoEnumMap[instance.anistar]!,
  'timestamp': instance.timestamp,
};

const _$StatusDtoEnumMap = {
  StatusDto.ok: 'ok',
  StatusDto.degraded: 'degraded',
  StatusDto.$unknown: r'$unknown',
};

const _$AnistarDtoEnumMap = {
  AnistarDto.ok: 'ok',
  AnistarDto.degraded: 'degraded',
  AnistarDto.unreachable: 'unreachable',
  AnistarDto.$unknown: r'$unknown',
};
