import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

/// Logs transport diagnostics while never exposing credentials or signed URLs.
final class DioLoggingInterceptor extends Interceptor {
  static const _requestStopwatchKey = 'app_logger.request_stopwatch';
  static const _permittedHeaders = {
    'accept',
    'content-type',
    'content-length',
    'user-agent',
  };

  final Logger _logger;

  DioLoggingInterceptor(this._logger);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_requestStopwatchKey] = Stopwatch()..start();
    _logger.d(
      'Dio request ${options.method} ${_safeUri(options.uri)} headers=${_safeHeaders(options.headers)}',
    );
    handler.next(options);
  }

  @override
  void onResponse(
    // ignore: avoid-dynamic, required by Dio's interceptor API.
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    final request = response.requestOptions;
    _logger.d(
      'Dio response ${response.statusCode} ${request.method} ${_safeUri(request.uri)} (${_elapsed(request)}ms)',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final request = err.requestOptions;
    _logger.e(
      'Dio error ${err.response?.statusCode ?? err.type.name} ${request.method} ${_safeUri(request.uri)} (${_elapsed(request)}ms)',
      error: err,
      stackTrace: err.stackTrace,
    );
    handler.next(err);
  }

  Uri _safeUri(Uri uri) => uri.replace(query: null, fragment: null);

  int _elapsed(RequestOptions options) {
    final stopwatch = options.extra[_requestStopwatchKey];

    return stopwatch is Stopwatch ? stopwatch.elapsedMilliseconds : 0;
  }

  Map<String, Object?> _safeHeaders(Map<String, dynamic> headers) =>
      Map.unmodifiable({
        for (final entry in headers.entries)
          entry.key: _permittedHeaders.contains(entry.key.toLowerCase())
              ? entry.value
              : '<redacted>',
      });
}
