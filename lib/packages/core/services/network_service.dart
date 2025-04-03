import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:dio_http2_adapter/dio_http2_adapter.dart';
import 'package:flutter/foundation.dart'; // For kDebugMode
import 'package:path_provider/path_provider.dart'; // To get temp directory for cookies

import '../../../utils/logger/logger.dart'; // Assuming logger instance is available here

/// A network service class built on Dio for handling HTTP requests.
/// Includes support for HTTP/2, cookie management, and logging.
class NetworkService {
  late final Dio _dio;
  late final CookieJar _cookieJar;

  /// Base URL for the API (replace with your actual base URL if needed)
  static const String _baseUrl = 'https://your.api.base.url'; // TODO: Configure this

  Dio get dio => _dio;

  /// Private constructor for Singleton pattern
  NetworkService._privateConstructor() {
    _initialize();
  }

  /// Singleton instance
  static final NetworkService _instance = NetworkService._privateConstructor();

  /// Factory constructor to return the singleton instance
  factory NetworkService() {
    return _instance;
  }

  Future<void> _initialize() async {
    final BaseOptions options = BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Accept': 'application/json',
        // Add other common headers here
      },
      // Validate status to handle different response codes if needed
      // validateStatus: (status) {
      //   return status != null && status >= 200 && status < 400;
      // },
    );

    _dio = Dio(options);

    // --- Cookie Management ---
    // Get a persistent storage directory for cookies
    final documentsDir = await getApplicationDocumentsDirectory();
    final cookiesPath = '${documentsDir.path}/.cookies/';
    _cookieJar = PersistCookieJar(
      ignoreExpires: true, // Store cookies even if they have expired
      storage: FileStorage(cookiesPath),
    );
    _dio.interceptors.add(CookieManager(_cookieJar));

    // --- HTTP/2 Adapter ---
    _dio.httpClientAdapter = Http2Adapter(
      ConnectionManager(
        idleTimeout: const Duration(seconds: 15),
        // Allow self-signed certificates in debug mode (use with caution!)
        onClientCreate: (uri, clientSetting) {
          // The 'clientSetting' parameter is of type ClientSetting
          // Assign a certificate validation callback based on the mode
          if (kDebugMode) {
            // In debug mode, accept all certificates (including self-signed)
            clientSetting.validateCertificate = (certificate, host, port) => true;
          } else {
            // In release mode, use the default validation (or assign a specific validation function if needed)
            clientSetting.validateCertificate = null; // Use default validation
          }
        },
      ),
    );

    // --- Logging Interceptor ---
    if (kDebugMode) {
      _dio.interceptors.add(_LoggingInterceptor());
    }

    // --- Other Interceptors (e.g., for Auth Tokens) ---
    // _dio.interceptors.add(AuthInterceptor()); // Example
  }

  // --- Example Request Methods ---

  /// Performs a GET request.
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      final response = await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      );
      return response;
    } on DioException catch (e) {
      logger.e('Dio GET Error: ${e.requestOptions.path}', error: e, stackTrace: e.stackTrace);
      // Handle or rethrow the error as needed
      rethrow;
    } catch (e, stackTrace) {
      logger.e('Unexpected GET Error: $path', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Performs a POST request.
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      final response = await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
      return response;
    } on DioException catch (e) {
      logger.e('Dio POST Error: ${e.requestOptions.path}', error: e, stackTrace: e.stackTrace);
      rethrow;
    } catch (e, stackTrace) {
      logger.e('Unexpected POST Error: $path', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // Add other methods like PUT, DELETE, PATCH as needed
}

/// Custom Interceptor for logging Dio requests and responses.
class _LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    logger.t(
      '--> ${options.method.toUpperCase()} ${options.uri}\n'
      'Headers: ${options.headers.map((k, v) => MapEntry(k, v)).toString()}\n'
      'Query Parameters: ${options.queryParameters}\n'
      'Data: ${options.data}',
    );
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    // Format headers for logging
    final headersString = response.headers.map.entries
        .map((entry) => '${entry.key}: ${entry.value.join(', ')}')
        .join('\n  ');
    logger.t(
      '<-- ${response.statusCode} ${response.requestOptions.method.toUpperCase()} ${response.requestOptions.uri}\n'
      'Headers:\n  $headersString\n'
      'Response: ${response.data}',
    );
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    logger.e(
      '<-- ${err.response?.statusCode ?? 'ERROR'} ${err.requestOptions.method.toUpperCase()} ${err.requestOptions.uri}\n'
      'Error: ${err.error}\n'
      'Message: ${err.message}',
      error: err.error,
      stackTrace: err.stackTrace,
    );
    super.onError(err, handler);
  }
}

// --- Example Usage (can be removed or placed elsewhere) ---
// void main() async {
//   // Ensure Flutter bindings are initialized if running standalone
//   // WidgetsFlutterBinding.ensureInitialized();
//
//   final networkService = NetworkService();
//
//   try {
//     // Example GET request
//     final response = await networkService.get('/posts/1'); // Example path
//     logger.i('GET Response data: ${response.data}');
//
//     // Example POST request
//     // final postResponse = await networkService.post('/posts', data: {'title': 'foo', 'body': 'bar', 'userId': 1});
//     // logger.i('POST Response data: ${postResponse.data}');
//
//   } catch (e) {
//     logger.e('Network request failed', error: e);
//   }
// }
