import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../domain/models/video_model.dart'; // Updated import path

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
          child: Column(
            // Changed from Stack to Column
            crossAxisAlignment: CrossAxisAlignment.stretch, // Stretch children horizontally
            children: [
              // Thumbnail - Use AspectRatio to maintain image proportions
              AspectRatio(
                aspectRatio: 16 / 9, // Or adjust as needed for the image source
                child: CachedNetworkImage(
                  imageUrl: video.thumbnailUrl.toString(),
                  fit: BoxFit.cover, // Cover the aspect ratio area
                  placeholder:
                      (context, url) => Container(
                        color: Colors.grey.shade800,
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                  errorWidget:
                      (context, url, error) => Container(
                        color: Colors.grey.shade800,
                        child: const Center(child: Icon(Icons.movie, size: 48, color: Colors.white54)),
                      ),
                ),
              ),

              // Video info below the image
              Padding(
                padding: const EdgeInsets.all(8.0), // Add padding around the text
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.title,
                      // Use theme text style for consistency
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 2, // Allow two lines for title
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${video.duration.inMinutes}:${(video.duration.inSeconds % 60).toString().padLeft(2, '0')} • ${video.category}',
                      style: Theme.of(context).textTheme.bodySmall, // Use theme text style
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
