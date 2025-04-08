import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/video_model.dart';

/// Card widget for displaying a video
class VideoCard extends StatelessWidget {
  /// The video to display
  final VideoModel video;

  /// Whether this card is currently selected
  final bool isSelected;

  /// Callback when the card is tapped
  final VoidCallback onTap;

  /// Constructor
  const VideoCard({super.key, required this.video, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? Border.all(color: Theme.of(context).colorScheme.primary, width: 3) : null,
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ]
                  : null,
        ),
        child: Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Thumbnail
              CachedNetworkImage(
                imageUrl: video.thumbnailUrl.toString(),
                fit: BoxFit.cover,
                placeholder:
                    (context, url) =>
                        Container(color: Colors.grey.shade800, child: const Center(child: CircularProgressIndicator())),
                errorWidget:
                    (context, url, error) => Container(
                      color: Colors.grey.shade800,
                      child: const Center(child: Icon(Icons.movie, size: 48, color: Colors.white54)),
                    ),
              ),

              // Gradient overlay
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                      stops: const [0.6, 1.0],
                    ),
                  ),
                ),
              ),

              // Video info
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${video.duration.inMinutes}:${(video.duration.inSeconds % 60).toString().padLeft(2, '0')} • ${video.category}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
