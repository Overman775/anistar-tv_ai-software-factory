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
  late List<VideoModel> _videos;
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
    _videos = videoService.getVideos();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Anistar TV'),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite),
            onPressed: () => context.go(AppRoutes.favorites),
          ),
        ],
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
                'Home',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 16 / 9,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: _videos.length,
                  itemBuilder: (context, index) {
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

  void _handleKeyEvent(RawKeyEvent event) {
    if (event is! RawKeyDownEvent) return;

    final int videosPerRow = 3;
    final int rowCount = (_videos.length / videosPerRow).ceil();

    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      setState(() {
        if (_selectedIndex < _videos.length - 1) {
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
              nextIndex < _videos.length ? nextIndex : _videos.length - 1;
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
      _playVideo(_videos[_selectedIndex].id);
    }
  }

  void _playVideo(String videoId) {
    context.go('${AppRoutes.player}/$videoId');
  }
}
