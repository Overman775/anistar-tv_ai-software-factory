import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

final class WatchedFixtureAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  final Set<int> watched = {};
  int mutationStatus = 200;
  bool persist = true;
  bool closed = false;
  bool missingMediaId = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (closed) {
      throw StateError('Fixture closed');
    }
    requests.add(options);
    if (options.uri.path == '/engine/ajax/ns.php') {
      if (persist && mutationStatus == 200) {
        final number = int.tryParse((options.queryParameters['vid'] as String).split('-').last);
        if (number != null) {
          watched.add(number);
        }
      }

      return ResponseBody.fromString('OK', mutationStatus);
    }
    final episodes = [2, 1].map(
      (number) =>
          "{title:'Серия $number',${missingMediaId ? '' : "media_id:'media-$number',"}viewing:${watched.contains(number)},files:[]}",
    );

    return ResponseBody.fromBytes(
      utf8.encode('var playlst=[${episodes.join(',')}];'),
      200,
      headers: {
        'content-type': ['text/html; charset=UTF-8'],
      },
    );
  }

  @override
  void close({bool force = false}) => closed = true;
}
