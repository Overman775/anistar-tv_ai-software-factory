import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:logger/logger.dart';

import '../../domain/models/video_model.dart';
import '../../domain/usecases/get_videos_paginated_usecase.dart';

part 'video_list_bloc.freezed.dart'; // Add part for generated freezed file
part 'video_list_events.dart';
part 'video_list_states.dart';

class VideoListBloc extends Bloc<VideoListEvent, VideoListState> {
  final GetVideosPaginatedUseCase _getVideosPaginatedUseCase;
  final String _baseUrl; // The base URL for fetching videos
  final Logger _logger;
  int _currentPage = 1;

  VideoListBloc({
    required GetVideosPaginatedUseCase getVideosPaginatedUseCase,
    required String baseUrl, // Require the base URL
    Logger? logger,
  }) : _getVideosPaginatedUseCase = getVideosPaginatedUseCase,
       _baseUrl = baseUrl,
       _logger = logger ?? Logger(),
       super(const VideoListState.initial()) {
    on<VideoListLoadStarted>(_onLoadStarted);
    on<VideoListLoadMoreRequested>(_onLoadMoreRequested);
  }

  Future<void> _onLoadStarted(VideoListLoadStarted event, Emitter<VideoListState> emit) async {
    _logger.d('Bloc: Load Started event received.');
    emit(const VideoListState.loading());
    _currentPage = 1; // Reset page number for initial load
    try {
      final pageModel = await _getVideosPaginatedUseCase(_baseUrl, _currentPage);
      if (pageModel != null) {
        _logger.i(
          'Bloc: Initial load successful. Videos: ${pageModel.videos.length}, HasMore: ${pageModel.hasMorePages}',
        );
        emit(VideoListState.loaded(videos: pageModel.videos, hasMore: pageModel.hasMorePages));
      } else {
        _logger.w('Bloc: Initial load failed - UseCase returned null.');
        emit(const VideoListState.error(message: 'Failed to load videos: Received null page data'));
      }
    } catch (e, stackTrace) {
      _logger.e('Bloc: Error during initial load', error: e, stackTrace: stackTrace);
      emit(VideoListState.error(message: 'Failed to load videos: ${e.toString()}'));
    }
  }

  Future<void> _onLoadMoreRequested(VideoListLoadMoreRequested event, Emitter<VideoListState> emit) async {
    _logger.d('Bloc: Load More Requested event received.');
    // Get current videos and hasMore status from the current state
    final currentState = state;
    List<VideoModel> currentVideos = [];
    bool currentHasMore = true; // Assume true unless state says otherwise

    // Extract state data safely using pattern matching or checks
    if (currentState is VideoListLoaded) {
      currentVideos = currentState.videos;
      currentHasMore = currentState.hasMore;
      _logger.t('Bloc: Currently in Loaded state. Videos: ${currentVideos.length}, HasMore: $currentHasMore');
    } else if (currentState is VideoListLoadingMore) {
      _logger.t('Bloc: Already loading more. Ignoring event.');
      return; // Already loading more, avoid concurrent requests
    } else if (currentState is VideoListError && currentState.videos != null) {
      // If in error state but have previous videos, allow loading more
      currentVideos = currentState.videos!;
      currentHasMore = currentState.hasMore ?? true; // Use previous hasMore if available
      _logger.t(
        'Bloc: Currently in Error state with videos. Videos: ${currentVideos.length}, HasMore: $currentHasMore',
      );
    } else {
      _logger.w('Bloc: Load More requested from invalid state: $currentState. Ignoring.');
      return; // Not in a state where loading more makes sense
    }

    if (!currentHasMore) {
      _logger.d('Bloc: No more videos to load. Ignoring event.');
      return; // No more videos to load
    }

    // Emit LoadingMore state with current videos
    _logger.t('Bloc: Emitting LoadingMore state.');
    emit(VideoListState.loadingMore(videos: currentVideos));

    try {
      _currentPage++;
      _logger.d('Bloc: Requesting page $_currentPage from UseCase.');
      final pageModel = await _getVideosPaginatedUseCase(_baseUrl, _currentPage);
      if (pageModel != null) {
        final combinedVideos = currentVideos + pageModel.videos;
        _logger.i(
          'Bloc: Load More successful. Total Videos: ${combinedVideos.length}, HasMore: ${pageModel.hasMorePages}',
        );
        emit(
          VideoListState.loaded(
            videos: combinedVideos, // Combine old and new videos
            hasMore: pageModel.hasMorePages, // Use hasMore from the new page data
          ),
        );
      } else {
        _logger.w('Bloc: Load More failed - UseCase returned null for page $_currentPage.');
        _currentPage--; // Revert page increment
        emit(
          VideoListState.error(
            message: 'Failed to load more videos: Received null page data',
            videos: currentVideos, // Keep existing videos
            hasMore: currentHasMore, // Keep previous hasMore status
          ),
        );
      }
    } catch (e, stackTrace) {
      _logger.e('Bloc: Error during Load More for page $_currentPage', error: e, stackTrace: stackTrace);
      _currentPage--; // Revert page increment on error
      emit(
        VideoListState.error(
          message: 'Failed to load more videos: ${e.toString()}',
          videos: currentVideos, // Keep the videos loaded so far
          hasMore: currentHasMore, // Keep the previous hasMore status
        ),
      );
    }
  }
}
