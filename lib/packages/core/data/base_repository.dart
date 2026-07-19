import 'package:app_logger/app_logger.dart';
import 'package:dio/dio.dart';

import '../domain/either.dart';
import '../domain/failure.dart';

abstract base class BaseRepository {
  final Logger _logger;

  BaseRepository([Logger? logger]) : _logger = logger ?? Logger(level: Level.off);

  Future<Either<Failure, T>> makeApiCall<T>(Future<T> Function() request) async {
    try {
      return Either.right(await request());
    } on DioException catch (error, stackTrace) {
      final failure = _mapDioException(error, stackTrace);

      return Either.left(failure);
    } on Failure catch (failure) {
      return Either.left(failure);
    } on Object catch (error, stackTrace) {
      _logger.errorFor<BaseRepository>('Unexpected repository error', error: error, stackTrace: stackTrace);

      return Either.left(UnknownFailure(cause: error, stackTrace: stackTrace));
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
    final serverMessage = _serverMessage(error);
    if (serverMessage != null) {
      return RequestFailure(message: serverMessage, cause: error, stackTrace: stackTrace);
    }
    if (statusCode == 400) {
      return RequestFailure(
        message: 'Сессия просмотра устарела. Запустите серию ещё раз.',
        cause: error,
        stackTrace: stackTrace,
      );
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
    if (data is! Map<String, Object?>) return null;
    final detail = data['detail'];
    if (detail is! String) return null;
    final message = detail.trim();

    return message.isNotEmpty ? message : null;
  }
}
