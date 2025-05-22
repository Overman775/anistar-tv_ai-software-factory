import 'package:anistar_tv/app/app_config.dart';
import 'package:anistar_tv/app/app_routes.dart';
import 'package:anistar_tv/utils/logger/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';

import '../../../../../packages/core/services/html_parser_service.dart'; // Added import
import '../../data/datasources/video_list_remote_datasource.dart';
import '../../data/repositories/video_list_repository_impl.dart';
import '../../domain/models/video_model.dart';
import '../../domain/repositories/video_list_repository.dart';
import '../../domain/usecases/get_videos_paginated_usecase.dart';
import '../bloc/video_list_bloc.dart';
import '../widgets/video_card.dart'; // Will be moved/created shortly

// Dependency Injection setup (replace with your actual DI solution if available)
// For simplicity, creating instances directly here or using context.read if provided globally.
VideoListRepository _createRepository(BuildContext context) {
  // Assuming HtmlParserService and Logger are provided higher up or globally
  // If using GetIt or Provider, fetch instances here.
  // final htmlParser = context.read<HtmlParserService>(); // Example with Provider
  // final logger = context.read<Logger>(); // Example with Provider
  final htmlParser = context.read<HtmlParserService>(); // Assuming provided
  final logger = Logger(); // Or get from context/DI

  final remoteDataSource = VideoListRemoteDataSourceImpl(htmlParserService: htmlParser, logger: logger);
  return VideoListRepositoryImpl(remoteDataSource: remoteDataSource, logger: logger);
}

GetVideosPaginatedUseCase _createUseCase(BuildContext context) {
  final repository = _createRepository(context);
  final logger = Logger(); // Or get from context/DI
  return GetVideosPaginatedUseCase(repository: repository, logger: logger);
}

// --- VideoListScreen Widget ---

/// A screen that displays a list of videos fetched from a given [baseUrl].
///
/// Requires a [baseUrl] to fetch the video list and an [onVideoTap] callback
/// function that is executed when a video card is tapped.
class VideoListScreen extends StatefulWidget {
  final String baseUrl;
  final Function(VideoModel video) onVideoTap;
  final String title; // Optional title for the AppBar

  const VideoListScreen({
    required this.baseUrl,
    required this.onVideoTap,
    this.title = 'Videos', // Default title
    super.key,
  });

  @override
  State<VideoListScreen> createState() => _VideoListScreenState();
}

class _VideoListScreenState extends State<VideoListScreen> {
  // UI specific state
  int _selectedIndex = 0;
  final FocusNode _gridFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  // BLoC instance
  late final VideoListBloc _videoListBloc;

  @override
  void initState() {
    super.initState();
    // Create BLoC instance, injecting UseCase and baseUrl
    _videoListBloc = VideoListBloc(
      getVideosPaginatedUseCase: _createUseCase(context), // Create/Get UseCase
      baseUrl: widget.baseUrl,
      logger: logger, // Use the underlying Logger instance from AppLogger
    );
    // Dispatch initial event
    _videoListBloc.add(const VideoListLoadStarted());

    _gridFocusNode.requestFocus();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _gridFocusNode.dispose();
    _videoListBloc.close(); // Close the BLoC
    super.dispose();
  }

  /// Scroll listener to detect when user reaches the bottom for pagination.
  void _scrollListener() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      final videoListState = _videoListBloc.state;
      bool canLoadMore = false;

      // Check if we can load more based on the current state
      if (videoListState is VideoListLoaded && videoListState.hasMore) {
        canLoadMore = true;
      } else if (videoListState is VideoListError && (videoListState.hasMore ?? false)) {
        // Allow retry/load more even from error state if hasMore was true
        canLoadMore = true;
      }

