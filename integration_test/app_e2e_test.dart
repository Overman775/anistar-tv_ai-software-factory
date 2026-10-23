// Native controller state changes on the Android event loop between pumps.
// ignore_for_file: prefer-moving-to-variable

// Deterministic Android TV suite: remote focus, TV panels and native playback.
// Phone touch journeys live separately in mobile_e2e_test.dart.

import 'package:anistar_tv/app/app_device_profile_resolver.dart';
import 'package:anistar_tv/packages/features/anime/presentation/screens/anime_screen.dart';
import 'package:anistar_tv/packages/features/anime/presentation/widgets/episode_card.dart';
import 'package:anistar_tv/packages/features/auth/presentation/intro_screen.dart';
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
import 'package:ui_kit/ui_kit.dart';
import 'package:video_player/video_player.dart';

import 'support/e2e_harness.dart';
import 'support/remote_controls.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  late E2eHarness fixture;

  setUpAll(() async {
    expect(
      await AppDeviceProfileResolver.resolve(),
      AppDeviceProfile.tv,
      reason: 'TV E2E requires an Android TV system image, not only a wide screen or TV skin.',
    );
  });

  setUp(() => fixture = E2eHarness());
  tearDown(() => fixture.close());

  _tvTest('guest search native playback and cancelled login preserve public context', (tester) async {
    await fixture.configure();
    await fixture.launch(tester, autoLogin: false);
    await RemoteControls.activate(
      tester,
      find.byKey(const ValueKey('intro_guest')),
      step: 'enter guest',
      direction: LogicalKeyboardKey.arrowDown,
    );
    await E2eHarness.waitFor(tester, () => find.byType(AnimeCard).evaluate().isNotEmpty, 'guest home');
    expect(find.byKey(const ValueKey('catalog-tab-true')), findsNothing);
    await _selectRail(tester, 'catalog-search');
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    await tester.enterText(find.byKey(const ValueKey('search-query')), 'Наруто');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    final first = find.byKey(const ValueKey('search-card-10938'));
    await E2eHarness.waitFor(tester, () => first.evaluate().isNotEmpty, 'public search cards');
    await RemoteControls.activate(
      tester,
      first,
      step: 'open public search detail',
      direction: LogicalKeyboardKey.arrowDown,
    );
    await E2eHarness.waitFor(tester, () => find.text('Смотреть серию 1').evaluate().isNotEmpty, 'guest detail');
    await _openVideo(tester);
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
    await _selectRail(tester, 'catalog-sign-in');
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

  _tvTest('Android TV search shows native IME only on entry and restores remote navigation after editing', (
    tester,
  ) async {
    await fixture.configure();
    await fixture.launch(tester, autoLogin: false);
    await RemoteControls.activate(
      tester,
      find.byKey(const ValueKey('intro_guest')),
      step: 'enter guest before search IME check',
      direction: LogicalKeyboardKey.arrowDown,
    );
    await E2eHarness.waitFor(tester, () => find.byType(AnimeCard).evaluate().isNotEmpty, 'guest home');
    await _selectRail(tester, 'catalog-genres');
    await E2eHarness.waitFor(
      tester,
      () => find.byType(GenresScreen).evaluate().isNotEmpty,
      'other section before search',
    );

    final query = find.byKey(const ValueKey('search-query'));
    final rail = find.byType(CatalogNavigationRail);
    TextField queryField() => tester.widget<TextField>(query);
    double keyboardInset() => MediaQuery.viewInsetsOf(tester.element(query)).bottom;

    await _selectRail(tester, 'catalog-search', direction: LogicalKeyboardKey.arrowUp);
    await E2eHarness.waitFor(tester, () => !queryField().readOnly, 'search field editing after route entry');
    // On the configured Android TV AVD this comes from the OS IME window, not
    // from a TextInput.show method-call observation. The host runner records
    // dumpsys input_method (or an emulator screenshot) for this same step.
    await E2eHarness.waitFor(tester, () => keyboardInset() > 0, 'native Android IME inset after search entry');
    // Keep the native IME visible long enough for the host ADB observer to
    // capture its real window state and emulator frame during this fixture.
    await tester.pump(const Duration(seconds: 2));

    await tester.enterText(query, 'Наруто');
    final queryController = queryField().controller;
    if (queryController == null) {
      fail('Search query must have a controller.');
    }
    final cursorAtEnd = queryController.selection.extentOffset;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(queryField().focusNode?.hasFocus, isTrue);
    expect(queryController.selection.extentOffset, lessThan(cursorAtEnd));
    expect(tester.widget<CatalogNavigationRail>(rail).expanded, isFalse);

    await tester.binding.handlePopRoute();
    await E2eHarness.waitFor(tester, () => queryField().readOnly, 'Back finishes search editing');
    await E2eHarness.waitFor(tester, () => keyboardInset() == 0, 'native Android IME hidden after Back');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await E2eHarness.waitFor(
      tester,
      () => tester.widget<CatalogNavigationRail>(rail).expanded,
      'Left opens menu after editing is finished',
    );
    await RemoteControls.activate(tester, find.byKey(const ValueKey('catalog-search')), step: 'return to search field');
    await E2eHarness.waitFor(tester, () => queryField().readOnly, 'rail reselect does not reopen the IME');
    expect(keyboardInset(), 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await E2eHarness.waitFor(tester, () => !queryField().readOnly, 'explicit Select starts editing again');
    await E2eHarness.waitFor(tester, () => keyboardInset() > 0, 'native Android IME after explicit editing');

    await tester.testTextInput.receiveAction(TextInputAction.search);
    final first = find.byKey(const ValueKey('search-card-10938'));
    await E2eHarness.waitFor(tester, () => first.evaluate().isNotEmpty, 'search result after IME submit');
    await E2eHarness.waitFor(tester, () => queryField().readOnly, 'editing finishes after submit');
    await E2eHarness.waitFor(tester, () => keyboardInset() == 0, 'native Android IME hidden after submit');

    await RemoteControls.activate(
      tester,
      first,
      step: 'open search detail before no-reopen check',
      direction: LogicalKeyboardKey.arrowDown,
    );
    await E2eHarness.waitFor(tester, () => find.byType(AnimeScreen).evaluate().isNotEmpty, 'search detail');
    await tester.binding.handlePopRoute();
    await E2eHarness.waitFor(tester, () => find.byType(AnimeScreen).evaluate().isEmpty, 'return to search');

    await _selectRail(tester, 'catalog-search');
    await E2eHarness.waitFor(tester, () => queryField().readOnly, 'same search destination remains non-editing');
    expect(keyboardInset(), 0, reason: 'Returning from details and reselecting Search must not reopen the IME.');
  });

  _tvTest('D-pad Left moves between real catalog cards before opening the active rail', (tester) async {
    await fixture.configure();
    await fixture.launch(tester);
    final rail = find.byType(CatalogNavigationRail);
    int? focusedAnimeId() =>
        FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<AnimeCard>()?.anime.id;
    void expectRailCollapsed() => expect(tester.widget<CatalogNavigationRail>(rail).expanded, isFalse);

    await E2eHarness.waitFor(tester, () => focusedAnimeId() != null, 'initial catalog card focus');
    final firstId = focusedAnimeId();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await E2eHarness.waitFor(
      tester,
      () => focusedAnimeId() != null && focusedAnimeId() != firstId,
      'right neighbor focus',
    );
    final rightId = focusedAnimeId();
    expectRailCollapsed();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await E2eHarness.waitFor(tester, () => focusedAnimeId() == firstId, 'left neighbor focus');
    expect(focusedAnimeId(), isNot(rightId));
    expectRailCollapsed();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await E2eHarness.waitFor(
      tester,
      () => tester.widget<CatalogNavigationRail>(rail).expanded,
      'first-column Left opens active rail',
    );
    final home = tester.widget<TextButton>(find.byKey(const ValueKey('catalog-tab-false')));
    expect(FocusManager.instance.primaryFocus, same(home.focusNode));
  });

  _tvTest('genre sorting applies per request, paginates and restores focus after detail', (tester) async {
    await fixture.configure();
    await fixture.launch(tester);
    await E2eHarness.waitFor(tester, () => find.byType(AnimeCard).evaluate().isNotEmpty, 'catalog');
    await _selectRail(tester, 'catalog-genres');
    await _enterGenres(tester);
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

  _tvTest('genres and anime metadata open paginated filters and restore remote focus', (tester) async {
    await fixture.configure();
    await fixture.launch(tester);
    await E2eHarness.waitFor(tester, () => find.byType(AnimeCard).evaluate().isNotEmpty, 'catalog');
    await _selectRail(tester, 'catalog-genres');
    await _enterGenres(tester);
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

  _tvTest('startup retry, login rejection, encrypted restore, expiry and logout gate the catalog', (tester) async {
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
    // A normal protected request must detect expiry without a refresh button.
    await _selectRail(tester, 'catalog-genres');
    await E2eHarness.waitFor(tester, () => find.byType(IntroScreen).evaluate().isNotEmpty, 'expired session intro');
    // Verify the gate again after this separate session transition.
    // ignore: avoid-duplicate-test-assertions
    expect(find.byType(CatalogScreen), findsNothing);
    await E2eHarness.login(tester);
    await E2eHarness.waitFor(tester, () => find.byType(AnimeCard).evaluate().isNotEmpty, 'second login');
    await _selectRail(tester, 'catalog-account');
    await E2eHarness.waitFor(
      tester,
      () => FocusManager.instance.primaryFocus?.debugLabel == 'Отмена подтверждения',
      'logout defaults to cancel',
    );
    await RemoteControls.activate(
      tester,
      find.widgetWithText(AppButton, 'Выйти из аккаунта'),
      step: 'confirm account logout',
      direction: LogicalKeyboardKey.arrowDown,
    );
    await E2eHarness.waitFor(tester, () => find.byType(IntroScreen).evaluate().isNotEmpty, 'logout intro');
    await tester.pumpWidget(const SizedBox.shrink());
    await fixture.launch(tester, autoLogin: false, resetSession: false);
    await E2eHarness.waitFor(
      tester,
      () => find.byKey(const ValueKey('intro_sign_in')).evaluate().isNotEmpty,
      'logout survives restart',
    );
    // Verify the gate again after this separate session transition.
    // ignore: avoid-duplicate-test-assertions
    expect(find.byType(CatalogScreen), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  _tvTest('website favorites survive a new client and update both tabs and details', (tester) async {
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
    await _selectSheetAction(tester, 'Добавить в избранное');
    final marker = find.descendant(
      of: find.byWidgetPredicate((widget) => widget is AnimeCard && widget.anime.id == 10938),
      matching: find.byType(MediaCardBookmark),
    );
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
    await _selectRail(tester, 'catalog-tab-true');
    await E2eHarness.waitFor(tester, () => find.byType(AnimeCard).evaluate().length == 1, 'website favorites tab');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await E2eHarness.waitFor(tester, () => find.text('В избранном').evaluate().isNotEmpty, 'detail removal action');
    await RemoteControls.activate(
      tester,
      find.byKey(const ValueKey('favorite-button-10938')),
      step: 'detail favorite removal',
      direction: LogicalKeyboardKey.arrowRight,
    );
    await E2eHarness.waitFor(tester, () => find.text('В избранное').evaluate().isNotEmpty, 'confirmed detail removal');
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
    await _selectRail(tester, 'catalog-tab-false', direction: LogicalKeyboardKey.arrowUp);
    await E2eHarness.waitFor(tester, () => marker.evaluate().isNotEmpty, 'external website change');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  _tvTest('site rejects a favorite mutation without changing the UI; explicit retry recovers', (tester) async {
    await fixture.configure(favoriteError: true);
    await fixture.launch(tester);
    await E2eHarness.waitFor(tester, () => find.byType(AnimeCard).evaluate().isNotEmpty, 'favorite error catalog');
    await RemoteControls.expectFocused(tester, find.byType(AnimeCard).first, 'favorite card focus');
    await RemoteControls.holdSelect(tester);
    await E2eHarness.waitFor(
      tester,
      () => find.text('Добавить в избранное').evaluate().isNotEmpty,
      'remote favorite menu',
    );
    await _selectSheetAction(tester, 'Добавить в избранное');
    await E2eHarness.waitFor(tester, () => find.text('Обновить статус').evaluate().isNotEmpty, 'favorite rejection');
    expect(
      find.descendant(
        of: find.byWidgetPredicate((widget) => widget is AnimeCard && widget.anime.id == 10938),
        matching: find.byType(MediaCardBookmark),
      ),
      findsNothing,
    );
    expect((await fixture.state())['favorites'], isEmpty);
    await fixture.configure(reset: false);
    await _selectSheetAction(tester, 'Обновить статус');
    await E2eHarness.waitFor(
      tester,
      () => find.text('Добавить в избранное').evaluate().isNotEmpty,
      'fresh favorite status',
    );
    await _selectSheetAction(tester, 'Добавить в избранное');
    await E2eHarness.waitFor(
      tester,
      () => find
          .descendant(
            of: find.byWidgetPredicate((widget) => widget is AnimeCard && widget.anime.id == 10938),
            matching: find.byType(MediaCardBookmark),
          )
          .evaluate()
          .isNotEmpty,
      'manual favorite retry',
    );
    expect((await fixture.state())['favorite_writes'], 2);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  _tvTest('remote tabs, empty favorites, dialog cancellation and route focus restoration', (tester) async {
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
    for (var transition = 0; transition < 3; transition++) {
      await _selectRail(tester, 'catalog-tab-true');
      await E2eHarness.waitFor(tester, () => find.text('Избранное пусто').evaluate().isNotEmpty, 'empty favorites');
      expect(tester.element(find.byType(CatalogNavigationRail)), same(rail));
      expect(tester.widget<CatalogNavigationRail>(find.byType(CatalogNavigationRail)).expanded, isFalse);
      await tester.binding.handlePopRoute();
      await E2eHarness.waitFor(
        tester,
        () => tester.widget<CatalogNavigationRail>(find.byType(CatalogNavigationRail)).expanded,
        'root Back opens active menu',
      );
      final menuFocus = tester.widget<TextButton>(find.byKey(const ValueKey('catalog-tab-true'))).focusNode;
      expect(FocusManager.instance.primaryFocus, same(menuFocus));
      await _selectRail(tester, 'catalog-tab-false', direction: LogicalKeyboardKey.arrowUp);
      await E2eHarness.waitFor(tester, () => find.byType(AnimeCard).evaluate().isNotEmpty, 'repeated home');
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await E2eHarness.waitFor(tester, () => find.byType(AnimeScreen).evaluate().isNotEmpty, 'remote detail');
    await tester.binding.handlePopRoute();
    await E2eHarness.waitFor(tester, () => find.byType(AnimeScreen).evaluate().isEmpty, 'return to same card');
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await E2eHarness.waitFor(tester, () => find.byType(AnimeScreen).evaluate().isNotEmpty, 'reopen same card');
    await _openVideo(tester);
    final player = E2eHarness.requirePlayer(tester);
    await RemoteControls.openQuality(tester);
    await E2eHarness.waitFor(tester, () => find.text('SD 360p').evaluate().isNotEmpty, 'remote chooser');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await E2eHarness.waitFor(tester, () => find.text('SD 360p').evaluate().isEmpty, 'cancel chooser');
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

  _tvTest('native seek hold release and controls idle after Play Back and pause resume', (tester) async {
    await fixture.configure();
    await fixture.launch(tester);
    await _openAnime(tester);
    await _openVideo(tester);
    final player = E2eHarness.requirePlayer(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.mediaPause);
    await E2eHarness.waitFor(tester, () => !player.value.isPlaying, 'pause for seek hold');
    await player.seekTo(const Duration(seconds: 15));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
    await E2eHarness.waitFor(
      tester,
      () => tester.widget<Slider>(find.byType(Slider)).value == 0,
      'held rewind preview to start',
    );
    expect(player.value.position, const Duration(seconds: 15), reason: 'hold must not seek native video');
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);
    await E2eHarness.waitFor(tester, () => player.value.position <= Duration.zero, 'release commits rewind');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(milliseconds: 100));
    expect(player.value.position, Duration.zero, reason: 'short press also waits for release');
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
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
    await E2eHarness.expectScreenAwake(tester, false);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  _tvTest('Android screen flag follows playback lifecycle and repeated catalog returns', (tester) async {
    await fixture.configure();
    await fixture.launch(tester);
    await E2eHarness.expectScreenAwake(tester, false);
    await _openAnime(tester);
    for (var entry = 0; entry < 2; entry++) {
      await _openVideo(tester);
      final player = E2eHarness.requirePlayer(tester);
      await E2eHarness.expectScreenAwake(tester, true);
      await tester.sendKeyEvent(LogicalKeyboardKey.mediaPause);
      await E2eHarness.expectScreenAwake(tester, false);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(player.value.isPlaying, isFalse);
      await E2eHarness.expectScreenAwake(tester, false);
      await tester.sendKeyEvent(LogicalKeyboardKey.mediaPlay);
      await E2eHarness.expectScreenAwake(tester, true);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await E2eHarness.expectScreenAwake(tester, false);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await E2eHarness.expectScreenAwake(tester, true);
      await player.seekTo(player.value.duration - const Duration(milliseconds: 300));
      await E2eHarness.waitFor(tester, () => player.value.isCompleted, 'native completion');
      await E2eHarness.expectScreenAwake(tester, false);
      await tester.sendKeyEvent(LogicalKeyboardKey.mediaPlay);
      await E2eHarness.expectScreenAwake(tester, true);
      await tester.binding.handlePopRoute();
      await E2eHarness.expectScreenAwake(tester, false);
      await E2eHarness.waitFor(tester, () => find.byType(PlayerScreen).evaluate().isEmpty, 'player disposed');
    }
    await tester.binding.handlePopRoute();
    await E2eHarness.waitFor(tester, () => find.byType(AnimeScreen).evaluate().isEmpty, 'catalog return');
    await E2eHarness.expectScreenAwake(tester, false);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  _tvTest('catalog, real HTML, native 720/360 HLS, remote, episode and back', (tester) async {
    await fixture.configure();
    await fixture.launch(tester);
    await _openAnime(tester);
    expect(
      find.byWidgetPredicate((widget) => widget is EpisodeCard && (widget.isWatched || widget.episode.isWatched)),
      findsNothing,
    );
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
    await E2eHarness.waitFor(tester, () => find.text('SD 360p').evaluate().isNotEmpty, 'quality dialog');
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
    await _revealEpisodes(tester);
    await E2eHarness.waitFor(
      tester,
      () =>
          find
              .byWidgetPredicate((widget) => widget is EpisodeCard && (widget.isWatched || widget.episode.isWatched))
              .evaluate()
              .length ==
          2,
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
    await _openAnime(tester, watchLabel: 'Посмотреть снова');
    await _revealEpisodes(tester);
    await E2eHarness.waitFor(
      tester,
      () =>
          find
              .byWidgetPredicate((widget) => widget is EpisodeCard && (widget.isWatched || widget.episode.isWatched))
              .evaluate()
              .length ==
          2,
      'watched history after client restart',
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  _tvTest('remote navigation loads and displays the next catalog page', (tester) async {
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

  _tvTest('catalog refusal is visible and explicit retry recovers', (tester) async {
    await fixture.configure(catalogError: true);
    await fixture.launch(tester);
    await E2eHarness.waitFor(tester, () => find.text('Каталог недоступен').evaluate().isNotEmpty, 'catalog error');
    await fixture.configure(reset: false);
    await RemoteControls.activate(tester, RemoteControls.action('Попробовать снова'), step: 'catalog retry');
    await E2eHarness.waitFor(tester, () => find.byType(AnimeCard).evaluate().isNotEmpty, 'catalog retry');
    final events = _events(await fixture.state());
    final statuses = events
        .where((event) => event['path'] == '/anime/' && event['method'] == 'GET' && event['authenticated'] == true)
        .map((event) => event['status']);
    expect(statuses, [403, 200]);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  _tvTest('expired HLS refreshes its HTML once and opens a fresh native source', (tester) async {
    await fixture.configure(videoMode: 'refresh_once');
    await fixture.launch(tester);
    await _openAnime(tester);
    await _openVideo(tester);
    expect(E2eHarness.requirePlayer(tester).dataSource, contains('/fresh/'));
    final state = await fixture.state();
    final events = _events(state).toList();
    final refused = events.indexWhere((event) => _path(event).contains('/expired/') && event['status'] == 403);
    final recovered = events.indexWhere((event) => _path(event).startsWith('/hls/fresh/'));
    expect(refused, greaterThanOrEqualTo(0));
    expect(recovered, greaterThan(refused));
    // Watched marking fetches HTML after playback begins too. Bound only the
    // source recovery window, before any fresh manifest can start playback.
    final refreshes = events
        .sublist(refused + 1, recovered)
        .where((event) => _path(event).startsWith('/test/player2/'));
    expect(refreshes, hasLength(1), reason: 'exactly one HTML refresh between rejection and fresh native source');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  _tvTest('persistent HLS rejection stops retrying and manual retry can recover', (tester) async {
    await fixture.configure(videoMode: 'always_expired');
    await fixture.launch(tester);
    await _openAnime(tester);
    await _pressPlay(tester);
    await E2eHarness.waitFor(
      tester,
      () => find.text('Видео не запустилось').evaluate().isNotEmpty,
      'bounded video error',
    );
    await E2eHarness.expectScreenAwake(tester, false);
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
    await E2eHarness.waitFor(
      tester,
      () => (E2eHarness.player(tester)?.value.position.inMilliseconds ?? 0) > 500,
      'manual retry advances native playback',
    );
    await RemoteControls.backToEpisodes(tester);
    await E2eHarness.waitFor(tester, () => find.byType(PlayerScreen).evaluate().isEmpty, 'retry returns to anime');
    await _revealEpisodes(tester);
    await E2eHarness.waitFor(
      tester,
      () =>
          find
              .byWidgetPredicate((widget) => widget is EpisodeCard && (widget.isWatched || widget.episode.isWatched))
              .evaluate()
              .length ==
          1,
      'manual retry has one app-confirmed watched episode',
    );
    final recovered = await fixture.state();
    expect(recovered['watched'], [1]);
    expect(_events(recovered).where((event) => _path(event).startsWith('/engine/ajax/ns.php')), hasLength(1));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

void _tvTest(String name, Future<void> Function(WidgetTester) body) =>
    E2eHarness.testCase(name, body, profile: AppDeviceProfile.tv);

Future<void> _openAnime(WidgetTester tester, {String watchLabel = 'Смотреть серию 1'}) async {
  final card = find.byWidgetPredicate((widget) => widget is AnimeCard && widget.anime.id == 10938);
  await E2eHarness.waitFor(tester, () => card.evaluate().isNotEmpty, 'catalog');
  expect(find.text('Реклама'), findsNothing);
  await RemoteControls.activate(tester, card, step: 'catalog anime 10938');
  await E2eHarness.waitFor(tester, () => find.text(watchLabel).evaluate().isNotEmpty, 'details and sorted episodes');
}

Future<void> _pressPlay(WidgetTester tester) async {
  final button = find.textContaining('Смотреть серию ');
  final action = find.ancestor(of: button, matching: find.byType(AppButton));
  await RemoteControls.activate(tester, action, step: 'first episode play');
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

Future<void> _selectSheetAction(WidgetTester tester, String label) =>
    RemoteControls.activate(tester, RemoteControls.action(label), step: 'sheet action: $label');

Future<void> _selectRail(
  WidgetTester tester,
  String key, {
  LogicalKeyboardKey direction = LogicalKeyboardKey.arrowDown,
}) async {
  await E2eHarness.waitFor(tester, () {
    final rails = find.byType(CatalogNavigationRail).evaluate().toList();
    if (rails.length != 1) {
      return false;
    }
    final route = ModalRoute.of(rails.single);

    return route == null || route.isCurrent && route.animation?.status == AnimationStatus.completed;
  }, 'current catalog rail after route transition');
  if (!tester.widget<CatalogNavigationRail>(find.byType(CatalogNavigationRail)).expanded) {
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await E2eHarness.waitFor(
      tester,
      () => tester.widget<CatalogNavigationRail>(find.byType(CatalogNavigationRail)).expanded,
      'catalog rail focus',
    );
  }
  await RemoteControls.activate(tester, find.byKey(ValueKey(key)), step: 'rail action $key', direction: direction);
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

bool _controlsVisible(WidgetTester tester) => tester.widget<PlayerView>(find.byType(PlayerView)).controlsVisible;

Future<void> _enterGenres(WidgetTester tester) async {
  await E2eHarness.waitFor(tester, () => find.text('Комедия').evaluate().isNotEmpty, 'inline genre tile ready');
  if (FocusManager.instance.primaryFocus?.debugLabel != 'Комедия') {
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
  }
}

Future<void> _revealEpisodes(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
  await E2eHarness.waitFor(
    tester,
    () => FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<EpisodeCard>() != null,
    'confirmed episodes revealed by remote',
  );
}
