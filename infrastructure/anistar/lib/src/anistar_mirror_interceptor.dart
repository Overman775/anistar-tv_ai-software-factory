import 'dart:async';

import 'package:dio/dio.dart';

import 'anistar_failure.dart';
import 'anistar_mirror_manager.dart';

/// Discovers a new origin but never replays credentials or mutations there.
final class AnistarMirrorInterceptor extends Interceptor {
  final AnistarMirrorManager _manager;

  AnistarMirrorInterceptor(this._manager);

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) => unawaited(_recover(err, handler));

  @override
  void onResponse(Response<Object?> response, ResponseInterceptorHandler handler) {
    final uri = response.requestOptions.uri;
    final status = response.statusCode ?? 0;
    final location = response.headers.value('location');
    final redirected = status >= 300 && status < 400 && location != null && uri.resolve(location).origin != uri.origin;
    if (response.headers.value('cf-mitigated') != 'challenge' && !redirected) {
      handler.next(response);

      return;
    }
    unawaited(_challenge(response, handler));
  }

  Future<void> _challenge(Response<Object?> response, ResponseInterceptorHandler handler) async {
    Object failure = const AnistarFailure(message: 'AniStar изменил зеркало или ограничил доступ. Повторите вход.');
    try {
      await _manager.recover(response.requestOptions.uri);
    } on AnistarFailure catch (error) {
      failure = error;
    } on Object {
      failure = const AnistarFailure(message: 'Не удалось проверить зеркало AniStar. Повторите запрос.');
    }
    handler.reject(DioException(requestOptions: response.requestOptions, response: response, error: failure));
  }

  Future<void> _recover(DioException error, ErrorInterceptorHandler handler) async {
    final status = error.response?.statusCode;
    final unavailable =
        error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        status == 403 ||
        status == 451 ||
        (status != null && status >= 300 && status < 400) ||
        (status != null && status >= 500);
    if (!unavailable || error.error is AnistarFailure) {
      handler.next(error);

      return;
    }
    try {
      await _manager.recover(error.requestOptions.uri);
      handler.next(error);
    } on AnistarFailure catch (failure) {
      handler.next(DioException(requestOptions: error.requestOptions, response: error.response, error: failure));
    } on Object {
      handler.next(error);
    }
  }
}
