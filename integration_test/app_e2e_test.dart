// Native controller state changes on the Android event loop between pumps.
// ignore_for_file: prefer-moving-to-variable

import 'package:anistar_tv/packages/features/anime/presentation/screens/anime_screen.dart';
import 'package:anistar_tv/packages/features/auth/presentation/login_screen.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/screens/catalog_screen.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/widgets/anime_card.dart';
import 'package:anistar_tv/packages/features/player/presentation/screens/player_screen.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:video_player/video_player.dart';

import 'support/e2e_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  late E2eHarness fixture;

  setUp(() => fixture = E2eHarness());
  tearDown(() => fixture.close());

  testWidgets('login rejection, encrypted restore, expiry and logout gate the catalog', (tester) async {
    await fixture.configure();
    await fixture.launch(tester, autoLogin: false);
    expect(find.byType(CatalogScreen), findsNothing);
    await E2eHarness.login(tester, password: 'wrong');
    await E2eHarness.waitFor(
      tester,
      () => find.text('Вход не выполнен. Проверьте логин и пароль.').evaluate().isNotEmpty,
      'rejected login',
    );
    // Verify the gate again after this separate session transition.
    // ignore: avoid-duplicate-test-assertions
    expect(find.byType(CatalogScreen), findsNothing);
    await E2eHarness.login(tester);
    await E2eHarness.waitFor(tester, () => find.byType(AnimeCard).evaluate().isNotEmpty, 'authenticated catalog');
    final postCount = _events(await fixture.state()).where((event) => event['method'] == 'POST').length;
    await tester.pumpWidget(const SizedBox.shrink());
    await fixture.launch(tester, autoLogin: false, resetSession: false);
    await E2eHarness.waitFor(
      tester,
      () => find.byType(AnimeCard).evaluate().isNotEmpty,
      'encrypted session restoration',
    );
    expect(_events(await fixture.state()).where((event) => event['method'] == 'POST'), hasLength(postCount));
    await fixture.expireSession();
    await tester.tap(find.byTooltip('Обновить каталог'));
    await E2eHarness.waitFor(tester, () => find.byType(LoginScreen).evaluate().isNotEmpty, 'expired session gate');
    // Verify the gate again after this separate session transition.
    // ignore: avoid-duplicate-test-assertions
    expect(find.byType(CatalogScreen), findsNothing);
    await E2eHarness.login(tester);
    await E2eHarness.waitFor(tester, () => find.byType(AnimeCard).evaluate().isNotEmpty, 'second login');
    await tester.tap(find.byTooltip('Выйти из аккаунта'));
    await E2eHarness.waitFor(tester, () => find.byType(LoginScreen).evaluate().isNotEmpty, 'logout gate');
    await tester.pumpWidget(const SizedBox.shrink());
    await fixture.launch(tester, autoLogin: false, resetSession: false);
    await E2eHarness.waitFor(
      tester,
      () =>
          find.byKey(const ValueKey('login_submit')).evaluate().isNotEmpty &&
          tester.widget<FilledButton>(find.byKey(const ValueKey('login_submit'))).onPressed != null,
      'logout survives restart',
    );
    // Verify the gate again after this separate session transition.
    // ignore: avoid-duplicate-test-assertions
    expect(find.byType(CatalogScreen), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('website favorites survive a new client and update both tabs and details', (tester) async {
    await fixture.configure();
    await fixture.launch(tester);
    await E2eHarness.waitFor(tester, () => find.byType(AnimeCard).evaluate().isNotEmpty, 'favorites catalog');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.select);
    expect(find.text('Добавить в избранное'), findsNothing);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
    await E2eHarness.waitFor(tester, () => find.text('Добавить в избранное').evaluate().isNotEmpty, 'held OK menu');
    expect(find.byType(AnimeScreen), findsNothing);
    expect((await fixture.state())['favorite_writes'], 0);
    await tester.tap(find.text('Добавить в избранное'));
    final marker = find.byKey(const ValueKey('favorite-10938'));
    await E2eHarness.waitFor(tester, () => marker.evaluate().isNotEmpty, 'confirmed catalog star');
    final added = await fixture.state();
    expect(added['favorites'], [10938]);
    expect(added['favorite_writes'], 1);
    final write = _events(added).singleWhere((event) => _path(event).startsWith('/engine/ajax/favorites.php'));
    expect(write['authenticated'], isTrue);
    expect(write['referer'], '${fixture.origin}10938-test.html');
    // Recreate the complete app/provider tree. The list lives on the site fixture.
    await tester.pumpWidget(const SizedBox.shrink());
    await fixture.launch(tester, autoLogin: false, resetSession: false);
    await E2eHarness.waitFor(tester, () => marker.evaluate().isNotEmpty, 'site star after client restart');
    await tester.tap(find.byKey(const ValueKey('catalog-tab-true')));
    await E2eHarness.waitFor(tester, () => find.byType(AnimeCard).evaluate().length == 1, 'website favorites tab');
    await tester.tap(find.byType(AnimeCard));
    await E2eHarness.waitFor(
      tester,
      () => find.text('Удалить из избранного').evaluate().isNotEmpty,
      'detail removal action',
    );
    await tester.tap(find.text('Удалить из избранного'));
    await E2eHarness.waitFor(
      tester,
      () => find.text('Добавить в избранное').evaluate().isNotEmpty,
      'confirmed detail removal',
    );
    await tester.binding.handlePopRoute();
    await E2eHarness.waitFor(
      tester,
      () => find.text('Избранное пусто').evaluate().isNotEmpty && find.byType(AnimeScreen).evaluate().isEmpty,
      'favorites reload after detail',
    );
    final removed = await fixture.state();
    expect(removed['favorites'], isEmpty);
    expect(removed['favorite_writes'], 2);
    // Simulate adding on another client, then read the site's current state.
    await fixture.configure(reset: false, favorites: '10938');
    await tester.tap(find.byKey(const ValueKey('catalog-tab-false')));
    await E2eHarness.waitFor(tester, () => marker.evaluate().isNotEmpty, 'external website change');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('site rejects a favorite mutation without changing the UI; explicit retry recovers', (tester) async {
    await fixture.configure(favoriteError: true);
    await fixture.launch(tester);
    await E2eHarness.waitFor(tester, () => find.byType(AnimeCard).evaluate().isNotEmpty, 'favorite error catalog');
    await tester.longPress(find.byType(AnimeCard).first);
    await E2eHarness.waitFor(
      tester,
      () => find.text('Добавить в избранное').evaluate().isNotEmpty,
      'touch favorite menu',
    );
    await tester.tap(find.text('Добавить в избранное'));
    await E2eHarness.waitFor(tester, () => find.text('Обновить статус').evaluate().isNotEmpty, 'favorite rejection');
    expect(find.byKey(const ValueKey('favorite-10938')), findsNothing);
    expect((await fixture.state())['favorites'], isEmpty);
    await fixture.configure(reset: false);
    await tester.tap(find.text('Обновить статус'));
    await E2eHarness.waitFor(
      tester,
      () => find.text('Добавить в избранное').evaluate().isNotEmpty,
      'fresh favorite status',
    );
    await tester.tap(find.text('Добавить в избранное'));
    await E2eHarness.waitFor(
      tester,
      () => find.byKey(const ValueKey('favorite-10938')).evaluate().isNotEmpty,
      'manual favorite retry',
    );
    expect((await fixture.state())['favorite_writes'], 2);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('remote tabs, empty favorites, dialog cancellation and route focus restoration', (tester) async {
    await fixture.configure(favorites: '');
    await fixture.launch(tester);
    await E2eHarness.waitFor(tester, () => find.byType(AnimeCard).evaluate().isNotEmpty, 'remote catalog');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump(const Duration(milliseconds: 250));
    expect(
      FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<TextButton>()?.key,
      const ValueKey('catalog-tab-false'),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await E2eHarness.waitFor(tester, () => find.text('Избранное пусто').evaluate().isNotEmpty, 'empty favorites');
    expect(
      FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<TextButton>()?.key,
      const ValueKey('catalog-tab-true'),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await E2eHarness.waitFor(tester, () => find.byType(AnimeCard).evaluate().isNotEmpty, 'remote home tab');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await E2eHarness.waitFor(tester, () => find.byType(AnimeScreen).evaluate().isNotEmpty, 'remote detail');
    await tester.binding.handlePopRoute();
    await E2eHarness.waitFor(tester, () => find.byType(AnimeScreen).evaluate().isEmpty, 'return to same card');
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await E2eHarness.waitFor(tester, () => find.byType(AnimeScreen).evaluate().isNotEmpty, 'reopen same card');
    await _openVideo(tester);
    final player = E2eHarness.requirePlayer(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await E2eHarness.waitFor(tester, () => find.text('360p').evaluate().isNotEmpty, 'remote chooser');
    await tester.binding.handlePopRoute();
    await E2eHarness.waitFor(tester, () => find.text('360p').evaluate().isEmpty, 'cancel chooser');
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await E2eHarness.waitFor(tester, () => !player.value.isPlaying, 'remote pause after cancellation');
    expect(identical(player, E2eHarness.requirePlayer(tester)), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.mediaPause);
    await tester.pump(const Duration(milliseconds: 300));
    expect(player.value.isPlaying, isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.mediaPlay);
    await E2eHarness.waitFor(tester, () => player.value.isPlaying, 'dedicated media play');
    await tester.sendKeyEvent(LogicalKeyboardKey.mediaPlay);
    await tester.pump(const Duration(milliseconds: 300));
    expect(player.value.isPlaying, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.mediaPause);
    await E2eHarness.waitFor(tester, () => !player.value.isPlaying, 'dedicated media pause');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await E2eHarness.waitFor(tester, () => player.value.position.inSeconds >= 10, 'remote seek after cancellation');
    await tester.binding.handlePopRoute();
    await E2eHarness.waitFor(tester, () => find.byType(PlayerScreen).evaluate().isEmpty, 'remote player back');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('catalog, real HTML, native 720/360 HLS, remote, episode and back', (tester) async {
    await fixture.configure();
    await fixture.launch(tester);
    await _openAnime(tester);
    expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
    await _openVideo(tester);
    var player = E2eHarness.requirePlayer(tester);
    expect(player.formatHint, VideoFormat.hls);
    expect(player.dataSource, endsWith('720.mp4'));
    expect(player.value.size.height, 720);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await E2eHarness.waitFor(tester, () => player.value.position.inSeconds >= 10, 'remote seek');
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await E2eHarness.waitFor(tester, () => !player.value.isPlaying, 'pause');
    final pausedPosition = player.value.position;
    await tester.pump(const Duration(milliseconds: 700));
    expect((player.value.position - pausedPosition).abs(), lessThan(const Duration(milliseconds: 600)));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await E2eHarness.waitFor(tester, () => find.text('360p').evaluate().isNotEmpty, 'quality dialog');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    final high = player;
    await E2eHarness.waitFor(
      tester,
      () => E2eHarness.player(tester)?.value.isInitialized == true && !identical(E2eHarness.player(tester), high),
      'native 360p replacement',
    );
    player = E2eHarness.requirePlayer(tester);
    expect(player.value.size.height, 360);
    expect(player.value.isPlaying, isFalse);
    expect((player.value.position - pausedPosition).abs(), lessThan(const Duration(seconds: 2)));
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await E2eHarness.waitFor(tester, () => player.value.isPlaying, 'resume');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await E2eHarness.waitFor(tester, () => find.text('Серия 2').evaluate().isNotEmpty, 'episode dialog');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    final firstEpisode = player;
    await E2eHarness.waitFor(
      tester,
      () =>
          E2eHarness.player(tester)?.value.isInitialized == true && !identical(E2eHarness.player(tester), firstEpisode),
      'episode replacement',
    );
    player = E2eHarness.requirePlayer(tester);
    await E2eHarness.waitFor(tester, () => player.value.position.inMilliseconds > 500, 'episode advances');
    expect(player.value.position.inSeconds, lessThan(5));
    expect(player.value.hasError, isFalse);
    await tester.binding.handlePopRoute();
    await E2eHarness.waitFor(tester, () => find.byType(PlayerScreen).evaluate().isEmpty, 'back to anime');
    expect(find.byType(AnimeScreen), findsOneWidget);
    await E2eHarness.waitFor(
      tester,
      () => find.byIcon(Icons.check_circle_rounded).evaluate().length == 2,
      'watched checks after playback',
    );
    final positionAfterBack = player.value.position;
    await tester.pump(const Duration(milliseconds: 700));
    expect(player.value.position, positionAfterBack, reason: 'closed native player must stop advancing');
    await tester.binding.handlePopRoute();
    await E2eHarness.waitFor(
      tester,
      () => find.byType(CatalogScreen).evaluate().isNotEmpty && find.byType(AnimeScreen).evaluate().isEmpty,
      'back to catalog',
    );
    final state = await fixture.state();
    expect(state['watched'], [1, 2]);
    final marks = _events(state).where((event) => _path(event).startsWith('/engine/ajax/ns.php')).toList();
    expect(marks, hasLength(2));
    expect(marks.every((event) => event['authenticated'] == true), isTrue);
    _verifyRequests(state, fixture);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await fixture.launch(tester, autoLogin: false, resetSession: false);
    await _openAnime(tester);
    await E2eHarness.waitFor(
      tester,
      () => find.byIcon(Icons.check_circle_rounded).evaluate().length == 2,
      'watched history after client restart',
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('remote navigation loads and displays the next catalog page', (tester) async {
    await fixture.configure();
    await fixture.launch(tester);
    await E2eHarness.waitFor(tester, () => find.byType(AnimeCard).evaluate().isNotEmpty, 'initial catalog');
    final nextPageCards = find
        .byWidgetPredicate((widget) => widget is AnimeCard && widget.anime.id >= 10950)
        .hitTestable();
    for (var row = 0; row < 6; row++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump(const Duration(milliseconds: 150));
      if (nextPageCards.evaluate().isNotEmpty) {
        break;
      }
    }
    await E2eHarness.waitFor(tester, () => nextPageCards.evaluate().isNotEmpty, 'next page card');
    expect(nextPageCards, findsAtLeastNWidgets(1));
    final events = _events(await fixture.state());
    expect(events.where((event) => _path(event) == '/anime/page/2/'), hasLength(1));
    expect(find.text('Реклама'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('catalog refusal is visible and explicit retry recovers', (tester) async {
    await fixture.configure(catalogError: true);
    await fixture.launch(tester);
    await E2eHarness.waitFor(tester, () => find.text('Каталог недоступен').evaluate().isNotEmpty, 'catalog error');
    await fixture.configure(reset: false);
    await tester.tap(find.text('Попробовать снова'));
    await E2eHarness.waitFor(tester, () => find.byType(AnimeCard).evaluate().isNotEmpty, 'catalog retry');
    final events = _events(await fixture.state());
    final statuses = events
        .where((event) => event['path'] == '/anime/' && event['method'] == 'GET' && event['authenticated'] == true)
        .map((event) => event['status']);
    expect(statuses, [403, 200]);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('expired HLS refreshes its HTML once and opens a fresh native source', (tester) async {
    await fixture.configure(videoMode: 'refresh_once');
    await fixture.launch(tester);
    await _openAnime(tester);
    await _openVideo(tester);
    expect(E2eHarness.requirePlayer(tester).dataSource, contains('/fresh/'));
    final state = await fixture.state();
    expect(state['player_pages'], greaterThanOrEqualTo(4), reason: 'detail, history, initial source and one refresh');
    final events = _events(state);
    expect(events.any((event) => _path(event).contains('/expired/') && event['status'] == 403), isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('persistent HLS rejection stops retrying and manual retry can recover', (tester) async {
    await fixture.configure(videoMode: 'always_expired');
    await fixture.launch(tester);
    await _openAnime(tester);
    await _pressPlay(tester);
    await E2eHarness.waitFor(
      tester,
      () => find.text('Видео не запустилось').evaluate().isNotEmpty,
      'bounded video error',
    );
    expect((await fixture.state())['player_pages'], 4);
    await tester.pump(const Duration(seconds: 2));
    expect((await fixture.state())['player_pages'], 4, reason: 'no background retry loop');
    await fixture.configure(reset: false);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await E2eHarness.waitFor(
      tester,
      () => E2eHarness.player(tester)?.value.isInitialized ?? false,
      'manual video retry',
    );
    expect((await fixture.state())['player_pages'], greaterThanOrEqualTo(5));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Future<void> _openAnime(WidgetTester tester) async {
  final card = find.byWidgetPredicate((widget) => widget is AnimeCard && widget.anime.id == 10938);
  await E2eHarness.waitFor(tester, () => card.evaluate().isNotEmpty, 'catalog');
  expect(find.text('Реклама'), findsNothing);
  await tester.ensureVisible(card);
  await tester.sendKeyEvent(LogicalKeyboardKey.select);
  await E2eHarness.waitFor(
    tester,
    () => find.text('Смотреть серию 1').evaluate().isNotEmpty,
    'details and sorted episodes',
  );
}

Future<void> _pressPlay(WidgetTester tester) async {
  final button = find.text('Смотреть серию 1');
  await tester.ensureVisible(button);
  await tester.tap(button);
}

Future<void> _openVideo(WidgetTester tester) async {
  await _pressPlay(tester);
  await E2eHarness.waitFor(
    tester,
    () => E2eHarness.player(tester)?.value.isInitialized ?? false,
    '720p initialization',
  );
  await E2eHarness.waitFor(
    tester,
    () => (E2eHarness.player(tester)?.value.position.inMilliseconds ?? 0) > 500,
    'native playback advances',
  );
}

void _verifyRequests(Map<String, Object?> state, E2eHarness fixture) {
  final events = _events(state).toList();
  final media = events.where((event) => _path(event).startsWith('/hls/')).toList();
  expect(media, isNotEmpty);
  expect(
    media.every((event) => event['authenticated'] == false),
    isTrue,
    reason: 'native CDN requests must not receive AniStar cookies',
  );
  expect(
    events.where((event) => _path(event).startsWith('/test/player2/')).every((event) => event['authenticated'] == true),
    isTrue,
  );
  expect(
    media.every((event) => event['referer'] == '${fixture.origin}test/player2/videoas_p2p_new.php?id=10938'),
    isTrue,
  );
  expect(media.every((event) => event['status'] == 200 || event['status'] == 206), isTrue);
  for (final quality in ['360', '720']) {
    expect(media.any((event) => _path(event).contains('/$quality.mp4/variant.m3u8')), isTrue);
    expect(media.any((event) => _path(event).contains('/$quality.mp4/segment-')), isTrue);
  }
}

Iterable<Map<String, Object?>> _events(Map<String, Object?> state) {
  final values = state['events'];
  if (values is! List<Object?>) {
    throw const FormatException('Missing fixture request events');
  }

  return values.whereType<Map<String, Object?>>();
}

String _path(Map<String, Object?> event) => event['path']?.toString() ?? '';
