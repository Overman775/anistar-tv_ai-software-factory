import 'package:anistar/anistar.dart';
import 'package:anistar/providers.dart';
import 'package:anistar_tv/app/app_container.dart';
import 'package:anistar_tv/packages/features/anime/anime_providers.dart';
import 'package:anistar_tv/packages/features/auth/auth_providers.dart';
import 'package:anistar_tv/packages/features/catalog/catalog_providers.dart';
import 'package:anistar_tv/packages/features/favorites/favorites_providers.dart';
import 'package:anistar_tv/packages/features/log_viewer/domain/repositories/log_repository.dart';
import 'package:anistar_tv/packages/features/log_viewer/log_viewer_providers.dart';
import 'package:anistar_tv/packages/features/player/player_providers.dart';
import 'package:anistar_tv/packages/features/watch_history/watch_history_providers.dart';
import 'package:app_logging/app_logging.dart';
import 'package:app_logging/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:networking/providers.dart';
import 'package:storage/providers.dart';
import 'package:storage/storage.dart';

import '../mocks/anistar/anistar_fixtures.dart';
import '../mocks/anistar/auth_fixture_adapter.dart';
import '../mocks/anistar/fake_anistar_client.dart';
import '../mocks/features/log_viewer/fake_log_repository.dart';
import '../mocks/networking/html_fixture_adapter.dart';
import '../mocks/storage/memory_secure_storage.dart';

void main() {
  test('all network repository bindings receive a contract-only client override without HTML startup', () async {
    final client = FakeAnistarClient()..watchedResult = {1};
    final container = ProviderContainer(
      overrides: [
        ...createAppOverrides(
          logger: Logger(level: Level.off),
          mirrorUri: Uri.parse('https://mirror.test/'),
          preferences: SharedPreferencesStorage(),
          secureStorage: MemorySecureStorage(),
        ),
        anistarClientProvider.overrideWithValue(client),
      ],
    );
    addTearDown(container.dispose);
    await container.read(authRepositoryProvider).restore();
    await container.read(catalogRepositoryProvider).getPage(1);
    await container.read(catalogBrowseRepositoryProvider).getGenres();
    await container.read(animeRepositoryProvider).getAnime(id: 1, slug: '1-anime');
    await container.read(playbackRepositoryProvider).createSession(animeId: 1, episodeNumber: 1);
    await container.read(favoritesRepositoryProvider).getPage(1);
    await container.read(watchedEpisodesRepositoryProvider).getWatched(1);
    expect(client.calls, [
      'restore',
      'catalog',
      'genres',
      'details',
      'episodes',
      'episodes',
      'favorites',
      'watchedEpisodes',
    ]);
    expect(container.read(anistarClientProvider), same(client));
  });

  test('log binding is supplied by composition and can be overridden independently', () async {
    final production = ProviderContainer(
      overrides: createAppOverrides(
        logger: Logger(level: Level.off),
        mirrorUri: Uri.parse('https://mirror.test/'),
        preferences: SharedPreferencesStorage(),
        secureStorage: MemorySecureStorage(),
      ),
    );
    addTearDown(production.dispose);
    expect(production.read(logRepositoryProvider), isA<LogRepository>());
    final logs = FakeLogRepository(files: ['test.txt'], content: 'Test');
    final isolated = ProviderContainer(overrides: [logRepositoryProvider.overrideWithValue(logs)]);
    addTearDown(isolated.dispose);
    final repository = isolated.read(logRepositoryProvider);
    expect((await repository.getLogFiles()).successOrNull, ['test.txt']);
    expect((await repository.getLogContent('test.txt')).successOrNull, 'Test');
  });

  test('auth and catalog share one client, transport and cookie session; logout clears both', () async {
    final container = ProviderContainer(
      overrides: createAppOverrides(
        logger: Logger(level: Level.off),
        mirrorUri: Uri.parse('https://v30.astar.bz/'),
        preferences: SharedPreferencesStorage(),
        secureStorage: MemorySecureStorage(),
      ),
    );
    addTearDown(container.dispose);
    final adapter = AuthFixtureAdapter()..authenticatedBody = '$memberAuthHtml$catalogHtml';
    final dio = container.read(dioProvider)..httpClientAdapter = adapter;
    final client = container.read(anistarClientProvider);
    final auth = container.read(authRepositoryProvider);
    expect((await auth.signIn('test', 'private-password')).successOrNull, 'test');
    final page = await container.read(catalogRepositoryProvider).getPage(1);
    expect(page.successOrNull?.items.single.id, 10938);
    // Capture different requests before and after logout, never reuse a snapshot.
    // ignore: prefer-moving-to-variable
    final authenticatedHeaders = adapter.requests.last.headers;
    expect(authenticatedHeaders['Cookie'], contains('dle_password=session-secret'));
    expect(container.read(anistarClientProvider), same(client));
    expect(container.read(anistarDioProvider), same(dio));

    expect((await auth.signOut()).isSuccess, isTrue);
    expect(await client.restore(), isNull);
    await expectLater(client.catalog(1), throwsA(isA<AnistarClientException>()));
    // ignore: prefer-moving-to-variable
    final guestHeaders = adapter.requests.last.headers;
    expect(guestHeaders.containsKey('Cookie'), isFalse);
  });

  test('composition binds all repositories and owns one disposable HTTP transport', () async {
    final logger = Logger(level: Level.off);
    final preferences = SharedPreferencesStorage(logger: logger);
    final secure = MemorySecureStorage();
    final container = ProviderContainer(
      overrides: createAppOverrides(
        logger: logger,
        mirrorUri: Uri.parse('https://v30.astar.bz/'),
        preferences: preferences,
        secureStorage: secure,
      ),
    );
    final adapter = HtmlFixtureAdapter({
      '/anime/': catalogHtml,
      '/10938-test.html': detailHtml,
      '/test/player2/videoas_p2p_new.php': playerHtml,
    });
    container.read(dioProvider).httpClientAdapter = adapter;
    addTearDown(() {
      container.dispose();
      expect(adapter.isClosed, isTrue);
    });
    expect(container.read(loggerProvider), same(logger));
    expect(container.read(sharedPreferencesStorageProvider), same(preferences));
    expect(container.read(secureStorageProvider), same(secure));
    final page = await container.read(catalogRepositoryProvider).getPage(1);
    final anime = await container.read(animeRepositoryProvider).getAnime(id: 10938, slug: '10938-test');
    final session = await container.read(playbackRepositoryProvider).createSession(animeId: 10938, episodeNumber: 1);
    expect(page.successOrNull?.items.single.id, 10938);
    expect(anime.successOrNull?.episodes, hasLength(2));
    expect(session.successOrNull?.manifestUri.toString(), signed720);
    final headers = adapter.requests.first.headers;
    expect(headers['User-Agent'], 'AniStarTV/1.0');
    expect(headers['Accept'], 'text/html');
  });
}