      // Only add event if we can load more and are not already loading more
      if (canLoadMore && videoListState is! VideoListLoadingMore) {
        _videoListBloc.add(const VideoListLoadMoreRequested());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Provide the BLoC instance to the widget tree below
    return BlocProvider.value(
      value: _videoListBloc,
      child: Scaffold(
        // AppBar can be customized or removed depending on usage context
        appBar: AppBar(
          title: Text(widget.title),
          // Example action: Refresh button
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => _videoListBloc.add(const VideoListLoadStarted()),
              tooltip: 'Refresh',
            ),
            if (AppConfig.isDevFlavor) // Show log button only in dev flavor
              IconButton(
                icon: const Icon(Icons.article_outlined), // Or Icons.description, Icons.list_alt
                tooltip: 'View Logs',
                onPressed: () {
                  context.push(AppRoutes.logViewer);
                },
              ),
          ],
        ),
        body: KeyboardListener(
          focusNode: _gridFocusNode,
          onKeyEvent: _handleKeyEvent,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            // Use BlocBuilder to react to state changes
            child: BlocBuilder<VideoListBloc, VideoListState>(
              builder: (context, state) {
                // Extract videos and status safely from state
                List<VideoModel> videos = [];
                bool isLoadingMore = false;
                String? errorMessage;
                bool hasMore = true; // Assume true initially

                // Use pattern matching on the state
                switch (state) {
                  case VideoListLoaded(videos: final loadedVideos, hasMore: final loadedHasMore):
                    videos = loadedVideos;
                    hasMore = loadedHasMore;
                  case VideoListLoadingMore(videos: final loadingMoreVideos):
                    videos = loadingMoreVideos;
                    isLoadingMore = true;
                  // hasMore is implicitly true if we are loading more
                  case VideoListError(message: final errorMsg, videos: final errorVideos, hasMore: final errorHasMore):
                    videos = errorVideos ?? []; // Show previous videos if available
                    errorMessage = errorMsg;
                    hasMore = errorHasMore ?? false; // Use stored hasMore or default to false
                  case VideoListInitial():
                  case VideoListLoading():
                    // Handled by _buildContent's initial loading check
                    break;
                }

                return _buildContent(context, state, videos, isLoadingMore, errorMessage, hasMore);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    VideoListState state,
    List<VideoModel> videos,
    bool isLoadingMore,
    String? errorMessage,
    bool hasMore, // Needed for keyboard navigation logic
  ) {
    // Initial Loading State
    if (state is VideoListInitial || state is VideoListLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Error State (only if no videos are available to show)
    if (errorMessage != null && videos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 60),
            Padding(padding: const EdgeInsets.only(top: 16), child: Text('Error: $errorMessage')),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _videoListBloc.add(const VideoListLoadStarted()),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    // Empty State (after loading, but no videos found)
    if (videos.isEmpty && !isLoadingMore && errorMessage == null) {
      return const Center(child: Text('No videos found.'));
    }

    // Loaded or Loading More State (or Error with existing videos)
    // Calculate cross axis count based on screen width (example)
    // final screenWidth = MediaQuery.of(context).size.width;
    // final crossAxisCount = (screenWidth / 200).floor().clamp(2, 5); // Adjust 200 based on desired item width
    const crossAxisCount = 4; // Fixed cross axis count

    return GridView.builder(
      controller: _scrollController,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount, // Use the fixed value
        childAspectRatio: 2 / 3, // Aspect ratio for vertical cards
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      // Add 1 to item count if loading more or if there's an error message to display at the bottom
      itemCount: videos.length + (isLoadingMore || (errorMessage != null && videos.isNotEmpty) ? 1 : 0),
      itemBuilder: (context, index) {
        // Show loading indicator at the end if isLoadingMore
        if (isLoadingMore && index == videos.length) {
          return const Center(
            child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()),
          );
        }

        // Show error message at the bottom if applicable (and not already showing full-screen error)
        if (errorMessage != null && videos.isNotEmpty && index == videos.length) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text('Error loading more: $errorMessage', style: const TextStyle(color: Colors.orange)),
            ),
          );
        }

        // Handle potential index out of bounds
        if (index >= videos.length) {
          return const SizedBox.shrink(); // Should not happen in normal flow
        }

        final video = videos[index];
        return VideoCard(
          video: video,
          isSelected: index == _selectedIndex,
          onTap: () {
            // Update selection and call the callback
            setState(() {
              _selectedIndex = index;
            });
            widget.onVideoTap(video);
          },
        );
      },
    );
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    final videoListState = _videoListBloc.state;
    List<VideoModel> videos = [];
    bool hasMore = false;

    // Extract videos and hasMore status safely
    switch (videoListState) {
      case VideoListLoaded(videos: final loadedVideos, hasMore: final loadedHasMore):
        videos = loadedVideos;
        hasMore = loadedHasMore;
      case VideoListLoadingMore(videos: final loadingMoreVideos):
        videos = loadingMoreVideos;
        hasMore = true; // Assume hasMore if loading more
      case VideoListError(videos: final errorVideos, hasMore: final errorHasMore):
        videos = errorVideos ?? [];
        hasMore = errorHasMore ?? false;
      case VideoListInitial():
      case VideoListLoading():
        break; // No videos to navigate
    }

    logger.d('Key pressed: ${event.logicalKey.debugName}, Videos: ${videos.length}, Selected: $_selectedIndex');
    if (videos.isEmpty) return;

    // Calculate grid dimensions based on fixed crossAxisCount
    // final screenWidth = MediaQuery.of(context).size.width;
    // final videosPerRow = (screenWidth / 200).floor().clamp(2, 5);
    const videosPerRow = 4; // Use fixed value
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
        if (newSelectedIndex >= videos.length - videosPerRow && hasMore && videoListState is! VideoListLoadingMore) {
          _videoListBloc.add(const VideoListEvent.loadMoreRequested());
        }
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      final int currentRow = _selectedIndex ~/ videosPerRow;
      if (currentRow > 0) {
        newSelectedIndex -= videosPerRow;
        // Ensure index doesn't go below 0 (shouldn't happen with check, but safety)
        if (newSelectedIndex < 0) newSelectedIndex = 0;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.select || event.logicalKey == LogicalKeyboardKey.enter) {
      if (_selectedIndex < videos.length) {
        widget.onVideoTap(videos[_selectedIndex]);
      }
      return; // Don't update state or scroll for select/enter
    }

    // Update state only if index changed
    if (newSelectedIndex != _selectedIndex) {
      setState(() {
        _selectedIndex = newSelectedIndex;
        _ensureItemVisible(videosPerRow); // Pass videosPerRow
      });
    }
  }

