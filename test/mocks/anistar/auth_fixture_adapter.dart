import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

const guestAuthHtml =
    '<form method="post" action=""><input type="hidden" name="login" value="submit"><input type="hidden" name="token" value="fixture"><input name="login_name"><input name="login_password" type="password"></form>';
const memberAuthHtml = '<a href="/index.php?action=logout">Выход</a>';

final class AuthFixtureAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  int getStatus = 200;
  bool rejectLogin = false;
  bool expired = false;
  String? redirect;
  String? formAction;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (options.method == 'POST') {
      if (rejectLogin) {
        return _body('$guestAuthHtml Ошибка авторизации');
      }

      return _body(
        redirect == null ? memberAuthHtml : '',
        status: redirect == null ? 200 : 302,
        headers: {
          'set-cookie': [
            'dle_user_id=42; Path=/; Secure; HttpOnly',
            'dle_password=session-secret; Path=/; Secure; HttpOnly',
          ],
          if (redirect case final location?) 'location': [location],
        },
      );
    }
    final authenticated = !expired && options.headers['Cookie']?.toString().contains('dle_user_id=42') == true;
    final form = formAction == null ? guestAuthHtml : guestAuthHtml.replaceFirst('action=""', 'action="$formAction"');

    return _body(authenticated ? memberAuthHtml : form, status: getStatus);
  }

  @override
  void close({bool force = false}) {
    requests.clear();
  }

  static ResponseBody _body(String body, {int status = 200, Map<String, List<String>> headers = const {}}) =>
      ResponseBody.fromBytes(
        utf8.encode(body),
        status,
        headers: {
          'content-type': ['text/html; charset=UTF-8'],
          ...headers,
        },
      );
}
