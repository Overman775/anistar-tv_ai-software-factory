import 'package:core/data.dart';
import 'package:dio/dio.dart';
import 'package:networking/networking.dart';

import 'anistar_failure.dart';
import 'anistar_html_parser.dart';
import 'anistar_search_html.dart';
import 'contract/anistar_catalog_page_dto.dart';
import 'html_decoder.dart';
import 'html_form_encoder.dart';

/// One active query and its last server-confirmed continuation.
final class AnistarSearchSource {
  final Dio _dio;
  final Uri _origin;
  final int Function()? _accessGeneration;
  String? _query;
  AnistarSearchForm? _continuation;
  int _nextPage = 1;
  int _generation = 0;
  int? _queryAccessGeneration;
  CancelToken? _active;

  AnistarSearchSource(this._dio, this._accessGeneration) : _origin = Uri.parse(_dio.options.baseUrl);

  Future<AnistarCatalogPageDto> search(String query, {int page = 1, RequestCancellation? cancellation}) async {
    final value = query.trim();
    final length = value.runes.length;
    if (page < 1 || length > 120) {
      throw const AnistarFailure(message: 'Некорректные параметры поиска.');
    }
    if (value.isNotEmpty && length < 4) {
      throw const AnistarFailure(message: 'Введите не менее 4 символов.');
    }
    if (page == 1) {
      _generation++;
      _active?.cancel();
      _query = value;
      _queryAccessGeneration = _accessGeneration?.call();
      _continuation = null;
      _nextPage = 1;
    } else if (_query != value ||
        _nextPage != page ||
        _continuation == null ||
        _queryAccessGeneration != _accessGeneration?.call()) {
      throw const AnistarFailure(message: 'Продолжение поиска больше недоступно. Выполните поиск снова.');
    }
    final generation = _generation;
    _checkCurrent(generation, cancellation);
    if (value.isEmpty) {
      return AnistarCatalogPageDto(items: const [], page: page, hasNext: false);
    }
    final cancelToken = CancelToken();
    _active = cancelToken;
    final unregister = cancellation?.onCancel(cancelToken.cancel);
    try {
      final AnistarSearchForm form;
      if (page == 1) {
        final response = await _page(_origin, cancelToken);
        _checkCurrent(generation, cancellation);
        form = AnistarSearchHtml.form(response.source, response.uri, response.contentType);
      } else {
        form =
            _continuation ??
            (throw const AnistarFailure(message: 'Продолжение поиска больше недоступно. Выполните поиск снова.'));
      }
      final fields = <String, String>{
        ...form.fields,
        'story': value,
        if (page > 1) ...{'search_start': '$page', 'result_from': '${(page - 1) * 10 + 1}'},
      };
      final body = HtmlFormEncoder.encode(
        fields,
        form.contentType,
        characterError: 'Этот символ нельзя передать в поиске AniStar.',
      );
      _checkCurrent(generation, cancellation);
      final response = await _page(form.action, cancelToken, body: body, contentType: form.contentType);
      _checkCurrent(generation, cancellation);
      final result = AnistarHtmlParser(_origin).search(response.source, page);
      final responseForm = result.items.isNotEmpty || result.hasNext
          ? AnistarSearchHtml.form(
              response.source,
              response.uri,
              response.contentType,
              continuation: true,
              query: value,
            )
          : null;
      _checkCurrent(generation, cancellation);
      _continuation = result.hasNext ? responseForm : null;
      _nextPage = page + 1;

      return result;
    } finally {
      unregister?.call();
      if (identical(_active, cancelToken)) {
        _active = null;
      }
    }
  }

  void _checkCurrent(int generation, RequestCancellation? cancellation) {
    if (generation != _generation ||
        cancellation?.isCancelled == true ||
        _queryAccessGeneration != _accessGeneration?.call()) {
      throw const AnistarFailure(message: 'Поиск отменён.');
    }
  }

  Future<({String source, String? contentType, Uri uri})> _page(
    Uri uri,
    CancelToken cancellation, {
    String? body,
    String? contentType,
  }) async {
    if (uri.scheme != 'https' || uri.userInfo.isNotEmpty || uri.origin != _origin.origin) {
      throw const AnistarFailure(message: 'AniStar вернул небезопасный адрес поиска.');
    }
    final response = await _dio.request<List<int>>(
      uri.toString(),
      data: body,
      cancelToken: cancellation,
      options: DioClient.withoutRetry(
        Options(
          method: body == null ? 'GET' : 'POST',
          responseType: ResponseType.bytes,
          followRedirects: false,
          headers: {
            'Accept': 'text/html',
            'User-Agent': 'AniStarTV/1.0',
            'Cache-Control': 'no-cache',
            if (body != null) ...{
              'Content-Type': 'application/x-www-form-urlencoded; $contentType',
              'Referer': _origin.toString(),
            },
          },
        ),
      ),
    );
    if (response.headers.value('cf-mitigated') == 'challenge') {
      throw const AnistarFailure(message: 'AniStar требует проверку браузера. Попробуйте другое зеркало.');
    }
    final bytes = response.data;
    if (bytes == null || bytes.isEmpty) {
      throw const AnistarFailure(message: 'AniStar вернул пустую страницу поиска.');
    }
    final type = response.headers.value('content-type');
    final charset = AnistarSearchHtml.charsetOf(type);

    return (source: HtmlDecoder.decode(bytes, charset), contentType: type, uri: response.requestOptions.uri);
  }
}
