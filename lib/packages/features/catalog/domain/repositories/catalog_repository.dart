import '../../../../core/core.dart';
import '../models/anime_page.dart';

abstract interface class CatalogRepository {
  Future<Either<Failure, AnimePage>> getPage(int page);
}
