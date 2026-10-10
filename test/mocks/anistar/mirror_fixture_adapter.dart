import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'anistar_fixtures.dart';

final class MirrorFixtureAdapter implements HttpClientAdapter {
  final Map<String, int> statuses;
  final List<RequestOptions> requests = [];
  String html = catalogHtml;
  bool challenge = false;
  String? location;
  bool _closed = false;

  MirrorFixtureAdapter(this.statuses);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (_closed) {
      throw StateError('Mirror fixture adapter closed');
    }
    requests.add(options);

    return ResponseBody.fromBytes(
      utf8.encode(html),
      statuses[options.uri.host] ?? 403,
      headers: {
        'content-type': ['text/html; charset=UTF-8'],
        if (challenge) 'cf-mitigated': ['challenge'],
        if (location case final String redirect) 'location': [redirect],
      },
    );
  }

  @override
  void close({bool force = false}) => _closed = true;
}
