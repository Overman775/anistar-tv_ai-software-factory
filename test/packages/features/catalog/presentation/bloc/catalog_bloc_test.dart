import 'dart:async';

import 'package:anistar_tv/packages/features/catalog/domain/models/anime_page.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/anime_summary.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/bloc/catalog_bloc.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/bloc/catalog_event.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/bloc/catalog_state.dart';
import 'package:app_logging/app_logging.dart';
import 'package:core/data.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../../mocks/features/catalog/fake_catalog_repository.dart';
import '../../../../../mocks/features/catalog/fake_catalog_screen_repository.dart';

void main() {
  test('replacement captures source and generation while late old pages and first pages are ignored', () async {
    final oldMore = Completer<Result<AnimePage, Failure>>();
    final intermediate = Completer<Result<AnimePage, Failure>>();
    final oldRequests = <int>[];
    final latestRequests = <int>[];
    final old = FakeCatalogScreenRepository(
      load: (page) {
        oldRequests.add(page);

        return page == 1 ? Future.value(Result.success(_page(id: 1, page: 1, hasNext: true))) : oldMore.future;
      },
    );
    final middle = FakeCatalogScreenRepository(load: (_) => intermediate.future);
    final latest = FakeCatalogScreenRepository(
      load: (page) {
        latestRequests.add(page);

        return Future.value(Result.success(_page(id: page + 10, page: page, hasNext: true)));
      },
    );
    final bloc = CatalogBloc(
      repository: old,
      logger: Logger(level: Level.off),
    );
    addTearDown(bloc.close);
    bloc.add(const CatalogStarted());
    await _flushEvents();
    bloc.add(const CatalogMoreRequested());
    await _flushEvents();
    bloc.add(CatalogStarted(repository: middle, preserveContent: true));
    await _flushEvents();
    expect(bloc.state.items, isEmpty);
    bloc.add(CatalogStarted(repository: latest));
    await _flushEvents();
    oldMore.complete(Result.success(_page(id: 2, page: 2, hasNext: true)));
    intermediate.complete(Result.success(_page(id: 3, page: 1, hasNext: true)));
    await _flushEvents();
    final firstLatest = bloc.state;
    expect(firstLatest.items.map((item) => item.id), [11]);
    bloc.add(const CatalogMoreRequested());
    await _flushEvents();
    final secondLatest = bloc.state;
    expect(secondLatest.items.map((item) => item.id), [11, 12]);
    expect(oldRequests, [1, 2]);
    expect(latestRequests, [1, 2]);
  });

  test('failed pull keeps the loaded pages and next page number, without duplicate refreshes', () async {
    final refresh = Completer<Result<AnimePage, Failure>>();
    final requests = <int>[];
    final bloc = CatalogBloc(
      logger: Logger(),
      repository: FakeCatalogScreenRepository(
        load: (number) {
          requests.add(number);
          if (number == 1 && requests.length > 1) {
            return refresh.future;
          }

          return Future.value(Result.success(_page(id: number, page: number, hasNext: true)));
        },
      ),
    );
    addTearDown(bloc.close);
    bloc.add(const CatalogStarted());
    await _flushEvents();
    bloc.add(const CatalogMoreRequested());
    await _flushEvents();
    bloc.add(const CatalogStarted(preserveContent: true));
    await _flushEvents();
    final refreshingState = bloc.state;
    expect(refreshingState, isA<CatalogRefreshing>());
    expect(refreshingState.items.map((item) => item.id), [1, 2]);
    bloc
      ..add(const CatalogStarted(preserveContent: true))
      ..add(const CatalogMoreRequested());
    await _flushEvents();
    expect(requests, [1, 2, 1]);
    refresh.complete(const Result.failure(UnknownFailure()));
    await _flushEvents();
    final failureState = bloc.state;
    expect(failureState, isA<CatalogFailure>());
    expect(failureState.items.map((item) => item.id), [1, 2]);
    bloc.add(const CatalogMoreRequested());
    await _flushEvents();
    expect(requests.last, 3);
    final finalState = bloc.state;
    expect(finalState.items.map((item) => item.id), [1, 2, 3]);
  });

  test('loads the first page and appends the next one', () async {
    final repository = FakeCatalogRepository();
    final bloc = CatalogBloc(repository: repository, logger: Logger());
    final stream = bloc.stream;
    const readyState = TypeMatcher<CatalogReady>();
    final firstPage = readyState.having((state) => state.items.length, 'items', 1);
    final loadingMore = readyState.having((state) => state.isLoadingMore, 'loading more', isTrue);
    final secondPage = readyState
        .having((state) => state.items.length, 'items', 2)
        .having((state) => state.hasMore, 'has more', isFalse);
    addTearDown(bloc.close);

    bloc.add(const CatalogStarted());
    await expectLater(stream, emitsInOrder([isA<CatalogLoading>(), firstPage]));

    bloc.add(const CatalogMoreRequested());
    await expectLater(stream, emitsInOrder([loadingMore, secondPage]));
  });

  test('discards an outdated pagination result after catalog refresh', () async {
    final repository = ControlledCatalogRepository();
    final bloc = CatalogBloc(repository: repository, logger: Logger());
    final states = <CatalogState>[];
    final subscription = bloc.stream.listen(states.add);
    addTearDown(() async {
      await subscription.cancel();
      await bloc.close();
    });

    bloc.add(const CatalogStarted());
    await _flushEvents();
    bloc.add(const CatalogMoreRequested());
    await _flushEvents();
    bloc.add(const CatalogStarted());
    await _flushEvents();
    repository.pagination.complete(_page(id: 2, page: 2, hasNext: false));
    await _flushEvents();

    final lastState = states.last as CatalogReady;
    expect(lastState.items.map((item) => item.id), [101]);
    expect(states.whereType<CatalogReady>().any((state) => state.items.length > 1), isFalse);
  });
}

Future<void> _flushEvents() => Future<void>.delayed(const Duration(milliseconds: 10));

AnimePage _page({required int id, required int page, required bool hasNext}) => AnimePage(
  items: [
    AnimeSummary(id: id, slug: '$id-anime', title: 'Аниме $id', posterUri: Uri.parse('https://images.test/$id.jpg')),
  ],
  page: page,
  hasNext: hasNext,
);
