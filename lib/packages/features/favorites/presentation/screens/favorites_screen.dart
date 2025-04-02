import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../../app/app_routes.dart';
import '../../../home/models/video_model.dart';
import '../../../home/presentation/widgets/video_card.dart';
import '../../../home/services/video_service.dart';
import '../../services/favorites_service.dart';

/// Screen displaying favorite videos
class FavoritesScreen extends StatefulWidget {
  /// Constructor
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  late List<VideoModel> _favoriteVideos;
  int _selectedIndex = 0;
  final FocusNode _gridFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _gridFocusNode.requestFocus();
  }

  @override
  void dispose() {
    _gridFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final videoService = Provider.of<VideoService>(context);
    final favoritesService = Provider.of<FavoritesService>(context);
    _favoriteVideos = favoritesService.getFavoriteVideos(videoService);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorites'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.home),
        ),
      ),
      body: RawKeyboardListener(
        focusNode: _gridFocusNode,
        onKey: _handleKeyEvent,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'My Favorites',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              if (_favoriteVideos.isEmpty)
                const Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.favorite_border,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No favorites yet',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Add videos to your favorites to see them here',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 16 / 9,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                    itemCount: _favoriteVideos.length,
                    itemBuilder: (context, index) {
                      final video = _favoriteVideos[index];
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

  void _handleKeyEvent(RawKeyEvent event) {
    if (event is! RawKeyDownEvent || _favoriteVideos.isEmpty) return;

    final int videosPerRow = 3;
    final int rowCount = (_favoriteVideos.length / videosPerRow).ceil();

    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      setState(() {
        if (_selectedIndex < _favoriteVideos.length - 1) {
          _selectedIndex++;
        }
      });
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      setState(() {
        if (_selectedIndex > 0) {
          _selectedIndex--;
        }
      });
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() {
        final int currentRow = _selectedIndex ~/ videosPerRow;
        if (currentRow < rowCount - 1) {
          final int nextIndex = _selectedIndex + videosPerRow;
          _selectedIndex =
              nextIndex < _favoriteVideos.length
                  ? nextIndex
                  : _favoriteVideos.length - 1;
        }
      });
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() {
        final int currentRow = _selectedIndex ~/ videosPerRow;
        if (currentRow > 0) {
          _selectedIndex -= videosPerRow;
        }
      });
    } else if (event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.enter) {
      _playVideo(_favoriteVideos[_selectedIndex].id);
    } else if (event.logicalKey == LogicalKeyboardKey.escape ||
        event.logicalKey == LogicalKeyboardKey.backspace) {
      context.go(AppRoutes.home);
    }
  }

  void _playVideo(String videoId) {
    context.go('${AppRoutes.player}/$videoId');
  }
}
