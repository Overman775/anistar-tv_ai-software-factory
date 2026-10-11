import 'package:app_logging/app_logging.dart';
import 'package:core/data.dart';
import 'package:dio/dio.dart';

import 'network_failure.dart';

abstract base class BaseRepository {
  final Logger _logger;

  BaseRepository([Logger? logger]) : _logger = logger ?? Logger(level: Level.off);

  Future<Result<T, Failure>> makeApiCall<T>(Future<T> Function() request) async {
    try {
      return Result.success(await request());
    } on DioException catch (error, stackTrace) {
      final failure = _mapDioException(error, stackTrace);

      return Result.failure(failure);
    } on Failure catch (failure) {
      return Result.failure(failure);
    } on Object catch (error, stackTrace) {
      _logger.errorFor<BaseRepository>(
        'Unexpected repository error',
        error: error.runtimeType.toString(),
        stackTrace: stackTrace,
      );

      return Result.failure(UnknownFailure(cause: error, stackTrace: stackTrace));
    }
  }

  Failure _mapDioException(DioException error, StackTrace stackTrace) => switch (error.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout => TimeoutFailure(cause: error, stackTrace: stackTrace),
    DioExceptionType.connectionError ||
    DioExceptionType.cancel => ConnectionFailure(cause: error, stackTrace: stackTrace),
    DioExceptionType.badResponse => _mapResponse(error, stackTrace),
    DioExceptionType.badCertificate ||
    DioExceptionType.unknown ||
    _ => UnknownFailure(cause: error, stackTrace: stackTrace),
  };

  Failure _mapResponse(DioException error, StackTrace stackTrace) {
    final statusCode = error.response?.statusCode;
    if (statusCode == 403) {
      return RequestFailure(message: 'Доступ к ресурсу запрещён.', cause: error, stackTrace: stackTrace);
    }
    final serverMessage = _serverMessage(error);
    if (serverMessage != null) {
      return RequestFailure(message: serverMessage, cause: error, stackTrace: stackTrace);
    }
    if (statusCode == 400) {
      return RequestFailure(message: 'Сервер не принял параметры запроса.', cause: error, stackTrace: stackTrace);
    }
    if (statusCode == 404) {
      return RequestFailure(message: 'Запрошенные данные не найдены.', cause: error, stackTrace: stackTrace);
    }
    if (statusCode == 422) {
      return RequestFailure(message: 'Сервер не принял параметры запроса.', cause: error, stackTrace: stackTrace);
    }
    if (statusCode == 429) {
      return RequestFailure(message: 'Слишком много запросов. Повторите позже.', cause: error, stackTrace: stackTrace);
    }
    if (statusCode != null && 500 <= statusCode && statusCode <= 599) {
      return ServerFailure(cause: error, stackTrace: stackTrace);
    }

    return RequestFailure(message: 'Сервер отклонил запрос.', cause: error, stackTrace: stackTrace);
  }

  String? _serverMessage(DioException error) {
    final data = error.response?.data;
    if (data is! Map<String, Object?>) {
      return null;
    }
    final detail = data['detail'];
    if (detail is! String) {
      return null;
    }
    final message = detail.trim();

    return message.isNotEmpty ? message : null;
  }
}
