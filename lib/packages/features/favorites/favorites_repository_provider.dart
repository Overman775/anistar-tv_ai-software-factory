import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'domain/favorites_repository.dart';

final favoritesRepositoryProvider = Provider<FavoritesRepository>(
  (ref) => throw StateError('FavoritesRepository must be supplied by the application.'),
);

final favoritesAccountProvider = Provider<String?>((ref) => null);
