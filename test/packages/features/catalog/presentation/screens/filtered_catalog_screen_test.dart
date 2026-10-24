// Each assertion observes focus or UI after a separate remote event.

import 'dart:async';

import 'package:anistar_tv/packages/features/catalog/catalog_providers.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/anime_page.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/screens/catalog_screen.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/widgets/anime_card.dart';
import 'package:anistar_tv/packages/features/home/presentation/home_destination.dart';
import 'package:anistar_tv/packages/features/home/presentation/screens/tv_route_shell.dart';
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
      CatalogScreen(filter: comedyFilter, onAnimeTap: (_) => fail('Unexpected anime selection')),
      wrapInScaffold: false,
      overrides: [catalogBrowseRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pumpAndSettle();
    expect(find.text('Каталог недоступен'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(find.byType(AnimeCard), findsWidgets);
    expect(find.byKey(const ValueKey('catalog-refresh')), findsNothing);
    expect(repository.requests, List.filled(2, ('/anime/comedy/', 1)));
  });

  testWidgets('empty filter lets the route shell return to its parent after loading', (tester) async {
    final pending = Completer<Result<AnimePage, Failure>>();
    await pumpTvApp(
      tester,
      const SizedBox(key: ValueKey('catalog-parent')),
      wrapInScaffold: false,
      overrides: [
        catalogBrowseRepositoryProvider.overrideWithValue(FakeCatalogBrowseRepository(load: (_, _) => pending.future)),
      ],
    );
    await tester.pump();
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    unawaited(
      navigator.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => TvRouteShell(
            destination: HomeDestination.genres,
            onDestinationSelected: (_) => fail('Unexpected destination selection'),
            builder: (onOpenNavigation) => CatalogScreen(
              filter: comedyFilter,
              onOpenNavigation: onOpenNavigation,
              onAnimeTap: (_) => fail('Unexpected anime selection'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    pending.complete(Result.success(AnimePage(page: 1, hasNext: false, items: [])));
    await tester.pumpAndSettle();
    expect(find.text('Каталог пуст'), findsOneWidget);
    navigator.pop();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('catalog-parent')), findsOneWidget);
  });
}
