import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../../../features/favorites/services/favorites_service.dart';
import '../../../../features/home/models/video_model.dart';

/// Widget for video player controls
class PlayerControls extends StatelessWidget {
  /// The video being played
  final VideoModel video;

  /// The video player controller
  final VideoPlayerController? controller;

  /// Whether the video is currently playing
  final bool isPlaying;

  /// Callback when play/pause button is pressed
  final VoidCallback onPlayPause;

  /// Callback when seek backward button is pressed
  final VoidCallback onSeekBackward;

  /// Callback when seek forward button is pressed
  final VoidCallback onSeekForward;

  /// Callback when favorite button is pressed
  final VoidCallback onToggleFavorite;

  /// Callback when back button is pressed
  final VoidCallback onBack;

  /// Constructor
  const PlayerControls({
    super.key,
    required this.video,
    required this.controller,
    required this.isPlaying,
    required this.onPlayPause,
    required this.onSeekBackward,
    required this.onSeekForward,
    required this.onToggleFavorite,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final favoritesService = Provider.of<FavoritesService>(context);
    final isFavorite = favoritesService.isFavorite(video.id);

    return Stack(
      fit: StackFit.expand,
      children: [
        // Semi-transparent background
        Container(color: Colors.black.withValues(alpha: .7)),

        // Top bar with title and back button
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black.withValues(alpha: .7), Colors.transparent],
              ),
            ),
            child: Row(
              children: [
                IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: onBack),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.title,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(video.category, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: isFavorite ? Colors.red : Colors.white,
                  ),
                  onPressed: onToggleFavorite,
                ),
              ],
            ),
          ),
        ),

        // Center controls
        Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ControlButton(icon: Icons.replay_10, onPressed: onSeekBackward),
              const SizedBox(width: 32),
              _ControlButton(icon: isPlaying ? Icons.pause : Icons.play_arrow, size: 64, onPressed: onPlayPause),
              const SizedBox(width: 32),
              _ControlButton(icon: Icons.forward_10, onPressed: onSeekForward),
            ],
          ),
        ),

        // Progress bar
        if (controller != null && controller!.value.isInitialized)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withValues(alpha: .7), Colors.transparent],
                ),
              ),
              child: Column(
                children: [
                  VideoProgressIndicator(
                    controller!,
                    allowScrubbing: true,
                    colors: const VideoProgressColors(
                      playedColor: Colors.red,
                      bufferedColor: Colors.white24,
                      backgroundColor: Colors.white12,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_formatDuration(controller!.value.position), style: const TextStyle(color: Colors.white)),
                      Text(_formatDuration(controller!.value.duration), style: const TextStyle(color: Colors.white)),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

/// Button for player controls
class _ControlButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback onPressed;

  const _ControlButton({super.key, required this.icon, this.size = 40, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), shape: BoxShape.circle),
      child: IconButton(icon: Icon(icon, color: Colors.white), iconSize: size, onPressed: onPressed),
    );
  }
}
