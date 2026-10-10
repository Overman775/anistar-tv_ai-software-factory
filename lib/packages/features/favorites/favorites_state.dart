import 'package:flutter/foundation.dart';

/// A session-scoped display cache. The website remains the source of truth.
@immutable
final class FavoritesState {
  final Map<int, bool> known;
  final int revision;
  final int? updatingAnimeId;

  const FavoritesState({this.known = const {}, this.revision = 0, this.updatingAnimeId});
}
