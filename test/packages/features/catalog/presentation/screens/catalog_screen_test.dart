import 'dart:async';

import 'package:anistar_tv/packages/features/auth/auth_providers.dart';
import 'package:anistar_tv/packages/features/catalog/catalog_providers.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/anime_page.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/anime_summary.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/catalog_filter.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/screens/catalog_screen.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/widgets/anime_card.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/widgets/catalog_inspector_copy.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/widgets/catalog_skeleton.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/widgets/catalog_tail.dart';
import 'package:anistar_tv/packages/features/favorites/favorites_providers.dart';
import 'package:anistar_tv/packages/features/favorites/presentation/favorite_actions_sheet.dart';
import 'package:anistar_tv/packages/features/home/presentation/screens/home_screen.dart';
import 'package:core/data.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../../../mocks/features/catalog/fake_catalog_screen_repository.dart';
import '../../../../../mocks/features/favorites/fake_favorites_repository.dart';
import '../../../../../support/test_app.dart';

// Focus is mutable: each assertion reads the result of the preceding key event.
final _posters = find.byKey(const ValueKey('tv-catalog-poster-rail'));

ScrollPosition _posterPosition(WidgetTester tester) =>
    tester.state<ScrollableState>(find.descendant(of: _posters, matching: find.byType(Scrollable))).position;

int? _focusedAnimeId() =>
    FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<AnimeCard>()?.anime.id;

