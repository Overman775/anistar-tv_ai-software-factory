// Each native observation and touch pump samples a new device state.
// ignore_for_file: prefer-moving-to-variable

import 'package:anistar_tv/app/app_device_profile_resolver.dart';
import 'package:anistar_tv/packages/features/anime/presentation/screens/anime_screen.dart';
import 'package:anistar_tv/packages/features/anime/presentation/widgets/mobile_anime_content.dart';
import 'package:anistar_tv/packages/features/auth/presentation/intro_screen.dart';
import 'package:anistar_tv/packages/features/auth/presentation/login_screen.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/mobile/mobile_anime_card.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/screens/catalog_screen.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/screens/genres_screen.dart';
import 'package:anistar_tv/packages/features/home/presentation/mobile/mobile_home_shell.dart';
import 'package:anistar_tv/packages/features/player/presentation/screens/player_screen.dart';
import 'package:anistar_tv/packages/features/player/presentation/widgets/mobile_player_controls.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:video_player/video_player.dart';

import 'support/e2e_harness.dart';
import 'support/mobile_controls.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  late E2eHarness fixture;
  setUpAll(() async {
    expect(
      await AppDeviceProfileResolver.resolve(),
      AppDeviceProfile.mobile,
      reason: 'Mobile E2E requires a phone system image, not a narrow TV window.',
    );
  });
  setUp(() => fixture = E2eHarness());
  tearDown(() => fixture.close());
  Future<void> launch(WidgetTester tester, {bool login = true, bool resetSession = true}) async {
    await fixture.launch(tester, autoLogin: false, resetSession: resetSession);
    if (login) {
      await MobileControls.login(tester);
      await _waitHome(tester);
    }
  }

  _mobileTest('guest search native playback and cancelled login preserve public context', (tester) async {
    await fixture.configure();
    await fixture.launch(tester, autoLogin: false);
    await MobileControls.tap(tester, find.byKey(const ValueKey('intro_guest')), 'enter guest');
    await E2eHarness.waitFor(tester, () => find.byType(NavigationBar).evaluate().isNotEmpty, 'guest home');
    expect(find.text('Избранное'), findsNothing);
    await MobileControls.tab(tester, 'Поиск');
    await tester.enterText(find.byKey(const ValueKey('search-query')), 'Наруто');
    await MobileControls.tap(tester, find.byKey(const ValueKey('search-submit')), 'submit public search');
    final first = find.byKey(const ValueKey('search-card-10938'));
    await E2eHarness.waitFor(tester, () => first.evaluate().isNotEmpty, 'public search cards');
    await MobileControls.tap(tester, first, 'open public search detail');
    await E2eHarness.waitFor(
      tester,
      () => find.byType(AnimeScreen).evaluate().isNotEmpty && find.byType(MobileAnimeContent).evaluate().isNotEmpty,
      'guest detail',
    );
    await MobileControls.revealAnimeAction(tester, 'Смотреть серию 1');
    await MobileControls.openVideo(tester);
    await E2eHarness.waitFor(
      tester,
      () => (E2eHarness.player(tester)?.value.position.inMilliseconds ?? 0) > 500,
      'guest native video advances',
    );
    await tester.binding.handlePopRoute();
    await E2eHarness.waitFor(tester, () => find.byType(PlayerScreen).evaluate().isEmpty, 'guest player Back');
    await tester.binding.handlePopRoute();
    await E2eHarness.waitFor(tester, () => first.evaluate().isNotEmpty, 'restore guest search');
    expect(tester.widget<TextField>(find.byKey(const ValueKey('search-query'))).controller?.text, 'Наруто');
    await MobileControls.tap(tester, find.byKey(const ValueKey('mobile-account')).hitTestable(), 'guest sign in');
    await E2eHarness.waitFor(tester, () => find.byType(LoginScreen).evaluate().isNotEmpty, 'guest login overlay');
    await tester.binding.handlePopRoute();
    await E2eHarness.waitFor(tester, () => find.byType(LoginScreen).evaluate().isEmpty, 'cancel guest login');
    expect(first, findsOneWidget);
    final state = await fixture.state();
    expect(state['favorite_writes'], 0);
    expect(state['watched'], isEmpty);
    final events = _events(state);
    expect(events.any((event) => event['method'] == 'POST' && event['path'] == '/'), isTrue);
    expect(events.any((event) => event['authenticated'] == true), isFalse);
    expect(
      events.where((event) {
        final path = event['path']?.toString() ?? '';

        return path.contains('do=favorites') ||
            path.startsWith('/engine/ajax/favorites.php') ||
            path.startsWith('/engine/ajax/ns.php');
      }),
      isEmpty,
    );
  });

  _mobileTest('mobile touch login rejection, session restore, expiry and logout', (tester) async {
    await fixture.configure();
    await launch(tester, login: false);
    expect(find.byType(MobileHomeShell), findsNothing);
    await MobileControls.login(tester, password: 'wrong');
    await E2eHarness.waitFor(
      tester,
      () => find.text('Вход не выполнен. Проверьте логин и пароль.').evaluate().isNotEmpty,
      'touch login rejection',
    );
    await MobileControls.login(tester);
    await _waitHome(tester);
    final loginPosts = _events(await fixture.state()).where((event) => event['method'] == 'POST').length;
    await tester.pumpWidget(const SizedBox.shrink());
    await launch(tester, login: false, resetSession: false);
    await _waitHome(tester);
    expect(_events(await fixture.state()).where((event) => event['method'] == 'POST'), hasLength(loginPosts));
    await fixture.expireSession();
    await MobileControls.tab(tester, 'Жанры');
    await E2eHarness.waitFor(tester, () => find.byType(IntroScreen).evaluate().isNotEmpty, 'mobile expiry intro');
    await MobileControls.login(tester);
    await _waitHome(tester);
    await MobileControls.tap(tester, find.byKey(const ValueKey('mobile-account')), 'account');
    await E2eHarness.waitFor(tester, () => find.text('Выйти из аккаунта').evaluate().isNotEmpty, 'account actions');
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('тест'), findsOneWidget);
    await MobileControls.tap(tester, find.text('Выйти из аккаунта'), 'touch logout');
    await E2eHarness.waitFor(
      tester,
      () => find.text('Выйти из аккаунта?').evaluate().isNotEmpty,
      'logout confirmation',
    );
    await MobileControls.tap(tester, find.widgetWithText(AppButton, 'Выйти из аккаунта'), 'confirm touch logout');
    await E2eHarness.waitFor(tester, () => find.byType(IntroScreen).evaluate().isNotEmpty, 'mobile logout intro');
    await tester.pumpWidget(const SizedBox.shrink());
    await launch(tester, login: false, resetSession: false);
    await E2eHarness.waitFor(
      tester,
      () => find.byType(IntroScreen).evaluate().isNotEmpty,
      'logout intro survives restart',
    );
    // A new restored client must remain outside the authenticated shell.
    // ignore: avoid-duplicate-test-assertions
    expect(find.byType(MobileHomeShell), findsNothing);
  });

  _mobileTest('mobile header, pagination, tab position, system Back and pull refresh', (tester) async {
    await fixture.configure(favorites: '');
    await launch(tester);
    expect(find.byKey(const ValueKey('catalog-refresh')), findsNothing);
    final scroll = _homeScroll();
    final navigation = find.byKey(const ValueKey('mobile-navigation'));
    final navigationTop = tester.getTopLeft(navigation);
    await tester.drag(scroll, const Offset(0, -300));
    await E2eHarness.waitFor(
      tester,
      () => find.byKey(const ValueKey('mobile-account')).hitTestable().evaluate().isEmpty,
      'header hidden',
    );
    expect(tester.getTopLeft(navigation), navigationTop);
    await tester.drag(scroll, const Offset(0, 80));
    await E2eHarness.waitFor(
      tester,
      () => find.byKey(const ValueKey('mobile-account')).hitTestable().evaluate().isNotEmpty,
      'header reverse reveal',
    );
    final nextCards = find
        .byWidgetPredicate((widget) => widget is MobileAnimeCard && widget.anime.id >= 10950)
        .hitTestable();
    for (var drag = 0; drag < 12 && nextCards.evaluate().isEmpty; drag++) {
      await tester.drag(scroll, const Offset(0, -500));
      await tester.pump(const Duration(milliseconds: 300));
    }
    await E2eHarness.waitFor(tester, () => nextCards.evaluate().isNotEmpty, 'mobile second page');
    final controller = tester.widget<CustomScrollView>(scroll).controller;
    if (controller == null) {
      fail('Mobile catalog has no retained scroll controller.');
    }
    final offset = controller.offset;
    expect(_events(await fixture.state()).where((event) => event['path'] == '/anime/page/2/'), hasLength(1));
    await MobileControls.tab(tester, 'Избранное');
    await E2eHarness.waitFor(tester, () => find.text('Избранное пусто').evaluate().isNotEmpty, 'empty favorites tab');
    await tester.binding.handlePopRoute();
    await E2eHarness.waitFor(
      tester,
      () =>
          find.byType(NavigationBar).evaluate().isNotEmpty &&
          tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex == 0,
      'Back returns home tab',
    );
    expect(controller.offset, offset);
    expect(find.byKey(const ValueKey('mobile-account')).hitTestable(), findsOneWidget);
    controller.jumpTo(0);
    await tester.pump(const Duration(milliseconds: 300));
    final before = _authenticatedCatalogGets(await fixture.state()).length;
    await tester.drag(scroll, const Offset(0, 350));
    await E2eHarness.waitFor(
      tester,
      () =>
          MobileControls.card(10938).evaluate().isNotEmpty && find.byType(RefreshProgressIndicator).evaluate().isEmpty,
      'pull refresh complete',
    );
    expect(_authenticatedCatalogGets(await fixture.state()).length, greaterThan(before));
    expect(find.text('Реклама'), findsNothing);
  });

  _mobileTest('mobile genre filter and touch sort sheets apply and cancel drafts', (tester) async {
    await fixture.configure();
    await launch(tester);
    await MobileControls.tab(tester, 'Жанры');
    await E2eHarness.waitFor(tester, () => find.text('Комедия').evaluate().isNotEmpty, 'mobile genres');
    await MobileControls.tap(tester, find.text('Комедия'), 'comedy genre');
    await _waitFilter(tester);
    await MobileControls.tap(tester, find.widgetWithText(TextButton, 'По дате · Сначала новые'), 'touch sort');
    expect(find.byType(BottomSheet), findsOneWidget);
    await MobileControls.tap(tester, find.text('По алфавиту'), 'alphabetical criterion');
    await MobileControls.tap(tester, find.text('Я → А'), 'descending titles');
    await MobileControls.tap(tester, find.text('Применить'), 'apply sort');
    await E2eHarness.waitFor(tester, () => MobileControls.card(10961).evaluate().isNotEmpty, 'sorted mobile catalog');
    final sorted = _events(await fixture.state()).where((event) => event['path'] == '/anime/comedy/').last;
    expect(sorted['sort'], {'dle_sort_cat': 'title', 'dle_direction_cat': 'desc'});
    await MobileControls.tap(tester, find.widgetWithText(TextButton, 'По алфавиту · Я → А'), 'reopen sort');
    await MobileControls.tap(tester, find.text('По дате'), 'draft date sort');
    await tester.binding.handlePopRoute();
    await E2eHarness.waitFor(tester, () => find.byType(BottomSheet).evaluate().isEmpty, 'cancel draft with Back');
    expect(find.text('По алфавиту · Я → А'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await E2eHarness.waitFor(
      tester,
      () => find.byType(GenresScreen).evaluate().isNotEmpty && find.byType(NavigationBar).evaluate().length == 1,
      'Back to single genre navigation',
    );
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 3);
  });

  _mobileTest('mobile pull refresh retains home on refusal, synchronizes empty favorites and anime details', (
    tester,
  ) async {
    await fixture.configure(favorites: '');
    await launch(tester);
    await fixture.configure(catalogError: true, reset: false);
    await tester.drag(_homeScroll(), const Offset(0, 350));
    await E2eHarness.waitFor(
      tester,
      () =>
          find.textContaining('Не удалось обновить.').evaluate().isNotEmpty &&
          find.byType(RefreshProgressIndicator).evaluate().isEmpty,
      'home refresh refusal finishes',
    );
    expect(MobileControls.card(10938), findsOneWidget, reason: 'a failed refresh keeps the current catalog');
    await fixture.configure(reset: false);
    final beforeHome = _authenticatedCatalogGets(await fixture.state()).length;
    await tester.drag(_homeScroll(), const Offset(0, 350));
    await tester.pump(const Duration(milliseconds: 300));
    await E2eHarness.waitFor(
      tester,
      () => find.byType(RefreshProgressIndicator).evaluate().isEmpty,
      'home refresh retry',
    );
    expect(_authenticatedCatalogGets(await fixture.state()).length, beforeHome + 1);
    await MobileControls.tab(tester, 'Избранное');
    await E2eHarness.waitFor(
      tester,
      () => find.text('Избранное пусто').evaluate().isNotEmpty,
      'initial empty favorites',
    );
    await fixture.configure(reset: false, favorites: '10938');
    await tester.drag(_favoritesScroll(), const Offset(0, 350));
    await E2eHarness.waitFor(
      tester,
      () =>
          MobileControls.card(10938).evaluate().isNotEmpty && find.byType(RefreshProgressIndicator).evaluate().isEmpty,
      'pull loads site favorite into empty tab',
    );
    expect(find.byKey(const ValueKey('mobile-account')).hitTestable(), findsOneWidget);
    expect(find.byKey(const ValueKey('mobile-navigation')).hitTestable(), findsOneWidget);
    // The fixture's query parser omits blank values; a nonnumeric marker clears the set without reset.
    await fixture.configure(reset: false, favorites: 'empty');
    await tester.drag(_favoritesScroll(), const Offset(0, 350));
    await E2eHarness.waitFor(
      tester,
      () =>
          find.text('Избранное пусто').evaluate().isNotEmpty &&
          find.byType(RefreshProgressIndicator).evaluate().isEmpty,
      'pull removes externally deleted last favorite',
    );
    await MobileControls.tab(tester, 'Главная');
    await MobileControls.openAnime(tester);
    final animeScroll = find.descendant(of: find.byType(AnimeScreen), matching: find.byType(ListView));
    final detailController = tester.widget<ListView>(animeScroll).controller;
    if (detailController == null) {
      fail('Mobile detail has no scroll controller.');
    }
    detailController.jumpTo(0);
    await tester.pump(const Duration(milliseconds: 300));
    expect(detailController.offset, 0, reason: 'pull refresh starts at the actual detail top');
    final beforeDetail = (await fixture.state())['player_pages'];
    if (beforeDetail is! int) {
      fail('Missing fixture episode-page count');
    }
    await fixture.configure(reset: false, favorites: '10938');
    await tester.drag(animeScroll, const Offset(0, 350));
    await E2eHarness.waitFor(
      tester,
      () => find.byType(RefreshProgressIndicator).evaluate().isEmpty,
      'detail refresh finishes before scrolling',
    );
    await MobileControls.revealAnimeAction(tester, 'В избранном');
    await E2eHarness.waitFor(
      tester,
      () => find.text('В избранном').evaluate().isNotEmpty && find.byType(RefreshProgressIndicator).evaluate().isEmpty,
      'pull reloads anime details and episodes',
    );
    expect((await fixture.state())['player_pages'], beforeDetail + 1);
    expect(find.text('Обновить контент'), findsNothing);
  });

  _mobileTest('mobile favorite failure, explicit recovery, removal and empty-state return', (tester) async {
    await fixture.configure(favoriteError: true, favorites: '');
    await launch(tester);
    await MobileControls.tap(tester, find.byKey(const ValueKey('anime-actions-10938')), 'favorite actions');
    await MobileControls.tap(tester, find.text('Добавить в избранное'), 'rejected favorite');
    await E2eHarness.waitFor(tester, () => find.text('Обновить статус').evaluate().isNotEmpty, 'favorite failure');
    expect((await fixture.state())['favorites'], isEmpty);
    await fixture.configure(reset: false);
    await MobileControls.tap(tester, find.text('Обновить статус'), 'favorite status recovery');
    await MobileControls.tap(tester, find.text('Добавить в избранное'), 'confirmed favorite retry');
    await E2eHarness.waitFor(tester, () => find.byType(BottomSheet).evaluate().isEmpty, 'favorite confirmed');
    expect((await fixture.state())['favorites'], [10938]);
    await MobileControls.tab(tester, 'Избранное');
    await MobileControls.openAnime(tester);
    await MobileControls.revealAnimeAction(tester, 'В избранном');
    await MobileControls.tap(tester, find.text('В избранном'), 'detail favorite removal');
    await E2eHarness.waitFor(tester, () => find.text('В избранное').evaluate().isNotEmpty, 'removal confirmed');
    await tester.binding.handlePopRoute();
    await E2eHarness.waitFor(tester, () => find.text('Избранное пусто').evaluate().isNotEmpty, 'empty favorites');
    final removed = await fixture.state();
    expect(removed['favorites'], isEmpty, reason: 'last favorite was removed on the site');
    expect(removed['favorite_writes'], 3);
    await MobileControls.tap(tester, find.text('Перейти на главную'), 'empty favorite home action');
    await _waitHome(tester);
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 0);
  });

  _mobileTest('mobile native player seek, quality, real rotation, lifecycle, episode and Back', (tester) async {
    await fixture.configure();
    await launch(tester);
    await MobileControls.openAnime(tester);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byKey(const ValueKey('mobile-header')), findsOneWidget);
    await MobileControls.openVideo(tester);
    expect(find.descendant(of: find.byType(PlayerScreen), matching: find.byType(RefreshIndicator)), findsNothing);
    var player = E2eHarness.requirePlayer(tester);
    expect(player.formatHint, VideoFormat.hls);
    expect(player.value.size.height, 720);
    expect(find.byType(MobilePlayerControls), findsOneWidget);
    await E2eHarness.expectScreenAwake(tester, true);
    await MobileControls.playerAction(tester, 'player-play');
    await E2eHarness.waitFor(tester, () => !player.value.isPlaying, 'touch pause');
    await E2eHarness.expectScreenAwake(tester, false);
    // Exercise the timeline's real drag recognizer, rather than calling Slider callbacks.
    final timeline = find.byKey(const ValueKey('player-timeline'));
    final timelineRect = tester.getRect(timeline);
    final expectedSeek = Duration(milliseconds: (player.value.duration.inMilliseconds / 2).round());
    final scrub = await tester.startGesture(timelineRect.center - Offset(timelineRect.width * 0.2, 0));
    await scrub.moveTo(timelineRect.center);
    await tester.pump();
    await scrub.up();
    await E2eHarness.waitFor(
      tester,
      () => (player.value.position - expectedSeek).abs() < const Duration(seconds: 1),
      'native timeline drag commits seek',
    );
    final pausedPosition = player.value.position;
    await MobileControls.playerAction(tester, 'player-quality');
    expect(find.byType(BottomSheet), findsOneWidget);
    await tester.binding.handlePopRoute();
    await E2eHarness.waitFor(
      tester,
      () => find.byType(BottomSheet).evaluate().isEmpty && find.byType(PlayerScreen).evaluate().isNotEmpty,
      'Back cancels mobile quality sheet without leaving player',
    );
    expect(E2eHarness.requirePlayer(tester), same(player), reason: 'sheet cancellation preserves native stream');
    expect(player.dataSource, endsWith('720.mp4'));
    expect(player.value.isPlaying, isFalse, reason: 'sheet cancellation preserves pause');
    expect(
      (player.value.position - pausedPosition).abs(),
      lessThan(const Duration(seconds: 1)),
      reason: 'sheet cancellation preserves seek',
    );
    // A canceled chooser must release touch transport to the current stream.
    await MobileControls.playerAction(tester, 'player-play');
    await E2eHarness.waitFor(tester, () => player.value.isPlaying, 'touch play after chooser cancellation');
    await MobileControls.playerAction(tester, 'player-play');
    await E2eHarness.waitFor(tester, () => !player.value.isPlaying, 'touch pause after chooser cancellation');
    final qualityPosition = player.value.position;
    await MobileControls.playerAction(tester, 'player-quality');
    await MobileControls.tap(tester, find.text('SD 360p'), 'select 360p');
    final high = player;
    await _waitReplacement(tester, high, '360p controller');
    player = E2eHarness.requirePlayer(tester);
    expect(player.value.size.height, 360);
    expect(player.value.isPlaying, isFalse);
    expect((player.value.position - qualityPosition).abs(), lessThan(const Duration(seconds: 2)));
    await MobileControls.playerAction(tester, 'player-rotate');
    await _waitOrientation(tester, Orientation.landscape);
    expect(E2eHarness.requirePlayer(tester), same(player), reason: 'native rotation preserves controller');
    expect(player.value.isPlaying, isFalse, reason: 'landscape rotation keeps pause');
    expect(
      (player.value.position - qualityPosition).abs(),
      lessThan(const Duration(seconds: 2)),
      reason: 'landscape rotation keeps seek position',
    );
    expect(AppLayoutScope.profileOf(tester.element(find.byType(PlayerScreen))), AppDeviceProfile.mobile);
    await MobileControls.playerAction(tester, 'player-rotate');
    await _waitOrientation(tester, Orientation.portrait);
    expect(E2eHarness.requirePlayer(tester), same(player), reason: 'portrait rotation preserves controller');
    expect(player.value.isPlaying, isFalse, reason: 'portrait rotation keeps pause');
    await MobileControls.playerAction(tester, 'player-play');
    await E2eHarness.waitFor(tester, () => player.value.isPlaying, 'play before mobile background');
    await E2eHarness.expectScreenAwake(tester, true);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    late final Duration backgroundPosition;
    try {
      // Live binding cannot finish pump() while SchedulerBinding.framesEnabled is false.
      await MobileControls.expectPausedPlaybackWithoutFrames(tester, player);
      backgroundPosition = player.value.position;
    } finally {
      // Resume before any assertion failure enters frame-based test cleanup.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    }
    await E2eHarness.waitFor(
      tester,
      () => player.value.isPlaying && player.value.position > backgroundPosition,
      'mobile resume continues native playback',
    );
    await E2eHarness.expectScreenAwake(tester, true);
    await MobileControls.playerAction(tester, 'player-next-episode');
    final first = player;
    await _waitReplacement(tester, first, 'next mobile episode');
    player = E2eHarness.requirePlayer(tester);
    await E2eHarness.waitFor(tester, () => player.value.position.inMilliseconds > 500, 'episode advances');
    expect(player.value.position.inSeconds, lessThan(5));
    expect(player.value.size.height, 360, reason: 'episode replacement retains selected quality');
    await tester.binding.handlePopRoute();
    await E2eHarness.waitFor(tester, () => find.byType(PlayerScreen).evaluate().isEmpty, 'Back closes native player');
    await E2eHarness.expectScreenAwake(tester, false);
    expect(find.byType(AnimeScreen), findsOneWidget);
    final stoppedPosition = player.value.position;
    await tester.pump(const Duration(milliseconds: 700));
    expect(player.value.position, stoppedPosition, reason: 'disposed video stops advancing');
    await tester.binding.handlePopRoute();
    await _waitHome(tester);
    final state = await fixture.state();
    expect(state['watched'], [1, 2]);
    _verifyMedia(state, fixture);
  });

  _mobileTest('mobile catalog refusal has touch retry and recovers without refresh button', (tester) async {
    await fixture.configure(catalogError: true);
    await launch(tester, login: false);
    await MobileControls.login(tester);
    await E2eHarness.waitFor(tester, () => find.text('Каталог недоступен').evaluate().isNotEmpty, 'catalog failure');
    expect(find.byType(MobileAnimeCard), findsNothing);
    await fixture.configure(reset: false);
    await MobileControls.tap(tester, find.text('Попробовать снова'), 'touch catalog retry');
    await _waitHome(tester);
    expect(_authenticatedCatalogGets(await fixture.state()).map((event) => event['status']), [403, 200]);
  });

  _mobileTest('mobile persistent video error stops automatic retries and touch retry recovers', (tester) async {
    await fixture.configure(videoMode: 'always_expired');
    await launch(tester);
    await MobileControls.openAnime(tester);
    await MobileControls.tap(tester, find.text('Смотреть серию 1'), 'start failing video');
    await E2eHarness.waitFor(
      tester,
      () => find.text('Видео не запустилось').evaluate().isNotEmpty,
      'bounded video error',
    );
    final before = (await fixture.state())['player_pages'];
    expect(before, 4);
    await tester.pump(const Duration(seconds: 2));
    expect((await fixture.state())['player_pages'], before, reason: 'no background video retry loop');
    await fixture.configure(reset: false);
    await MobileControls.tap(tester, find.text('Повторить'), 'touch video retry');
    await E2eHarness.waitFor(tester, () => E2eHarness.player(tester)?.value.isInitialized == true, 'video recovery');
    expect(E2eHarness.requirePlayer(tester).value.hasError, isFalse);
    await tester.binding.handlePopRoute();
    await E2eHarness.waitFor(tester, () => find.byType(PlayerScreen).evaluate().isEmpty, 'Back after video recovery');
  });
}

