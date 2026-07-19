import 'dart:math';

import 'package:app_logger/app_logger.dart';
import 'package:dio/dio.dart';
import 'package:dio_smart_retry/dio_smart_retry.dart';

import 'network_config.dart';

/// Creates the single configured Dio instance used by generated API clients.
abstract final class DioClient {
  static Dio create({
    required NetworkConfig config,
    required Logger logger,
    List<Interceptor> interceptors = const [],
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: config.baseUri.toString(),
        connectTimeout: config.connectTimeout,
        receiveTimeout: config.receiveTimeout,
        sendTimeout: config.sendTimeout,
        headers: const {'Accept': 'application/json', 'Content-Type': 'application/json'},
      ),
    );

    dio.interceptors
      ..add(_RetryInterceptor(dio: dio, logger: logger))
      ..add(DioLoggingInterceptor(logger))
      ..addAll(interceptors);

    return dio;
  }
}

final class _RetryInterceptor extends RetryInterceptor {
  static final _random = Random();

  static List<Duration> get _retryDelays => [
    Duration(milliseconds: _random.nextInt(500) + 500),
    Duration(milliseconds: _random.nextInt(1000) + 1500),
  ];

  _RetryInterceptor({required super.dio, required Logger logger})
    : super(retryDelays: _retryDelays, logPrint: logger.d, retryEvaluator: _shouldRetry);

  static bool _shouldRetry(DioException error, int attempt) {
    if (error.type == DioExceptionType.cancel || error.response?.statusCode == 401) return false;

    final isIdempotent = switch (error.requestOptions.method) {
      'GET' || 'HEAD' || 'OPTIONS' || 'PUT' => true,
      _ => false,
    };
    if (!isIdempotent) return false;

    final statusCode = error.response?.statusCode;
    if (statusCode == 429 || statusCode == 503) return true;

    return error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError ||
        statusCode == 408 ||
        (statusCode != null && 500 <= statusCode && statusCode <= 599);
  }
}
