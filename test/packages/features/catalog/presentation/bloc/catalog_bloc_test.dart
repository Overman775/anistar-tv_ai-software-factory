import 'package:anistar_tv/packages/features/catalog/domain/models/anime_page.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/anime_summary.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/bloc/catalog_bloc.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/bloc/catalog_event.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/bloc/catalog_state.dart';
import 'package:app_logging/app_logging.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../../mocks/features/catalog/fake_catalog_repository.dart';

void main() {
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