void _mobileTest(String name, Future<void> Function(WidgetTester) body) =>
    E2eHarness.testCase(name, body, profile: AppDeviceProfile.mobile);

Future<void> _waitHome(WidgetTester tester) => E2eHarness.waitFor(
  tester,
  () => find.byType(MobileHomeShell).evaluate().isNotEmpty && MobileControls.card(10938).evaluate().isNotEmpty,
  'mobile home',
);

Finder _homeScroll() => find.descendant(
  of: find.byWidgetPredicate((widget) => widget is CatalogScreen && !widget.favoritesOnly && widget.filter == null),
  matching: find.byType(CustomScrollView),
);

Finder _favoritesScroll() => find
    .descendant(
      of: find.byWidgetPredicate((widget) => widget is CatalogScreen && widget.favoritesOnly),
      matching: find.byType(Scrollable),
    )
    .first;

Future<void> _waitFilter(WidgetTester tester) => E2eHarness.waitFor(
  tester,
  () => find
      .descendant(
        of: find.byWidgetPredicate((widget) => widget is CatalogScreen && widget.filter?.path == '/anime/comedy/'),
        matching: find.byType(MobileAnimeCard),
      )
      .evaluate()
      .isNotEmpty,
  'mobile comedy filter',
);

Future<void> _waitReplacement(WidgetTester tester, VideoPlayerController previous, String step) => E2eHarness.waitFor(
  tester,
  () => E2eHarness.player(tester)?.value.isInitialized == true && !identical(E2eHarness.player(tester), previous),
  step,
);

