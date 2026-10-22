import 'dart:async';

import 'package:anistar_tv/packages/features/catalog/domain/models/anime_page.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/anime_summary.dart';
import 'package:anistar_tv/packages/features/search/presentation/search_bloc.dart';
import 'package:core/data.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../mocks/features/search/fake_search_repository.dart';

void main() {
  test('blank and invalid queries stay local and are not remembered', () async {
    final repository = FakeSearchRepository();
    final history = FakeSearchHistoryRepository();
    final bloc = SearchBloc(repository, history);
    addTearDown(bloc.close);
    await _submit(bloc, '   ', SearchStatus.ready);
    expect(bloc.state.items, isEmpty);
    await _submit(bloc, 'abc', SearchStatus.error);
    expect(bloc.state.message, 'Введите не менее 4 символов.');
    await _submit(bloc, List.filled(121, 'a').join(), SearchStatus.error);
    expect(repository.requests, isEmpty);
    expect(history.writes, isEmpty);
  });

  test('a new explicit submit cancels the previous request and ignores its late result', () async {
    final older = Completer<Result<AnimePage, Failure>>();
    final repository = FakeSearchRepository(
      load: (request) async => request.query == 'older' ? older.future : _page(2),
    );
    final bloc = SearchBloc(repository, FakeSearchHistoryRepository());
    addTearDown(bloc.close);
    bloc.add(const SearchSubmitted('older'));
    await _drain();
    final oldCancellation = repository.requests.single.cancellation;
    await _submit(bloc, 'newer', SearchStatus.ready);
    older.complete(_page(1));
    await _drain();
    expect(oldCancellation?.isCancelled, isTrue);
    expect(bloc.state.query, 'newer');
    expect(bloc.state.items.map((item) => item.id), [2]);
  });

  test('pagination deduplicates, retains content on failure and requires explicit retry', () async {
    var failNextPage = true;
    final repository = FakeSearchRepository(
      load: (request) async {
        if (request.page == 1) {
          return _page(1, hasNext: true);
        }

        return failNextPage ? const Result.failure(UnknownFailure()) : _page(2, duplicate: 1, page: 2);
      },
    );
    final bloc = SearchBloc(repository, FakeSearchHistoryRepository());
    addTearDown(bloc.close);
    await _submit(bloc, 'anime', SearchStatus.ready);
    final states = bloc.stream;
    final failed = states.firstWhere((state) => state.message != null);
    bloc.add(const SearchMoreRequested());
    final failedState = await failed;
    expect(failedState.items.single.id, 1);
    expect(failedState.page, 1);
    bloc.add(const SearchMoreRequested());
    await _drain();
    expect(repository.requests.map((request) => request.page), [1, 2]);
    failNextPage = false;
    final complete = states.firstWhere((state) => state.page == 2);
    bloc.add(const SearchMoreRequested(retry: true));
    final completedState = await complete;
    expect(completedState.items.map((item) => item.id), [1, 2]);
    expect(completedState.hasMore, isFalse);
    expect(repository.requests.last.page, 2);
  });

  test('a late page from an earlier query cannot append to a new query', () async {
    final page = Completer<Result<AnimePage, Failure>>();
    final repository = FakeSearchRepository(
      load: (request) async {
        if (request.page == 2) {
          return page.future;
        }

        return _page(request.query == 'older' ? 1 : 3, hasNext: request.query == 'older');
      },
    );
    final bloc = SearchBloc(repository, FakeSearchHistoryRepository());
    addTearDown(bloc.close);
    await _submit(bloc, 'older', SearchStatus.ready);
    bloc.add(const SearchMoreRequested());
    await _drain();
    await _submit(bloc, 'newer', SearchStatus.ready);
    page.complete(_page(2, page: 2));
    await _drain();
    expect(bloc.state.items.map((item) => item.id), [3]);
    expect(bloc.state.page, 1);
  });

  test('history is bounded, deduplicated by case and ё, removable and nonblocking on storage failure', () async {
    final history = FakeSearchHistoryRepository()..saveResult = const Result.failure(UnknownFailure());
    final bloc = SearchBloc(FakeSearchRepository(), history);
    addTearDown(bloc.close);
    await _submit(bloc, ' Ёжик ', SearchStatus.ready);
    await _submit(bloc, 'ежик', SearchStatus.ready);
    final deduplicated = bloc.state;
    expect(deduplicated.history, ['ежик']);
    for (var index = 0; index < 9; index++) {
      await _submit(bloc, 'anime-$index', SearchStatus.ready);
    }
    final bounded = bloc.state;
    expect(bounded.history, List.generate(8, (index) => 'anime-${8 - index}'));
    bloc.add(const SearchHistoryChanged(remove: 'anime-8'));
    await _drain();
    final removed = bloc.state;
    expect(removed.history.first, 'anime-7');
    bloc.add(const SearchHistoryChanged());
    await _drain();
    final cleared = bloc.state;
    expect(cleared.history, isEmpty);
    expect(history.writes.last, isEmpty);
    expect(cleared.status, SearchStatus.ready);
  });

  test('late history loading does not overwrite a submitted or cleared history', () async {
    final pending = Completer<Result<List<String>, Failure>>();
    final history = FakeSearchHistoryRepository()..pendingRead = pending;
    final bloc = SearchBloc(FakeSearchRepository(), history);
    addTearDown(bloc.close);
    await _submit(bloc, 'newer', SearchStatus.ready);
    pending.complete(const Result.success(['older']));
    await _drain();
    expect(bloc.state.history, ['newer']);
  });
}

Future<SearchState> _submit(SearchBloc bloc, String query, SearchStatus status) {
  final result = bloc.stream.firstWhere((state) => state.query == query.trim() && state.status == status);
  bloc.add(SearchSubmitted(query));

  return result;
}

Result<AnimePage, Failure> _page(int id, {bool hasNext = false, int? duplicate, int page = 1}) => Result.success(
  AnimePage(
    items: [
      if (duplicate != null) AnimeSummary(id: duplicate, slug: '$duplicate-anime', title: 'Anime $duplicate'),
      AnimeSummary(id: id, slug: '$id-anime', title: 'Anime $id'),
    ],
    page: page,
    hasNext: hasNext,
  ),
);

Future<void> _drain() async {
  for (var turn = 0; turn < 3; turn++) {
    await Future<void>.delayed(Duration.zero);
  }
}
