import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../models/video_model.dart';
import '../../../../services/video_service.dart';

part 'home_block.freezed.dart'; // Add part for generated freezed file
part 'home_events.dart';
part 'home_states.dart';

const _pageSize = 4; // Same page size as in the original HomeScreen

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final VideoService _videoService;
  int _currentPage = 1;

  HomeBloc({required VideoService videoService}) : _videoService = videoService, super(const HomeState.initial()) {
    on<HomeLoadStarted>(_onLoadStarted);
    on<HomeLoadMoreRequested>(_onLoadMoreRequested);
  }

  Future<void> _onLoadStarted(HomeLoadStarted event, Emitter<HomeState> emit) async {
    emit(const HomeState.loading());
    try {
      _currentPage = 1; // Reset page for initial load
      final videos = await _videoService.getVideosPaginated(_currentPage, _pageSize);
      final hasMore = await _videoService.hasMoreVideos(_currentPage, _pageSize);
      emit(HomeState.loaded(videos: videos, hasMore: hasMore));
    } catch (e) {
      // Consider logging the error e
      emit(HomeState.error(message: 'Failed to load videos: ${e.toString()}'));
    }
  }

  Future<void> _onLoadMoreRequested(HomeLoadMoreRequested event, Emitter<HomeState> emit) async {
    // Get current videos and hasMore status from the current state
    final currentState = state;
    List<VideoModel> currentVideos = [];
    bool currentHasMore = true; // Assume true unless state says otherwise

    if (currentState is HomeLoaded) {
      currentVideos = currentState.videos;
      currentHasMore = currentState.hasMore;
    } else if (currentState is HomeLoadingMore) {
      // Already loading more, avoid concurrent requests
      return;
    } else if (currentState is HomeError && currentState.videos != null) {
      // If in error state but have previous videos, allow loading more
      currentVideos = currentState.videos!;
      currentHasMore = currentState.hasMore ?? true;
    } else {
      // Not in a state where loading more makes sense (e.g., Initial, Loading)
      return;
    }

    if (!currentHasMore) {
      return; // No more videos to load
    }

    // Emit LoadingMore state with current videos
    emit(HomeState.loadingMore(videos: currentVideos));

    try {
      _currentPage++;
      final newVideos = await _videoService.getVideosPaginated(_currentPage, _pageSize);
      final hasMore = await _videoService.hasMoreVideos(_currentPage, _pageSize);
      emit(HomeState.loaded(videos: currentVideos + newVideos, hasMore: hasMore));
    } catch (e) {
      _currentPage--; // Revert page increment on error
      // Consider logging the error e
      // Emit error state but keep existing videos
      emit(
        HomeState.error(
          message: 'Failed to load more videos: ${e.toString()}',
          videos: currentVideos, // Keep the videos loaded so far
          hasMore: currentHasMore, // Keep the previous hasMore status
        ),
      );
    }
  }
}
