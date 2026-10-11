import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'domain/repositories/watched_episodes_repository.dart';

final watchedEpisodesRepositoryProvider = Provider<WatchedEpisodesRepository>(
  (ref) => throw StateError('WatchedEpisodesRepository must be supplied by the application.'),
);
