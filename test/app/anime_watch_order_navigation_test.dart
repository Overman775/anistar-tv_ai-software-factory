import 'dart:async';

import 'package:anistar/html.dart';
import 'package:anistar_tv/app/app_router.dart';
import 'package:anistar_tv/app/app_routes.dart';
import 'package:anistar_tv/packages/features/anime/anime_providers.dart';
import 'package:anistar_tv/packages/features/anime/data/repositories/anistar_anime_repository.dart';
import 'package:anistar_tv/packages/features/anime/presentation/screens/anime_screen.dart';
import 'package:anistar_tv/packages/features/catalog/catalog_providers.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/screens/catalog_screen.dart';
import 'package:app_logging/app_logging.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../mocks/anistar/anistar_fixtures.dart';
import '../mocks/anistar/test_anistar_client.dart';
import '../mocks/features/catalog/fake_catalog_screen_repository.dart';
import '../mocks/networking/html_fixture_adapter.dart';
import '../mocks/storage/memory_secure_storage.dart';
import '../support/test_app.dart';

void main() {
  for (final tv in [true, false]) {
    testWidgets('watch order follows the canonical title redirect and restores disclosure on ${tv ? 'TV' : 'mobile'}', (
      tester,
    ) async {
      final router = AppRouter(AppLogger.logger);
      addTearDown(router.dispose);
      final adapter = HtmlFixtureAdapter(
        {
          '/10938-test.html':
              '''
$detailHtml
<div class="news_text"><div class="title_spoiler">Порядок просмотра</div>
<div class="text_spoiler" hidden>
<a href="/10938-test.html">Первый сезон</a>
<a href="//v31.astar.bz/10686-.html">Второй сезон</a>
</div></div>
''',
          '/10686-second-season.html': detailHtml.replaceFirst(
            'Тестовое аниме &amp; друзья',
            'Карточка второго сезона',
          ),
          _episodesPath: playerHtml,
        },
        overrides: const {
          '/10686-.html': (
            statusCode: 301,
            headers: {
              'location': ['/10686-second-season.html'],
            },
          ),
        },
      );
      final dio = Dio(BaseOptions(baseUrl: 'https://v31.astar.bz/'))..httpClientAdapter = adapter;
      addTearDown(() => dio.close(force: true));
      final session = AnistarSession(Uri.parse(dio.options.baseUrl), MemorySecureStorage());
      addTearDown(session.close);
      dio.interceptors.add(AnistarSessionInterceptor(session));
      final repository = AnistarAnimeRepository(createTestAnistarClient(dio, session: session));
      final app = MaterialApp.router(routerConfig: router.router, theme: AppTheme.darkTheme);
      final overrides = [
        catalogRepositoryProvider.overrideWithValue(const FakeCatalogScreenRepository()),
        animeRepositoryProvider.overrideWithValue(repository),
      ];
      if (tv) {
        await pumpTvApp(tester, app, disableAnimations: true, wrapInScaffold: false, overrides: overrides);
      } else {
        await pumpMobileApp(tester, app, disableAnimations: true, wrapInScaffold: false, overrides: overrides);
      }
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(CatalogScreen));
      unawaited(const AnimeRoute(animeId: 10938, slug: '10938-test', title: 'Первый сезон').push<void>(context));
      await tester.pumpAndSettle();
      expect(find.text('Тестовое аниме & друзья'), findsOneWidget);

      final disclosure = find.text('Подробнее');
      await tester.ensureVisible(disclosure);
      await tester.tap(disclosure);
      await tester.pumpAndSettle();
      final linkedPart = find.text('Второй сезон');
      await tester.ensureVisible(linkedPart);
      await tester.pumpAndSettle();
      expect(find.text('Первый сезон, Открыто'), findsOneWidget);
      final partControl = find.ancestor(of: linkedPart, matching: find.byType(TvFocusable));
      final partFocus = tester.widget<TvFocusable>(partControl.first).focusNode;
      adapter.responses[_episodesPath] = playerHtml.replaceAll('Серия 1', 'Серия 9').replaceAll('Серия 2', 'Серия 10');
      if (tv) {
        partFocus?.requestFocus();
        await tester.pumpAndSettle();
        expect(FocusManager.instance.primaryFocus, same(partFocus));
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
      } else {
        await tester.tap(linkedPart);
      }
      await tester.pumpAndSettle();

      final screen = tester.widget<AnimeScreen>(find.byType(AnimeScreen));
      expect((screen.animeId, screen.slug), (10686, '10686-'));
      expect(
        adapter.requests.map((request) => request.uri.path),
        containsAllInOrder(['/10686-.html', '/10686-second-season.html']),
      );
      final episodes = adapter.requests.where((request) => request.uri.path == _episodesPath);
      expect(episodes.map((request) => request.uri.queryParameters['id']), ['10938', '10686']);
      expect(find.text('Карточка второго сезона'), findsOneWidget);
      expect(find.text('Серия 10'), findsOneWidget);
      expect(find.text('Серия 2'), findsNothing);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(tester.widget<AnimeScreen>(find.byType(AnimeScreen)).animeId, 10938);
      expect(linkedPart.hitTestable(), findsOneWidget);
      if (tv) expect(FocusManager.instance.primaryFocus, same(partFocus));
      expect(tester.takeException(), isNull);
    });
  }
}

const _episodesPath = '/test/player2/videoas_p2p_new.php';
