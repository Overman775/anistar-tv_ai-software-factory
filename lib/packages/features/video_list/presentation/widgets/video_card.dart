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
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? Border.all(color: colorScheme.primary, width: 3) : null,
          boxShadow:
              isSelected
                  ? [BoxShadow(color: colorScheme.primary.withValues(alpha: 0.5), blurRadius: 10, spreadRadius: 2)]
                  : null,
        ),
        child: Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Stack(
            // Changed from Column to Stack
            alignment: Alignment.bottomCenter, // Align children to the bottom center
            children: [
              // Thumbnail - Takes full space of the card
              Positioned.fill(
                child: CachedNetworkImage(
                  imageUrl: video.thumbnailUrl.toString(),
                  fit: BoxFit.cover,
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

              // Darkened overlay for text
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.9), // More opaque at the bottom
                        Colors.black.withValues(alpha: 0.1), // Less transparent at the top
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.all(8.0), // Padding inside the overlay
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min, // Take minimum space needed
                    children: [
                      Text(
                        video.title,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white, // Ensure text is visible
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      // Display only category here now
                      Text(
                        video.category,
                        style: textTheme.bodySmall?.copyWith(
                          color: Colors.white70, // Ensure text is visible
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Rating in top-right corner
              if (video.rating != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6), // Semi-transparent background
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 14), // Slightly smaller icon
                        const SizedBox(width: 4),
                        Text(
                          video.rating!.toStringAsFixed(1),
                          style: textTheme.bodySmall?.copyWith(
                            // Slightly larger text
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
