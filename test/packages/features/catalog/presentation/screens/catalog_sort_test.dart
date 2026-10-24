// Each assertion observes a separate remote event or asynchronous response.

import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:anistar_tv/packages/features/catalog/catalog_providers.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/anime_page.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/anime_summary.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/catalog_sort.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/bloc/catalog_bloc.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/bloc/catalog_event.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/screens/catalog_screen.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/widgets/anime_card.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/widgets/catalog_sort_sheet.dart';
import 'package:anistar_tv/packages/features/home/presentation/home_destination.dart';
import 'package:anistar_tv/packages/features/home/presentation/screens/tv_route_shell.dart';
import 'package:core/data.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../../../mocks/features/catalog/fake_catalog_browse_repository.dart';
import '../../../../../mocks/features/catalog/fake_catalog_screen_repository.dart';
import '../../../../../support/test_app.dart';

Future<void> _key(WidgetTester tester, LogicalKeyboardKey key, [int count = 1]) async {
  for (var i = 0; i < count; i++) {
    await tester.sendKeyEvent(key);
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<void> _applyTitle(WidgetTester tester) async {
  await _key(tester, LogicalKeyboardKey.arrowUp);
  await _key(tester, LogicalKeyboardKey.select);
  expect(FocusManager.instance.primaryFocus?.debugLabel, 'sort-option-0');
  await _key(tester, LogicalKeyboardKey.arrowDown, 4);
  await _key(tester, LogicalKeyboardKey.select);
  await _key(tester, LogicalKeyboardKey.arrowDown, 2);
  await _key(tester, LogicalKeyboardKey.select);
  await _key(tester, LogicalKeyboardKey.arrowDown);
  await _key(tester, LogicalKeyboardKey.select);
}

Finder _sortChoice(String label) => find.byWidgetPredicate((widget) => widget is TvChoiceTile && widget.label == label);

Future<void> _openSortWithPopularityDraft(WidgetTester tester) async {
  if (FocusManager.instance.primaryFocus?.debugLabel != 'Сортировка') {
    await _key(tester, LogicalKeyboardKey.arrowUp);
  }
  expect(FocusManager.instance.primaryFocus?.debugLabel, 'Сортировка');
  await _key(tester, LogicalKeyboardKey.select);
  expect(find.byType(CatalogSortSheet), findsOneWidget);
  expect(FocusManager.instance.primaryFocus?.debugLabel, 'sort-option-0');
  expect(tester.widget<TvChoiceTile>(_sortChoice('По дате')).selected, isTrue);
  expect(tester.getSemantics(_sortChoice('По дате')).getSemanticsData().flagsCollection.isSelected, Tristate.isTrue);
  expect(tester.widget<TvChoiceTile>(_sortChoice('По популярности')).selected, isFalse);
  await _key(tester, LogicalKeyboardKey.arrowDown);
  await _key(tester, LogicalKeyboardKey.select);
  expect(FocusManager.instance.primaryFocus?.debugLabel, 'sort-option-1');
}

void _expectUnsavedPopularityDraft(WidgetTester tester, FakeCatalogBrowseRepository repository, {required int option}) {
  expect(find.byType(CatalogSortSheet), findsOneWidget);
  expect(FocusManager.instance.primaryFocus?.debugLabel, 'sort-option-$option');
  expect(tester.widget<TvChoiceTile>(_sortChoice('По популярности')).selected, isTrue);
  expect(
    tester.getSemantics(_sortChoice('По популярности')).getSemanticsData().flagsCollection.isSelected,
    Tristate.isTrue,
  );
  expect(tester.widget<TvChoiceTile>(_sortChoice('По убыванию')).selected, isTrue);
  expect(repository.requests, hasLength(1));
  expect(tester.getSize(find.byKey(const ValueKey('catalog-navigation-rail'))).width, 88);
}

Future<void> _sendIgnoredHorizontalInput(
  WidgetTester tester,
  LogicalKeyboardKey key,
  VoidCallback expectUnchanged,
) async {
  await tester.sendKeyDownEvent(key);
  await tester.pump();
  expectUnchanged();
  await tester.sendKeyRepeatEvent(key);
  await tester.pump();
  expectUnchanged();
  await tester.sendKeyUpEvent(key);
  await tester.pump();
  expectUnchanged();
}

void _expectDefaultSortRestored(FakeCatalogBrowseRepository repository) {
  expect(find.byType(CatalogSortSheet), findsNothing);
  expect(FocusManager.instance.primaryFocus?.debugLabel, 'Сортировка');
  expect(find.text('По дате · Сначала новые'), findsOneWidget);
  expect(repository.sorts, [defaultCatalogSort]);
  expect(repository.requests, hasLength(1));
}

void main() {
  for (final size in [compactTvSize, wideTvSize, const Size(390, 844)]) {
    testWidgets('sort draft, cancel, apply, same selection and focus at $size', (tester) async {
      final repository = FakeCatalogBrowseRepository(
        load: (_, page) => const FakeCatalogScreenRepository().getPage(page),
      );
      await pumpTvApp(
        tester,
        CatalogScreen(filter: comedyFilter, onAnimeTap: (_) => fail('Unexpected anime selection')),
        size: size,
        wrapInScaffold: false,
        overrides: [catalogBrowseRepositoryProvider.overrideWithValue(repository)],
      );
      await tester.pumpAndSettle();
      await _key(tester, LogicalKeyboardKey.arrowUp);
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'Сортировка');
      await _key(tester, LogicalKeyboardKey.select);
      await _key(tester, LogicalKeyboardKey.arrowDown);
      await _key(tester, LogicalKeyboardKey.select);
      expect(repository.requests.length, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'Сортировка');
      expect(find.text('По дате · Сначала новые'), findsOneWidget);
      await _key(tester, LogicalKeyboardKey.arrowDown);
      await _applyTitle(tester);
      await tester.pumpAndSettle();
      expect(repository.sorts, [defaultCatalogSort, (criterion: CatalogSortCriterion.title, ascending: true)]);
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'Сортировка');
      expect(find.text('По алфавиту · А → Я'), findsOneWidget);
      await _key(tester, LogicalKeyboardKey.select);
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'sort-option-4');
      await _key(tester, LogicalKeyboardKey.arrowDown, 3);
      await _key(tester, LogicalKeyboardKey.select);
      expect(repository.requests.length, 2);
      await _key(tester, LogicalKeyboardKey.arrowDown);
      expect(FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<AnimeCard>()?.anime.id, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('sort keeps an unsaved draft through horizontal key lifecycles and preserves cancel and apply', (
    tester,
  ) async {
    final repository = FakeCatalogBrowseRepository(
      load: (_, page) => const FakeCatalogScreenRepository().getPage(page),
    );
    var destinationSelections = 0;
    await pumpTvApp(
      tester,
      TvRouteShell(
        destination: HomeDestination.genres,
        onDestinationSelected: (_) => destinationSelections++,
        builder: (onOpenNavigation) => CatalogScreen(
          filter: comedyFilter,
          onOpenNavigation: onOpenNavigation,
          onAnimeTap: (_) => fail('Unexpected anime selection'),
        ),
      ),
      wrapInScaffold: false,
      overrides: [catalogBrowseRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pumpAndSettle();

    await _openSortWithPopularityDraft(tester);
    var focusedRow = 1;
    for (final row in [1, 5, 7, 8]) {
      if (row != focusedRow) {
        await _key(tester, LogicalKeyboardKey.arrowDown, row - focusedRow);
        focusedRow = row;
      }
      for (final key in [LogicalKeyboardKey.arrowLeft, LogicalKeyboardKey.arrowRight]) {
        await _sendIgnoredHorizontalInput(
          tester,
          key,
          () => _expectUnsavedPopularityDraft(tester, repository, option: row),
        );
      }
    }
    expect(destinationSelections, 0);

    await _key(tester, LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    _expectDefaultSortRestored(repository);

    await _openSortWithPopularityDraft(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    _expectDefaultSortRestored(repository);

    await _openSortWithPopularityDraft(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    _expectDefaultSortRestored(repository);

    await _openSortWithPopularityDraft(tester);
    await tester.tapAt(const Offset(100, 270));
    await tester.pumpAndSettle();
    _expectDefaultSortRestored(repository);

    await _openSortWithPopularityDraft(tester);
    for (final key in [LogicalKeyboardKey.arrowLeft, LogicalKeyboardKey.arrowRight]) {
      await _sendIgnoredHorizontalInput(
        tester,
        key,
        () => _expectUnsavedPopularityDraft(tester, repository, option: 1),
      );
    }
    await _key(tester, LogicalKeyboardKey.arrowDown, 6);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'sort-option-7');
    await _key(tester, LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(repository.sorts, [defaultCatalogSort, (criterion: CatalogSortCriterion.popularity, ascending: false)]);
    expect(repository.requests, hasLength(2));
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'Сортировка');
    expect(find.text('По популярности · По убыванию'), findsOneWidget);

    await _key(tester, LogicalKeyboardKey.select);
    await _key(tester, LogicalKeyboardKey.arrowDown, 6);
    await _key(tester, LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(repository.requests, hasLength(2));
    expect(destinationSelections, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sort discards pending old pagination, retries new order and resets the page', (tester) async {
    final oldMore = Completer<Result<AnimePage, Failure>>();
    final newFirst = Completer<Result<AnimePage, Failure>>();
    var firstCalls = 0;
    final repository = FakeCatalogBrowseRepository(
      load: (_, page) {
        if (page == 2 && firstCalls == 1) {
          return oldMore.future;
        }
        if (page == 1 && ++firstCalls == 2) {
          return newFirst.future;
        }

        return Future.value(
          Result.success(
            AnimePage(
              page: page,
              hasNext: true,
              items: List.generate(
                12,
                (i) => AnimeSummary(
                  id: firstCalls * 100 + page * 12 + i,
                  slug: '$i-test',
                  title: 'Batch $firstCalls item $i',
                  posterUri: Uri(),
                ),
              ),
            ),
          ),
        );
      },
    );
    await pumpTvApp(
      tester,
      CatalogScreen(filter: comedyFilter, onAnimeTap: (_) => fail('Unexpected anime selection')),
      wrapInScaffold: false,
      overrides: [catalogBrowseRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pumpAndSettle();
    final bloc = tester.element(find.byType(AnimeCard).first).read<CatalogBloc>()..add(const CatalogMoreRequested());
    await tester.pump();
    await _applyTitle(tester);
    expect(find.byType(AnimeCard), findsNothing);
    oldMore.complete(Result.success(AnimePage(page: 2, hasNext: false, items: [])));
    await tester.pump();
    expect(find.byType(AnimeCard), findsNothing);
    newFirst.complete(const Result.failure(UnknownFailure()));
    await tester.pumpAndSettle();
    expect(find.text('Каталог недоступен'), findsOneWidget);
    await _key(tester, LogicalKeyboardKey.arrowUp);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'Сортировка');
    await _key(tester, LogicalKeyboardKey.arrowDown);
    await _key(tester, LogicalKeyboardKey.select);
    expect(find.byType(AnimeCard), findsWidgets);
    bloc.add(const CatalogMoreRequested());
    await tester.pumpAndSettle();
    expect(repository.requests.map((request) => request.$2), [1, 2, 1, 1, 2]);
    expect(
      repository.sorts.skip(2).every((sort) => sort == (criterion: CatalogSortCriterion.title, ascending: true)),
      isTrue,
    );
    expect(bloc.state.items.every((item) => item.title.startsWith('Batch 3')), isTrue);
  });

  testWidgets('filtered route shell moves from Sort to retry with one Down', (tester) async {
    var requests = 0;
    final repository = FakeCatalogBrowseRepository(
      load: (_, page) {
        requests++;

        return Future.value(
          requests == 1
              ? const Result.failure(UnknownFailure())
              : Result.success(
                  AnimePage(
                    page: page,
                    hasNext: false,
                    items: [AnimeSummary(id: 1, slug: 'retry', title: 'Recovered catalog', posterUri: Uri())],
                  ),
                ),
        );
      },
    );
    await pumpTvApp(
      tester,
      TvRouteShell(
        destination: HomeDestination.genres,
        onDestinationSelected: (_) => fail('Unexpected destination selection'),
        builder: (onOpenNavigation) => CatalogScreen(
          filter: comedyFilter,
          onOpenNavigation: onOpenNavigation,
          onAnimeTap: (_) => fail('Unexpected anime selection'),
        ),
      ),
      wrapInScaffold: false,
      overrides: [catalogBrowseRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pumpAndSettle();

    expect(find.text('Каталог недоступен'), findsOneWidget);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'Сортировка');

    await _key(tester, LogicalKeyboardKey.arrowDown);

    expect(FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<TvStateView>(), isNotNull);
    await _key(tester, LogicalKeyboardKey.arrowUp);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'Сортировка');
    await _key(tester, LogicalKeyboardKey.arrowDown);
    expect(FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<TvStateView>(), isNotNull);
    await _key(tester, LogicalKeyboardKey.select);
    await tester.pumpAndSettle();

    expect(requests, 2);
    expect(find.byType(AnimeCard), findsOneWidget);
  });

  testWidgets('delayed sorted results keep focus on the button until Down', (tester) async {
    final sorted = Completer<Result<AnimePage, Failure>>();
    var calls = 0;
    final repository = FakeCatalogBrowseRepository(
      load: (_, page) {
        calls++;

        return calls == 1 ? const FakeCatalogScreenRepository().getPage(page) : sorted.future;
      },
    );
    await pumpTvApp(
      tester,
      CatalogScreen(filter: comedyFilter, onAnimeTap: (_) => fail('Unexpected selection')),
      wrapInScaffold: false,
      overrides: [catalogBrowseRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pumpAndSettle();
    await _applyTitle(tester);
    await tester.pump(const Duration(seconds: 1));
    sorted.complete(
      Result.success(
        AnimePage(
          page: 1,
          hasNext: false,
          items: [AnimeSummary(id: 99, slug: '99-test', title: 'Delayed new item', posterUri: Uri())],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'Сортировка');
    await _key(tester, LogicalKeyboardKey.arrowDown);
    expect(FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<AnimeCard>()?.anime.id, 99);
  });

  testWidgets('sort stays reachable in loading and empty results', (tester) async {
    final pending = Completer<Result<AnimePage, Failure>>();
    final repository = FakeCatalogBrowseRepository(load: (_, _) => pending.future);
    await pumpTvApp(
      tester,
      CatalogScreen(filter: comedyFilter, onAnimeTap: (_) => fail('Unexpected anime selection')),
      wrapInScaffold: false,
      overrides: [catalogBrowseRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pump();
    await _key(tester, LogicalKeyboardKey.arrowUp);
    await _key(tester, LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(CatalogSortSheet), findsOneWidget);
    await _key(tester, LogicalKeyboardKey.escape);
    pending.complete(Result.success(AnimePage(page: 1, hasNext: false, items: [])));
    await tester.pumpAndSettle();
    await _key(tester, LogicalKeyboardKey.arrowRight);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'Сортировка');
    await _key(tester, LogicalKeyboardKey.select);
    expect(find.byType(CatalogSortSheet), findsOneWidget);
  });
}
