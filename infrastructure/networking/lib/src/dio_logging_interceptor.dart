import 'package:app_logging/app_logging.dart';
import 'package:dio/dio.dart';

/// Logs transport diagnostics while never exposing credentials or signed URLs.
final class DioLoggingInterceptor extends Interceptor {
  static const _requestStopwatchKey = 'app_logger.request_stopwatch';
  static const _requestIdKey = 'app_logger.request_id';
  static const _permittedHeaders = {'accept', 'content-type', 'content-length', 'user-agent'};
  final Logger _logger;
  final Set<String> _publicPaths;
  int _nextRequestId = 0;

  DioLoggingInterceptor(this._logger, {Set<String> publicPaths = const {}})
    : _publicPaths = Set.unmodifiable(publicPaths);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_requestStopwatchKey] = Stopwatch()..start();
    options.extra[_requestIdKey] = ++_nextRequestId;
    _logger.d(
      'Dio request ${options.method} ${_safeUri(options.uri)} [#${options.extra[_requestIdKey]}] '
      'headers=${_safeHeaders(options.headers)}',
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
      'Dio response ${response.statusCode} ${request.method} ${_safeUri(request.uri)} '
      '[#${request.extra[_requestIdKey]}] (${_elapsed(request)}ms) '
      'content-type=${response.headers.value('content-type')} content-length=${response.headers.value('content-length')}',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final request = err.requestOptions;
    _logger.log(
      err.type == DioExceptionType.cancel ? Level.debug : Level.error,
      'Dio error ${err.response?.statusCode ?? err.type.name} ${request.method} ${_safeUri(request.uri)} '
      '[#${request.extra[_requestIdKey]}] (${_elapsed(request)}ms)',
      error: err.type.name,
    );
    handler.next(err);
  }

  /// Only known public endpoints may expose a path; signed URLs expose the origin.
  Uri _safeUri(Uri uri) => Uri(
    scheme: uri.scheme,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
    path: _publicPaths.contains(uri.path) ? uri.path : null,
  );

  int _elapsed(RequestOptions options) {
    final stopwatch = options.extra[_requestStopwatchKey];

    return stopwatch is Stopwatch ? stopwatch.elapsedMilliseconds : 0;
  }

  Map<String, Object?> _safeHeaders(Map<String, dynamic> headers) => Map.unmodifiable({
    for (final entry in headers.entries)
      entry.key: _permittedHeaders.contains(entry.key.toLowerCase()) ? entry.value : '<redacted>',
  });
}
