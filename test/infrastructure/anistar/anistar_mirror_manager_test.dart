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
      initial: initial ?? Uri.parse('https://v30.astar.bz/'),
      storage: SharedPreferencesStorage(),
      probe: Dio()..httpClientAdapter = adapter,
      now: now,
    );
    addTearDown(value.close);

    return value;
  }

  test('healthy mirror is checked once, probes have no cookies or credentials', () async {
    final adapter = MirrorFixtureAdapter({'v30.astar.bz': 200});
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

  test('blocked v30 skips v31 and persists only v32 for the next launch', () async {
    final adapter = MirrorFixtureAdapter({'v32.astar.bz': 200});
    final value = manager(adapter);
    await value.initialize();
    final changed = value.changes.first;
    await Future.wait([value.ensureAvailable(), value.ensureAvailable()]);
    expect(await changed, Uri.parse('https://v32.astar.bz/'));
    expect(adapter.requests.map((request) => request.uri.host), ['v30.astar.bz', 'v31.astar.bz', 'v32.astar.bz']);
    expect(await SharedPreferencesStorage().get<int>(AnistarMirrorManager.storageKey, 0), 32);
    final next = manager(MirrorFixtureAdapter({'v32.astar.bz': 200}));
    await next.initialize();
    expect(next.current.host, 'v32.astar.bz');
  });

  test('all blocked candidates stop after four successors; failure has a cooldown', () async {
    var now = DateTime(2026, 10, 10);
    final adapter = MirrorFixtureAdapter({});
    final value = manager(adapter, now: () => now);
    await value.initialize();
    final unavailable = throwsA(isA<AnistarFailure>());
    await expectLater(value.ensureAvailable(), unavailable);
    final attempts = adapter.requests.length;
    expect(attempts, 5);
    final duringCooldown = value.ensureAvailable();
    await expectLater(duringCooldown, unavailable);
    expect(adapter.requests.length, attempts);
    expect(await SharedPreferencesStorage().containsKey(AnistarMirrorManager.storageKey), isFalse);
    now = now.add(const Duration(minutes: 1));
    adapter.statuses['v31.astar.bz'] = 200;
    await value.ensureAvailable();
    expect(value.current.host, 'v31.astar.bz');
  });

  test('recovery checks catalog before changing for an endpoint or CDN failure', () async {
    final adapter = MirrorFixtureAdapter({'v30.astar.bz': 200});
    final failedOrigin = Uri.parse('https://v30.astar.bz/');
    final value = manager(adapter);
    await value.initialize();
    await value.ensureAvailable();
    await value.recover(Uri.parse('https://cdn.test/video.m3u8'));
    expect(adapter.requests, hasLength(1));
    await value.recover(failedOrigin);
    expect(adapter.requests, hasLength(2));
    final before = value.current.host;
    expect(before, 'v30.astar.bz');
    adapter.statuses['v30.astar.bz'] = 451;
    adapter.statuses['v31.astar.bz'] = 200;
    await value.recover(failedOrigin);
    final after = value.current.host;
    expect(after, 'v31.astar.bz');
    await value.recover(Uri.parse('https://v30.astar.bz/anime/'));
    expect(adapter.requests, hasLength(4));
  });

  test('HTTP 200 with challenge or unrelated HTML is not a healthy mirror', () async {
    for (final challenge in [false, true]) {
      final adapter = MirrorFixtureAdapter({for (var v = 30; v <= 34; v++) 'v$v.astar.bz': 200})
        ..challenge = challenge
        ..html = '<h1>Access denied</h1>';
      final value = manager(adapter);
      await value.initialize();
      await expectLater(value.ensureAvailable(), throwsA(isA<AnistarFailure>()));
      expect(adapter.requests, hasLength(5));
    }
  });

  test('invalid and older cached versions do not override configured baseline', () async {
    for (final cached in [29, 10000, '31']) {
      SharedPreferences.setMockInitialValues({AnistarMirrorManager.storageKey: cached});
      final value = manager(MirrorFixtureAdapter({}));
      await value.initialize();
      expect(value.current.host, 'v30.astar.bz');
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

  test('DNS/connection failures preserve the mirror and recover after the cooldown', () async {
    var now = DateTime(2026, 10, 11);
    final adapter = MirrorFixtureAdapter({'v30.astar.bz': 200})..failureType = DioExceptionType.connectionError;
    final value = manager(adapter, now: () => now);
    await value.initialize();
    await expectLater(value.ensureAvailable(), throwsA(isA<AnistarFailure>()));
    expect(value.current.host, 'v30.astar.bz');
    expect(adapter.requests, hasLength(5));
    expect(await SharedPreferencesStorage().containsKey(AnistarMirrorManager.storageKey), isFalse);

    adapter.failureType = null;
    now = now.add(const Duration(minutes: 1));
    await value.ensureAvailable();
    expect(adapter.requests.last.uri.host, 'v30.astar.bz');
    expect(await SharedPreferencesStorage().get<int>(AnistarMirrorManager.storageKey, 0), 30);
  });
}
