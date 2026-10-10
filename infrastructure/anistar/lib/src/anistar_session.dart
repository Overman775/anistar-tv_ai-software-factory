import 'dart:async';
import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:storage/storage.dart';

import 'anistar_failure.dart';

/// One encrypted, origin-bound record. All mutations are serialized, including logout.
final class AnistarSession {
  final Uri origin;
  final SecureStorage _storage;
  final DefaultCookieJar _jar = DefaultCookieJar();
  final StreamController<void> _expired = StreamController<void>.broadcast();
  Future<void> _pending = Future<void>.value();
  bool _loaded = false;
  String? _account;
  int _generation = 0;

  String get storageKey => 'anistar.session.v1.${Uri.encodeComponent(origin.origin)}';
  String? get account => _account;
  int get generation => _generation;
  Stream<void> get expired => _expired.stream;

  AnistarSession(this.origin, this._storage);

  bool owns(Uri uri) => uri.scheme == 'https' && uri.userInfo.isEmpty && uri.origin == origin.origin;

  Future<void> initialize() => _serial(_initialize);

  Future<String?> cookieHeader(Uri uri) => _serial(() async {
    await _initialize();
    if (!owns(uri)) {
      return null;
    }
    final cookies = await _jar.loadForRequest(uri);
    // cookie_jar 4.0.9 admits expired Secure cookies on HTTPS; enforce expiry here too.
    final valid = _jar.hostCookies.values
        .followedBy(_jar.domainCookies.values)
        .expand((paths) => paths.values)
        .expand((values) => values.values)
        .where((cookie) => !cookie.isExpired())
        .map((cookie) => cookie.cookie)
        .toSet();
    final header = cookies.where(valid.contains).map((cookie) => '${cookie.name}=${cookie.value}').join('; ');

    return header.isEmpty ? null : header;
  });

  Future<void> saveCookies(Uri uri, List<String> headers, int generation) => _serial(() async {
    if (!owns(uri) || generation != _generation || headers.isEmpty) {
      return;
    }
    final cookies = headers
        .map(Cookie.fromSetCookieValue)
        .where((cookie) {
          final domain = cookie.domain?.replaceFirst(RegExp(r'^\.'), '');

          return domain == null || uri.host == domain || uri.host.endsWith('.$domain');
        })
        .toList(growable: false);
    await _jar.saveFromResponse(uri, cookies);
    if (_account != null) {
      await _persist();
    }
  });

  Future<void> authenticate(String account, int generation) => _serial(() async {
    if (generation != _generation) {
      throw const AnistarFailure(message: 'Вход отменён. Повторите попытку.');
    }
    _account = account;
    try {
      await _persist();
    } on Object catch (_, stackTrace) {
      _account = null;
      await _jar.deleteAll();
      Error.throwWithStackTrace(
        const AnistarFailure(message: 'Не удалось сохранить защищённую сессию. Вход не завершён.'),
        stackTrace,
      );
    }
  });

  Future<void> clear({bool expired = false, int? expectedGeneration}) => _serial(() async {
    if (expectedGeneration != null && expectedGeneration != _generation) {
      return;
    }
    // A failed delete must not report successful logout and leave a restorable session.
    try {
      await _storage.remove(storageKey);
    } on Object catch (_, stackTrace) {
      Error.throwWithStackTrace(
        const AnistarFailure(message: 'Не удалось удалить защищённую сессию. Повторите выход.'),
        stackTrace,
      );
    }
    _generation++;
    _loaded = true;
    _account = null;
    await _jar.deleteAll();
    if (expired) {
      _expired.add(null);
    }
  });

  Future<void> close() => _expired.close();

  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _pending.then((_) => action());
    _pending = result.then<void>((_) => null, onError: (Object _) => null);

    return result;
  }

  Future<void> _initialize() async {
    if (_loaded) {
      return;
    }
    try {
      final stored = await _storage.get(storageKey);
      if (stored != null) {
        final Object? decoded = jsonDecode(stored);
        if (decoded is! Map<String, Object?> || decoded['origin'] != origin.origin || decoded['version'] != 1) {
          throw const FormatException('Invalid session record');
        }
        final account = decoded['account'];
        if (account is! String || account.isEmpty) {
          throw const FormatException('Missing session account');
        }
        _restoreCookies(_jar.hostCookies, decoded['host']);
        _restoreCookies(_jar.domainCookies, decoded['domain']);
        _account = account;
      }
      _loaded = true;
    } on FormatException {
      await _storage.remove(storageKey);
      await _jar.deleteAll();
      _account = null;
      _loaded = true;
    } on Object catch (_, stackTrace) {
      await _jar.deleteAll();
      _account = null;
      Error.throwWithStackTrace(
        const AnistarFailure(message: 'Не удалось прочитать защищённую сессию. Повторите попытку.'),
        stackTrace,
      );
    }
  }

  static void _restoreCookies(Map<String, Map<String, Map<String, SerializableCookie>>> target, Object? data) {
    if (data is! Map<String, Object?>) {
      throw const FormatException('Invalid cookies');
    }
    for (final host in data.entries) {
      final paths = host.value;
      if (paths is! Map<String, Object?>) {
        throw const FormatException('Invalid cookie paths');
      }
      final restored = <String, Map<String, SerializableCookie>>{};
      for (final path in paths.entries) {
        final values = path.value;
        if (values is! Map<String, Object?>) {
          throw const FormatException('Invalid cookie values');
        }
        restored[path.key] = values.map((name, value) {
          if (value is! String) {
            throw const FormatException('Invalid cookie');
          }

          return MapEntry(name, SerializableCookie.fromJson(value));
        });
      }
      target[host.key] = restored;
    }
  }

  Future<void> _persist() => _storage.set(
    storageKey,
    jsonEncode({
      'version': 1,
      'origin': origin.origin,
      'account': _account,
      'host': _jar.hostCookies,
      'domain': _jar.domainCookies,
    }),
  );
}
