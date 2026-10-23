import 'package:core/data.dart';

import '../models/anime_page.dart';

// Repository identity is required for DI and interchangeable implementations.
abstract interface class CatalogRepository {
  Future<Result<AnimePage, Failure>> getPage(int page);
}
