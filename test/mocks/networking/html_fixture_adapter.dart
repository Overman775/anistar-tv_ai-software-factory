import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

final class HtmlFixtureAdapter implements HttpClientAdapter {
  final Map<String, String> responses;
  final List<RequestOptions> requests = [];
  final int statusCode;
  final Map<String, List<String>> responseHeaders;
  bool _closed = false;

  bool get isClosed => _closed;

  HtmlFixtureAdapter(this.responses, {this.statusCode = 200, this.responseHeaders = const {}});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (_closed) {
      throw StateError('Fixture adapter is closed');
    }
    requests.add(options);
    final html = responses[options.uri.path];

    return ResponseBody.fromBytes(
      utf8.encode(html ?? 'Not found'),
      html == null ? 404 : statusCode,
      headers: {
        'content-type': ['text/html; charset=UTF-8'],
        ...responseHeaders,
      },
    );
  }

  @override
  void close({bool force = false}) {
    _closed = true;
  }
}
