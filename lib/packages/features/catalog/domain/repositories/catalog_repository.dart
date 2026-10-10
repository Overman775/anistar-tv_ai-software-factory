import 'package:core/data.dart';

import '../models/anime_page.dart';

// Repository identity is required for DI and interchangeable implementations.
// ignore: one_member_abstracts
abstract interface class CatalogRepository {
  Future<Result<AnimePage, Failure>> getPage(int page);
}