void main() {
  testWidgets('hidden source does not request continuation until activated', (tester) async {
    final active = ValueNotifier(false);
    addTearDown(active.dispose);
    final requests = <int>[];
    const item = AnimeSummary(id: 1, slug: '1-first', title: 'First');
    await pumpTvApp(
      tester,
      ValueListenableBuilder(
        valueListenable: active,
        builder: (context, value, _) => CatalogScreen(active: value, onAnimeTap: (_) => fail('Unexpected activation')),
      ),
      wrapInScaffold: false,
      overrides: [
        catalogRepositoryProvider.overrideWithValue(
          FakeCatalogScreenRepository(
            load: (page) async {
              requests.add(page);
              return Result.success(AnimePage(items: [item], page: page, hasNext: page == 1));
            },
          ),
        ),
      ],
    );
    await tester.pumpAndSettle();
    expect(requests, [1]);
    active.value = true;
    await tester.pumpAndSettle();
    expect(requests, [1, 2]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pending Right is canceled when focus leaves the poster', (tester) async {
    final pageTwo = Completer<Result<AnimePage, Failure>>();
    const first = AnimeSummary(id: 1, slug: '1-first', title: 'First');
    const next = AnimeSummary(id: 2, slug: '2-next', title: 'Next');
    await pumpTvApp(
      tester,
      CatalogScreen(onAnimeTap: (_) => fail('Unexpected activation')),
      wrapInScaffold: false,
      overrides: [
        catalogRepositoryProvider.overrideWithValue(
          FakeCatalogScreenRepository(
            load: (page) => page == 1
                ? Future.value(Result.success(AnimePage(items: [first], page: 1, hasNext: true)))
                : pageTwo.future,
          ),
        ),
      ],
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    pageTwo.complete(Result.success(AnimePage(items: [next], page: 2, hasNext: false)));
    await tester.pumpAndSettle();
    expect(_focusedAnimeId(), isNull);
    expect(focusedControlLabel(tester), 'Смотреть');
    expect(tester.takeException(), isNull);
  });

  testWidgets('duplicate-only page advances to short final page without repeated items', (tester) async {
    final requests = <int>[];
    const first = AnimeSummary(id: 1, slug: '1-first', title: 'First');
    const next = AnimeSummary(id: 2, slug: '2-next', title: 'Next');
    await pumpTvApp(
      tester,
      CatalogScreen(onAnimeTap: (_) => fail('Unexpected activation')),
      wrapInScaffold: false,
      overrides: [
        catalogRepositoryProvider.overrideWithValue(
          FakeCatalogScreenRepository(
            load: (page) async {
              requests.add(page);
              return Result.success(AnimePage(items: page == 3 ? [next] : [first], page: page, hasNext: page < 3));
            },
          ),
        ),
      ],
    );
    await tester.pumpAndSettle();
    expect(requests, [1, 2, 3]);
    expect(find.byKey(const ValueKey(1)), findsOneWidget);
    expect(find.byKey(const ValueKey(2)), findsOneWidget);
    expect(find.byKey(const ValueKey('tv-catalog-unloaded-slot'), skipOffstage: false), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unloaded slot in cache waits for real viewport intersection and makes one request', (tester) async {
    final pageTwo = Completer<Result<AnimePage, Failure>>();
    final requests = <int>[];
    final items = List.generate(8, (i) => AnimeSummary(id: i + 1, slug: '${i + 1}-test', title: 'Title ${i + 1}'));
    await pumpTvApp(
      tester,
      CatalogScreen(onAnimeTap: (_) => fail('Unexpected activation')),
      wrapInScaffold: false,
      overrides: [
        catalogRepositoryProvider.overrideWithValue(
          FakeCatalogScreenRepository(
            load: (page) {
              requests.add(page);
              return page == 1
                  ? Future.value(Result.success(AnimePage(items: items, page: 1, hasNext: true)))
                  : pageTwo.future;
            },
          ),
        ),
      ],
    );
    await tester.pumpAndSettle();
    final slot = find.byKey(const ValueKey('tv-catalog-unloaded-slot'), skipOffstage: false).first;
    expect(slot, findsOneWidget);
    expect(tester.getRect(slot).overlaps(tester.getRect(_posters)), isFalse);
    expect(requests, [1]);
    _posterPosition(tester).jumpTo(300);
    await tester.pump();
    await tester.pump();
    expect(requests, [1, 2]);
    await tester.pump(const Duration(milliseconds: 100));
    expect(requests, [1, 2]);
    expect(find.byKey(const ValueKey('tv-catalog-loading-slot')), findsWidgets);
    pageTwo.complete(Result.success(AnimePage(items: [], page: 2, hasNext: false)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('tv-catalog-loading-slot')), findsNothing);
    expect(find.byKey(const ValueKey('tv-catalog-unloaded-slot')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('horizontal overlap alone does not load a vertically displaced slot', (tester) async {
    final requests = <int>[];
    final items = List.generate(8, (i) => AnimeSummary(id: i + 1, slug: '${i + 1}-test', title: 'Title ${i + 1}'));
    await pumpTvApp(
      tester,
      CatalogScreen(onAnimeTap: (_) => fail('Unexpected activation')),
      wrapInScaffold: false,
      overrides: [
        catalogRepositoryProvider.overrideWithValue(
          FakeCatalogScreenRepository(
            load: (page) async {
              requests.add(page);
              return Result.success(AnimePage(items: page == 1 ? items : [], page: page, hasNext: page == 1));
            },
          ),
        ),
      ],
    );
    await tester.pumpAndSettle();

    final slot = find.byKey(const ValueKey('tv-catalog-unloaded-slot'), skipOffstage: false).first;
    final slotBox = tester.renderObject<RenderBox>(slot).parent?.parent;
    final alignmentBox = slotBox?.parent;
    if (slotBox is! RenderConstrainedBox || alignmentBox is! RenderPositionedBox) {
      throw TestFailure('The first unloaded slot must have its own size and alignment');
    }
    final originalConstraints = slotBox.additionalConstraints;
    final originalAlignment = alignmentBox.alignment;
    // The production rail aligns every slot vertically. Move only the first
    // slot in the render tree to exercise the otherwise independent Y check.
    slotBox.additionalConstraints = BoxConstraints.tightFor(width: originalConstraints.maxWidth, height: 20);
    alignmentBox.alignment = const Alignment(-1, 5);
    final position = _posterPosition(tester)..jumpTo(300);
    await tester.pumpAndSettle();

    final viewport = tester.getRect(_posters);
    final displaced = tester.getRect(slot);
    expect(displaced.left, lessThan(viewport.right));
    expect(displaced.right, greaterThan(viewport.left));
    expect(displaced.top, greaterThanOrEqualTo(viewport.bottom));
    expect(requests, [1]);

    slotBox.additionalConstraints = originalConstraints;
    alignmentBox.alignment = originalAlignment;
    position.jumpTo(301);
    await tester.pumpAndSettle();
    expect(requests, [1, 2]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('covered catalog cancels pending Right and does not chain an in-flight page', (tester) async {
    final requests = <int>[];
    final pageTwo = Completer<Result<AnimePage, Failure>>();
    const first = AnimeSummary(id: 1, slug: '1-first', title: 'First');
    const appended = AnimeSummary(id: 2, slug: '2-appended', title: 'Appended');
    await pumpTvApp(
      tester,
      CatalogScreen(onAnimeTap: (_) => fail('Unexpected activation')),
      wrapInScaffold: false,
      disableAnimations: true,
      overrides: [
        catalogRepositoryProvider.overrideWithValue(
          FakeCatalogScreenRepository(
            load: (page) {
              requests.add(page);
              return page == 2
                  ? pageTwo.future
                  : Future.value(Result.success(AnimePage(items: [first], page: page, hasNext: page == 1)));
            },
          ),
        ),
      ],
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(_focusedAnimeId(), 1);
    expect(requests, [1, 2]);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    unawaited(
      navigator.push<void>(
        PageRouteBuilder(
          opaque: false,
          pageBuilder: (_, _, _) => const Material(child: Center(child: Text('Covering route'))),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Covering route'), findsOneWidget);
    pageTwo.complete(Result.success(AnimePage(items: [appended], page: 2, hasNext: true)));
    await tester.pumpAndSettle();
    expect(requests, [1, 2]);
    expect(_focusedAnimeId(), isNull);

    navigator.pop();
    await tester.pumpAndSettle();
    expect(requests, [1, 2, 3]);
    expect(find.byKey(const ValueKey(2)), findsOneWidget);
    expect(_focusedAnimeId(), 1);
    expect(tester.takeException(), isNull);
  });

  for (final replaceAccount in [true, false]) {
    testWidgets('replacement discards an in-flight page and pending Right (account=$replaceAccount)', (tester) async {
      final requests = <int>[];
      final pageTwo = Completer<Result<AnimePage, Failure>>();
      const first = AnimeSummary(id: 1, slug: '1-first', title: 'First');
      const stale = AnimeSummary(id: 2, slug: '2-stale', title: 'Stale');
      const replacement = AnimeSummary(id: 3, slug: '3-replacement', title: 'Replacement');
      var changed = false;
      final repository = FakeCatalogScreenRepository(
        load: (page) {
          requests.add(page);
          return page == 2
              ? pageTwo.future
              : Future.value(
                  Result.success(
                    AnimePage(items: changed ? [first, replacement] : [first], page: page, hasNext: !changed),
                  ),
                );
        },
      );
      final newOriginRepository = FakeCatalogScreenRepository(load: repository.getPage);
      await pumpTvApp(
        tester,
        CatalogScreen(onAnimeTap: (_) => fail('Unexpected activation')),
        wrapInScaffold: false,
        overrides: [
          catalogRepositoryProvider.overrideWith((_) => changed && !replaceAccount ? newOriginRepository : repository),
          authAccessProvider.overrideWith((_) => AuthenticatedAccess(changed && replaceAccount ? 'new' : 'old')),
          favoritesRepositoryProvider.overrideWithValue(FakeFavoritesRepository()),
        ],
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(requests, [1, 2]);
      expect(_focusedAnimeId(), 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      final container = ProviderScope.containerOf(tester.element(find.byType(CatalogScreen)));
      changed = true;
      if (replaceAccount) {
        container.invalidate(authAccessProvider);
      } else {
        container.invalidate(catalogRepositoryProvider);
      }
      await tester.pumpAndSettle();
      expect(requests, [1, 2, 1]);
      expect(find.byKey(const ValueKey(3)), findsOneWidget);
      expect(_focusedAnimeId(), 1);

      pageTwo.complete(Result.success(AnimePage(items: [stale], page: 2, hasNext: true)));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey(2)), findsNothing);
      expect(find.byKey(const ValueKey(3)), findsOneWidget);
      expect(requests, [1, 2, 1]);
      expect(_focusedAnimeId(), 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('pending Right transfers to first appended card only while focus remains', (tester) async {
    final pageTwo = Completer<Result<AnimePage, Failure>>();
    const first = AnimeSummary(id: 1, slug: '1-first', title: 'First');
    const next = AnimeSummary(id: 2, slug: '2-next', title: 'Next');
    await pumpTvApp(
      tester,
      CatalogScreen(onAnimeTap: (_) => fail('Unexpected activation')),
      wrapInScaffold: false,
      overrides: [
        catalogRepositoryProvider.overrideWithValue(
          FakeCatalogScreenRepository(
            load: (page) => page == 1
                ? Future.value(Result.success(AnimePage(items: [first], page: 1, hasNext: true)))
                : pageTwo.future,
          ),
        ),
      ],
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(_focusedAnimeId(), 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    pageTwo.complete(Result.success(AnimePage(items: [next], page: 2, hasNext: false)));
    await tester.pumpAndSettle();
    expect(_focusedAnimeId(), 2);
    expect(tester.takeException(), isNull);
  });

  for (final reducedMotion in [false, true]) {
    testWidgets('poster scale uses directional motion independently of scroll (reduced=$reducedMotion)', (
      tester,
    ) async {
      await pumpTvApp(
        tester,
        CatalogScreen(onAnimeTap: (_) => fail('Unexpected title activation')),
        wrapInScaffold: false,
        disableAnimations: reducedMotion,
        overrides: [catalogRepositoryProvider.overrideWithValue(const FakeCatalogScreenRepository())],
      );
      await tester.pumpAndSettle();

      Finder poster(int id) => find.byKey(ValueKey(id));
      Finder scale(int id) => find.descendant(of: poster(id), matching: find.byType(AnimatedScale)).first;
      double paintedScale(int id) => tester
          .widget<ScaleTransition>(find.descendant(of: scale(id), matching: find.byType(ScaleTransition)).first)
          .scale
          .value;

      const enter = Cubic(0.215, 0.61, 0.355, 1);
      const exit = Cubic(0.55, 0.055, 0.675, 0.19);
      const scrollTime = Duration(milliseconds: 64);
      final anchor = tester.getTopLeft(poster(1)).dx;
      expect(paintedScale(1), 1.08);
      expect(paintedScale(2), 0.94);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(_focusedAnimeId(), 2);
      final deselected = tester.widget<AnimatedScale>(scale(1));
      final selected = tester.widget<AnimatedScale>(scale(2));
      expect(deselected.scale, 0.94);
      expect(selected.scale, 1.08);
      expect(deselected.curve, exit);
      expect(selected.curve, enter);
      expect(deselected.duration, reducedMotion ? Duration.zero : const Duration(milliseconds: 180));
      expect(selected.duration, reducedMotion ? Duration.zero : const Duration(milliseconds: 280));
      if (reducedMotion) {
        expect(paintedScale(1), 0.94);
        expect(paintedScale(2), 1.08);
      } else {
        expect(tester.getTopLeft(poster(2)).dx, greaterThan(anchor));
        await tester.pump(scrollTime);
        expect(paintedScale(1), closeTo(1.08 - 0.14 * exit.transform(64 / 180), 0.001));
        expect(paintedScale(2), closeTo(0.94 + 0.14 * enter.transform(64 / 280), 0.001));
      }
      expect(tester.getTopLeft(poster(2)).dx, closeTo(anchor, 1));
      await tester.pumpAndSettle();
      expect(paintedScale(1), 0.94);
      expect(paintedScale(2), 1.08);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Watch and Favorite share a 48dp row at normal text scale', (tester) async {
    await pumpTvApp(
      tester,
      CatalogScreen(onAnimeTap: (_) => fail('Unexpected title activation')),
      textScale: 1,
      wrapInScaffold: false,
      overrides: [
        authAccessProvider.overrideWithValue(const AuthenticatedAccess('test')),
        favoritesAccountProvider.overrideWithValue('test'),
        favoritesRepositoryProvider.overrideWithValue(FakeFavoritesRepository()),
        catalogRepositoryProvider.overrideWithValue(const FakeCatalogScreenRepository()),
      ],
    );
    await tester.pumpAndSettle();
    final watch = tester.getRect(find.widgetWithText(AppButton, 'Смотреть'));
    final favorite = tester.getRect(find.byKey(const ValueKey('favorite-button-1')));
    expect(watch.height, 48);
    expect(favorite.height, 48);
    expect(favorite.top, watch.top);
    expect(favorite.left, greaterThan(watch.right));
    expect(tester.takeException(), isNull);
  });

  testWidgets('rapid rail changes retarget and Watch opens the current item during dwell', (tester) async {
    final items = List.generate(6, (i) => AnimeSummary(id: i + 1, slug: '${i + 1}-test', title: 'Title ${i + 1}'));
    int? opened;
    await pumpTvApp(
      tester,
      CatalogScreen(onAnimeTap: (anime) => opened = anime.id),
      wrapInScaffold: false,
      overrides: [
        catalogRepositoryProvider.overrideWithValue(
          FakeCatalogScreenRepository(
            load: (page) async => Result.success(AnimePage(items: items, page: 1, hasNext: false)),
          ),
        ),
      ],
    );
    await tester.pumpAndSettle();
    final firstX = tester.getTopLeft(find.byKey(const ValueKey(1))).dx;
    final scroll = _posterPosition(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(_focusedAnimeId(), 2);
    await tester.pump(const Duration(milliseconds: 20));
    expect(scroll.pixels, inExclusiveRange(0, 128));
    final interruptedOffset = scroll.pixels;
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(_focusedAnimeId(), 3);
    expect(scroll.pixels, closeTo(interruptedOffset, 0.1));
    for (var id = 4; id <= 6; id++) {
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump(const Duration(milliseconds: 10));
      expect(_focusedAnimeId(), id);
    }
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(milliseconds: 64));
    expect(_focusedAnimeId(), 6);
    expect(tester.getTopLeft(find.byKey(const ValueKey(6))).dx, closeTo(firstX, 1));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
    expect(_focusedAnimeId(), 5);
    final leftOffset = scroll.pixels;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(_focusedAnimeId(), 6);
    expect(scroll.pixels, closeTo(leftOffset, 0.1));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump(const Duration(milliseconds: 10));
    expect(_focusedAnimeId(), 5);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    expect(opened, 5);
    expect(tester.takeException(), isNull);
  });

  for (final fadeIn in [false, true]) {
    testWidgets('Watch opens the focused title during fade ${fadeIn ? 'in' : 'out'}', (tester) async {
      final opened = <int>[];
      await pumpTvApp(
        tester,
        CatalogScreen(onAnimeTap: (anime) => opened.add(anime.id)),
        wrapInScaffold: false,
        overrides: [catalogRepositoryProvider.overrideWithValue(const FakeCatalogScreenRepository())],
      );
      await tester.pumpAndSettle();
      final rail = tester.getRect(_posters);
      final copy = find.byType(CatalogInspectorCopy);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      if (fadeIn) {
        await tester.pump(const Duration(milliseconds: 111));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
      } else {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(tester.widget<CatalogInspectorCopy>(copy).opacity.value, inExclusiveRange(0, 1));
      expect(tester.widget<CatalogInspectorCopy>(copy).anime.id, fadeIn ? 2 : 1);
      if (fadeIn) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
        expect(_focusedAnimeId(), 3);
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(focusedControlLabel(tester), 'Смотреть');
      final expectedId = fadeIn ? 3 : 2;
      expect(tester.widget<CatalogInspectorCopy>(copy).anime.id, expectedId);
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(opened, [expectedId]);
      expect(tester.getRect(_posters), rail);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('960×540 at 200% reveals Watch, Favorite and genre while the poster rail stays fixed', (tester) async {
    const genre = CatalogFilter(label: 'Фантастические приключения', path: '/anime/adventure/');
    final item = AnimeSummary.withGenreFilters(
      id: 1,
      slug: '1-rich',
      title: 'Очень длинное название истории о друзьях и необыкновенных приключениях',
      rating: 8.7,
      isFavorite: false,
      seriesInfo: 'Телевизионный сериал, двадцать четыре серии по двадцать четыре минуты',
      voiceover: 'Многоголосая русская озвучка нескольких студий и субтитры',
      publicationDate: 'Вчера, 23:59',
      genreText: genre.label,
      genreFilters: [genre],
      description: 'Друзья отправились в путешествие. ' * 20,
      updateMessage: 'Добавлена новая заключительная серия с русской озвучкой',
    );
    final opened = <int>[];
    final favorites = FakeFavoritesRepository();
    final filters = <CatalogFilter>[];
    await pumpTvApp(
      tester,
      CatalogScreen(onAnimeTap: (anime) => opened.add(anime.id), onFilterSelected: filters.add),
      textScale: 2,
      wrapInScaffold: false,
      overrides: [
        authAccessProvider.overrideWithValue(const AuthenticatedAccess('test')),
        favoritesAccountProvider.overrideWithValue('test'),
        favoritesRepositoryProvider.overrideWithValue(favorites),
        catalogRepositoryProvider.overrideWithValue(
          FakeCatalogScreenRepository(
            load: (_) async => Result.success(AnimePage(items: [item], page: 1, hasNext: false)),
          ),
        ),
      ],
    );
    await tester.pumpAndSettle();
    final rail = tester.getRect(_posters);
    final upper = find.descendant(of: find.byType(CatalogInspectorCopy), matching: find.byType(SingleChildScrollView));
    final scrollable = find.descendant(of: upper, matching: find.byType(Scrollable));
    final scroll = tester.state<ScrollableState>(scrollable).position;
    final watch = find.widgetWithText(AppButton, 'Смотреть');
    final favorite = find.byKey(const ValueKey('favorite-button-1'));
    final genreButton = find.byKey(ValueKey(genre.path));
    expect(scroll.maxScrollExtent, greaterThan(0));
    expect(MediaQuery.textScalerOf(tester.element(watch)).scale(16), 32);
    expect(_focusedAnimeId(), 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(focusedControlLabel(tester), 'Смотреть');
    expect(scroll.pixels, greaterThan(0));
    expect(tester.getRect(watch).bottom, lessThanOrEqualTo(tester.getRect(upper).bottom));
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    expect(opened, [1]);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus, same(tester.widget<AppButton>(favorite).focusNode));
    expect(tester.getRect(favorite).bottom, lessThanOrEqualTo(tester.getRect(upper).bottom));
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(favorites.writes, [true]);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(focusedControlLabel(tester), genre.label);
    expect(tester.getRect(genreButton).top, greaterThanOrEqualTo(tester.getRect(upper).top));
    expect(tester.getRect(genreButton).bottom, lessThanOrEqualTo(tester.getRect(upper).bottom));
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    expect(filters, [genre]);
    expect(tester.getRect(_posters), rail);
    expect(rail.bottom, compactTvSize.height);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a thousand catalog entries stay virtualized and the last poster remains operable', (tester) async {
    final items = List.generate(
      1000,
      (index) =>
          AnimeSummary(id: index + 1, slug: '${index + 1}-anime', title: 'Аниме ${index + 1}・🎬', posterUri: Uri()),
    );
    final requests = <int>[];
    int? opened;
    final repository = FakeCatalogScreenRepository(
      load: (page) async {
        requests.add(page);

        return Result.success(AnimePage(items: items, page: 1, hasNext: false));
      },
    );
    await pumpTvApp(
      tester,
      CatalogScreen(onAnimeTap: (anime) => opened = anime.id),
      size: wideTvSize,
      wrapInScaffold: false,
      overrides: [
        authAccessProvider.overrideWithValue(const AuthenticatedAccess('test')),
        favoritesAccountProvider.overrideWithValue('test'),
        catalogRepositoryProvider.overrideWithValue(repository),
      ],
    );
    await tester.pumpAndSettle();
    expect(find.byType(AnimeCard).evaluate().length, lessThan(50));
    final scroll = _posterPosition(tester);
    final lastOffset = scroll.maxScrollExtent;
    scroll.jumpTo(lastOffset);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey(1000)));
    await tester.pumpAndSettle();
    expect(opened, 1000);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    expect(opened, 999);
    expect(requests, [1]);
    expect(tester.takeException(), isNull);
  });
  testWidgets('menu expands from the first poster and returns to the same poster', (tester) async {
    await pumpTvApp(
      tester,
      HomeScreen(
        onAnimeTap: (_) => fail('Unexpected activation'),
        onSignOut: () => fail('Unexpected logout'),
        onOpenLogs: () => fail('Unexpected logs'),
      ),
      wrapInScaffold: false,
      overrides: [
        authAccessProvider.overrideWithValue(const AuthenticatedAccess('test')),
        favoritesAccountProvider.overrideWithValue('test'),
        catalogRepositoryProvider.overrideWithValue(const FakeCatalogScreenRepository()),
      ],
    );
    await tester.pumpAndSettle();
    final rail = find.byKey(const ValueKey('catalog-navigation-rail'));
    expect(tester.getSize(rail).width, 88);
    final card = FocusManager.instance.primaryFocus;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.getSize(rail).width, inExclusiveRange(88, 264));
    await tester.pumpAndSettle();
    expect(tester.getSize(rail).width, 264);
    final labels = <String?>[focusedControlLabel(tester)];
    for (var i = 0; i < 5; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      labels.add(focusedControlLabel(tester));
    }
    expect(labels, ['Главная', 'Поиск', 'Избранное', 'Жанры', 'Выйти из аккаунта', 'Открыть логи']);
    expect(find.byKey(const ValueKey('catalog-refresh')), findsNothing);
    expect(focusedControlLabel(tester), 'Открыть логи');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus, same(card));
    // Check the final collapsed width after the return transition.
    expect(tester.getSize(rail).width, 88);
    expect(tester.takeException(), isNull);
  });

  testWidgets('release rail skips logs and root Back keeps the catalog route active', (tester) async {
    var rootBacks = 0;
    await pumpTvApp(
      tester,
      HomeScreen(
        onAnimeTap: (_) => fail('Unexpected activation'),
        onSignOut: () => fail('Unexpected logout'),
        onRootBack: () => rootBacks++,
      ),
      wrapInScaffold: false,
      overrides: [
        authAccessProvider.overrideWithValue(const AuthenticatedAccess('test')),
        favoritesAccountProvider.overrideWithValue('test'),
        catalogRepositoryProvider.overrideWithValue(const FakeCatalogScreenRepository()),
      ],
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    for (var i = 0; i < 4; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
    }
    expect(focusedControlLabel(tester), 'Выйти из аккаунта');
    expect(find.byKey(const ValueKey('catalog-logs')), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(rootBacks, 1);
    expect(find.byType(CatalogScreen), findsOneWidget);
  });

  testWidgets('empty favorites can focus their content action and return home', (tester) async {
    await pumpTvApp(
      tester,
      HomeScreen(onAnimeTap: (_) => fail('Unexpected activation')),
      wrapInScaffold: false,
      overrides: [
        authAccessProvider.overrideWithValue(const AuthenticatedAccess('test')),
        favoritesAccountProvider.overrideWithValue('test'),
        catalogRepositoryProvider.overrideWithValue(const FakeCatalogScreenRepository()),
        favoritesRepositoryProvider.overrideWithValue(FakeFavoritesRepository()),
      ],
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('catalog-tab-true')));
    await tester.pumpAndSettle();
    expect(find.text('Избранное пусто'), findsOneWidget);
    // Activation already moved into the first content action.
    final homeAction = tester.widget<AppButton>(find.widgetWithText(AppButton, 'Перейти на главную'));
    expect(FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<AppButton>(), same(homeAction));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(find.byType(AnimeCard), findsWidgets);
  });

  testWidgets('long OK slides actions from the right and Left closes it restoring the card', (tester) async {
    final favorites = FakeFavoritesRepository();
    await pumpTvApp(
      tester,
      HomeScreen(onAnimeTap: (_) => fail('Long OK must not open details')),
      wrapInScaffold: false,
      overrides: [
        authAccessProvider.overrideWithValue(const AuthenticatedAccess('test')),
        favoritesAccountProvider.overrideWithValue('test'),
        catalogRepositoryProvider.overrideWithValue(const FakeCatalogScreenRepository()),
        favoritesRepositoryProvider.overrideWithValue(favorites),
      ],
    );
    await tester.pumpAndSettle();
    final card = FocusManager.instance.primaryFocus;
    await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.select);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final sheet = find.byType(TvSideSheet);
    final surface = find.descendant(of: sheet, matching: find.byType(Material)).first;
    expect(tester.getTopLeft(surface).dx, greaterThan(520));
    await tester.pumpAndSettle();
    expect(tester.getRect(surface).right, 960);
    expect(tester.getRect(surface).left, 520);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.select);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.select);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(favorites.writes, isEmpty);
    for (final key in [LogicalKeyboardKey.arrowRight, LogicalKeyboardKey.arrowDown]) {
      await tester.sendKeyEvent(key);
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<TvSideSheet>(), isNotNull);
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus, same(card));
    expect(favorites.writes, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('removing the last favorite from its sheet returns focus to navigation', (tester) async {
    final favorites = FakeFavoritesRepository()..ids.add(1);
    await pumpTvApp(
      tester,
      HomeScreen(onAnimeTap: (_) => fail('Unexpected activation')),
      wrapInScaffold: false,
      overrides: [
        authAccessProvider.overrideWithValue(const AuthenticatedAccess('test')),
        favoritesAccountProvider.overrideWithValue('test'),
        catalogRepositoryProvider.overrideWithValue(const FakeCatalogScreenRepository()),
        favoritesRepositoryProvider.overrideWithValue(favorites),
      ],
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('catalog-tab-true')));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.select);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(find.text('Избранное пусто'), findsOneWidget);
    expect(focusedControlLabel(tester), 'Избранное');
    expect(find.byType(FavoriteActionsSheet), findsNothing);
    expect(favorites.ids, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion expands the rail immediately without moving the grid', (tester) async {
    await pumpTvApp(
      tester,
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: HomeScreen(onAnimeTap: (_) => fail('Unexpected activation')),
      ),
      wrapInScaffold: false,
      overrides: [
        authAccessProvider.overrideWithValue(const AuthenticatedAccess('test')),
        favoritesAccountProvider.overrideWithValue('test'),
        catalogRepositoryProvider.overrideWithValue(const FakeCatalogScreenRepository()),
      ],
    );
    await tester.pumpAndSettle();
    final card = find.byType(AnimeCard).first;
    final before = tester.getRect(card);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    await tester.pump();
    expect(tester.getSize(find.byKey(const ValueKey('catalog-navigation-rail'))).width, 264);
    expect(tester.getRect(card), before);
    expect(tester.takeException(), isNull);
  });

  testWidgets('catalog errors focus retry and allow a round trip through the rail', (tester) async {
    var requests = 0;
    await pumpTvApp(
      tester,
      HomeScreen(onAnimeTap: (_) => fail('Unexpected activation')),
      wrapInScaffold: false,
      overrides: [
        authAccessProvider.overrideWithValue(const AuthenticatedAccess('test')),
        favoritesAccountProvider.overrideWithValue('test'),
        catalogRepositoryProvider.overrideWithValue(
          FakeCatalogScreenRepository(
            load: (_) async {
              requests++;

              return requests == 1
                  ? const Result.failure(UnknownFailure())
                  : const FakeCatalogScreenRepository().getPage(1);
            },
          ),
        ),
      ],
    );
    await tester.pumpAndSettle();
    final retry = FocusManager.instance.primaryFocus;
    expect(retry?.context?.findAncestorWidgetOfExactType<AppButton>(), isNotNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(focusedControlLabel(tester), 'Главная');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus, same(retry));
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(requests, 2);
    expect(find.byType(AnimeCard), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('TV posters match their loading rail geometry at 960×540', (tester) async {
    await pumpTvApp(tester, const CatalogSkeleton(), disableAnimations: true, wrapInScaffold: false);
    final loadingRail = find.byType(ListView);
    final loadingPoster = find.descendant(of: loadingRail, matching: find.byType(TvSkeletonBox)).first;
    final loadingRect = tester.getRect(loadingPoster);
    final loadingRailRect = tester.getRect(loadingRail);
    expect(loadingRect.size, const Size(104, 156));
    expect(tester.widget<ListView>(loadingRail).scrollDirection, Axis.horizontal);
    await tester.pumpWidget(const SizedBox());
    await pumpTvApp(
      tester,
      CatalogScreen(onAnimeTap: (_) => fail('Unexpected anime activation')),
      disableAnimations: true,
      wrapInScaffold: false,
      overrides: [catalogRepositoryProvider.overrideWithValue(const FakeCatalogScreenRepository())],
    );
    await tester.pumpAndSettle();
    expect(tester.widget<ListView>(_posters).scrollDirection, Axis.horizontal);
    expect(tester.getRect(_posters).bottom, compactTvSize.height);
    expect(tester.getRect(_posters), loadingRailRect);
    expect(tester.getSize(find.byType(AnimeCard).first), loadingRect.size);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pagination failure waits for manual retry while focus and scrolling continue', (tester) async {
    final requests = <int>[];
    final pumpAndSettle = tester.pumpAndSettle;
    final initial = (await const FakeCatalogScreenRepository().getPage(1))
        .when(failure: (failure) => throw failure, success: (page) => page);
    final repository = FakeCatalogScreenRepository(
      load: (page) async {
        requests.add(page);

        return page == 1
            ? Result.success(AnimePage(items: initial.items, page: 1, hasNext: true))
            : const Result.failure(UnknownFailure());
      },
    );
    await pumpTvApp(
      tester,
      CatalogScreen(onAnimeTap: (anime) => expect(anime.id, isPositive)),
      wrapInScaffold: false,
      overrides: [
        authAccessProvider.overrideWithValue(const AuthenticatedAccess('test')),
        favoritesAccountProvider.overrideWithValue('test'),
        catalogRepositoryProvider.overrideWithValue(repository),
      ],
    );
    await pumpAndSettle();
    final scroll = _posterPosition(tester);
    for (var i = 1; i < initial.items.length; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await pumpAndSettle();
    }
    expect(requests, [1, 2]);
    expect(_focusedAnimeId(), initial.items.last.id);
    final endOffset = scroll.pixels;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await pumpAndSettle();
    expect(_focusedAnimeId(), initial.items[initial.items.length - 2].id);
    expect(scroll.pixels, lessThan(endOffset));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await pumpAndSettle();
    expect(scroll.pixels, endOffset);
    expect(requests, [1, 2]);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await pumpAndSettle();
    expect(find.byType(CatalogTail), findsOneWidget);
    expect(FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<CatalogTail>(), isNotNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await pumpAndSettle();
    expect(requests, [1, 2, 2]);
  });

  testWidgets('moves focus along a 1280×720 TV rail and activates with OK', (tester) async {
    int? openedAnimeId;
    await pumpTvApp(
      tester,
      CatalogScreen(onAnimeTap: (anime) => openedAnimeId = anime.id),
      size: wideTvSize,
      wrapInScaffold: false,
      overrides: [
        authAccessProvider.overrideWithValue(const AuthenticatedAccess('test')),
        favoritesAccountProvider.overrideWithValue('test'),
        catalogRepositoryProvider.overrideWithValue(const FakeCatalogScreenRepository()),
      ],
    );
    final pumpAndSettle = tester.pumpAndSettle;
    final sendKeyEvent = tester.sendKeyEvent;
    await pumpAndSettle();
    expect(find.byType(AnimeCard), findsAtLeastNWidgets(5));
    expect(tester.takeException(), isNull);
    for (var id = 2; id <= 10; id++) {
      await sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump(AppMotion.fast);
      expect(_focusedAnimeId(), id);
    }
    await sendKeyEvent(LogicalKeyboardKey.select);
    expect(openedAnimeId, 10);
  });

  testWidgets('returning to the first poster reveals it within the fixed bottom rail', (tester) async {
    await pumpTvApp(
      tester,
      CatalogScreen(
        onAnimeTap: (_) => fail('Unexpected anime activation'),
        onTabSelected: (_) => fail('Unexpected tab activation'),
      ),
      wrapInScaffold: false,
      overrides: [catalogRepositoryProvider.overrideWithValue(const FakeCatalogScreenRepository())],
    );
    await tester.pumpAndSettle();
    final first = find.byKey(const ValueKey(1));
    final original = tester.getRect(first);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(_focusedAnimeId(), 2);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(_focusedAnimeId(), 1);
    expect(tester.getRect(first), original);
    expect(tester.getRect(_posters).contains(original.topLeft), isTrue);
    expect(tester.getRect(_posters).contains(original.bottomRight), isTrue);
    expect(tester.widget<ListView>(_posters).clipBehavior, Clip.hardEdge);
  });

  testWidgets('empty favorites activation enters content and root Back restores its menu target', (tester) async {
    await pumpTvApp(
      tester,
      HomeScreen(onAnimeTap: (anime) => expect(anime.id, 1)),
      size: wideTvSize,
      wrapInScaffold: false,
      overrides: [
        authAccessProvider.overrideWithValue(const AuthenticatedAccess('test')),
        favoritesAccountProvider.overrideWithValue('test'),
        catalogRepositoryProvider.overrideWithValue(const FakeCatalogScreenRepository()),
        favoritesRepositoryProvider.overrideWithValue(FakeFavoritesRepository()),
      ],
    );
    final settle = tester.pumpAndSettle;
    final key = tester.sendKeyEvent;
    await settle();
    await key(LogicalKeyboardKey.arrowLeft);
    await settle();
    for (var step = 0; step < 2; step++) {
      await key(LogicalKeyboardKey.arrowDown);
      await tester.pump();
    }
    await key(LogicalKeyboardKey.select);
    await settle();
    expect(find.text('Избранное пусто'), findsOneWidget);
    final homeAction = tester.widget<AppButton>(find.widgetWithText(AppButton, 'Перейти на главную'));
    expect(FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<AppButton>(), same(homeAction));
    await tester.binding.handlePopRoute();
    await settle();
    expect(focusedControlLabel(tester), 'Избранное');
    for (var step = 0; step < 2; step++) {
      await key(LogicalKeyboardKey.arrowUp);
      await tester.pump();
    }
    await key(LogicalKeyboardKey.select);
    await settle();
    expect(find.byType(AnimeCard), findsWidgets);
    expect(FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<AnimeCard>(), isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the catalog heading and first row visible at 960x540', (tester) async {
    await pumpTvApp(
      tester,
      CatalogScreen(onAnimeTap: (anime) => expect(anime.id, isPositive)),
      wrapInScaffold: false,
      overrides: [
        authAccessProvider.overrideWithValue(const AuthenticatedAccess('test')),
        favoritesAccountProvider.overrideWithValue('test'),
        catalogRepositoryProvider.overrideWithValue(const FakeCatalogScreenRepository()),
      ],
    );
    await tester.pumpAndSettle();
    expect(find.text('Каталог'), findsNothing);
    expect(find.textContaining('загружено'), findsNothing);
    expect(find.textContaining('OK —'), findsNothing);
    expect(find.byType(AnimeCard), findsAtLeastNWidgets(4));
    expect(tester.takeException(), isNull);
  });
}
