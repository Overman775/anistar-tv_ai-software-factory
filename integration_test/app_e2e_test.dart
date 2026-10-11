// Native controller state changes on the Android event loop between pumps.
// ignore_for_file: prefer-moving-to-variable

import 'package:anistar_tv/packages/features/anime/presentation/screens/anime_screen.dart';
import 'package:anistar_tv/packages/features/auth/presentation/login_screen.dart';
import 'package:anistar_tv/packages/features/auth/presentation/startup_screen.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/screens/catalog_screen.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/screens/genres_screen.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/widgets/anime_card.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/widgets/catalog_navigation_rail.dart';
import 'package:anistar_tv/packages/features/player/presentation/screens/player_screen.dart';
import 'package:anistar_tv/packages/features/player/presentation/widgets/player_view.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:video_player/video_player.dart';

import 'support/e2e_harness.dart';
import 'support/remote_controls.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  late E2eHarness fixture;

  setUp(() => fixture = E2eHarness());
  tearDown(() => fixture.close());

  testWidgets('genre sorting applies per request, paginates and restores focus after detail', (tester) async {
    await fixture.configure();
    await fixture.launch(tester);
    await E2eHarness.waitFor(tester, () => find.byType(AnimeCard).evaluate().isNotEmpty, 'catalog');
    await tester.tap(find.byKey(const ValueKey('catalog-genres')));
    await E2eHarness.waitFor(tester, () => FocusManager.instance.primaryFocus?.debugLabel == 'Комедия', 'genre');
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await _waitFilter(tester, '/anime/comedy/');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 400));
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'sort-option-0');
    for (var i = 0; i < 4; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    for (var i = 0; i < 3; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await E2eHarness.waitFor(tester, () => find.text('Аниме 10961').evaluate().isNotEmpty, 'sorted first page');
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'Сортировка');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await E2eHarness.waitFor(tester, () => find.byType(AnimeScreen).evaluate().isNotEmpty, 'sorted detail');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.binding.handlePopRoute();
    await E2eHarness.waitFor(tester, () => find.byType(AnimeScreen).evaluate().isEmpty, 'sorted return');
    await tester.pump(const Duration(milliseconds: 300));
    expect(FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<AnimeCard>()?.anime.id, 10961);
    for (var i = 0; i < 3; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump(const Duration(milliseconds: 300));
    }
    await E2eHarness.waitFor(tester, () => find.text('Аниме 10949').evaluate().isNotEmpty, 'sorted second page');
    final events = _events(await fixture.state());
    final sorted = events.where((event) => event['sort'] is Map && (event['sort']! as Map)['dle_sort_cat'] == 'title');
    expect(sorted.any((event) => _path(event) == '/anime/comedy/page/2/'), isTrue);
    expect(sorted.every((event) => (event['sort']! as Map)['dle_direction_cat'] == 'desc'), isTrue);
    expect(
      events.where((event) => _path(event).endsWith('-test.html')).every((event) => (event['sort']! as Map).isEmpty),
      isTrue,
    );
  });

  testWidgets('genres and anime metadata open paginated filters and restore remote focus', (tester) async {
    await fixture.configure();
    await fixture.launch(tester);
    await E2eHarness.waitFor(tester, () => find.byType(AnimeCard).evaluate().isNotEmpty, 'catalog');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'Жанры');
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await E2eHarness.waitFor(tester, () => FocusManager.instance.primaryFocus?.debugLabel == 'Комедия', 'first genre');
    expect(find.byType(GenresScreen), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await _waitFilter(tester, '/anime/comedy/');
    expect(tester.widget<CatalogScreen>(find.byType(CatalogScreen)).filter?.path, '/anime/comedy/');
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await E2eHarness.waitFor(
      tester,
      () => FocusManager.instance.primaryFocus?.debugLabel == 'Смотреть первую серию',
      'anime actions',
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await E2eHarness.waitFor(
      tester,
      () => E2eHarness.player(tester)?.value.isInitialized == true,
      'filtered anime playback',
    );
    await RemoteControls.backToEpisodes(tester);
    await E2eHarness.waitFor(
      tester,
      () => find.byType(PlayerScreen).evaluate().isEmpty,
      'filtered anime after playback',
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump(const Duration(milliseconds: 200));
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'Онгоинги');
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await _waitFilter(tester, '/new/');
    expect(tester.widget<CatalogScreen>(find.byType(CatalogScreen)).filter?.path, '/new/');
    for (var row = 0; row < 3; row++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump(const Duration(milliseconds: 300));
    }
    await E2eHarness.waitFor(tester, () => find.text('Аниме 10950').evaluate().isNotEmpty, 'filtered second page');
    final events = _events(await fixture.state());
    expect(events.any((event) => _path(event) == '/new/page/2/'), isTrue);
    await tester.binding.handlePopRoute();
    await E2eHarness.waitFor(
      tester,
      () => FocusManager.instance.primaryFocus?.debugLabel == 'Онгоинги',
      'metadata focus after Back',
    );
    await tester.binding.handlePopRoute();
    await _waitFilter(tester, '/anime/comedy/');
    expect(tester.widget<CatalogScreen>(find.byType(CatalogScreen)).filter?.label, 'Комедия');
    await tester.binding.handlePopRoute();
    await E2eHarness.waitFor(tester, () => find.byType(GenresScreen).evaluate().isNotEmpty, 'genre picker after Back');
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'Комедия');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('startup retry, login rejection, encrypted restore, expiry and logout gate the catalog', (tester) async {
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
    await E2eHarness.waitFor(
      tester,
      () => FocusManager.instance.primaryFocus?.debugLabel == 'Пароль',
      'password retry',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump(const Duration(milliseconds: 300));
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'Логин');
    await tester.enterText(find.byKey(const ValueKey('login_username')), 'тест');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump(const Duration(milliseconds: 300));
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'Пароль');
    await tester.enterText(find.byKey(const ValueKey('login_password')), 'wrong-again');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump(const Duration(milliseconds: 300));
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'Войти');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump(const Duration(milliseconds: 300));
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'Логин');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await E2eHarness.waitFor(
      tester,
      () => FocusManager.instance.primaryFocus?.debugLabel == 'Пароль',
      'second rejection',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump(const Duration(milliseconds: 300));
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'Логин');
    await E2eHarness.login(tester);
    await E2eHarness.waitFor(tester, () => find.byType(AnimeCard).evaluate().isNotEmpty, 'authenticated catalog');
    final postCount = _events(await fixture.state()).where((event) => event['method'] == 'POST').length;
    await fixture.configure(catalogError: true, reset: false);
    await tester.pumpWidget(const SizedBox.shrink());
    await fixture.launch(tester, autoLogin: false, resetSession: false);
    await E2eHarness.waitFor(
      tester,
      () => find.byKey(const ValueKey('startup_retry')).evaluate().isNotEmpty,
      'startup session refusal',
    );
    expect(find.byType(StartupScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
    await fixture.configure(reset: false);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
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
    await E2eHarness.waitFor(tester, () => find.text('Добавить в избранное').evaluate().isNotEmpty, 'held OK menu');
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.select);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
    expect(find.byType(AnimeScreen), findsNothing);
    expect((await fixture.state())['favorite_writes'], 0);
    await _tapSheetAction(tester, 'Добавить в избранное');
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
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
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
    await _tapSheetAction(tester, 'Добавить в избранное');
    await E2eHarness.waitFor(tester, () => find.text('Обновить статус').evaluate().isNotEmpty, 'favorite rejection');
    expect(find.byKey(const ValueKey('favorite-10938')), findsNothing);
    expect((await fixture.state())['favorites'], isEmpty);
    await fixture.configure(reset: false);
    await _tapSheetAction(tester, 'Обновить статус');
    await E2eHarness.waitFor(
      tester,
      () => find.text('Добавить в избранное').evaluate().isNotEmpty,
      'fresh favorite status',
    );
    await _tapSheetAction(tester, 'Добавить в избранное');
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
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump(const Duration(milliseconds: 250));
    expect(
      FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<TextButton>()?.key,
      const ValueKey('catalog-tab-false'),
    );
    final rail = tester.element(find.byType(CatalogNavigationRail));
    final menuFocus = tester.widget<TextButton>(find.byKey(const ValueKey('catalog-tab-true'))).focusNode;
    for (var transition = 0; transition < 3; transition++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump(const Duration(milliseconds: 250));
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pump();
      expect(tester.element(find.byType(CatalogNavigationRail)), same(rail));
      expect(FocusManager.instance.primaryFocus, same(menuFocus));
      expect(
        tester.getSize(find.byKey(const ValueKey('catalog-navigation-rail'))).width,
        CatalogNavigationRail.expandedWidth,
      );
      await E2eHarness.waitFor(tester, () => find.text('Избранное пусто').evaluate().isNotEmpty, 'empty favorites');
      if (transition < 2) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await E2eHarness.waitFor(tester, () => find.byType(AnimeCard).evaluate().isNotEmpty, 'repeated home');
      }
    }
    expect(
      FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<TextButton>()?.key,
      const ValueKey('catalog-tab-true'),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await E2eHarness.waitFor(tester, () => find.byType(AnimeCard).evaluate().isNotEmpty, 'remote home tab');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await E2eHarness.waitFor(tester, () => find.byType(AnimeScreen).evaluate().isNotEmpty, 'remote detail');
    await tester.binding.handlePopRoute();
    await E2eHarness.waitFor(tester, () => find.byType(AnimeScreen).evaluate().isEmpty, 'return to same card');
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await E2eHarness.waitFor(tester, () => find.byType(AnimeScreen).evaluate().isNotEmpty, 'reopen same card');
    await _openVideo(tester);
    final player = E2eHarness.requirePlayer(tester);
    await RemoteControls.openQuality(tester);
    await E2eHarness.waitFor(tester, () => find.text('360p').evaluate().isNotEmpty, 'remote chooser');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
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
    await RemoteControls.backToEpisodes(tester);
    await E2eHarness.waitFor(tester, () => find.byType(PlayerScreen).evaluate().isEmpty, 'visible remote back button');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('native seek hold release and controls idle after Play Back and pause resume', (tester) async {
    await fixture.configure();
    await fixture.launch(tester);
    await _openAnime(tester);
    await _openVideo(tester);
    final player = E2eHarness.requirePlayer(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.mediaPause);
    await E2eHarness.waitFor(tester, () => !player.value.isPlaying, 'pause for seek hold');
    await player.seekTo(const Duration(seconds: 15));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
    await E2eHarness.waitFor(tester, () => player.value.position <= Duration.zero, 'held rewind to start');
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await E2eHarness.waitFor(tester, () => player.value.position.inSeconds == 10, 'one short seek step');
    await tester.pump(const Duration(milliseconds: 800));
    expect(player.value.position.inSeconds, 10, reason: 'release stops native repeat');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await E2eHarness.waitFor(
      tester,
      () => FocusManager.instance.primaryFocus?.debugLabel == 'Пауза / воспроизведение',
      'play focus',
    );
    await tester.pump(const Duration(seconds: 5));
    expect(_controlsVisible(tester), isTrue, reason: 'paused controls stay visible');
    await player.seekTo(Duration.zero);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await E2eHarness.waitFor(tester, () => player.value.isPlaying, 'resume from play button');
    await E2eHarness.waitFor(tester, () => !_controlsVisible(tester), 'hide after play focus');
    await E2eHarness.waitFor(tester, () => FocusManager.instance.primaryFocus?.debugLabel == 'Видео', 'hidden focus');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await E2eHarness.waitFor(tester, () => FocusManager.instance.primaryFocus?.debugLabel == 'К сериям', 'Back focus');
    await tester.pump(const Duration(seconds: 3));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump(const Duration(seconds: 2));
    expect(_controlsVisible(tester), isTrue, reason: 'interaction renews timer even at focus boundary');
    await E2eHarness.waitFor(tester, () => !_controlsVisible(tester), 'hide after renewed Back inactivity');
    await tester.sendKeyEvent(LogicalKeyboardKey.mediaPause);
    await E2eHarness.waitFor(tester, () => !player.value.isPlaying, 'pause before closing hold');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.binding.handlePopRoute();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);
    await E2eHarness.waitFor(tester, () => find.byType(PlayerScreen).evaluate().isEmpty, 'Back during hold');
    await _expectScreenAwake(tester, false);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Android screen flag follows playback lifecycle and repeated catalog returns', (tester) async {
    await fixture.configure();
    await fixture.launch(tester);
    await _expectScreenAwake(tester, false);
    await _openAnime(tester);
    for (var entry = 0; entry < 2; entry++) {
      await _openVideo(tester);
      final player = E2eHarness.requirePlayer(tester);
      await _expectScreenAwake(tester, true);
      await tester.sendKeyEvent(LogicalKeyboardKey.mediaPause);
      await _expectScreenAwake(tester, false);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(player.value.isPlaying, isFalse);
      await _expectScreenAwake(tester, false);
      await tester.sendKeyEvent(LogicalKeyboardKey.mediaPlay);
      await _expectScreenAwake(tester, true);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await _expectScreenAwake(tester, false);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await _expectScreenAwake(tester, true);
      await player.seekTo(player.value.duration - const Duration(milliseconds: 300));
      await E2eHarness.waitFor(tester, () => player.value.isCompleted, 'native completion');
      await _expectScreenAwake(tester, false);
      await tester.sendKeyEvent(LogicalKeyboardKey.mediaPlay);
      await _expectScreenAwake(tester, true);
      await tester.binding.handlePopRoute();
      await _expectScreenAwake(tester, false);
      await E2eHarness.waitFor(tester, () => find.byType(PlayerScreen).evaluate().isEmpty, 'player disposed');
    }
    await tester.binding.handlePopRoute();
    await E2eHarness.waitFor(tester, () => find.byType(AnimeScreen).evaluate().isEmpty, 'catalog return');
    await _expectScreenAwake(tester, false);
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
    await RemoteControls.openQuality(tester);
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
    await RemoteControls.openEpisodes(tester);
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
    await RemoteControls.previousEpisode(tester);
    final second = player;
    await E2eHarness.waitFor(
      tester,
      () => E2eHarness.player(tester)?.value.isInitialized == true && !identical(E2eHarness.player(tester), second),
      'previous episode shortcut',
    );
    player = E2eHarness.requirePlayer(tester);
    // Recheck position and quality on the newly created previous-episode controller.
    // ignore: avoid-duplicate-test-assertions
    expect(player.value.position.inSeconds, lessThan(5));
    // ignore: avoid-duplicate-test-assertions
    expect(player.value.size.height, 360);
    expect(find.byKey(const ValueKey('player-previous-episode')), findsNothing);
    await RemoteControls.nextEpisode(tester);
    final first = player;
    await E2eHarness.waitFor(
      tester,
      () => E2eHarness.player(tester)?.value.isInitialized == true && !identical(E2eHarness.player(tester), first),
      'next episode shortcut',
    );
    player = E2eHarness.requirePlayer(tester);
    expect(find.byKey(const ValueKey('player-next-episode')), findsNothing);
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
    await _expectScreenAwake(tester, false);
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
    () => find.textContaining('Смотреть серию ').evaluate().isNotEmpty,
    'details and sorted episodes',
  );
}

Future<void> _pressPlay(WidgetTester tester) async {
  final button = find.textContaining('Смотреть серию ');
  await E2eHarness.waitFor(tester, () => button.hitTestable().evaluate().isNotEmpty, 'detail action after transition');
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

Future<void> _tapSheetAction(WidgetTester tester, String label) async {
  final action = find.text(label).hitTestable();
  await E2eHarness.waitFor(tester, () {
    if (action.evaluate().isEmpty) {
      return false;
    }

    return ModalRoute.of(tester.element(action))?.animation?.status == AnimationStatus.completed;
  }, 'sheet ready: $label');
  await tester.tap(action);
}

Future<void> _waitFilter(WidgetTester tester, String path) async {
  final screen = find.byWidgetPredicate((widget) => widget is CatalogScreen && widget.filter?.path == path);
  await E2eHarness.waitFor(
    tester,
    () => find.descendant(of: screen, matching: find.byType(AnimeCard)).evaluate().isNotEmpty,
    'filter $path',
  );
  // The previous route remains onstage during the entrance transition.
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _expectScreenAwake(WidgetTester tester, bool expected) async {
  const channel = MethodChannel('anistar_tv/playback_screen_awake');
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  bool? actual;
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 50));
    actual = await channel.invokeMethod<bool>('isEnabled');
    if (actual == expected) {
      return;
    }
  }
  expect(actual, expected, reason: 'actual Android FLAG_KEEP_SCREEN_ON');
}

bool _controlsVisible(WidgetTester tester) => tester.widget<PlayerView>(find.byType(PlayerView)).controlsVisible;
