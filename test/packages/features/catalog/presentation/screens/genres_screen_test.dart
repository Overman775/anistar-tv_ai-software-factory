// Each assertion observes focus or UI after a separate remote event.
// ignore_for_file: prefer-moving-to-variable

import 'dart:async';

import 'package:anistar_tv/packages/features/catalog/catalog_providers.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/catalog_filter.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/screens/genres_screen.dart';
import 'package:core/data.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../mocks/features/catalog/fake_catalog_browse_repository.dart';
import '../../../../../support/test_app.dart';

void main() {
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
      // ignore: avoid-duplicate-test-assertions
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
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'Комедия');
  });

  testWidgets('Back is available during loading without waiting for HTTP', (tester) async {
    final pending = Completer<Result<List<CatalogFilter>, Failure>>();
    await pumpTvApp(
      tester,
      GenresScreen(onSelected: (_) => fail('Unexpected selection')),
      wrapInScaffold: false,
      overrides: [
        catalogBrowseRepositoryProvider.overrideWithValue(FakeCatalogBrowseRepository(genres: () => pending.future)),
      ],
    );
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'Назад из жанров');
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
