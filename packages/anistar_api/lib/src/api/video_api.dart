//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

import 'dart:async';

import 'package:built_value/json_object.dart';
import 'package:built_value/serializer.dart';
import 'package:dio/dio.dart';

import 'dart:typed_data';
import 'package:anistar_api/src/api_util.dart';
import 'package:anistar_api/src/model/error_response.dart';
import 'package:anistar_api/src/model/http_validation_error.dart';
import 'package:anistar_api/src/model/playback_info.dart';
import 'package:anistar_api/src/model/quality_type.dart';

class VideoApi {
  final Dio _dio;

  final Serializers _serializers;

  const VideoApi(this._dio, this._serializers);

  /// Get a rewritten HLS manifest
  /// Returns an HLS manifest whose resources use short-lived signed API paths.
  ///
  /// Parameters:
  /// * [animeId]
  /// * [episodeNumber]
  /// * [quality] - Preferred quality
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [String] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<String>> getHlsManifest({
    required int animeId,
    required int episodeNumber,
    QualityType? quality = QualityType.n720,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path =
        r'/api/video/{anime_id}/episodes/{episode_number}/manifest.m3u8'
            .replaceAll(
                '{' r'anime_id' '}',
                encodeQueryParameter(_serializers, animeId, const FullType(int))
                    .toString())
            .replaceAll(
                '{' r'episode_number' '}',
                encodeQueryParameter(
                        _serializers, episodeNumber, const FullType(int))
                    .toString());
    final _options = Options(
      method: r'GET',
      headers: <String, dynamic>{
        ...?headers,
      },
      extra: <String, dynamic>{
        'secure': <Map<String, String>>[],
        ...?extra,
      },
      validateStatus: validateStatus,
    );

    final _queryParameters = <String, dynamic>{
      if (quality != null)
        r'quality': encodeQueryParameter(
            _serializers, quality, const FullType(QualityType)),
    };

    final _response = await _dio.request<Object>(
      _path,
      options: _options,
      queryParameters: _queryParameters,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );

    String? _responseData;

    try {
      final rawResponse = _response.data;
      _responseData = rawResponse == null ? null : rawResponse as String;
    } catch (error, stackTrace) {
      throw DioException(
        requestOptions: _response.requestOptions,
        response: _response,
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    return Response<String>(
      data: _responseData,
      headers: _response.headers,
      isRedirect: _response.isRedirect,
      requestOptions: _response.requestOptions,
      redirects: _response.redirects,
      statusCode: _response.statusCode,
      statusMessage: _response.statusMessage,
      extra: _response.extra,
    );
  }

  /// Stream a signed HLS resource
  /// Used by URLs embedded in the rewritten manifest. Flutter applications normally do not call this operation directly.
  ///
  /// Parameters:
  /// * [animeId]
  /// * [episodeNumber]
  /// * [token]
  /// * [range] - Single HTTP byte range
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [Uint8List] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<Uint8List>> getHlsResource({
    required int animeId,
    required int episodeNumber,
    required String token,
    String? range,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path =
        r'/api/video/{anime_id}/episodes/{episode_number}/resources/{token}'
            .replaceAll(
                '{' r'anime_id' '}',
                encodeQueryParameter(_serializers, animeId, const FullType(int))
                    .toString())
            .replaceAll(
                '{' r'episode_number' '}',
                encodeQueryParameter(
                        _serializers, episodeNumber, const FullType(int))
                    .toString())
            .replaceAll(
                '{' r'token' '}',
                encodeQueryParameter(
                        _serializers, token, const FullType(String))
                    .toString());
    final _options = Options(
      method: r'GET',
      responseType: ResponseType.bytes,
      headers: <String, dynamic>{
        r'Range': range,
        ...?headers,
      },
      extra: <String, dynamic>{
        'secure': <Map<String, String>>[],
        ...?extra,
      },
      validateStatus: validateStatus,
    );

    final _response = await _dio.request<Object>(
      _path,
      options: _options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );

    Uint8List? _responseData;

    try {
      final rawResponse = _response.data;
      _responseData = rawResponse == null ? null : rawResponse as Uint8List;
    } catch (error, stackTrace) {
      throw DioException(
        requestOptions: _response.requestOptions,
        response: _response,
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    return Response<Uint8List>(
      data: _responseData,
      headers: _response.headers,
      isRedirect: _response.isRedirect,
      requestOptions: _response.requestOptions,
      redirects: _response.redirects,
      statusCode: _response.statusCode,
      statusMessage: _response.statusMessage,
      extra: _response.extra,
    );
  }

  /// Get HLS playback information
  /// Returns a JSON contract for Flutter. Resolve &#x60;manifest_path&#x60; against the API base URL and pass the resulting URL to an HLS-capable player.
  ///
  /// Parameters:
  /// * [animeId]
  /// * [episodeNumber]
  /// * [quality] - Preferred quality
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [PlaybackInfo] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<PlaybackInfo>> getPlaybackInfo({
    required int animeId,
    required int episodeNumber,
    QualityType? quality = QualityType.n720,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/api/video/{anime_id}/episodes/{episode_number}/playback'
        .replaceAll(
            '{' r'anime_id' '}',
            encodeQueryParameter(_serializers, animeId, const FullType(int))
                .toString())
        .replaceAll(
            '{' r'episode_number' '}',
            encodeQueryParameter(
                    _serializers, episodeNumber, const FullType(int))
                .toString());
    final _options = Options(
      method: r'GET',
      headers: <String, dynamic>{
        ...?headers,
      },
      extra: <String, dynamic>{
        'secure': <Map<String, String>>[],
        ...?extra,
      },
      validateStatus: validateStatus,
    );

    final _queryParameters = <String, dynamic>{
      if (quality != null)
        r'quality': encodeQueryParameter(
            _serializers, quality, const FullType(QualityType)),
    };

    final _response = await _dio.request<Object>(
      _path,
      options: _options,
      queryParameters: _queryParameters,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );

    PlaybackInfo? _responseData;

    try {
      final rawResponse = _response.data;
      _responseData = rawResponse == null
          ? null
          : _serializers.deserialize(
              rawResponse,
              specifiedType: const FullType(PlaybackInfo),
            ) as PlaybackInfo;
    } catch (error, stackTrace) {
      throw DioException(
        requestOptions: _response.requestOptions,
        response: _response,
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    return Response<PlaybackInfo>(
      data: _responseData,
      headers: _response.headers,
      isRedirect: _response.isRedirect,
      requestOptions: _response.requestOptions,
      redirects: _response.redirects,
      statusCode: _response.statusCode,
      statusMessage: _response.statusMessage,
      extra: _response.extra,
    );
  }
}
