// Native playback changes between awaits: pumps and fresh controller snapshots
// must be repeated rather than cached across those transitions.
// ignore_for_file: prefer-moving-to-variable

import 'package:anistar_tv/app/app.dart';
import 'package:anistar_tv/packages/features/anime/presentation/screens/anime_screen.dart';
import 'package:anistar_tv/packages/features/auth/auth_providers.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/screens/catalog_screen.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/widgets/anime_card.dart';
import 'package:anistar_tv/packages/features/favorites/favorites_providers.dart';
import 'package:anistar_tv/packages/features/player/presentation/screens/player_screen.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storage/storage.dart';
import 'package:video_player/video_player.dart';

import 'support/live_harness.dart';

/// Live network smoke, deliberately separate from deterministic unit tests.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;

  testWidgets('Android direct catalog → anime → HLS → quality → episode → back', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
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
    expect(container.read(authControllerProvider).value, LiveHarness.username);
    final card = find.byWidgetPredicate((widget) => widget is AnimeCard && widget.anime.id == 10938);
    await _wait(tester, () => card.evaluate().isNotEmpty, 'anime 10938 in live catalog');
    await tester.ensureVisible(card);
    await tester.pump(const Duration(milliseconds: 500));
    final slug = tester.widget<AnimeCard>(card).anime.slug;
    await tester.tap(card);
    final playFirst = find.text('Смотреть серию 1');
    await _wait(tester, () => playFirst.evaluate().isNotEmpty, 'anime details and episodes');
    final favorites = container.read(favoritesRepositoryProvider);
    final status = await favorites.getStatus(animeId: 10938, slug: slug);
    final original = status.when(success: (value) => value, failure: (failure) => throw failure);
    final changedLabel = original ? 'Добавить в избранное' : 'Удалить из избранного';
    final originalLabel = original ? 'Удалить из избранного' : 'Добавить в избранное';
    try {
      final favorite = find.byKey(const ValueKey('favorite-button-10938'));
      await tester.ensureVisible(favorite);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(favorite);
      await _wait(tester, () => find.text(changedLabel).evaluate().isNotEmpty, 'website favorite toggle');
      final changed = await favorites.getStatus(animeId: 10938, slug: slug);
      expect(changed.when(success: (value) => value, failure: (failure) => throw failure), !original);
      await tester.tap(favorite);
      await _wait(tester, () => find.text(originalLabel).evaluate().isNotEmpty, 'website favorite restored');
    } finally {
      final restored = await favorites.setFavorite(animeId: 10938, slug: slug, favorite: original);
      restored.when(
        success: (_) => null,
        failure: (failure) => fail('Could not restore original favorite: ${failure.message}'),
      );
    }
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
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await _wait(tester, () => find.text('360p').evaluate().isNotEmpty, 'quality dialog');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    final previous = player;
    await _wait(tester, () => _player(tester) != null && !identical(_player(tester), previous), 'quality replacement');
    player = _requirePlayer(tester);
    await _wait(tester, () => player.value.position.inSeconds >= 121, '360p preserves seek position');
    expect(player.value.size.height, 360);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await _wait(tester, () => find.textContaining('Серия 2').evaluate().isNotEmpty, 'episode dialog');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    final firstEpisode = player;
    await _wait(
      tester,
      () => _player(tester) != null && !identical(_player(tester), firstEpisode),
      'episode replacement',
    );
    player = _requirePlayer(tester);
    await _wait(tester, () => player.value.position.inMilliseconds > 1000, 'episode 2 start');
    expect(player.value.position.inSeconds, lessThan(30));
    expect(player.value.hasError, isFalse);
    await tester.binding.handlePopRoute();
    await _wait(tester, () => find.byType(PlayerScreen).evaluate().isEmpty, 'back from player');
    expect(find.byType(AnimeScreen), findsOneWidget);
    await _wait(tester, () => find.byIcon(Icons.check_circle_rounded).evaluate().length == 2, 'two watched checks');
    await tester.pumpWidget(const SizedBox.shrink());
    await live.launch(tester);
    await _wait(tester, () => card.evaluate().isNotEmpty, 'catalog after second restart');
    await tester.ensureVisible(card);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(card);
    await _wait(
      tester,
      () => find.byIcon(Icons.check_circle_rounded).evaluate().length == 2,
      'persisted watched history',
    );
    await tester.binding.handlePopRoute();
    final logout = find.byTooltip('Выйти из аккаунта');
    await _wait(tester, () => logout.evaluate().isNotEmpty, 'logout action');
    await tester.tap(logout);
    await _wait(tester, () => find.byKey(const ValueKey('login_submit')).evaluate().isNotEmpty, 'logout gate');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}

VideoPlayerController? _player(WidgetTester tester) {
  final finder = find.byType(VideoPlayer);

  return finder.evaluate().isEmpty ? null : tester.widget<VideoPlayer>(finder).controller;
}

VideoPlayerController _requirePlayer(WidgetTester tester) =>
    _player(tester) ?? (throw TestFailure('Expected an initialized native player'));

Future<void> _wait(WidgetTester tester, bool Function() condition, String step) =>
    LiveHarness.wait(tester, condition, step);
