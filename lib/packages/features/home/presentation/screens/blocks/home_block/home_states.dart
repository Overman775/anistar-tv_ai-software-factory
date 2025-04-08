part of 'home_block.dart'; // Add part of directive

// Imports moved to home_block.dart

// part 'home_states.freezed.dart'; // This belongs in home_block.dart

@freezed
class HomeState with _$HomeState {
  /// Initial state, before any data loading has begun.
  const factory HomeState.initial() = HomeInitial;

  /// State indicating that the initial data load is in progress.
  const factory HomeState.loading() = HomeLoading;

  /// State indicating that video data has been successfully loaded.
  const factory HomeState.loaded({required List<VideoModel> videos, required bool hasMore}) = HomeLoaded;

  /// State indicating that more video data is being loaded (pagination).
  const factory HomeState.loadingMore({required List<VideoModel> videos}) = HomeLoadingMore;

  /// State indicating an error occurred during data loading.
  const factory HomeState.error({
    required String message,
    // Optionally include the previously loaded videos to still display them
    List<VideoModel>? videos,
    bool? hasMore,
  }) = HomeError;
}
