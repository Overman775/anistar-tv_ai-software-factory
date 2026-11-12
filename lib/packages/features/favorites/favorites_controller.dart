import 'package:core/data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'domain/favorites_failure.dart';
import 'favorites_repository_provider.dart';
import 'favorites_state.dart';

final class FavoritesController extends Notifier<FavoritesState> {
  int _scopeGeneration = 0;

  @override
  FavoritesState build() {
    ref.watch(favoritesAccountProvider);
    ++_scopeGeneration;

    return const FavoritesState();
  }

  void invalidate() => state = FavoritesState(
    known: state.updatingAnimeId == null ? const {} : state.known,
    revision: state.revision + 1,
    updatingAnimeId: state.updatingAnimeId,
  );

  void observe(int animeId, bool? favorite) {
    if (ref.read(favoritesAccountProvider) != null && favorite != null && state.updatingAnimeId == null) {
      state = FavoritesState(known: Map.unmodifiable({...state.known, animeId: favorite}), revision: state.revision);
    }
  }

  Future<Result<bool, Failure>> readStatus({required int animeId, required String slug}) async {
    final account = ref.read(favoritesAccountProvider);
    if (account == null) {
      return const Result.failure(FavoritesFailure('Войдите в аккаунт для работы с избранным.'));
    }
    final generation = _scopeGeneration;
    final revision = state.revision;
    final repository = ref.read(favoritesRepositoryProvider);
    final result = await repository.getStatus(animeId: animeId, slug: slug);
    if (!ref.mounted ||
        generation != _scopeGeneration ||
        ref.read(favoritesAccountProvider) != account ||
        ref.read(favoritesRepositoryProvider) != repository ||
        state.revision != revision ||
        state.updatingAnimeId == animeId) {
      return const Result.failure(FavoritesFailure('Статус изменился. Обновите избранное.'));
    }
    observe(animeId, result.successOrNull);

    return result;
  }

  Future<Failure?> setFavorite({required int animeId, required String slug, required bool favorite}) async {
    final account = ref.read(favoritesAccountProvider);
    if (account == null) {
      return const FavoritesFailure('Войдите в аккаунт для работы с избранным.');
    }
    if (state.updatingAnimeId != null) {
      return const FavoritesFailure('Дождитесь завершения изменения избранного.');
    }
    final generation = _scopeGeneration;
    final repository = ref.read(favoritesRepositoryProvider);
    final keepAlive = ref.keepAlive();
    state = FavoritesState(known: state.known, revision: state.revision, updatingAnimeId: animeId);
    try {
      final result = await repository.setFavorite(animeId: animeId, slug: slug, favorite: favorite);
      if (!ref.mounted || generation != _scopeGeneration || ref.read(favoritesAccountProvider) != account) {
        return null;
      }
      if (ref.read(favoritesRepositoryProvider) != repository) {
        state = FavoritesState(revision: state.revision + 1);

        return const FavoritesFailure('Контекст избранного изменился. Повторите действие.');
      }

      final confirmed = result.successOrNull;
      if (confirmed != favorite) {
        state = FavoritesState(known: state.known, revision: state.revision);

        return result.failureOrNull ?? const FavoritesFailure('AniStar не подтвердил изменение избранного.');
      }
      state = FavoritesState(
        known: Map.unmodifiable({...state.known, animeId: favorite}),
        revision: state.revision + 1,
      );

      return null;
    } finally {
      keepAlive.close();
    }
  }
}
