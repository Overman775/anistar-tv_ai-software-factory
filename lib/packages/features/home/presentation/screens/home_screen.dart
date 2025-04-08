import 'package:anistar_tv/utils/logger/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart'; // Import Bloc
import 'package:go_router/go_router.dart';

import '../../../../../app/app_routes.dart';
import '../../models/video_model.dart';
import '../../services/video_service.dart';
import '../widgets/video_card.dart';
import 'blocks/home_block/home_block.dart'; // Import BLoC

/// Home screen displaying available videos using BLoC
class HomeScreen extends StatefulWidget {
  /// Constructor
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // UI specific state remains
  int _selectedIndex = 0;
  final FocusNode _gridFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  // BLoC instance
  late final HomeBloc _homeBloc;

  @override
  void initState() {
    super.initState();
    // Create BLoC instance, injecting VideoService
    _homeBloc = HomeBloc(videoService: context.read<VideoService>());
    // Dispatch initial event
    _homeBloc.add(const HomeLoadStarted());

    _gridFocusNode.requestFocus();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _gridFocusNode.dispose();
    _homeBloc.close(); // Close the BLoC
    super.dispose();
  }

  // Removed: _loadInitialVideos, _loadMoreVideos

  /// Scroll listener to detect when user reaches the bottom
  void _scrollListener() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      final homeState = _homeBloc.state;
      bool canLoadMore = false;

      // Check if we can load more based on the current state
      if (homeState is HomeLoaded && homeState.hasMore) {
        canLoadMore = true;
      } else if (homeState is HomeError && (homeState.hasMore ?? false)) {
        // Allow retry/load more even from error state if hasMore was true
        canLoadMore = true;
      }

