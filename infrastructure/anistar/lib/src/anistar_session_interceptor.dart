import 'dart:async';

import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html;

import 'anistar_auth_html.dart';
import 'anistar_failure.dart';
import 'anistar_session.dart';
import 'html_decoder.dart';

final class AnistarSessionInterceptor extends Interceptor {
  final AnistarSession _session;

  AnistarSessionInterceptor(this._session);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) => unawaited(_request(options, handler));

  @override
  void onResponse(Response<Object?> response, ResponseInterceptorHandler handler) =>
      unawaited(_response(response, handler));

  Future<void> _request(RequestOptions options, RequestInterceptorHandler handler) async {
    try {
      if (_session.owns(options.uri)) {
        options.followRedirects = false;
        var cookie = await _session.cookieHeader(options.uri);
        final sort = options.extra['anistarSortCookies'];
        if (sort is Map<String, String>) {
          final existing = (cookie ?? '')
              .split('; ')
              .where((part) => part.isNotEmpty && !sort.containsKey(part.split('=').first));
          cookie = [...existing, ...sort.entries.map((entry) => '${entry.key}=${entry.value}')].join('; ');
        }
        options.extra['anistarGeneration'] = _session.generation;
        if (cookie != null) {
          options.headers['Cookie'] = cookie;
        } else {
          options.headers.remove('Cookie');
        }
      } else {
        options.headers.remove('Cookie');
      }
      handler.next(options);
    } on Object {
      handler.reject(
        DioException(
          requestOptions: options,
          error: const AnistarFailure(message: 'Не удалось прочитать защищённую сессию. Повторите попытку.'),
        ),
      );
    }
  }

  Future<void> _response(Response<Object?> response, ResponseInterceptorHandler handler) async {
    final options = response.requestOptions;
    try {
      if (_session.owns(options.uri)) {
        final generation = options.extra['anistarGeneration'];
        if (generation is! int || generation != _session.generation) {
          throw const AnistarFailure(message: 'Запрос относится к завершённой сессии.');
        }
        final sort = options.extra['anistarSortCookies'];
        final cookies = (response.headers['set-cookie'] ?? const <String>[])
            .where((header) => sort is! Map<String, String> || !sort.containsKey(header.split('=').first))
            .toList(growable: false);
        await _session.saveCookies(options.uri, cookies, generation);
        if (generation != _session.generation) {
          throw const AnistarFailure(message: 'Запрос относится к завершённой сессии.');
        }
        final data = response.data;
        if (_session.account != null && options.extra['anistarAuth'] != true && data is List<int>) {
          final source = HtmlDecoder.decode(data, response.headers.value('content-type'));
          final document = html.parse(source);
          if (AnistarAuthHtml.isGuestDocument(document) &&
              !AnistarAuthHtml.isAuthenticatedDocument(document, _session.origin)) {
            await _session.clear(expired: true, expectedGeneration: generation);
            throw const AnistarFailure(message: 'Сессия AniStar истекла. Войдите снова.');
          }
        }
      }
      handler.next(response);
    } on Object {
      handler.reject(
        DioException(
          requestOptions: options,
          response: response,
          error: const AnistarFailure(message: 'Не удалось обновить сессию AniStar. Войдите снова.'),
        ),
      );
    }
  }
}
