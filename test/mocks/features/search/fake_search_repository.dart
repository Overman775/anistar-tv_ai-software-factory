import 'dart:async';

import 'package:anistar_tv/packages/features/catalog/domain/models/anime_page.dart';
import 'package:anistar_tv/packages/features/search/domain/search_repository.dart';
import 'package:core/data.dart';

typedef SearchRequest = ({String query, int page, RequestCancellation? cancellation});

final class FakeSearchRepository implements SearchRepository {
  final List<SearchRequest> requests = [];
  final Future<Result<AnimePage, Failure>> Function(SearchRequest)? load;

  FakeSearchRepository({this.load});

  @override
  Future<Result<AnimePage, Failure>> search(String query, {int page = 1, RequestCancellation? cancellation}) async {
    final request = (query: query, page: page, cancellation: cancellation);
    requests.add(request);
    final handler = load;
    if (handler != null) {
      return handler(request);
    }

    return Result.success(AnimePage(items: const [], page: page, hasNext: false));
  }
}

final class FakeSearchHistoryRepository implements SearchHistoryRepository {
  final List<String> initial;
  final List<List<String>> writes = [];
  Completer<Result<List<String>, Failure>>? pendingRead;
  Result<void, Failure> saveResult = const Result.success(null);

  FakeSearchHistoryRepository([this.initial = const []]);

  @override
  Future<Result<List<String>, Failure>> read() async {
    final pending = pendingRead;
    if (pending != null) {
      return pending.future;
    }

    return Result.success(List.unmodifiable(initial));
  }

  @override
  Future<Result<void, Failure>> save(List<String> queries) async {
    writes.add(List.of(queries));

    return saveResult;
  }
}
