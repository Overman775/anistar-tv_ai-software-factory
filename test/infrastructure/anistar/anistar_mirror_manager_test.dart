import 'package:anistar/html.dart';
import 'package:anistar/parsing.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storage/storage.dart';

import '../../mocks/anistar/mirror_fixture_adapter.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  AnistarMirrorManager manager(MirrorFixtureAdapter adapter, {Uri? initial, DateTime Function()? now}) {
    final value = AnistarMirrorManager(
      initial: initial ?? Uri.parse('https://v1.astar.pw/'),
      storage: SharedPreferencesStorage(),
      probe: Dio()..httpClientAdapter = adapter,
      now: now,
    );
    addTearDown(value.close);

    return value;
  }

  test('healthy mirror is checked once, probes have no cookies or credentials', () async {
    final adapter = MirrorFixtureAdapter({'v1.astar.pw': 200});
    final value = manager(adapter);
    await value.initialize();
    await value.ensureAvailable();
    await value.ensureAvailable();
    expect(adapter.requests, hasLength(1));
    final request = adapter.requests.single;
    expect(request.uri.path, '/anime/');
    expect(request.followRedirects, isFalse);
    expect(request.headers.containsKey('Cookie'), isFalse);
    expect(request.data, isNull);
  });

  test('legacy cached version does not affect the new series', () async {
    const legacyKey = 'anistar.mirror.astar.bz.version';
    const currentKey = 'anistar.mirror.astar.pw.version';
    SharedPreferences.setMockInitialValues({legacyKey: 31});
    final adapter = MirrorFixtureAdapter({'v1.astar.pw': 200});
    final value = manager(adapter);
    await value.initialize();
    expect(value.current.host, 'v1.astar.pw');
    await value.ensureAvailable();
    expect(adapter.requests.map((request) => request.uri.host), ['v1.astar.pw']);
    final storage = SharedPreferencesStorage();
    expect(await storage.get<int>(legacyKey, 0), 31);
    expect(await storage.get<int>(currentKey, 0), 1);
  });

  test('blocked v1 skips v2 and persists only v3 for the next launch', () async {
    final adapter = MirrorFixtureAdapter({'v3.astar.pw': 200});
    final value = manager(adapter);
    await value.initialize();
    final changed = value.changes.first;
    await Future.wait([value.ensureAvailable(), value.ensureAvailable()]);
    expect(await changed, Uri.parse('https://v3.astar.pw/'));
    expect(adapter.requests.map((request) => request.uri.host), ['v1.astar.pw', 'v2.astar.pw', 'v3.astar.pw']);
    expect(await SharedPreferencesStorage().get<int>(AnistarMirrorManager.storageKey, 0), 3);
    final nextAdapter = MirrorFixtureAdapter({'v4.astar.pw': 200});
    final next = manager(nextAdapter);
    await next.initialize();
    expect(next.current.host, 'v3.astar.pw');
    expect(nextAdapter.requests, isEmpty);
    await next.ensureAvailable();
    expect(nextAdapter.requests.map((request) => request.uri.host), ['v3.astar.pw', 'v4.astar.pw']);
    expect(next.current.host, 'v4.astar.pw');
    expect(await SharedPreferencesStorage().get<int>('anistar.mirror.astar.pw.version', 0), 4);
  });

  test('all blocked candidates stop after four successors; failure has a cooldown', () async {
    var now = DateTime(2026, 10, 10);
    final adapter = MirrorFixtureAdapter({});
    final value = manager(adapter, now: () => now);
    await value.initialize();
    final unavailable = throwsA(isA<AnistarFailure>());
    await expectLater(value.ensureAvailable(), unavailable);
    final attempts = adapter.requests.length;
    expect(adapter.requests.map((request) => request.uri.host), [
      'v1.astar.pw',
      'v2.astar.pw',
      'v3.astar.pw',
      'v4.astar.pw',
      'v5.astar.pw',
    ]);
    final duringCooldown = value.ensureAvailable();
    await expectLater(duringCooldown, unavailable);
    expect(adapter.requests.length, attempts);
    expect(await SharedPreferencesStorage().containsKey(AnistarMirrorManager.storageKey), isFalse);
    now = now.add(const Duration(minutes: 1));
    adapter.statuses['v2.astar.pw'] = 200;
    await value.ensureAvailable();
    expect(value.current.host, 'v2.astar.pw');
  });

  test('recovery checks catalog before changing for an endpoint or CDN failure', () async {
    final adapter = MirrorFixtureAdapter({'v1.astar.pw': 200});
    final failedOrigin = Uri.parse('https://v1.astar.pw/');
    final value = manager(adapter);
    await value.initialize();
    await value.ensureAvailable();
    await value.recover(Uri.parse('https://cdn.test/video.m3u8'));
    expect(adapter.requests, hasLength(1));
    await value.recover(failedOrigin);
    expect(adapter.requests, hasLength(2));
    final before = value.current.host;
    expect(before, 'v1.astar.pw');
    adapter.statuses['v1.astar.pw'] = 451;
    adapter.statuses['v2.astar.pw'] = 200;
    await value.recover(failedOrigin);
    final after = value.current.host;
    expect(after, 'v2.astar.pw');
    await value.recover(Uri.parse('https://v1.astar.pw/anime/'));
    expect(adapter.requests, hasLength(4));
  });

  test('HTTP 200 with challenge or unrelated HTML is not a healthy mirror', () async {
    for (final challenge in [false, true]) {
      final adapter = MirrorFixtureAdapter({for (var v = 1; v <= 5; v++) 'v$v.astar.pw': 200})
        ..challenge = challenge
        ..html = '<h1>Access denied</h1>';
      final value = manager(adapter);
      await value.initialize();
      await expectLater(value.ensureAvailable(), throwsA(isA<AnistarFailure>()));
      expect(adapter.requests, hasLength(5));
    }
  });

  test('invalid and older cached versions do not override configured baseline', () async {
    for (final cached in [0, 1, 10000, '31']) {
      SharedPreferences.setMockInitialValues({AnistarMirrorManager.storageKey: cached});
      final value = manager(MirrorFixtureAdapter({}), initial: Uri.parse('https://v2.astar.pw/'));
      await value.initialize();
      expect(value.current.host, 'v2.astar.pw');
    }
  });

  test('custom origins keep their address and do not run discovery', () async {
    final adapter = MirrorFixtureAdapter({});
    final value = manager(adapter, initial: Uri.parse('https://localhost:8443/'));
    await value.initialize();
    await value.ensureAvailable();
    await value.recover(Uri.parse('https://localhost:8443/'));
    expect(adapter.requests, isEmpty);
    expect(value.current.toString(), 'https://localhost:8443/');
  });

  test('legacy series is fixed and never enters discovery', () async {
    final adapter = MirrorFixtureAdapter({});
    final value = manager(adapter, initial: Uri.parse('https://v31.astar.bz/'));
    await value.initialize();
    await value.ensureAvailable();
    await value.recover(Uri.parse('https://v31.astar.bz/'));
    expect(adapter.requests, isEmpty);
    expect(value.current.host, 'v31.astar.bz');
  });

  test('DNS/connection failures preserve the mirror and recover after the cooldown', () async {
    var now = DateTime(2026, 10, 11);
    final adapter = MirrorFixtureAdapter({'v1.astar.pw': 200})..failureType = DioExceptionType.connectionError;
    final value = manager(adapter, now: () => now);
    await value.initialize();
    await expectLater(value.ensureAvailable(), throwsA(isA<AnistarFailure>()));
    expect(value.current.host, 'v1.astar.pw');
    expect(adapter.requests, hasLength(5));
    expect(await SharedPreferencesStorage().containsKey(AnistarMirrorManager.storageKey), isFalse);

    adapter.failureType = null;
    now = now.add(const Duration(minutes: 1));
    await value.ensureAvailable();
    expect(adapter.requests.last.uri.host, 'v1.astar.pw');
    expect(await SharedPreferencesStorage().get<int>(AnistarMirrorManager.storageKey, 0), 1);
  });
}
