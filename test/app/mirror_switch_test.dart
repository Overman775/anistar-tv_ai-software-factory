import 'package:anistar/anistar.dart';
import 'package:anistar/providers.dart';
import 'package:anistar_tv/app/app_container.dart';
import 'package:app_logging/app_logging.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:networking/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storage/storage.dart';

import '../mocks/anistar/mirror_fixture_adapter.dart';
import '../mocks/storage/memory_secure_storage.dart';

void main() {
  for (final status in [302, 503]) {
    test('POST $status switches composition without replay or copying origin-bound cookies', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = SharedPreferencesStorage();
      final probeAdapter = MirrorFixtureAdapter({'v30.astar.bz': 200});
      final manager = AnistarMirrorManager(
        initial: Uri.parse('https://v30.astar.bz/'),
        storage: preferences,
        probe: Dio()..httpClientAdapter = probeAdapter,
      );
      await manager.initialize();
      await manager.ensureAvailable();
      addTearDown(manager.close);
      final requestAdapter = MirrorFixtureAdapter({'v30.astar.bz': status})..location = 'https://v31.astar.bz/anime/';
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
      await previous.initialize();
      final previousOrigin = previous.origin;
      final generation = previous.generation;
      await previous.saveCookies(previousOrigin, ['dle_user_id=42; Path=/; Secure'], generation);
      await previous.authenticate('account', generation);
      probeAdapter.statuses['v30.astar.bz'] = status;
      probeAdapter.statuses['v31.astar.bz'] = 200;
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
      expect(manager.current.host, 'v31.astar.bz');
      expect(origins.single.host, 'v31.astar.bz');
      final next = container.read(anistarSessionProvider);
      expect(next, isNot(same(previous)));
      expect(next.origin.host, 'v31.astar.bz');
      final nextOrigin = next.origin;
      final cookies = await next.cookieHeader(nextOrigin);
      expect(cookies, isNull);
      final restored = await container.read(anistarAuthServiceProvider).restore();
      expect(restored, isNull);
      expect(
        probeAdapter.requests.every((request) => !request.headers.containsKey('Cookie') && request.data == null),
        isTrue,
      );
    });
  }
}