  /// Ensure the selected item is visible in the viewport
  void _ensureItemVisible(int videosPerRow) {
    final videoListState = _videoListBloc.state;
    List<VideoModel> videos = [];

    // Extract videos safely
    switch (videoListState) {
      case VideoListLoaded(videos: final loadedVideos):
        videos = loadedVideos;
      case VideoListLoadingMore(videos: final loadingMoreVideos):
        videos = loadingMoreVideos;
      case VideoListError(videos: final errorVideos):
        videos = errorVideos ?? [];
      case VideoListInitial():
      case VideoListLoading():
        return; // No videos to ensure visibility for
    }

    if (videos.isEmpty || _selectedIndex >= videos.length) return;

    // Calculate item height based on aspect ratio and fixed cross axis count
    final double screenWidth = MediaQuery.of(context).size.width;
    // Subtract padding (16 on each side) and spacing between items
    final double totalHorizontalPadding = 16 * 2;
    final double totalHorizontalSpacing = 16 * (videosPerRow - 1); // videosPerRow is now 4
    final double availableWidth = screenWidth - totalHorizontalPadding - totalHorizontalSpacing;
    final double itemWidth = availableWidth / videosPerRow; // videosPerRow is now 4
    final double itemHeight = itemWidth / (2 / 3) + 16; // Use new aspect ratio and add main axis spacing

    final double targetPosition = ((_selectedIndex ~/ videosPerRow) * itemHeight) - 16; // Adjust for top padding

    // Check if item is outside the visible viewport buffer (e.g., one row above or below)
    final double currentScroll = _scrollController.position.pixels;
    final double viewportHeight = _scrollController.position.viewportDimension;

    // Determine scroll target position
    double scrollTarget = currentScroll; // Default to current position

    if (targetPosition < currentScroll) {
      // Item is above the viewport
      scrollTarget = targetPosition;
    } else if (targetPosition + itemHeight > currentScroll + viewportHeight) {
      // Item is below the viewport
      scrollTarget = targetPosition + itemHeight - viewportHeight + 16; // Adjust for bottom padding
    } else {
      // Item is already within the viewport, no need to scroll
      return;
    }

    // Clamp the scroll target to valid bounds
    scrollTarget = scrollTarget.clamp(
      _scrollController.position.minScrollExtent,
      _scrollController.position.maxScrollExtent,
    );

    _scrollController.animateTo(scrollTarget, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }
}
