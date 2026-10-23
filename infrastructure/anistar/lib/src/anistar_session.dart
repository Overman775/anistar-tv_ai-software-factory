import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:storage/storage.dart';

import 'anistar_failure.dart';

/// One encrypted, origin-bound record. All mutations are serialized, including logout.
final class AnistarSession {
  final Uri origin;

  static final _random = Random.secure();
  static final _storageTransactions = <String, Future<void>>{};

  final SecureStorage _storage;
  final DefaultCookieJar _jar = DefaultCookieJar();
  final StreamController<void> _expired = StreamController<void>.broadcast();
  Future<void> _pending = Future<void>.value();
  bool _loaded = false;
  String? _account;
  int _generation = 0;
  int _accessEpoch = 0;
  int _anonymousAccessEpoch = 0;
  int _authenticatedAccessEpoch = 0;
  int? _cancelledAuthenticationGeneration;
  String? _recordId;
  String? _cancelledRecordId;

  String get storageKey => 'anistar.session.v1.${Uri.encodeComponent(origin.origin)}';
  String? get account => _account;
  int get generation => _generation;
  bool get hasPendingAuthenticationCancellation => _cancelledAuthenticationGeneration != null;

  /// Public continuation identity, independent of an abandoned guest login.
  int get accessGeneration => _account == null ? _anonymousAccessEpoch : _authenticatedAccessEpoch;
  Stream<void> get expired => _expired.stream;

  AnistarSession(this.origin, this._storage);

  bool owns(Uri uri) => uri.scheme == 'https' && uri.userInfo.isEmpty && uri.origin == origin.origin;

  Future<void> initialize() => _serial(() async {
    await _initialize();
    if (hasPendingAuthenticationCancellation) {
      throw const AnistarFailure(message: 'Завершите отмену предыдущего входа AniStar.');
    }
  });

