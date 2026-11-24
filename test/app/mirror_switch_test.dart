import 'package:anistar/anistar.dart';
import 'package:anistar/html.dart';
import 'package:anistar/providers.dart';
import 'package:anistar_tv/app/app_container.dart';
import 'package:app_logging/app_logging.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:networking/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storage/storage.dart';

import '../mocks/anistar/anistar_fixtures.dart';
import '../mocks/anistar/mirror_fixture_adapter.dart';
import '../mocks/networking/html_fixture_adapter.dart';
import '../mocks/storage/memory_secure_storage.dart';

void main() {
  for (final sameOrigin in [true, false]) {
    test('authenticated detail 301 ${sameOrigin ? 'follows the canonical slug' : 'probes without replay'}', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = SharedPreferencesStorage();
      final origin = Uri.parse('https://v1.astar.pw/');
      final otherOrigin = Uri.parse('https://v2.astar.pw/');
      final probeAdapter = MirrorFixtureAdapter({origin.host: 200});
      final manager = AnistarMirrorManager(
        initial: origin,
        storage: preferences,
        probe: Dio()..httpClientAdapter = probeAdapter,
      );
      addTearDown(manager.close);
      await manager.initialize();
      await manager.ensureAvailable();
      probeAdapter.requests.clear();

      const shortPath = '/10686-.html';
      const canonicalPath = '/10686-canonical.html';
      const cookie = 'dle_user_id=42';
      final target = (sameOrigin ? origin : otherOrigin).resolve(canonicalPath);
      final requestAdapter = HtmlFixtureAdapter(
        {canonicalPath: detailHtml},
        overrides: {
          shortPath: (
            statusCode: 301,
            headers: {
              'location': [target.toString()],
            },
          ),
        },
      );
      final container = ProviderContainer(
        overrides: [
          ...createAppOverrides(
            logger: Logger(level: Level.off),
            mirrorUri: manager.current,
            preferences: preferences,
            secureStorage: MemorySecureStorage(),
            mirrorManager: manager,
          ),
          dioProvider.overrideWith((ref) {
            final dio = Dio(BaseOptions(baseUrl: ref.watch(networkConfigProvider).baseUri.toString()))
              ..httpClientAdapter = requestAdapter;
            ref.onDispose(() => dio.close(force: true));

            return dio;
          }),
        ],
      );
      addTearDown(container.dispose);
      final origins = <Uri>[];
      final subscription = container.listen(anistarActiveMirrorProvider, (_, next) => origins.add(next));
      addTearDown(subscription.close);
      await container.pump();
      final session = container.read(anistarSessionProvider);
      final client = container.read(anistarClientProvider);
      await session.initialize();
      final generation = session.generation;
      await session.saveCookies(origin, ['$cookie; Path=/; Secure'], generation);
      await session.authenticate('account', generation);
      final accessGeneration = session.accessGeneration;

      if (sameOrigin) {
        final details = await client.details('10686-');
        expect((details.id, details.slug, details.title), (10686, '10686-canonical', 'Тестовое аниме & друзья'));
        expect(probeAdapter.requests, isEmpty);
      } else {
        await expectLater(
          client.details('10686-'),
          throwsA(
            isA<AnistarClientException>().having(
              (failure) => failure.category,
              'category',
              AnistarClientErrorCategory.request,
            ),
          ),
        );
        expect(probeAdapter.requests.map((request) => request.uri), [origin.resolve('/anime/')]);
        expect(probeAdapter.requests.single.headers['Cookie'], isNull);
      }

      await container.pump();
      expect(requestAdapter.requests.map((request) => request.uri), [
        origin.resolve(shortPath),
        if (sameOrigin) target,
      ]);
      expect(requestAdapter.requests.map((request) => request.headers['Cookie']), everyElement(cookie));
      expect(manager.current, origin);
      expect(origins, isEmpty);
      expect(container.read(anistarSessionProvider), same(session));
      expect(container.read(anistarClientProvider), same(client));
      expect((session.account, session.accessGeneration), ('account', accessGeneration));
      expect(await session.cookieHeader(origin), cookie);
      expect(await session.cookieHeader(otherOrigin), isNull);
    });
  }

  for (final status in [302, 503]) {
    test('POST $status switches composition without replay or copying origin-bound cookies', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = SharedPreferencesStorage();
      final probeAdapter = MirrorFixtureAdapter({'v1.astar.pw': 200});
      final manager = AnistarMirrorManager(
        initial: Uri.parse('https://v1.astar.pw/'),
        storage: preferences,
        probe: Dio()..httpClientAdapter = probeAdapter,
      );
      await manager.initialize();
      await manager.ensureAvailable();
      addTearDown(manager.close);
      final requestAdapter = MirrorFixtureAdapter({'v1.astar.pw': status})..location = 'https://v2.astar.pw/anime/';
      final container = ProviderContainer(
        overrides: [
          ...createAppOverrides(
            logger: Logger(level: Level.off),
            mirrorUri: manager.current,
            preferences: preferences,
            secureStorage: MemorySecureStorage(),
            mirrorManager: manager,
          ),
          dioProvider.overrideWith((ref) {
            final dio = Dio(BaseOptions(baseUrl: ref.watch(networkConfigProvider).baseUri.toString()))
              ..httpClientAdapter = requestAdapter;
            ref.onDispose(() => dio.close(force: true));

            return dio;
          }),
        ],
      );
      addTearDown(container.dispose);
      final origins = <Uri>[];
      final subscription = container.listen(anistarActiveMirrorProvider, (_, next) => origins.add(next));
      addTearDown(subscription.close);
      await container.pump();
      final previous = container.read(anistarSessionProvider);
      final previousClient = container.read(anistarClientProvider);
      await previous.initialize();
      final previousOrigin = previous.origin;
      final generation = previous.generation;
      await previous.saveCookies(previousOrigin, ['dle_user_id=42; Path=/; Secure'], generation);
      await previous.authenticate('account', generation);
      probeAdapter.statuses['v1.astar.pw'] = status;
      probeAdapter.statuses['v2.astar.pw'] = 200;
      final transport = container.read(anistarDioProvider);
      await expectLater(
        transport.post<Object?>(
          'anime/',
          data: 'login_password=private',
          options: Options(validateStatus: (code) => code != null && code < 400),
        ),
        throwsA(isA<DioException>()),
      );
      await container.pump();
      expect(requestAdapter.requests, hasLength(1));
      expect(manager.current.host, 'v2.astar.pw');
      expect(origins.single.host, 'v2.astar.pw');
      final next = container.read(anistarSessionProvider);
      expect(container.read(anistarClientProvider), isNot(same(previousClient)));
      expect(next, isNot(same(previous)));
      expect(next.origin.host, 'v2.astar.pw');
      final nextOrigin = next.origin;
      final cookies = await next.cookieHeader(nextOrigin);
      expect(cookies, isNull);
      final restored = await container.read(anistarClientProvider).restore();
      expect(restored, isNull);
      expect(
        probeAdapter.requests.every((request) => !request.headers.containsKey('Cookie') && request.data == null),
        isTrue,
      );
    });
  }
}
