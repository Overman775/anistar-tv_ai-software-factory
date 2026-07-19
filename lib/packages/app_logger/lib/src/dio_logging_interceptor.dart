import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

/// Logs transport diagnostics while never exposing credentials or signed URLs.
final class DioLoggingInterceptor extends Interceptor {
  static const _sensitiveHeaders = {
    'authorization',
    'cookie',
    'set-cookie',
    'x-api-token',
  };

  final Logger _logger;

  DioLoggingInterceptor(this._logger);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
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
      'Dio response ${response.statusCode} ${request.method} ${_safeUri(request.uri)}',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final request = err.requestOptions;
    _logger.e(
      'Dio error ${err.response?.statusCode ?? err.type.name} ${request.method} ${_safeUri(request.uri)}',
      error: err,
      stackTrace: err.stackTrace,
    );
    handler.next(err);
  }

  Uri _safeUri(Uri uri) => uri.replace(query: null, fragment: null);

  Map<String, Object?> _safeHeaders(Map<String, dynamic> headers) =>
      Map.unmodifiable({
        for (final entry in headers.entries)
          entry.key: _sensitiveHeaders.contains(entry.key.toLowerCase())
              ? '<redacted>'
              : entry.value,
      });
}
