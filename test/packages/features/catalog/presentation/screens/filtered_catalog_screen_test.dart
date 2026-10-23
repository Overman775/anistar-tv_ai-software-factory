// Each assertion observes focus or UI after a separate remote event.

import 'dart:async';

import 'package:anistar_tv/packages/features/catalog/catalog_providers.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/anime_page.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/screens/catalog_screen.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/widgets/anime_card.dart';
import 'package:core/data.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../mocks/features/catalog/fake_catalog_browse_repository.dart';
import '../../../../../mocks/features/catalog/fake_catalog_screen_repository.dart';
import '../../../../../support/test_app.dart';

void main() {
  testWidgets('filtered catalog retries the same page and retains its filter', (tester) async {
    var attempts = 0;
    final repository = FakeCatalogBrowseRepository(
      load: (_, page) {
        attempts++;

        return attempts == 1
            ? Future.value(const Result.failure(UnknownFailure()))
            : const FakeCatalogScreenRepository().getPage(page);
      },
    );
    await pumpTvApp(
      tester,
      CatalogScreen(
        filter: comedyFilter,
        onAnimeTap: (_) => fail('Unexpected anime selection'),
        onBack: () => fail('Unexpected Back'),
      ),
      wrapInScaffold: false,
      overrides: [catalogBrowseRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pumpAndSettle();
    expect(find.text('Каталог недоступен'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(find.byType(AnimeCard), findsWidgets);
    expect(find.byKey(const ValueKey('catalog-refresh')), findsNothing);
    expect(repository.requests, List.filled(2, ('/anime/comedy/', 1)));
  });

  testWidgets('empty filter and loading keep the back action reachable', (tester) async {
    final pending = Completer<Result<AnimePage, Failure>>();
    var backCount = 0;
    await pumpTvApp(
      tester,
      CatalogScreen(
        filter: comedyFilter,
        onAnimeTap: (_) => fail('Unexpected anime selection'),
        onBack: () => backCount++,
      ),
      wrapInScaffold: false,
      overrides: [
        catalogBrowseRepositoryProvider.overrideWithValue(FakeCatalogBrowseRepository(load: (_, _) => pending.future)),
      ],
    );
    await tester.pump();
    pending.complete(Result.success(AnimePage(page: 1, hasNext: false, items: [])));
    await tester.pumpAndSettle();
    expect(find.text('Каталог пуст'), findsOneWidget);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'Назад');
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    expect(backCount, 1);
  });
}
