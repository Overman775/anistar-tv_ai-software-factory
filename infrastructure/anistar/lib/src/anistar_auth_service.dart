import 'package:core/data.dart';
import 'package:dio/dio.dart';

import 'anistar_auth_html.dart';
import 'anistar_failure.dart';
import 'anistar_session.dart';
import 'contract/anistar_client_exception.dart';
import 'html_decoder.dart';

final class AnistarAuthService {
  final AnistarSession session;
  final Future<void> Function()? ensureMirror;
  final Dio _dio;
  Future<String>? _pendingSignIn;
  Future<void>? _pendingCancellation;
  RequestCancellation? _attemptCancellation;
  int? _attemptGeneration;
  Future<void>? _cancellationCleanup;
  bool _cancellationBarrierObserved = false;

  AnistarAuthService(this._dio, this.session, {this.ensureMirror});

  Future<String?> restore({void Function()? onSessionCheck}) async {
    await ensureMirror?.call();
    onSessionCheck?.call();
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

  Future<String> signIn(String username, String password, {RequestCancellation? cancellation}) {
    if (_pendingSignIn != null || _pendingCancellation != null || session.hasPendingAuthenticationCancellation) {
      return Future<String>.error(const AnistarFailure(message: 'Завершите предыдущий вход или его отмену.'));
    }
    _attemptCancellation = cancellation;
    _attemptGeneration = null;
    _cancellationCleanup = null;
    _cancellationBarrierObserved = false;
    final pending = _performSignIn(username, password, cancellation: cancellation);
    _pendingSignIn = pending;

    return pending.whenComplete(() {
      if (identical(_pendingSignIn, pending)) {
        _pendingSignIn = null;
      }
    });
  }

  Future<void> cancelSignIn(RequestCancellation cancellation) {
    if (!identical(_attemptCancellation, cancellation)) {
      return Future<void>.value();
    }
    final existing = _pendingCancellation;
    if (existing != null) {
      return existing;
    }
    final pending = _completeCancellation(cancellation);
    _pendingCancellation = pending;

    return pending.whenComplete(() {
      if (identical(_pendingCancellation, pending)) {
        _pendingCancellation = null;
      }
    });
  }

  Future<void> signOut() => session.clear();

  Future<String> _performSignIn(String username, String password, {RequestCancellation? cancellation}) async {
    final account = username.trim();
    if (account.isEmpty || password.isEmpty) {
      throw const AnistarFailure(message: 'Введите логин и пароль.');
    }
    await ensureMirror?.call();
    _checkCancellation(cancellation);
    await session.clear();
    _checkCancellation(cancellation);
    final generation = session.generation;
    _attemptGeneration = generation;
    final cancelToken = CancelToken();
    Future<void>? cleanup;
    final unregister = cancellation?.onCancel(() {
      cancelToken.cancel();
      cleanup = session.cancelAuthentication(generation);
      _cancellationCleanup = cleanup;
    });
    try {
      final result = await _signIn(account, password, generation, cancelToken, cancellation);
      _checkCancellation(cancellation);

      return result;
    } finally {
      final pendingCleanup = cleanup;
      try {
        if (pendingCleanup != null) {
          await pendingCleanup;
        }
      } finally {
        unregister?.call();
      }
    }
  }

  Future<void> _completeCancellation(RequestCancellation cancellation) async {
    final retry = _cancellationBarrierObserved;
    _cancellationBarrierObserved = true;
    if (retry) {
      await session.retryCancelledAuthentication();

      return;
    }
    final pending = _pendingSignIn;
    cancellation.cancel();
    if (pending != null) {
      try {
        await pending;
      } on Object {
        // Ordinary cancelled-login errors are expected. Mandatory cleanup
        // failure must reach the owner and requires a separate explicit retry.
        if (session.hasPendingAuthenticationCancellation) {
          rethrow;
        }
      }
    }
    if (!identical(_attemptCancellation, cancellation)) {
      return;
    }
    final cleanup = _cancellationCleanup;
    final generation = _attemptGeneration;
    if (cleanup != null) {
      await cleanup;
    } else if (generation != null && generation == session.generation && session.account != null) {
      // The network Future can settle just before the UI consumes it. The
      // token still identifies that attempt, not a subsequently started login.
      await session.cancelAuthentication(generation);
    }
  }

  Future<String> _signIn(
    String account,
    String password,
    int generation,
    CancelToken cancelToken,
    RequestCancellation? cancellation,
  ) async {
    final pageUri = session.origin.resolve('anime/');
    final page = await _page(pageUri, cancellation: cancelToken);
    _checkCancellation(cancellation);
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
    final response = await _page(
      action,
      body: body,
      referer: page.requestOptions.uri,
      cp1251: cp1251,
      cancellation: cancelToken,
    );
    _checkCancellation(cancellation);
    final responseHtml = _html(response);
    if (!AnistarAuthHtml.isAuthenticated(responseHtml, session.origin)) {
      await session.clear(expectedGeneration: generation);
      if (AnistarAuthHtml.isGuest(responseHtml)) {
        throw const AnistarClientException(
          AnistarClientErrorCategory.invalidCredentials,
          'Вход не выполнен. Проверьте логин и пароль.',
        );
      }
      throw const AnistarFailure(message: 'Вход не выполнен. Проверьте логин и пароль.');
    }
    final cookie = await session.cookieHeader(pageUri);
    _checkCancellation(cancellation);
    if (cookie == null) {
      await session.clear(expectedGeneration: generation);
      throw const AnistarFailure(message: 'AniStar не выдал cookies сессии.');
    }
    _checkCancellation(cancellation);
    await session.authenticate(account, generation);
    _checkCancellation(cancellation);

    return account;
  }

  static void _checkCancellation(RequestCancellation? cancellation) {
    if (cancellation?.isCancelled == true) {
      throw const AnistarFailure(message: 'Вход отменён.');
    }
  }

  void _checkOrigin(Uri uri) {
    if (!session.owns(uri)) {
      throw const AnistarFailure(message: 'Форма входа перенаправляет на другое зеркало. Проверьте адрес AniStar.');
    }
  }

  Future<Response<List<int>>> _page(
    Uri uri, {
    String? body,
    Uri? referer,
    bool cp1251 = false,
    CancelToken? cancellation,
  }) async {
    var target = uri;
    var requestBody = body;
    for (var attempt = 0; attempt < 4; attempt++) {
      _checkOrigin(target);
      final response = await _dio.request<List<int>>(
        target.toString(),
        data: requestBody,
        cancelToken: cancellation,
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
