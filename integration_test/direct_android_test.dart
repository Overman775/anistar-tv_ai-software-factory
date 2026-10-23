// Native playback changes between awaits: pumps and fresh controller snapshots
// must be repeated rather than cached across those transitions.

import 'package:anistar/html.dart';
import 'package:anistar_tv/app/app.dart';
import 'package:anistar_tv/app/app_device_profile_resolver.dart';
import 'package:anistar_tv/packages/features/anime/anime_providers.dart';
import 'package:anistar_tv/packages/features/anime/presentation/screens/anime_screen.dart';
import 'package:anistar_tv/packages/features/anime/presentation/widgets/episode_card.dart';
import 'package:anistar_tv/packages/features/auth/auth_providers.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/screens/catalog_screen.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/widgets/anime_card.dart';
import 'package:anistar_tv/packages/features/favorites/favorites_providers.dart';
import 'package:anistar_tv/packages/features/player/presentation/screens/player_screen.dart';
import 'package:anistar_tv/packages/features/watch_history/watch_history_providers.dart';
import 'package:app_logging/app_logging.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:networking/networking.dart';
import 'package:networking/providers.dart';
import 'package:storage/storage.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:video_player/video_player.dart';

import 'support/e2e_harness.dart';
import 'support/live_harness.dart';
import 'support/remote_controls.dart';

