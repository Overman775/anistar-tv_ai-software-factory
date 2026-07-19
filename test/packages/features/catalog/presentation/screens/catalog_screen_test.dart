import 'package:anistar_tv/app/app_providers.dart';
import 'package:anistar_tv/packages/core/domain/either.dart';
import 'package:anistar_tv/packages/core/domain/failure.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/anime_page.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/anime_summary.dart';
import 'package:anistar_tv/packages/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/screens/catalog_screen.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/widgets/anime_card.dart';
import 'package:app_logger/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui_kit/ui_kit.dart';

void main() {
  testWidgets('moves focus across a 1280x720 TV grid and activates with OK', (tester) async {
    final view = tester.view;
    final pumpAndSettle = tester.pumpAndSettle;
    final sendKeyEvent = tester.sendKeyEvent;
    view
      ..physicalSize = const Size(1280, 720)
      ..devicePixelRatio = 1;
    addTearDown(view.reset);
    int? openedAnimeId;

    await _pumpCatalog(tester, (id) => openedAnimeId = id);
    await pumpAndSettle();

    expect(find.byType(AnimeCard), findsAtLeastNWidgets(5));
    expect(tester.takeException(), isNull);
    await sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(AppMotion.fast);
    await sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await pumpAndSettle();
    await sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await pumpAndSettle();
    await sendKeyEvent(LogicalKeyboardKey.select);

    expect(openedAnimeId, 12);
  });

  testWidgets('keeps the catalog heading and first row visible at 960x540', (tester) async {
    final view = tester.view;
    view
      ..physicalSize = const Size(960, 540)
      ..devicePixelRatio = 1;
    addTearDown(view.reset);

    await _pumpCatalog(tester, _expectPositive);
    await tester.pumpAndSettle();

    expect(find.text('Каталог'), findsOneWidget);
    expect(find.byType(AnimeCard), findsAtLeastNWidgets(4));
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpCatalog(WidgetTester tester, ValueChanged<int> onOpen) => tester.pumpWidget(
  ProviderScope(
    overrides: [
      catalogRepositoryProvider.overrideWithValue(const CatalogScreenTest()),
      loggerProvider.overrideWithValue(Logger()),
    ],
    child: MaterialApp(
      theme: AppTheme.darkTheme,
      home: CatalogScreen(onAnimeTap: (anime) => onOpen(anime.id)),
    ),
  ),
);

void _expectPositive(int value) => expect(value, isPositive);

final class CatalogScreenTest implements CatalogRepository {
  const CatalogScreenTest();

  @override
  Future<Either<Failure, AnimePage>> getPage(int page) async => Either.right(
    AnimePage(
      items: List.generate(
        12,
        (index) =>
            AnimeSummary(id: index + 1, slug: '${index + 1}-anime', title: 'Аниме ${index + 1}', posterUri: Uri()),
        growable: false,
      ),
      page: 1,
      hasNext: false,
    ),
  );
}
