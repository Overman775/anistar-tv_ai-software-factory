import 'package:dio/dio.dart';

import 'anistar_auth_html.dart';
import 'anistar_failure.dart';
import 'anistar_session.dart';
import 'html_decoder.dart';

final class AnistarAuthService {
  final AnistarSession session;
  final Future<void> Function()? ensureMirror;
  final Dio _dio;

  AnistarAuthService(this._dio, this.session, {this.ensureMirror});

  Future<String?> restore() async {
    await ensureMirror?.call();
    await session.initialize();
    final account = session.account;
    if (account == null) {
      return null;
    }
    final response = await _page(session.origin.resolve('anime/'));
    final source = _html(response);
    if (!AnistarAuthHtml.isAuthenticated(source, session.origin)) {
      if (AnistarAuthHtml.isGuest(source)) {
        await session.clear();

        return null;
      }
      throw const AnistarFailure(message: 'AniStar не подтвердил сессию. Повторите проверку.');
    }

    return account;
  }

  Future<String> signIn(String username, String password) async {
    final account = username.trim();
    if (account.isEmpty || password.isEmpty) {
      throw const AnistarFailure(message: 'Введите логин и пароль.');
    }
    await ensureMirror?.call();
    await session.clear();
    final generation = session.generation;
    final pageUri = session.origin.resolve('anime/');
    final page = await _page(pageUri);
    final form = AnistarAuthHtml.loginForm(_html(page));
    final action = page.requestOptions.uri.resolve(form.attributes['action'] ?? '');
    _checkOrigin(action);
    final fields = <String, String>{
      for (final input in form.querySelectorAll('input[type="hidden"][name]'))
        input.attributes['name']!: input.attributes['value'] ?? '',
      'login_name': account,
      'login_password': password,
      'login': 'submit',
    };
    final contentType = page.headers.value('content-type');
    final body = AnistarAuthHtml.encodeForm(fields, contentType);
    final cp1251 = RegExp('windows-1251|cp1251', caseSensitive: false).hasMatch(contentType ?? '');
    final response = await _page(action, body: body, referer: page.requestOptions.uri, cp1251: cp1251);
    if (!AnistarAuthHtml.isAuthenticated(_html(response), session.origin)) {
      await session.clear();
      throw const AnistarFailure(message: 'Вход не выполнен. Проверьте логин и пароль.');
    }
    if (await session.cookieHeader(pageUri) == null) {
      await session.clear();
      throw const AnistarFailure(message: 'AniStar не выдал cookies сессии.');
    }
    await session.authenticate(account, generation);

    return account;
  }

  Future<void> signOut() => session.clear();

  void _checkOrigin(Uri uri) {
    if (!session.owns(uri)) {
      throw const AnistarFailure(message: 'Форма входа перенаправляет на другое зеркало. Проверьте адрес AniStar.');
    }
  }

  Future<Response<List<int>>> _page(Uri uri, {String? body, Uri? referer, bool cp1251 = false}) async {
    var target = uri;
    var requestBody = body;
    for (var attempt = 0; attempt < 4; attempt++) {
      _checkOrigin(target);
      final response = await _dio.request<List<int>>(
        target.toString(),
        data: requestBody,
        options: Options(
          method: requestBody == null ? 'GET' : 'POST',
          responseType: ResponseType.bytes,
          followRedirects: false,
          validateStatus: (status) => status != null && status >= 200 && status < 400,
          extra: const {'anistarAuth': true},
          headers: {
            'Accept': 'text/html',
            'User-Agent': 'AniStarTV/1.0',
            'Cache-Control': 'no-cache',
            if (referer != null) 'Referer': referer.toString(),
            if (requestBody != null)
              'Content-Type': 'application/x-www-form-urlencoded; charset=${cp1251 ? 'windows-1251' : 'utf-8'}',
          },
        ),
      );
      final status = response.statusCode ?? 0;
      if (status >= 200 && status < 300) {
        return response;
      }
      final location = response.headers.value('location');
      if (location == null || !const [301, 302, 303].contains(status)) {
        throw const AnistarFailure(message: 'AniStar вернул неподдерживаемое перенаправление при входе.');
      }
      target = target.resolve(location);
      requestBody = null;
    }
    throw const AnistarFailure(message: 'Слишком много перенаправлений при входе в AniStar.');
  }

  static String _html(Response<List<int>> response) {
    if (response.headers.value('cf-mitigated') == 'challenge') {
      throw const AnistarFailure(message: 'AniStar требует проверку браузера. Попробуйте другое зеркало.');
    }

    return HtmlDecoder.decode(response.data ?? const [], response.headers.value('content-type'));
  }
}