/// Live network smoke, deliberately separate from deterministic unit tests.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;

  setUpAll(() async {
    expect(
      await AppDeviceProfileResolver.resolve(),
      AppDeviceProfile.tv,
      reason: 'Live remote-control E2E requires an Android TV system image.',
    );
  });

  E2eHarness.testCase('Android direct catalog → anime → HLS → quality → episode → back', (tester) async {
    final live = LiveHarness();
    await live.resetSession();
    await SharedPreferencesStorage().remove('anistar.watched.v1.${Uri.encodeComponent(LiveHarness.username)}.10938');
    await live.launch(tester);
    await LiveHarness.login(tester);
    await _wait(tester, () => find.byType(CatalogScreen).evaluate().isNotEmpty, 'authenticated catalog');
    expect(live.loginPosts, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await live.launch(tester);
    await _wait(tester, () => find.byType(CatalogScreen).evaluate().isNotEmpty, 'encrypted session restoration');
    expect(live.loginPosts, 1, reason: 'restore must not submit credentials again');
    final container = ProviderScope.containerOf(tester.element(find.byType(App)));
    expect(container.read(authAccessProvider).account, LiveHarness.username);
    final card = find.byWidgetPredicate((widget) => widget is AnimeCard && widget.anime.id == 10938);
    await _showCatalogCard(tester, card, 'anime 10938 in live catalog');
    await tester.ensureVisible(card);
    await tester.pump(const Duration(milliseconds: 500));
    final slug = tester.widget<AnimeCard>(card).anime.slug;
    await tester.tap(card);
    await _wait(
      tester,
      () => find.textContaining('Смотреть серию ').evaluate().isNotEmpty,
      'anime details and episodes',
    );
    await _verifyFavorites(tester, live, slug);
    final activeContainer = ProviderScope.containerOf(tester.element(find.byType(App)));
    final anime = (await activeContainer.read(animeRepositoryProvider).getAnime(id: 10938, slug: slug)).when(
      success: (data) => data,
      failure: (failure) => throw failure,
    );
    final unviewed = anime.episodes.where((episode) => !episode.isWatched && episode.number != 1);
    final secondEpisode = unviewed.isEmpty ? 2 : unviewed.first.number;
    // The primary action resumes the first unviewed episode. Server history
    // survives live runs, so select episode 1 explicitly instead of clearing it.
    final playFirst = find.byWidgetPredicate((widget) => widget is EpisodeCard && widget.episode.number == 1);
    final episodeScroll = find.descendant(of: find.byType(AnimeScreen), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(playFirst, 180, scrollable: episodeScroll);
    await tester.ensureVisible(playFirst);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(playFirst);
    await _wait(tester, () => _player(tester)?.value.isInitialized ?? false, '720p initialization');
    var player = _requirePlayer(tester);
    expect(player.formatHint, VideoFormat.hls);
    expect(player.httpHeaders['Referer'], contains('id=10938'));
    await _wait(tester, () => player.value.position.inMilliseconds > 1000, '720p playback');
    expect(player.value.size.height, 720);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await _wait(tester, () => player.value.position.inSeconds >= 10, 'remote seek');
    await player.seekTo(const Duration(seconds: 120));
    await _wait(tester, () => player.value.position.inSeconds >= 121, 'seek and resume');
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(seconds: 1));
    expect(player.value.isPlaying, isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await _wait(tester, () => player.value.isPlaying, 'remote resume');
    await RemoteControls.openQuality(tester);
    await _wait(tester, () => find.text('SD 360p').evaluate().isNotEmpty, 'quality dialog');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    final previous = player;
    await _wait(tester, () => _player(tester) != null && !identical(_player(tester), previous), 'quality replacement');
    player = _requirePlayer(tester);
    await _wait(tester, () => player.value.position.inSeconds >= 121, '360p preserves seek position');
    expect(player.value.size.height, 360);
    await RemoteControls.openEpisodes(tester);
    await _wait(tester, () => find.text('Выбор серии').evaluate().isNotEmpty, 'episode dialog');
    await RemoteControls.chooseEpisode(tester, secondEpisode);
    final firstEpisode = player;
    await _wait(
      tester,
      () => _player(tester) != null && !identical(_player(tester), firstEpisode),
      'episode replacement',
    );
    player = _requirePlayer(tester);
    await _wait(tester, () => player.value.position.inMilliseconds > 1000, 'selected episode start');
    expect(player.value.position.inSeconds, lessThan(30));
    expect(player.value.hasError, isFalse);
    await tester.binding.handlePopRoute();
    await _wait(tester, () => find.byType(PlayerScreen).evaluate().isEmpty, 'back from player');
    expect(find.byType(AnimeScreen), findsOneWidget);
    await _verifyWatched(tester, slug, {1, secondEpisode});
    await tester.pumpWidget(const SizedBox.shrink());
    await live.launch(tester);
    await _showCatalogCard(tester, card, 'catalog after second restart');
    await tester.ensureVisible(card);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(card);
    await _verifyWatched(tester, slug, {1, secondEpisode});
    await tester.binding.handlePopRoute();
    final logout = find.byTooltip('Выйти из аккаунта');
    await _wait(tester, () => logout.evaluate().isNotEmpty, 'logout action');
    await tester.tap(logout);
    await _wait(tester, () => find.byKey(const ValueKey('login_submit')).evaluate().isNotEmpty, 'logout gate');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  }, profile: AppDeviceProfile.tv);
}

VideoPlayerController? _player(WidgetTester tester) {
  final finder = find.byType(VideoPlayer);

  return finder.evaluate().isEmpty ? null : tester.widget<VideoPlayer>(finder).controller;
}

VideoPlayerController _requirePlayer(WidgetTester tester) =>
    _player(tester) ?? (throw TestFailure('Expected an initialized native player'));

Future<void> _wait(WidgetTester tester, bool Function() condition, String step) =>
    LiveHarness.wait(tester, condition, step);

Future<void> _verifyFavorites(WidgetTester tester, LiveHarness live, String slug) async {
  const animeId = 10938;
  final favoriteButton = find.byKey(const ValueKey('favorite-button-10938'));
  final card = find.byWidgetPredicate((widget) => widget is AnimeCard && widget.anime.id == animeId);
  // An independent cookie snapshot survives app unmount/relaunch, including a
  // failure while no ProviderScope is mounted. Keep transport until restoration.
  final origin = ProviderScope.containerOf(tester.element(find.byType(App))).read(networkConfigProvider).baseUri;
  final session = AnistarSession(origin, SecureStorage());
  final dio = DioClient.create(
    config: NetworkConfig(baseUri: origin),
    logger: AppLogger.logger,
    enableRetry: false,
  );
  dio.interceptors.add(AnistarSessionInterceptor(session));
  final client = HtmlAnistarClient(dio, session);
  bool? original;
  var bodyFailed = false;
  try {
    await session.initialize();
    original = await client.favoriteStatus(animeId: animeId, slug: slug);
    // Touch locates a known live title among a changing catalog. The native
    // player journey verifies the remote-control UX separately.
    if (original) {
      await tester.tap(favoriteButton);
      await _wait(tester, () => find.text('Добавить в избранное').evaluate().isNotEmpty, 'remove initial favorite');
    }
    await tester.tap(favoriteButton);
    await _wait(tester, () => find.text('Удалить из избранного').evaluate().isNotEmpty, 'confirmed website addition');
    await tester.binding.handlePopRoute();
    await _wait(tester, () => card.evaluate().isNotEmpty, 'main star after addition');
    expect(find.descendant(of: card, matching: find.byIcon(Icons.star_rounded)), findsOneWidget);
    await _selectTab(tester, 'Избранное');
    await _wait(tester, () => card.evaluate().isNotEmpty, 'authenticated favorites list');
    // Verify the badge on the distinct favorites route as well as the main route.
    expect(find.descendant(of: card, matching: find.byIcon(Icons.star_rounded)), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await live.launch(tester);
    await _showCatalogCard(tester, card, 'main after favorite restart');
    await _selectTab(tester, 'Избранное');
    await _wait(tester, () => card.evaluate().isNotEmpty, 'favorite persists on website');
    await tester.ensureVisible(card);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(card);
    await _wait(
      tester,
      () => find.text('Удалить из избранного').evaluate().isNotEmpty,
      'favorite detail after restart',
    );
    await tester.tap(favoriteButton);
    await _wait(tester, () => find.text('Добавить в избранное').evaluate().isNotEmpty, 'confirmed website removal');
    await tester.binding.handlePopRoute();
    await _wait(
      tester,
      () =>
          find.text('Избранное пусто').evaluate().isNotEmpty ||
          (find.byType(CatalogScreen).evaluate().isNotEmpty &&
              find.byType(AnimeCard).evaluate().isNotEmpty &&
              card.evaluate().isEmpty),
      'favorites list after removal',
    );
    expect(find.text('Избранное недоступно'), findsNothing);
    final repository = ProviderScope.containerOf(tester.element(find.byType(App))).read(favoritesRepositoryProvider);
    final page = (await repository.getPage(1)).when(success: (value) => value, failure: (failure) => throw failure);
    expect(page.items.any((anime) => anime.id == animeId), isFalse);
    await _selectTab(tester, 'Главная');
    await _wait(tester, () => find.byType(AnimeCard).evaluate().isNotEmpty, 'main after removal');
    final catalogScroll = find.descendant(of: find.byType(CatalogScreen), matching: find.byType(Scrollable)).first;
    tester.state<ScrollableState>(catalogScroll).position.jumpTo(0);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.scrollUntilVisible(card, 180, scrollable: catalogScroll);
    expect(find.descendant(of: card, matching: find.byIcon(Icons.star_rounded)), findsNothing);
    await tester.ensureVisible(card);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(card);
    await _wait(tester, () => favoriteButton.evaluate().isNotEmpty, 'return to anime');
  } on Object {
    bodyFailed = true;
    rethrow;
  } finally {
    try {
      if (original != null) {
        try {
          final restored = await client.setFavorite(animeId: animeId, slug: slug, favorite: original);
          expect(restored, original, reason: 'restore the original website favorite');
        } on Object catch (error) {
          if (!bodyFailed) {
            rethrow;
          }
          // Preserve the original failure without printing request objects that
          // could contain live-account credentials.
          debugPrint('Favorite cleanup also failed: ${error.runtimeType}');
        }
      }
    } finally {
      dio.close(force: true);
      await session.close();
    }
  }
}

Future<void> _verifyWatched(WidgetTester tester, String slug, Set<int> expected) async {
  final container = ProviderScope.containerOf(tester.element(find.byType(App)));
  final repository = container.read(watchedEpisodesRepositoryProvider);
  await _wait(tester, () => find.byType(AnimeScreen).evaluate().isNotEmpty, 'watched detail');
  final confirmed = (await repository.getWatched(10938))
      .when(success: (value) => value, failure: (failure) => throw failure);
  expect(confirmed, containsAll(expected));
  final fresh = (await container.read(animeRepositoryProvider).getAnime(id: 10938, slug: slug)).when(
    success: (value) => value,
    failure: (failure) => throw failure,
  );
  expect(fresh.episodes.where((episode) => episode.isWatched).map((episode) => episode.number), containsAll(expected));
  await _wait(tester, () => find.byType(EpisodeCard).evaluate().isNotEmpty, 'watched episode grid ready');
  for (final number in expected.toList()..sort((a, b) => b.compareTo(a))) {
    final card = find.byWidgetPredicate((widget) => widget is EpisodeCard && widget.episode.number == number);
    await tester.scrollUntilVisible(
      card,
      180,
      scrollable: find.descendant(of: find.byType(AnimeScreen), matching: find.byType(Scrollable)).first,
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.descendant(of: card, matching: find.byIcon(Icons.check_circle_rounded)), findsOneWidget);
  }
}

Future<void> _selectTab(WidgetTester tester, String label) async {
  final tab = find.byKey(ValueKey('catalog-tab-${label == 'Избранное'}'));
  await _wait(tester, () => tab.evaluate().isNotEmpty, 'tab available: $label');
  await tester.tap(tab);
  await _wait(
    tester,
    () => find.byType(AnimeCard).evaluate().isNotEmpty || find.text('Избранное пусто').evaluate().isNotEmpty,
    'catalog after menu selection',
  );
  await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _showCatalogCard(WidgetTester tester, Finder card, String step) async {
  await _wait(tester, () => find.byType(AnimeCard).evaluate().isNotEmpty, step);
  final scroll = find.descendant(of: find.byType(CatalogScreen), matching: find.byType(Scrollable)).first;
  tester.state<ScrollableState>(scroll).position.jumpTo(0);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.scrollUntilVisible(card, 180, scrollable: scroll);
}
