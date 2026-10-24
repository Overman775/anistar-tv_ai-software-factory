import 'package:core/data.dart';
import 'package:networking/networking.dart';
import 'package:storage/storage.dart';

import '../domain/search_repository.dart';
import '../domain/search_rules.dart';

final class LocalSearchHistoryRepository extends BaseRepository implements SearchHistoryRepository {
  final SharedPreferencesStorage _storage;
  final String _key;

  LocalSearchHistoryRepository(this._storage, {required String scope}) : _key = 'anistar.search.v1.$scope';

  @override
  Future<Result<List<String>, Failure>> read() => makeApiCall(() async {
    final values = await _storage.get<List<String>>(_key, const []);
    final seen = <String>{};

    return List.unmodifiable(
      values
          .map((value) => value.trim())
          .where((value) => SearchRules.hasValidHistoryLength(value) && seen.add(normalizeSearchQuery(value)))
          .take(SearchRules.historyLimit),
    );
  });

  @override
  Future<Result<void, Failure>> save(List<String> queries) => makeApiCall(() => _storage.set(_key, queries));
}
