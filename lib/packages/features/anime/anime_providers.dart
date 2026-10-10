import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'domain/repositories/anime_repository.dart';

final animeRepositoryProvider = Provider<AnimeRepository>(
  (ref) => throw StateError('AnimeRepository must be supplied by the application.'),
);
