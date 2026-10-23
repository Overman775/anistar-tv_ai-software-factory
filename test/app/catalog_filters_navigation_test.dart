// Each assertion observes focus or UI after a separate remote event.
// ignore_for_file: prefer-moving-to-variable

import 'package:anistar_tv/app/app_router.dart';
import 'package:anistar_tv/packages/features/anime/anime_providers.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_details.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_episode.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_screen_data.dart';
import 'package:anistar_tv/packages/features/anime/presentation/screens/anime_screen.dart';
import 'package:anistar_tv/packages/features/auth/auth_providers.dart';
import 'package:anistar_tv/packages/features/catalog/catalog_providers.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/screens/catalog_screen.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/screens/genres_screen.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/widgets/anime_card.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/widgets/catalog_navigation_rail.dart';
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
                    genres: const [],
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
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
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
        expect(tester.widget<CatalogScreen>(find.byType(CatalogScreen)).genresActive, isFalse);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pumpAndSettle();
        final homeFocus = tester.widget<TextButton>(find.byKey(const ValueKey('catalog-tab-false'))).focusNode;
        expect(FocusManager.instance.primaryFocus, same(homeFocus));
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        // Re-entering the section must restore its original public menu node.
        // ignore: avoid-duplicate-test-assertions
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
      final sortText = tester.element(find.text('По дате · Сначала новые'));
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
}
