// Mutable session state is intentionally observed before and after each operation.
// ignore_for_file: prefer-moving-to-variable

import 'dart:convert';

import 'package:anistar/anistar.dart';
import 'package:anistar/parsing.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../mocks/anistar/auth_fixture_adapter.dart';
import '../../mocks/storage/memory_secure_storage.dart';

void main() {
  final origin = Uri.parse('https://v30.astar.bz/');
  late MemorySecureStorage storage;
  late AnistarSession session;
  late AuthFixtureAdapter adapter;
  late Dio dio;
  late AnistarAuthService service;

  setUp(() {
    storage = MemorySecureStorage();
    session = AnistarSession(origin, storage);
    adapter = AuthFixtureAdapter();
    dio = Dio(BaseOptions(baseUrl: origin.toString()))
      ..httpClientAdapter = adapter
      ..interceptors.add(AnistarSessionInterceptor(session));
    service = AnistarAuthService(dio, session);
  });
  tearDown(() async {
    dio.close(force: true);
    await session.close();
  });

  test('login persists cookies and username, never the submitted password; restart validates session', () async {
    expect(await service.restore(), isNull);
    expect(await service.signIn(' test ', 'private-password'), 'test');
    expect(adapter.requests.last.data, contains('token=fixture'));
    expect(storage.values.values.single, contains('session-secret'));
    expect(storage.values.values.single, isNot(contains('private-password')));
    final restored = AnistarSession(origin, storage);
    addTearDown(restored.close);
    dio.interceptors.clear();
    dio.interceptors.add(AnistarSessionInterceptor(restored));
    expect(await AnistarAuthService(dio, restored).restore(), 'test');
    expect(adapter.requests.last.headers['Cookie'], contains('dle_password=session-secret'));
    expect(await restored.cookieHeader(Uri.parse('https://sfv.an-media.org/video')), isNull);
    expect(await restored.cookieHeader(Uri.parse('https://v31.astar.bz/')), isNull);
    expect(await restored.cookieHeader(Uri.parse('http://v30.astar.bz/')), isNull);
  });

  test('HTTP 200 with the login form is rejected and leaves no session', () async {
    adapter.rejectLogin = true;
    await expectLater(service.signIn('test', 'wrong'), throwsA(isA<AnistarFailure>()));
    expect(storage.values, isEmpty);
    expect(session.account, isNull);
    expect(adapter.requests.where((request) => request.method == 'POST'), hasLength(1));
  });

  test('CP1251 form encodes Cyrillic and preserves password spaces and punctuation', () {
    expect(
      AnistarAuthHtml.encodeForm({'login_name': 'тест', 'login_password': ' п+а& '}, 'windows-1251'),
      'login_name=%F2%E5%F1%F2&login_password=+%EF%2B%E0%26+',
    );
    expect(AnistarAuthHtml.encodeForm({'value': 'я'}, 'UTF-8'), 'value=%D1%8F');
    expect(() => AnistarAuthHtml.encodeForm({'value': '🙂'}, 'windows-1251'), throwsA(isA<AnistarFailure>()));
  });

  test('same-origin redirect receives cookies without resubmitting the password', () async {
    adapter.redirect = '/index.php';
    expect(await service.signIn('test', 'secret'), 'test');
    expect(adapter.requests.map((request) => request.method), ['GET', 'POST', 'GET']);
    expect(adapter.requests.last.headers['Cookie'], contains('dle_user_id=42'));
    expect(adapter.requests.last.data, isNull);
  });

  test('external form actions and redirects never receive credentials or cookies', () async {
    adapter.formAction = 'https://other.example/login';
    await expectLater(service.signIn('test', 'secret'), throwsA(isA<AnistarFailure>()));
    expect(adapter.requests, hasLength(1));
    adapter
      ..formAction = null
      ..redirect = 'https://other.example/login';
    // Redirect and form action are separate rejection paths.
    // ignore: avoid-duplicate-test-assertions
    await expectLater(service.signIn('test', 'secret'), throwsA(isA<AnistarFailure>()));
    expect(adapter.requests.every((request) => request.uri.origin == origin.origin), isTrue);
    expect(storage.values, isEmpty);
  });

  test('expired secure cookies are omitted, including after encrypted restoration', () async {
    await session.initialize();
    final initialGeneration = session.generation;
    await session.saveCookies(origin, [
      'expired=x; Secure; Path=/; Max-Age=0',
      'valid=y; Secure; Path=/; Max-Age=60',
    ], initialGeneration);
    final generation = session.generation;
    await session.authenticate('test', generation);
    final record = jsonDecode(storage.values.values.single) as Map<String, Object?>;
    final host = record['host']! as Map<String, Object?>;
    final paths = host[origin.host]! as Map<String, Object?>;
    final cookies = paths['/']! as Map<String, Object?>;
    cookies['valid'] = 'valid=y; Secure; Path=/; Max-Age=60;_crt=1';
    storage.values[session.storageKey] = jsonEncode(record);
    final restored = AnistarSession(origin, storage);
    addTearDown(restored.close);
    expect(await restored.cookieHeader(origin), isNull);
  });

  test('secure read or write failure cannot authenticate', () async {
    storage.failRead = true;
    await expectLater(service.restore(), throwsA(isA<AnistarFailure>()));
    storage
      ..failRead = false
      ..failWrite = true;
    await expectLater(service.signIn('test', 'secret'), throwsA(isA<AnistarFailure>()));
    expect(session.account, isNull);
    expect(storage.values, isEmpty);
  });

  test('logout removes only its record, ignores late cookies and reports deletion failure', () async {
    await service.signIn('test', 'secret');
    storage.values['another-feature'] = 'keep';
    final generation = session.generation;
    storage.failDelete = true;
    await expectLater(service.signOut(), throwsA(isA<AnistarFailure>()));
    expect(session.account, 'test');
    storage.failDelete = false;
    await service.signOut();
    await session.saveCookies(origin, ['dle_user_id=42; Path=/'], generation);
    expect(storage.values, {'another-feature': 'keep'});
    expect(await session.cookieHeader(origin), isNull);
  });

  test('a forbidden page preserves the session; cookies are stripped from foreign requests', () async {
    await service.signIn('test', 'secret');
    adapter.getStatus = 403;
    await expectLater(
      dio.get<List<int>>('anime/', options: Options(responseType: ResponseType.bytes)),
      throwsA(isA<DioException>()),
    );
    expect(session.account, 'test');
    adapter.getStatus = 200;
    await dio.get<List<int>>(
      'https://cdn.example/video',
      options: Options(responseType: ResponseType.bytes, headers: {'Cookie': 'must-not-leak'}),
    );
    expect(adapter.requests.last.headers.containsKey('Cookie'), isFalse);
    expect(storage.values, hasLength(1));
  });

  test('late expiry from a previous session cannot clear a newly authenticated account', () async {
    await service.signIn('test', 'secret');
    final oldGeneration = session.generation;
    await service.signOut();
    await service.signIn('new-account', 'secret');
    await session.clear(expired: true, expectedGeneration: oldGeneration);
    expect(session.account, 'new-account');
    expect(storage.values.values.single, contains('new-account'));
    expect(await session.cookieHeader(origin), contains('dle_user_id=42'));
  });

  test('only same-origin logout markup confirms authentication', () {
    expect(AnistarAuthHtml.isAuthenticated(memberAuthHtml, origin), isTrue);
    expect(
      AnistarAuthHtml.isAuthenticated('<a href="https://foreign.example/index.php?action=logout">Exit</a>', origin),
      isFalse,
    );
    expect(AnistarAuthHtml.isAuthenticated(guestAuthHtml, origin), isFalse);
  });

  test('logout detection ignores non-HTTP, foreign, credential-bearing and malformed links', () {
    const unrelated =
        '<a href="javascript:void(0)">Menu</a><a href="mailto:test@example.org">Mail</a> '
        '<a href="data:text/html,logout">Data</a><a href="https://[invalid">Broken</a> '
        '<a href="https://v31.astar.bz/?action=logout">Foreign</a><a href="https://user@v30.astar.bz/?action=logout">User info</a> '
        '<a href="http://v30.astar.bz/?action=logout">HTTP</a><a href="/?action=%ZZ">Bad query</a>';
    expect(AnistarAuthHtml.isAuthenticated(unrelated, origin), isFalse);
    expect(
      AnistarAuthHtml.logoutUri('$unrelated<a href="/index.php?action=logout&amp;other=1">Exit</a>', origin),
      origin.resolve('index.php?action=logout&other=1'),
    );
  });

  test('guest HTML invalidates a running session and emits an expiry event', () async {
    await service.signIn('test', 'secret');
    final expired = session.expired.first;
    adapter.expired = true;
    await expectLater(
      dio.get<List<int>>('anime/', options: Options(responseType: ResponseType.bytes)),
      throwsA(isA<DioException>()),
    );
    await expired;
    expect(session.account, isNull);
    expect(storage.values, isEmpty);
  });

  test('restore clears rejected cookies; malformed encrypted data recovers without anonymous access', () async {
    await service.signIn('test', 'secret');
    adapter.expired = true;
    expect(await service.restore(), isNull);
    expect(storage.values, isEmpty);
    storage.values[session.storageKey] = '{bad';
    final restored = AnistarSession(origin, storage);
    addTearDown(restored.close);
    await restored.initialize();
    expect(restored.account, isNull);
    // Corrupt record cleanup is independent of expiry cleanup.
    // ignore: avoid-duplicate-test-assertions
    expect(storage.values, isEmpty);
  });
}
