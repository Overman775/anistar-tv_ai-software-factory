part of 'video_list_bloc.dart';

/// Base class for VideoList states using Freezed for immutability and equality.
@freezed
abstract class VideoListState with _$VideoListState {
  /// Initial state before any loading begins.
  const factory VideoListState.initial() = VideoListInitial;

  /// State when the initial list of videos is being loaded.
  const factory VideoListState.loading() = VideoListLoading;

  /// State when more videos are being loaded (pagination).
  /// Includes the currently loaded videos.
  const factory VideoListState.loadingMore({required List<VideoModel> videos}) = VideoListLoadingMore;

  /// State when videos have been successfully loaded.
  /// Includes the list of videos and whether more pages are available.
  const factory VideoListState.loaded({required List<VideoModel> videos, required bool hasMore}) = VideoListLoaded;

  /// State when an error occurred during loading.
  /// Optionally includes the videos loaded so far and the previous 'hasMore' status.
  const factory VideoListState.error({
    required String message,
    List<VideoModel>? videos, // Videos loaded before the error
    bool? hasMore, // hasMore status before the error
  }) = VideoListError;
}