  Future<String?> cookieHeader(Uri uri) => _serial(() async {
    await _initialize();
    if (!owns(uri) || hasPendingAuthenticationCancellation) {
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
    if (generation != _generation || hasPendingAuthenticationCancellation) {
      throw const AnistarFailure(message: 'Вход отменён. Повторите попытку.');
    }
    _recordId = _newRecordId();
    try {
      await _persist(account: account);
    } on Object catch (_, stackTrace) {
      if (_account != null) {
        _anonymousAccessEpoch = ++_accessEpoch;
      }
      _account = null;
      await _jar.deleteAll();
      Error.throwWithStackTrace(
        const AnistarFailure(message: 'Не удалось сохранить защищённую сессию. Вход не завершён.'),
        stackTrace,
      );
    }
    if (generation != _generation) {
      throw const AnistarFailure(message: 'Вход отменён. Повторите попытку.');
    }
    _account = account;
    _authenticatedAccessEpoch = ++_accessEpoch;
  });

  /// Invalidates late responses synchronously, then removes an abandoned login.
  Future<void> cancelAuthentication(int expectedGeneration) {
    if (expectedGeneration != _generation) {
      return Future<void>.value();
    }
    final cancelledGeneration = ++_generation;
    _cancelledAuthenticationGeneration = cancelledGeneration;
    _cancelledRecordId = _recordId;
    _recordId = null;
    _account = null;

    return retryCancelledAuthentication();
  }

  /// Repeats only the deletion owned by the cancelled attempt.
  Future<void> retryCancelledAuthentication() => _removeCancelledAuthentication();

  Future<void> clear({bool expired = false, int? expectedGeneration}) => _serial(() async {
    if (expectedGeneration != null && expectedGeneration != _generation) {
      return;
    }
    // A failed delete must not report successful logout and leave a restorable session.
    try {
      await _storageTransaction(() => _storage.remove(storageKey));
    } on Object catch (_, stackTrace) {
      Error.throwWithStackTrace(
        const AnistarFailure(message: 'Не удалось удалить защищённую сессию. Повторите выход.'),
        stackTrace,
      );
    }
    _generation++;
    _loaded = true;
    if (_account != null) {
      _anonymousAccessEpoch = ++_accessEpoch;
    }
    _account = null;
    _cancelledAuthenticationGeneration = null;
    _recordId = null;
    _cancelledRecordId = null;
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

  Future<T> _storageTransaction<T>(Future<T> Function() action) {
    final previous = _storageTransactions[storageKey] ?? Future<void>.value();
    final result = previous.then((_) => action());
    final settled = result.then<void>((_) => null, onError: (Object _) => null);
    _storageTransactions[storageKey] = settled;
    unawaited(
      settled.then((_) {
        if (identical(_storageTransactions[storageKey], settled)) {
          unawaited(_storageTransactions.remove(storageKey));
        }
      }),
    );

    return result;
  }

  Future<void> _initialize() async {
    if (_loaded) {
      return;
    }
    try {
      final stored = await _storageTransaction(() => _storage.get(storageKey));
      if (stored != null) {
        final Object? decoded = jsonDecode(stored);
        if (decoded is! Map<String, Object?> || decoded['origin'] != origin.origin || decoded['version'] != 1) {
          throw const FormatException('Invalid session record');
        }
        if (decoded['cancelled'] == true) {
          _cancelledAuthenticationGeneration = _generation;
          final recordId = decoded['recordId'];
          if (recordId is! String || recordId.isEmpty) {
            throw const FormatException('Missing cancelled record identity');
          }
          _cancelledRecordId = recordId;
          await _removeCancelledAuthentication();
          _loaded = true;

          return;
        }
        final account = decoded['account'];
        if (account is! String || account.isEmpty) {
          throw const FormatException('Missing session account');
        }
        _restoreCookies(_jar.hostCookies, decoded['host']);
        _restoreCookies(_jar.domainCookies, decoded['domain']);
        _account = account;
        final recordId = decoded['recordId'];
        _recordId = recordId is String && recordId.isNotEmpty ? recordId : null;
        _authenticatedAccessEpoch = ++_accessEpoch;
      }
      _loaded = true;
    } on FormatException {
      await _storageTransaction(() => _storage.remove(storageKey));
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

  Future<void> _removeCancelledAuthentication() => _storageTransaction(() async {
    final generation = _cancelledAuthenticationGeneration;
    if (generation == null) {
      return;
    }
    if (generation != _generation) {
      throw const AnistarFailure(message: 'Отмена относится к другой сессии AniStar.');
    }
    var completed = false;
    try {
      final existing = await _storage.get(storageKey);
      if (existing == null || !_ownsCancelledRecord(existing)) {
        // Another session may have replaced the abandoned attempt. Its
        // credentials are not ours to overwrite or remove.
        completed = true;

        return;
      }
      // Replacing credentials first leaves a non-restorable record if removal
      // fails. A fresh process must finish this cleanup before restoring access.
      final tombstone = jsonEncode({
        'version': 1,
        'origin': origin.origin,
        'cancelled': true,
        'recordId': _cancelledRecordId,
      });
      await _storage.set(storageKey, tombstone);
      final saved = await _storage.get(storageKey);
      if (saved != tombstone) {
        if (saved != null && _ownsCancelledRecord(saved)) {
          throw const AnistarFailure(message: 'AniStar не подтвердил отмену сохранённой сессии.');
        }
        completed = true;

        return;
      }
      await _storage.remove(storageKey);
      final remaining = await _storage.get(storageKey);
      if (remaining != null && _ownsCancelledRecord(remaining)) {
        throw const AnistarFailure(message: 'Не удалось подтвердить удаление отменённой сессии.');
      }
      completed = true;
    } on Object catch (_, stackTrace) {
      Error.throwWithStackTrace(
        const AnistarFailure(message: 'Не удалось удалить отменённую сессию AniStar. Повторите отмену входа.'),
        stackTrace,
      );
    } finally {
      _account = null;
      await _jar.deleteAll();
      if (completed) {
        _cancelledAuthenticationGeneration = null;
        _cancelledRecordId = null;
      }
    }
  });

  bool _ownsCancelledRecord(String source) {
    final Object? decoded = jsonDecode(source);

    return _cancelledRecordId != null &&
        decoded is Map<String, Object?> &&
        decoded['origin'] == origin.origin &&
        decoded['version'] == 1 &&
        decoded['recordId'] == _cancelledRecordId;
  }

  static String _newRecordId() =>
      List.generate(16, (_) => _random.nextInt(256)).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

  Future<void> _persist({String? account}) {
    final record = jsonEncode({
      'version': 1,
      'origin': origin.origin,
      'account': account ?? _account,
      'recordId': _recordId ??= _newRecordId(),
      'host': _jar.hostCookies,
      'domain': _jar.domainCookies,
    });

    return _storageTransaction(() => _storage.set(storageKey, record));
  }
}
