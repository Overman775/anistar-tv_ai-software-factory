// Each assertion observes focus or UI after a separate remote event.

import 'dart:async';

import 'package:anistar_tv/app/app_router.dart';
import 'package:anistar_tv/app/app_routes.dart';
import 'package:anistar_tv/packages/features/anime/anime_providers.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_details.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_episode.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_screen_data.dart';
import 'package:anistar_tv/packages/features/anime/presentation/screens/anime_screen.dart';
import 'package:anistar_tv/packages/features/auth/auth_providers.dart';
import 'package:anistar_tv/packages/features/catalog/catalog_providers.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/anime_page.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/anime_summary.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/catalog_filter.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/screens/catalog_screen.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/screens/genres_screen.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/widgets/anime_card.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/widgets/catalog_inspector_copy.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/widgets/catalog_navigation_rail.dart';
import 'package:anistar_tv/packages/features/home/presentation/home_destination.dart';
import 'package:anistar_tv/packages/features/home/presentation/screens/tv_route_shell.dart';
import 'package:app_logging/app_logging.dart';
import 'package:core/data.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../mocks/features/anime/fake_anime_screen_repository.dart';
import '../mocks/features/catalog/fake_catalog_browse_repository.dart';
import '../mocks/features/catalog/fake_catalog_screen_repository.dart';
import '../support/test_app.dart';

