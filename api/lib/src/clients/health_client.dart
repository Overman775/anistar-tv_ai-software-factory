// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/liveness_response_dto.dart';
import '../models/readiness_response_dto.dart';

part 'health_client.g.dart';

@RestApi()
abstract class HealthClient {
  factory HealthClient(Dio dio, {String? baseUrl}) = _HealthClient;

  /// Check process liveness.
  ///
  /// Does not contact AniStar. Use this endpoint for container health checks.
  @GET('/live')
  Future<LivenessResponseDto> getLive();

  /// Check AniStar readiness.
  ///
  /// Returns HTTP 503 when the upstream dependency is unavailable.
  @GET('/ready')
  Future<ReadinessResponseDto> getReady();
}
