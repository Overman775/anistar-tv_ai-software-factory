import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'anistar_fixtures.dart';

/// A stateful site fixture: only the AJAX endpoint changes its account list.
final class FavoritesFixtureAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  bool favorite = false;
  bool reject = false;
  bool wrongId = false;
  bool persist = true;
  int mutationStatus = 200;
  bool closed = false;

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
    var status = 200;
    final String body;
    switch (options.uri.path) {
      case '/10938-test.html':
        body = '$detailHtml${_control(10938)}<script>var dle_skin="new36";</script>';
      case '/index.php':
        body = favorite
            ? '$catalogHtml${_control(10938)}'
            : '<div id="dle-content">Вы еще ничего не добавляли в свои закладки.</div>';
      case '/engine/ajax/favorites.php':
        status = mutationStatus;
        if (reject) {
          body = 'error';
        } else {
          final target = options.queryParameters['action'] == 'plus';
          final previous = favorite;
          favorite = target;
          body = _control(wrongId ? 42 : 10938);
          if (!persist) {
            favorite = previous;
          }
        }
      default:
        status = 404;
        body = 'Not found';
    }

    return ResponseBody.fromBytes(
      utf8.encode(body),
      status,
      headers: {
        'content-type': ['text/html; charset=UTF-8'],
      },
    );
  }

  @override
  void close({bool force = false}) => closed = true;

  String _control(int id) => '<img onclick="doFavorites(\'$id\',\'${favorite ? 'minus' : 'plus'}\');return false;">';
}
