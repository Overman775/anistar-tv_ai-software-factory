import 'package:anistar_tv/packages/features/catalog/domain/models/anime_page.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/anime_summary.dart';
import 'package:anistar_tv/packages/features/favorites/domain/favorites_repository.dart';
import 'package:core/data.dart';

final class FakeFavoritesRepository implements FavoritesRepository {
  final Set<int> ids = {};
  final List<bool> writes = [];
  final List<int> pages = [];
  Future<Result<bool, Failure>> Function(bool desired)? change;
  Failure? statusFailure;

  @override
  Future<Result<AnimePage, Failure>> getPage(int page) async {
    pages.add(page);

    return Result.success(
      AnimePage(
        items: [
          for (final id in ids)
            AnimeSummary(id: id, slug: '$id-test', title: 'Аниме $id', isFavorite: true, posterUri: Uri()),
        ],
        page: page,
        hasNext: false,
      ),
    );
  }

  @override
  Future<Result<bool, Failure>> getStatus({required int animeId, required String slug}) async {
    final failure = statusFailure;

    return failure == null ? Result.success(ids.contains(animeId)) : Result.failure(failure);
  }

  @override
  Future<Result<bool, Failure>> setFavorite({
    required int animeId,
    required String slug,
    required bool favorite,
  }) async {
    writes.add(favorite);
    final handler = change;
    if (handler != null) {
      return handler(favorite);
    }
    if (favorite) {
      ids.add(animeId);
    } else {
      ids.remove(animeId);
    }

    return Result.success(favorite);
  }
}
