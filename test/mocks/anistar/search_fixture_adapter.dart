import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'auth_fixture_adapter.dart';

const searchHomeForm = '''
<form method="post" action="/" accept-charset="windows-1251">
<input type="hidden" name="do" value="search"><input type="hidden" name="subaction" value="search">
<input name="story"></form>''';

String searchResultsHtml(String query, {int page = 1, bool hasNext = true}) =>
    '''
<form id="fullsearch" method="post" action="/index.php?do=search" accept-charset="windows-1251">
<input type="hidden" name="do" value="search"><input type="hidden" name="subaction" value="search">
<input type="hidden" name="search_start" value="$page"><input type="hidden" name="result_from" value="${(page - 1) * 10 + 1}">
<input type="hidden" name="full_search" value="0"><input name="story" value="$query"></form>
<div id="dle-content">${[9493, page, page + 1, page].map((id) => '<div class="short news"><div class="news_header"><div class="title_left"><a href="/$id-anime.html">Anime $id</a></div></div></div>').join()}</div>
${hasNext ? '<div class="pagenav"><a href="#" onclick="list_submit(${page + 1}); return false;">${page + 1}</a></div>' : ''}
''';

final class SearchFixtureAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  final AuthFixtureAdapter auth = AuthFixtureAdapter();
  final Future<ResponseBody> Function(RequestOptions)? respond;
  String query;
  String home = searchHomeForm;
  int postStatus = 200;

  SearchFixtureAdapter({this.query = 'Наруто', this.respond});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (options.uri.path == '/anime/' || (options.data?.toString().contains('login_name=') ?? false)) {
      return auth.fetch(options, requestStream, cancelFuture);
    }
    if (respond case final handler?) {
      return handler(options);
    }
    if (options.method == 'GET') {
      return response(home);
    }
    final match = RegExp(r'(?:^|&)search_start=(\d+)').firstMatch(options.data.toString());
    final page = int.tryParse(match?.group(1) ?? '') ?? 1;

    return response(
      searchResultsHtml(query, page: page, hasNext: page == 1),
      status: postStatus,
    );
  }

  static ResponseBody response(String source, {int status = 200, String contentType = 'text/html; charset=UTF-8'}) =>
      ResponseBody.fromBytes(
        utf8.encode(source),
        status,
        headers: {
          'content-type': [contentType],
        },
      );

  @override
  // The fixture has no sockets, streams, or other disposable transport resources.
  // ignore: no-empty-block
  void close({bool force = false}) {
    // This in-memory adapter owns no transport resources.
  }
}
