import 'dart:async';

import 'package:anistar/anistar.dart';
import 'package:anistar/html.dart';
import 'package:anistar/parsing.dart';
import 'package:anistar_tv/packages/features/auth/data/anistar_auth_repository.dart';
import 'package:core/data.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:networking/networking.dart';

import '../../mocks/anistar/auth_fixture_adapter.dart';
import '../../mocks/storage/memory_secure_storage.dart';

void main() {
  late AnistarSession session;
  late AuthFixtureAdapter adapter;
  late Dio dio;

  setUp(() {
    final origin = Uri.parse('https://v30.astar.bz/');
    session = AnistarSession(origin, MemorySecureStorage());
    adapter = AuthFixtureAdapter();
    dio = Dio(BaseOptions(baseUrl: origin.toString()))
      ..httpClientAdapter = adapter
      ..interceptors.add(AnistarSessionInterceptor(session));
  });
  tearDown(() async {
    dio.close(force: true);
    await session.close();
  });

  test('restore reports session checking only after the mirror is available', () async {
    final available = Completer<void>();
    var checks = 0;
    final client = HtmlAnistarClient(dio, session, ensureMirror: () => available.future);
    final pending = AnistarAuthRepository(client).restore(onSessionCheck: () => checks++);
    await Future<void>.delayed(Duration.zero);
    expect(checks, 0);
    available.complete();
    final restored = await pending;
    expect(checks, 1);
    expect(restored.successOrNull, isNull);
    expect(adapter.requests, isEmpty);
  });

  test('failed mirror check sends no credentials; recovery permits one login POST', () async {
    var available = false;
    final client = HtmlAnistarClient(
      dio,
      session,
      ensureMirror: () async {
        if (!available) {
          throw const AnistarFailure(message: 'Mirror unavailable');
        }
      },
    );
    final repository = AnistarAuthRepository(client);
    // The same login must be retried after mirror availability changes.
    final blocked = await repository.signIn('test', 'private-password');
    expect(blocked.failureOrNull, isA<RequestFailure>());
    expect(adapter.requests, isEmpty);

    available = true;
    final recovered = await repository.signIn('test', 'private-password');
    expect(recovered.successOrNull, 'test');
    expect(adapter.requests.where((request) => request.method == 'POST'), hasLength(1));
  });

  test('unexpected mirror error is sanitized at the client boundary', () async {
    final client = HtmlAnistarClient(
      dio,
      session,
      ensureMirror: () async {
        throw StateError('private-password; Cookie=session-secret');
      },
    );
    final result = await AnistarAuthRepository(client).restore();
    final failure = result.failureOrNull;
    expect(failure, isA<UnknownFailure>());
    expect(failure?.message, const UnknownFailure().message);
    expect(adapter.requests, isEmpty);
  });

  test('session expiry propagates through the client and repository contract', () async {
    final client = HtmlAnistarClient(dio, session);
    final repository = AnistarAuthRepository(client);
    await client.signIn('test', 'private-password');
    final expired = repository.expired.first;
    adapter.expired = true;
    await expectLater(client.catalog(1), throwsA(isA<AnistarClientException>()));
    await expired.timeout(const Duration(seconds: 1));
    expect(session.account, isNull);
  });
}
