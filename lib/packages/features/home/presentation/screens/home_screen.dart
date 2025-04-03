import 'package:anistar_tv/utils/logger/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../../app/app_routes.dart';
import '../../models/video_model.dart';
import '../../services/video_service.dart';
import '../widgets/video_card.dart';

/// Home screen displaying available videos
class HomeScreen extends StatefulWidget {
  /// Constructor
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<VideoModel> _videos = [];
  int _selectedIndex = 0;
  final FocusNode _gridFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  // Pagination variables
  int _currentPage = 1;
  final int _pageSize = 4;
  bool _isLoading = false;
  bool _hasMoreVideos = true;

  @override
  void initState() {
    super.initState();
    _gridFocusNode.requestFocus();
    _scrollController.addListener(_scrollListener);
    _loadInitialVideos();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _gridFocusNode.dispose();
    super.dispose();
  }

  /// Load the initial set of videos
  Future<void> _loadInitialVideos() async {
    final videoService = Provider.of<VideoService>(context, listen: false);

    setState(() {
      _isLoading = true;
    });

    try {
      final videos = await videoService.getVideosPaginated(_currentPage, _pageSize);
      final hasMore = await videoService.hasMoreVideos(_currentPage, _pageSize);

      setState(() {
        _videos.addAll(videos);
        _hasMoreVideos = hasMore;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      // Handle error
    }
  }

  /// Load more videos when scrolling to the bottom
  Future<void> _loadMoreVideos() async {
    if (_isLoading || !_hasMoreVideos) return;

    final videoService = Provider.of<VideoService>(context, listen: false);

    setState(() {
      _isLoading = true;
    });

    try {
      _currentPage++;
      final videos = await videoService.getVideosPaginated(_currentPage, _pageSize);
      final hasMore = await videoService.hasMoreVideos(_currentPage, _pageSize);

      setState(() {
        _videos.addAll(videos);
        _hasMoreVideos = hasMore;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _currentPage--;
        _isLoading = false;
      });
      // Handle error
    }
  }

  /// Scroll listener to detect when user reaches the bottom
  void _scrollListener() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMoreVideos();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Anistar TV'),
        actions: [IconButton(icon: const Icon(Icons.favorite), onPressed: () => context.go(AppRoutes.favorites))],
      ),
      body: KeyboardListener(
        // Replace RawKeyboardListener with KeyboardListener
        focusNode: _gridFocusNode,
        onKeyEvent: _handleKeyEvent, // Use onKeyEvent instead of onKey
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Home', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Expanded(
                child:
                    _videos.isEmpty && _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : GridView.builder(
                          controller: _scrollController,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 16 / 9,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                          itemCount: _videos.length + (_isLoading && _hasMoreVideos ? 1 : 0),
                          itemBuilder: (context, index) {
                            // Show loading indicator at the end
                            if (index == _videos.length) {
                              return const Center(
                                child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()),
                              );
                            }

                            final video = _videos[index];
                            return VideoCard(
                              video: video,
                              isSelected: index == _selectedIndex,
                              onTap: () => _playVideo(video.id),
                            );
                          },
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleKeyEvent(KeyEvent event) {
    // Update method signature
    if (event is! KeyDownEvent) return; // Check for KeyDownEvent

    logger.d('Key pressed: ${event.logicalKey.debugName}'); // Log the key press
    if (_videos.isEmpty) return;

    final int videosPerRow = 3;
    final int rowCount = (_videos.length / videosPerRow).ceil();

    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      setState(() {
        if (_selectedIndex < _videos.length - 1) {
          _selectedIndex++;
          _ensureItemVisible();
        }
      });
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      setState(() {
        if (_selectedIndex > 0) {
          _selectedIndex--;
          _ensureItemVisible();
        }
      });
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() {
        final int currentRow = _selectedIndex ~/ videosPerRow;
        if (currentRow < rowCount - 1) {
          final int nextIndex = _selectedIndex + videosPerRow;
          _selectedIndex = nextIndex < _videos.length ? nextIndex : _videos.length - 1;
          _ensureItemVisible();

          // If we're near the bottom, try to load more videos
          if (_selectedIndex >= _videos.length - videosPerRow && _hasMoreVideos) {
            _loadMoreVideos();
          }
        }
      });
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() {
        final int currentRow = _selectedIndex ~/ videosPerRow;
        if (currentRow > 0) {
          _selectedIndex -= videosPerRow;
          _ensureItemVisible();
        }
      });
    } else if (event.logicalKey == LogicalKeyboardKey.select || event.logicalKey == LogicalKeyboardKey.enter) {
      _playVideo(_videos[_selectedIndex].id);
    }
  }

  /// Ensure the selected item is visible in the viewport
  void _ensureItemVisible() {
    if (_videos.isEmpty) return;

    final int videosPerRow = 3;
    final double itemHeight = MediaQuery.of(context).size.width / videosPerRow / (16 / 9) + 16;
    final double targetPosition = ((_selectedIndex ~/ videosPerRow) * itemHeight) - 16;

    if (targetPosition < _scrollController.position.pixels ||
        targetPosition >
            _scrollController.position.pixels + _scrollController.position.viewportDimension - itemHeight * 2) {
      _scrollController.animateTo(targetPosition, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  void _playVideo(String videoId) {
    context.go('${AppRoutes.player}/$videoId');
  }
}
