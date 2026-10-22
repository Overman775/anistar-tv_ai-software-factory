import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'domain/search_repository.dart';

final searchRepositoryProvider = Provider<SearchRepository>(
  (ref) => throw StateError('SearchRepository must be supplied by the application.'),
);
final searchHistoryRepositoryProvider = Provider<SearchHistoryRepository>(
  (ref) => throw StateError('SearchHistoryRepository must be supplied by the application.'),
);