Future<void> _waitOrientation(WidgetTester tester, Orientation orientation) => E2eHarness.waitFor(
  tester,
  () => MediaQuery.orientationOf(tester.element(find.byType(PlayerScreen))) == orientation,
  'native phone rotation to $orientation',
);

Iterable<Map<String, Object?>> _events(Map<String, Object?> state) {
  final values = state['events'];
  if (values is! List<Object?>) {
    throw const FormatException('Missing fixture request events');
  }

  return values.whereType<Map<String, Object?>>();
}

Iterable<Map<String, Object?>> _authenticatedCatalogGets(Map<String, Object?> state) =>
    _events(state)
        .where((event) => event['path'] == '/anime/' && event['method'] == 'GET' && event['authenticated'] == true);

void _verifyMedia(Map<String, Object?> state, E2eHarness fixture) {
  final media = _events(state).where((event) => event['path']?.toString().startsWith('/hls/') ?? false).toList();
  expect(media, isNotEmpty);
  expect(media.every((event) => event['authenticated'] == false), isTrue);
  expect(
    media.every((event) => event['referer'] == '${fixture.origin}test/player2/videoas_p2p_new.php?id=10938'),
    isTrue,
  );
  for (final quality in ['360', '720']) {
    expect(media.any((event) => event['path']?.toString().contains('/$quality.mp4/segment-') ?? false), isTrue);
  }
}
