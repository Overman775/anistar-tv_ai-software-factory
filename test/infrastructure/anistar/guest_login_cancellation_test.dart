import 'dart:async';

import 'package:anistar/anistar.dart';
import 'package:anistar/html.dart';
import 'package:anistar_tv/packages/features/auth/auth_providers.dart';
import 'package:anistar_tv/packages/features/auth/data/anistar_auth_repository.dart';
import 'package:app_logging/app_logging.dart';
import 'package:core/data.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storage/storage.dart';

import '../../mocks/anistar/auth_fixture_adapter.dart';

void main() {
  test('a late cancellation barrier surfaces the first cleanup failure before an explicit retry', () async {
    final origin = Uri.parse('https://auth.test/');
    final storage = _GatedSecureStorage();
    final session = AnistarSession(origin, storage);
    addTearDown(session.close);
    final dio = Dio(BaseOptions(baseUrl: origin.toString()))
      ..httpClientAdapter = AuthFixtureAdapter()
      ..interceptors.add(AnistarSessionInterceptor(session));
    addTearDown(() => dio.close(force: true));
    final client = HtmlAnistarClient(dio, session);
    final token = RequestCancellation();
    final login = client.signIn('abandoned', 'fixture-password', cancellation: token);
    final clientFailure = throwsA(isA<AnistarClientException>());
    final rejected = expectLater(login, clientFailure);
    await storage.persisting.future;
    storage.failRemoval = true;
    token.cancel();
    storage.release.complete();
    await rejected;
    final deletes = storage.removalCalls;
    await expectLater(client.cancelSignIn(token), clientFailure);
    expect(storage.removalCalls, deletes);
    storage.failRemoval = false;
    await client.cancelSignIn(token);
    expect(storage.removalCalls, deletes + 1);
    final restored = AnistarSession(origin, storage);
    addTearDown(restored.close);
    await restored.initialize();
    expect(restored.account, isNull);
    expect(await restored.cookieHeader(origin), isNull);
  });

  for (final failTombstone in [false, true]) {
    test(
      'failed cancelled persistence cleanup remains retryable until verified (tombstone write fails=$failTombstone)',
      () async {
        final origin = Uri.parse('https://auth.test/');
        final storage = _GatedSecureStorage();
        final session = AnistarSession(origin, storage);
        addTearDown(session.close);
        final dio = Dio(BaseOptions(baseUrl: origin.toString()))
          ..httpClientAdapter = AuthFixtureAdapter()
          ..interceptors.add(AnistarSessionInterceptor(session));
        addTearDown(() => dio.close(force: true));
        final client = HtmlAnistarClient(dio, session);
        final repository = AnistarAuthRepository(client, Logger(level: Level.off));
        final container = ProviderContainer(overrides: [authRepositoryProvider.overrideWithValue(repository)]);
        addTearDown(container.dispose);
        AuthSessionState? readState() => container.read(authControllerProvider).value;
        await container.read(authControllerProvider.future);
        final controller = container.read(authControllerProvider.notifier)
          ..enterAnonymous()
          ..requestSignIn();
        final login = controller.signIn('abandoned', 'fixture-password');
        await storage.persisting.future;
        storage
          ..failRemoval = true
          ..failCancellationWrite = failTombstone;
        final cancellation = controller.cancelSignIn();
        final pending = readState();
        expect(pending?.isCancellingSignIn, isTrue);
        expect(pending?.loginRequested, isTrue);
        await controller.signIn('forbidden-before-cleanup', 'fixture-password');
        storage.release.complete();
        await Future.wait([login, cancellation]);
        final failed = readState();
        expect(failed?.access, isA<AnonymousAccess>());
        expect(failed?.operation, AuthOperation.cancellationFailed);
        expect(failed?.loginRequested, isTrue);
        expect(failed?.cancellationFailure, isA<Failure>());
        expect(session.account, isNull);
        if (!failTombstone) {
          final blockedRestore = AnistarSession(origin, storage);
          addTearDown(blockedRestore.close);
          await expectLater(blockedRestore.initialize(), throwsA(isA<Failure>()));
          expect(blockedRestore.account, isNull);
          expect(storage.values.values.any((record) => record.contains('abandoned')), isFalse);
        }
        storage
          ..failRemoval = false
          ..failCancellationWrite = false;
        await controller.cancelSignIn();
        final cleaned = readState();
        expect(cleaned?.requiresCancellation, isFalse);
        expect(cleaned?.loginRequested, isFalse);
        expect(cleaned?.cancellationFailure, isNull);
        final restored = AnistarSession(origin, storage);
        addTearDown(restored.close);
        await restored.initialize();
        expect(restored.account, isNull);
        expect(await restored.cookieHeader(origin), isNull);
        expect(storage.values, isEmpty);
        controller.requestSignIn();
        await controller.signIn('replacement', 'fixture-password');
        expect(container.read(authAccessProvider).account, 'replacement');
      },
    );
  }

  for (final startReplacement in [false, true]) {
    test(
      'cancel during encrypted persistence prevents abandoned restoration (replacement=$startReplacement)',
      () async {
        final origin = Uri.parse('https://auth.test/');
        final storage = _GatedSecureStorage();
        final session = AnistarSession(origin, storage);
        addTearDown(session.close);
        final dio = Dio(BaseOptions(baseUrl: origin.toString()))
          ..httpClientAdapter = AuthFixtureAdapter()
          ..interceptors.add(AnistarSessionInterceptor(session));
        addTearDown(() => dio.close(force: true));
        final client = HtmlAnistarClient(dio, session);
        final cancellation = RequestCancellation();
        final abandoned = client.signIn('abandoned', 'fixture-password', cancellation: cancellation);
        final clientFailure = throwsA(isA<AnistarClientException>());
        final rejected = expectLater(abandoned, clientFailure);
        await storage.persisting.future;
        expect(session.account, isNull);
        cancellation.cancel();
        final cancelled = client.cancelSignIn(cancellation);
        if (startReplacement) {
          await expectLater(client.signIn('premature', 'fixture-password'), clientFailure);
        }
        storage.release.complete();
        await rejected;
        await cancelled;
        if (startReplacement) {
          expect(await client.signIn('replacement', 'fixture-password'), 'replacement');
          await client.cancelSignIn(cancellation);
        }
        final restored = AnistarSession(origin, storage);
        addTearDown(restored.close);
        await restored.initialize();
        final expected = startReplacement ? 'replacement' : null;
        expect(session.account, expected);
        expect(restored.account, expected);
        expect(storage.values.values.any((record) => record.contains('abandoned')), isFalse);
        final cookies = await restored.cookieHeader(origin);
        expect(cookies, startReplacement ? contains('dle_user_id=42') : isNull);
      },
    );
  }
}

// The private storage double belongs to these cancellation regression tests.
// ignore: prefer-match-file-name
final class _GatedSecureStorage extends SecureStorage {
  final Map<String, String> values = {};
  final persisting = Completer<void>();
  final release = Completer<void>();
  bool failRemoval = false;
  int removalCalls = 0;
  bool failCancellationWrite = false;
  bool _gateFirstWrite = true;

  @override
  Future<String?> get(String key) async => values[key];

  @override
  Future<void> set(String key, String value) async {
    if (failCancellationWrite) {
      throw StateError('Fixture secure write failure');
    }
    // Model the plugin having committed bytes before its Future completes.
    values[key] = value;
    if (_gateFirstWrite) {
      _gateFirstWrite = false;
      persisting.complete();
      await release.future;
    }
  }

  @override
  Future<void> remove(String key) async {
    removalCalls++;
    if (failRemoval) {
      throw StateError('Fixture secure delete failure');
    }
    values.remove(key);
  }
}
