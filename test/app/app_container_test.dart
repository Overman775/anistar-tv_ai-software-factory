import 'package:anistar_tv/app/app_container.dart';
import 'package:anistar_tv/packages/features/anime/anime_providers.dart';
import 'package:anistar_tv/packages/features/catalog/catalog_providers.dart';
import 'package:anistar_tv/packages/features/player/player_providers.dart';
import 'package:app_logging/app_logging.dart';
import 'package:app_logging/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:networking/providers.dart';
import 'package:storage/providers.dart';
import 'package:storage/storage.dart';

import '../mocks/anistar/anistar_fixtures.dart';
import '../mocks/networking/html_fixture_adapter.dart';
import '../mocks/storage/memory_secure_storage.dart';

void main() {
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
