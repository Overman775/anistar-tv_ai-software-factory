import 'package:core/data.dart';

import '../../catalog/domain/models/anime_page.dart';

abstract interface class SearchRepository {
  Future<Result<AnimePage, Failure>> search(String query, {int page = 1, RequestCancellation? cancellation});
}

abstract interface class SearchHistoryRepository {
  Future<Result<List<String>, Failure>> read();
  Future<Result<void, Failure>> save(List<String> queries);
}

String normalizeSearchQuery(String value) => value.trim().toLowerCase().replaceAll('ё', 'е');
