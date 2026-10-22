import 'package:core/data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'domain/favorites_failure.dart';
import 'favorites_repository_provider.dart';
import 'favorites_state.dart';

final class FavoritesController extends Notifier<FavoritesState> {
  @override
  FavoritesState build() {
    ref.watch(favoritesAccountProvider);

    return const FavoritesState();
  }

  void invalidate() => state = FavoritesState(revision: state.revision + 1, updatingAnimeId: state.updatingAnimeId);

  void observe(int animeId, bool? favorite) {
    if (ref.read(favoritesAccountProvider) != null && favorite != null && state.updatingAnimeId == null) {
      state = FavoritesState(known: Map.unmodifiable({...state.known, animeId: favorite}), revision: state.revision);
    }
  }

  Future<Failure?> setFavorite({required int animeId, required String slug, required bool favorite}) async {
    final account = ref.read(favoritesAccountProvider);
    if (account == null) {
      return const FavoritesFailure('Войдите в аккаунт для работы с избранным.');
    }
    if (state.updatingAnimeId != null) {
      return const FavoritesFailure('Дождитесь завершения изменения избранного.');
    }
    state = FavoritesState(known: state.known, revision: state.revision, updatingAnimeId: animeId);
    final result = await ref
        .read(favoritesRepositoryProvider)
        .setFavorite(animeId: animeId, slug: slug, favorite: favorite);
    if (!ref.mounted || ref.read(favoritesAccountProvider) != account) {
      return null;
    }

    return result.when(
      success: (confirmed) {
        state = FavoritesState(
          known: Map.unmodifiable({...state.known, animeId: confirmed}),
          revision: state.revision + 1,
        );

        return null;
      },
      failure: (failure) {
        state = FavoritesState(known: state.known, revision: state.revision);

        return failure;
      },
    );
  }
}