      // Only add event if we can load more and are not already loading more
      if (canLoadMore && homeState is! HomeLoadingMore) {
        _homeBloc.add(const HomeLoadMoreRequested());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Provide the BLoC instance to the widget tree below
    return BlocProvider.value(
      value: _homeBloc,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Anistar TV'),
          actions: [IconButton(icon: const Icon(Icons.favorite), onPressed: () => context.go(AppRoutes.favorites))],
        ),
        body: KeyboardListener(
          focusNode: _gridFocusNode,
          onKeyEvent: _handleKeyEvent,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            // Use BlocBuilder to react to state changes
            child: BlocBuilder<HomeBloc, HomeState>(
              builder: (context, state) {
                // Extract videos and hasMore status safely from state
                List<VideoModel> videos = [];
                bool isLoadingMore = false;
                String? errorMessage;

                switch (state) {
                  case HomeLoaded(videos: final loadedVideos):
                    videos = loadedVideos;
                  case HomeLoadingMore(videos: final loadingMoreVideos):
                    videos = loadingMoreVideos;
                    isLoadingMore = true;
                  case HomeError(videos: final errorVideos, message: final errorMsg):
                    videos = errorVideos ?? []; // Show previous videos if available
                    errorMessage = errorMsg;
                  // Handle other potential states if necessary, or provide a default
                  case HomeInitial():
                  case HomeLoading():
                    // No specific action needed here for video/error extraction
                    break;
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Home', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Expanded(child: _buildContent(context, state, videos, isLoadingMore, errorMessage)),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    HomeState state,
    List<VideoModel> videos,
    bool isLoadingMore,
    String? errorMessage,
  ) {
    // Initial Loading State
    if (state is HomeInitial || state is HomeLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Error State
    if (errorMessage != null && videos.isEmpty) {
      // Show error only if there are no videos to display
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 60),
            Padding(padding: const EdgeInsets.only(top: 16), child: Text('Error: $errorMessage')),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: () => _homeBloc.add(const HomeLoadStarted()), child: const Text('Retry')),
          ],
        ),
      );
    }

    // Loaded or Loading More State (or Error with existing videos)
    if (videos.isEmpty && !isLoadingMore) {
      return const Center(child: Text('No videos found.'));
    }

    return GridView.builder(
      controller: _scrollController,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 16 / 9,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      // Add 1 to item count if loading more
      itemCount: videos.length + (isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        // Show loading indicator at the end if isLoadingMore
        if (isLoadingMore && index == videos.length) {
          return const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()));
        }

        // Handle potential index out of bounds if videos list is modified unexpectedly
        if (index >= videos.length) {
          return const SizedBox.shrink(); // Should not happen in normal flow
        }

        final video = videos[index];
        return VideoCard(video: video, isSelected: index == _selectedIndex, onTap: () => _playVideo(video.id));
      },
    );
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    final homeState = _homeBloc.state;
    List<VideoModel> videos = [];
    bool hasMore = false;

    // Extract videos and hasMore status safely
    switch (homeState) {
      case HomeLoaded(videos: final loadedVideos, hasMore: final loadedHasMore):
        videos = loadedVideos;
        hasMore = loadedHasMore;
      case HomeLoadingMore(videos: final loadingMoreVideos):
        videos = loadingMoreVideos;
        // Assume hasMore might be true if we are loading more
        hasMore = true;
      case HomeError(videos: final errorVideos, hasMore: final errorHasMore):
        videos = errorVideos ?? [];
        hasMore = errorHasMore ?? false;
      // Handle other potential states if necessary, or provide a default
      case HomeInitial():
      case HomeLoading():
        // No specific action needed here for video/hasMore extraction
        break;
    }

    logger.d('Key pressed: ${event.logicalKey.debugName}, Videos: ${videos.length}, Selected: $_selectedIndex');
    if (videos.isEmpty) return;

    final int videosPerRow = 3;
    final int rowCount = (videos.length / videosPerRow).ceil();
    int newSelectedIndex = _selectedIndex; // Calculate new index first

    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      if (_selectedIndex < videos.length - 1) {
        newSelectedIndex++;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      if (_selectedIndex > 0) {
        newSelectedIndex--;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      final int currentRow = _selectedIndex ~/ videosPerRow;
      if (currentRow < rowCount - 1) {
        final int potentialNextIndex = _selectedIndex + videosPerRow;
        newSelectedIndex = potentialNextIndex < videos.length ? potentialNextIndex : videos.length - 1;

        // If we're near the bottom, try to load more videos
        if (newSelectedIndex >= videos.length - videosPerRow && hasMore && homeState is! HomeLoadingMore) {
          _homeBloc.add(const HomeLoadMoreRequested());
        }
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      final int currentRow = _selectedIndex ~/ videosPerRow;
      if (currentRow > 0) {
        newSelectedIndex -= videosPerRow;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.select || event.logicalKey == LogicalKeyboardKey.enter) {
      if (_selectedIndex < videos.length) {
        _playVideo(videos[_selectedIndex].id);
      }
      return; // Don't update state or scroll for select/enter
    }

    // Update state only if index changed
    if (newSelectedIndex != _selectedIndex) {
      setState(() {
        _selectedIndex = newSelectedIndex;
        _ensureItemVisible();
      });
    }
  }

  /// Ensure the selected item is visible in the viewport
  void _ensureItemVisible() {
    final homeState = _homeBloc.state;
    List<VideoModel> videos = [];

    // Extract videos safely
    switch (homeState) {
      case HomeLoaded(videos: final loadedVideos):
        videos = loadedVideos;
      case HomeLoadingMore(videos: final loadingMoreVideos):
        videos = loadingMoreVideos;
      case HomeError(videos: final errorVideos):
        videos = errorVideos ?? [];
      // Handle other potential states if necessary, or provide a default
      case HomeInitial():
      case HomeLoading():
        // No specific action needed here for video extraction
        break;
    }

    if (videos.isEmpty || _selectedIndex >= videos.length) return;

    final int videosPerRow = 3;
    // Calculate item height based on aspect ratio and cross axis count
    final double itemWidth = (MediaQuery.of(context).size.width - (videosPerRow + 1) * 16) / videosPerRow;
    final double itemHeight = itemWidth / (16 / 9) + 16; // Add spacing

    final double targetPosition = ((_selectedIndex ~/ videosPerRow) * itemHeight) - 16; // Adjust for padding

    // Check if item is outside the visible viewport buffer (e.g., one row above or below)
    final double buffer = itemHeight;
    final double currentScroll = _scrollController.position.pixels;
    final double viewportHeight = _scrollController.position.viewportDimension;

    if (targetPosition < currentScroll - buffer ||
        targetPosition > currentScroll + viewportHeight - itemHeight + buffer) {
      // Calculate a clamped position to avoid overscrolling
      double clampedPosition = targetPosition.clamp(
        _scrollController.position.minScrollExtent,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.animateTo(
        clampedPosition,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _playVideo(String videoId) {
    context.go('${AppRoutes.player}/$videoId');
  }
}
