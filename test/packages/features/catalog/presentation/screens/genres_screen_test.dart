// Each assertion observes focus or UI after a separate remote event.

import 'dart:async';

import 'package:anistar_tv/packages/features/catalog/catalog_providers.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/catalog_filter.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/screens/genres_screen.dart';
import 'package:anistar_tv/packages/features/home/presentation/home_destination.dart';
import 'package:anistar_tv/packages/features/home/presentation/screens/tv_route_shell.dart';
import 'package:core/data.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../../../mocks/features/catalog/fake_catalog_browse_repository.dart';
import '../../../../../support/test_app.dart';

void main() {
  testWidgets('fifty long multilingual genres at 200% fit two lines and stay reachable', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final items = List.generate(
      50,
      (index) => CatalogFilter(label: 'Повседневность・日本語・العربية・🎬 $index', path: '/genre-$index/'),
    );
    CatalogFilter? selected;
    await pumpTvApp(
      tester,
      GenresScreen(onSelected: (item) => selected = item),
      size: const Size(390, 844),
      wrapInScaffold: false,
      overrides: [
        catalogBrowseRepositoryProvider.overrideWithValue(
          FakeCatalogBrowseRepository(genres: () async => Result.success(items)),
        ),
      ],
    );
    await tester.pumpAndSettle();
    final label = find.text(items.first.label);
    final tile = find.ancestor(of: label, matching: find.byType(TvFocusable));
    expect(tester.getSize(label).height, lessThanOrEqualTo(tester.getSize(tile).height));
    for (var i = 0; i < items.length; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
    }
    expect(find.text(items.last.label).hitTestable(), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    expect(selected, items.last);
    expect(tester.takeException(), isNull);
  });
  for (final size in [compactTvSize, wideTvSize, const Size(390, 844)]) {
    testWidgets('all genres are reachable by remote at $size and selection requires OK', (tester) async {
      final items = List.generate(25, (index) => CatalogFilter(label: 'Жанр $index', path: '/genre-$index/'));
      CatalogFilter? selected;
      await pumpTvApp(
        tester,
        GenresScreen(onSelected: (item) => selected = item),
        size: size,
        wrapInScaffold: false,
        overrides: [
          catalogBrowseRepositoryProvider.overrideWithValue(
            FakeCatalogBrowseRepository(genres: () async => Result.success(items)),
          ),
        ],
      );
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'Жанр 0');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      // Boundary navigation must leave focus on the same tile.
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'Жанр 0');
      for (var i = 0; i < 14; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
      }
      expect(selected, isNull);
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'Жанр 24');
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      expect(selected?.path, '/genre-24/');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('failed genre request focuses retry and OK recovers', (tester) async {
    var attempts = 0;
    await pumpTvApp(
      tester,
      GenresScreen(onSelected: (_) => fail('Unexpected selection')),
      wrapInScaffold: false,
      overrides: [
        catalogBrowseRepositoryProvider.overrideWithValue(
          FakeCatalogBrowseRepository(
            genres: () async {
              attempts++;

              return attempts == 1 ? const Result.failure(UnknownFailure()) : const Result.success([comedyFilter]);
            },
          ),
        ),
      ],
    );
    await tester.pumpAndSettle();
    expect(find.text('Жанры недоступны'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('Комедия'), findsOneWidget);
  });

  testWidgets('loading keeps the genres route shell mounted without waiting for HTTP', (tester) async {
    final pending = Completer<Result<List<CatalogFilter>, Failure>>();
    await pumpTvApp(
      tester,
      TvRouteShell(
        destination: HomeDestination.genres,
        onDestinationSelected: (_) => fail('Unexpected destination selection'),
        builder: (onOpenNavigation) =>
            GenresScreen(onOpenNavigation: onOpenNavigation, onSelected: (_) => fail('Unexpected selection')),
      ),
      wrapInScaffold: false,
      overrides: [
        catalogBrowseRepositoryProvider.overrideWithValue(FakeCatalogBrowseRepository(genres: () => pending.future)),
      ],
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byKey(const ValueKey('catalog-navigation-rail')), findsOneWidget);
  });
}
