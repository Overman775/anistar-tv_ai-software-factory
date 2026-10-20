import 'dart:math';

import 'package:app_logging/app_logging.dart';
import 'package:dio/dio.dart';
import 'package:dio_smart_retry/dio_smart_retry.dart';

import 'dio_logging_interceptor.dart';
import 'network_config.dart';

/// Creates a neutral HTTP transport with bounded retries and safe logging.
abstract final class DioClient {
  /// A GET can mutate upstream state. Such requests must opt out of transport retry.
  static Options withoutRetry(Options options) => options..disableRetry = true;

  static Dio create({
    required NetworkConfig config,
    required Logger logger,
    List<Interceptor> interceptors = const [],
    bool enableRetry = true,
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: config.baseUri.toString(),
        connectTimeout: config.connectTimeout,
        receiveTimeout: config.receiveTimeout,
        sendTimeout: config.sendTimeout,
      ),
    );

    if (enableRetry) {
      dio.interceptors.add(_RetryInterceptor(dio: dio));
    }
    dio.interceptors
      ..addAll(interceptors)
      ..add(DioLoggingInterceptor(logger, publicPaths: config.loggablePaths));

    return dio;
  }

  /// Inserts session/header interceptors before logging to preserve diagnostic order.
  static void addInterceptors(Dio dio, List<Interceptor> interceptors) {
    final loggingIndex = dio.interceptors.indexWhere((interceptor) => interceptor is DioLoggingInterceptor);
    dio.interceptors.insertAll(loggingIndex < 0 ? dio.interceptors.length : loggingIndex, interceptors);
  }
}

final class _RetryInterceptor extends RetryInterceptor {
  static final _random = Random();

  static List<Duration> get _retryDelays => [
    Duration(milliseconds: _random.nextInt(500) + 500),
    Duration(milliseconds: _random.nextInt(1000) + 1500),
  ];

  // The dependency's retry messages include the complete request path.
  // DioLoggingInterceptor already records each attempt without credentials.
  _RetryInterceptor({required super.dio}) : super(retryDelays: _retryDelays, retryEvaluator: _shouldRetry);

  static bool _shouldRetry(DioException error, int attempt) {
    if (error.type == DioExceptionType.cancel || error.response?.statusCode == 401) {
      return false;
    }

    final isIdempotent = switch (error.requestOptions.method) {
      'GET' || 'HEAD' || 'OPTIONS' || 'PUT' => true,
      _ => false,
    };
    if (!isIdempotent) {
      return false;
    }

    final statusCode = error.response?.statusCode;
    if (statusCode == 429 || statusCode == 503) {
      return true;
    }

    return error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError ||
        statusCode == 408 ||
        (statusCode != null && 500 <= statusCode && statusCode <= 599);
  }
}