void main() {
  for (final fromDetail in [true, false]) {
    testWidgets('filter from ${fromDetail ? 'detail' : 'left menu'} restores source and result focus after Back', (
      tester,
    ) async {
      final router = AppRouter(AppLogger.logger);
      addTearDown(router.dispose);
      final repository = FakeCatalogBrowseRepository(
        load: (_, page) => const FakeCatalogScreenRepository().getPage(page),
      );
      await pumpTvApp(
        tester,
        MaterialApp.router(routerConfig: router.router, theme: AppTheme.darkTheme),
        wrapInScaffold: false,
        overrides: [
          authAccessProvider.overrideWithValue(const AuthenticatedAccess('test')),
          catalogRepositoryProvider.overrideWithValue(const FakeCatalogScreenRepository()),
          catalogBrowseRepositoryProvider.overrideWithValue(repository),
          animeRepositoryProvider.overrideWithValue(
            FakeAnimeScreenRepository(
              load: (id, slug) async => Result.success(
                AnimeScreenData(
                  details: AnimeDetails(
                    id: id,
                    slug: slug,
                    title: 'Тест',
                    genres: const ['Комедия'],
                    isOngoing: true,
                    filters: const [ongoingFilter, comedyFilter],
                  ),
                  episodes: const [AnimeEpisode(number: 1, title: 'Серия 1')],
                ),
              ),
            ),
          ),
        ],
      );
      await tester.pumpAndSettle();
      if (fromDetail) {
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
        expect(focusedControlLabel(tester), 'Подробнее');
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
      } else {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(focusedControlLabel(tester), 'Жанры');
        expect(find.byType(GenresScreen), findsNothing);
        final menu = tester.element(find.byType(CatalogNavigationRail));
        final menuFocus = FocusManager.instance.primaryFocus;
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pumpAndSettle();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(tester.element(find.byType(CatalogNavigationRail)), same(menu));
        expect(FocusManager.instance.primaryFocus, same(menuFocus));
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(CatalogScreen), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pumpAndSettle();
        final homeFocus = tester.widget<TextButton>(find.byKey(const ValueKey('catalog-tab-false'))).focusNode;
        expect(FocusManager.instance.primaryFocus, same(homeFocus));
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        // Re-entering the section must restore its original public menu node.
        expect(FocusManager.instance.primaryFocus, same(menuFocus));
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pumpAndSettle();
      }
      final sourceFocus = FocusManager.instance.primaryFocus;
      expect(sourceFocus?.debugLabel, 'Комедия');
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(repository.requests, [('/anime/comedy/', 1)]);
      expect(tester.widget<CatalogScreen>(find.byType(CatalogScreen)).filter?.path, comedyFilter.path);
      final sortText = tester.element(find.text('Фильтр'));
      final inheritedStyle = DefaultTextStyle.of(sortText).style;
      expect(inheritedStyle.fontFamily, TvTypography.fontFamily);
      expect(inheritedStyle.decoration ?? TextDecoration.none, TextDecoration.none);
      final cardFocus = FocusManager.instance.primaryFocus;
      expect(
        cardFocus?.context?.findAncestorWidgetOfExactType<AnimeCard>(),
        isNotNull,
        reason: 'filter starts on first card; focused=${cardFocus?.debugLabel}',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(find.byType(AnimeScreen), findsOneWidget);
      router.router.pop();
      await tester.pumpAndSettle();
      expect(find.byType(AnimeCard), findsWidgets);
      expect(FocusManager.instance.primaryFocus, same(cardFocus));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus, same(sourceFocus));
      expect(repository.requests, hasLength(1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('mobile author route shows one full heading above its compact sort control', (tester) async {
    const title = 'Очень длинное имя автора с полным названием для проверки переноса заголовка';
    final router = AppRouter(AppLogger.logger);
    addTearDown(router.dispose);
    await pumpMobileApp(
      tester,
      MaterialApp.router(routerConfig: router.router, theme: AppTheme.darkTheme),
      size: const Size(320, 740),
      textScale: 2,
      wrapInScaffold: false,
      overrides: [
        authAccessProvider.overrideWithValue(const AuthenticatedAccess('test')),
        catalogRepositoryProvider.overrideWithValue(const FakeCatalogScreenRepository()),
        catalogBrowseRepositoryProvider.overrideWithValue(
          FakeCatalogBrowseRepository(load: (_, page) => const FakeCatalogScreenRepository().getPage(page)),
        ),
      ],
    );
    await tester.pumpAndSettle();
    final home = tester.element(find.byType(CatalogScreen));
    unawaited(
      const FilterRoute(
        path: '/filter/author/%f1%e8+%fd/',
        title: title,
        destination: HomeDestination.home,
      ).push<void>(home),
    );
    await tester.pumpAndSettle();
    final heading = find.text(title);
    final sort = find.byKey(const ValueKey('catalog-sort'));
    expect(heading, findsOneWidget);
    expect(tester.widget<Text>(heading).maxLines, isNull);
    expect(tester.getRect(heading).bottom, lessThan(tester.getRect(sort).top));
    expect(tester.getSize(sort).height, greaterThanOrEqualTo(36));
    expect(find.text('Фильтр'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text(title), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wrapped genre navigation skips plain text and chooses nearest previous row', (tester) async {
    const genres = [
      CatalogFilter(label: 'Длинные приключения', path: '/anime/adventure/'),
      CatalogFilter(label: 'Необычная комедия', path: '/anime/comedy/'),
      CatalogFilter(label: 'Историческая драма', path: '/anime/drama/'),
      CatalogFilter(label: 'Далёкая фантастика', path: '/anime/fantasy/'),
    ];
    final anime = AnimeSummary.withGenreFilters(
      id: 1,
      slug: '1-test',
      title: 'Тест',
      genreText: '${genres.map((item) => item.label).join(', ')}, Неподдерживаемый',
      genreFilters: genres,
    );
    await pumpTvApp(
      tester,
      CatalogScreen(onAnimeTap: (_) => fail('Unexpected anime'), onFilterSelected: (_) => fail('Unexpected filter')),
      size: const Size(640, 360),
      wrapInScaffold: false,
      overrides: [
        catalogRepositoryProvider.overrideWithValue(
          FakeCatalogScreenRepository(
            load: (page) async => Result.success(AnimePage(items: [anime], page: page, hasNext: false)),
          ),
        ),
      ],
    );
    await tester.pumpAndSettle();
    final rects = [for (final genre in genres) tester.getRect(find.byKey(ValueKey(genre.path)))];
    expect(rects.map((rect) => rect.top).toSet().length, greaterThan(1));
    expect(find.text('Неподдерживаемый'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(focusedControlLabel(tester), 'Смотреть');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(focusedControlLabel(tester), genres.last.label);
    final last = rects.last;
    final previousTop = rects
        .where((rect) => rect.top < last.top - 0.5)
        .map((rect) => rect.top)
        .reduce((a, b) => a > b ? a : b);
    final indices =
        [
          for (var i = 0; i < rects.length; i++)
            if ((rects[i].top - previousTop).abs() < 0.5) i,
        ]..sort(
          (a, b) => (rects[a].center.dx - last.center.dx).abs().compareTo((rects[b].center.dx - last.center.dx).abs()),
        );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(focusedControlLabel(tester), genres[indices.first].label);
    expect(tester.takeException(), isNull);
  });

  testWidgets('TV genre chip pushes the original filter and Back preserves the parent selection', (tester) async {
    const child = CatalogFilter(label: 'Фантастика и приключения', path: '/xfsearch/janrs/%f4%e0%ed+%f2/');
    final items = [
      const AnimeSummary(id: 1, slug: '1-first', title: 'Первый тайтл'),
      AnimeSummary.withGenreFilters(
        id: 2,
        slug: '2-second',
        title: 'Второй тайтл',
        genreText: '${comedyFilter.label}, ${child.label}',
        genreFilters: [comedyFilter, child],
      ),
    ];
    final repository = FakeCatalogBrowseRepository(
      load: (filter, page) => Future.value(
        Result.success(
          AnimePage(items: filter.path == comedyFilter.path ? items : [items.first], page: page, hasNext: false),
        ),
      ),
    );
    final router = AppRouter(AppLogger.logger);
    addTearDown(router.dispose);
    await pumpTvApp(
      tester,
      MaterialApp.router(routerConfig: router.router, theme: AppTheme.darkTheme),
      wrapInScaffold: false,
      overrides: [
        authAccessProvider.overrideWithValue(const AuthenticatedAccess('test')),
        catalogRepositoryProvider.overrideWithValue(const FakeCatalogScreenRepository()),
        catalogBrowseRepositoryProvider.overrideWithValue(repository),
      ],
    );
    await tester.pumpAndSettle();
    final home = tester.element(find.byType(CatalogScreen));
    unawaited(
      const FilterRoute(path: '/anime/comedy/', title: 'Комедия', destination: HomeDestination.home).push<void>(home),
    );
    await tester.pumpAndSettle();
    final parentScreen = tester.state(find.byType(CatalogScreen));
    final rail = find.byKey(const ValueKey('tv-catalog-poster-rail'));
    final copy = find.byType(CatalogInspectorCopy);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(tester.widget<CatalogInspectorCopy>(copy).anime.id, 2);
    final scrollable = find.descendant(of: rail, matching: find.byType(Scrollable));
    final parentScroll = tester.state<ScrollableState>(scrollable).position;
    final parentOffset = parentScroll.pixels;
    expect(parentOffset, greaterThan(0));
    final currentGenre = find.descendant(of: copy, matching: find.byKey(ValueKey(comedyFilter.path)));
    await tester.ensureVisible(currentGenre);
    await tester.tap(currentGenre);
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(CatalogScreen)), same(parentScreen));
    expect(repository.requests, [(comedyFilter.path, 1)]);
    expect(tester.state<ScrollableState>(scrollable).position.pixels, parentOffset);

    expect(focusedControlLabel(tester), comedyFilter.label);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    final sourceFocus = FocusManager.instance.primaryFocus;
    expect(focusedControlLabel(tester), child.label);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(repository.requests, [(comedyFilter.path, 1), (child.path, 1)]);
    final childFilter = tester.widget<CatalogScreen>(find.byType(CatalogScreen)).filter;
    expect(childFilter?.path, child.path);
    expect(childFilter?.label, child.label);
    expect(tester.widget<TvRouteShell>(find.byType(TvRouteShell)).destination, HomeDestination.home);
    expect(find.text(child.label), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(CatalogScreen)), same(parentScreen));
    expect(FocusManager.instance.primaryFocus, same(sourceFocus));
    expect(tester.widget<CatalogInspectorCopy>(copy).anime.id, 2);
    expect(tester.state<ScrollableState>(scrollable).position.pixels, parentOffset);
    expect(repository.requests, [(comedyFilter.path, 1), (child.path, 1)]);
    expect(tester.takeException(), isNull);

    final watch = tester.widget<AppButton>(find.widgetWithText(AppButton, 'Смотреть'));
    watch.focusNode?.requestFocus();
    await tester.pumpAndSettle();
    expect(focusedControlLabel(tester), 'Смотреть');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(focusedControlLabel(tester), child.label, reason: 'Up from Watch selects the last genre in source order');
    final genreFocus = FocusManager.instance.primaryFocus;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(focusedControlLabel(tester), 'Сортировка');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus, same(genreFocus));
    expect(repository.requests, [(comedyFilter.path, 1), (child.path, 1)]);
  });
}
