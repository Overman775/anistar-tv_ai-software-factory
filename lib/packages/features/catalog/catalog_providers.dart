import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'domain/repositories/catalog_repository.dart';

final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) => throw StateError('CatalogRepository must be supplied by the application.'),
);
