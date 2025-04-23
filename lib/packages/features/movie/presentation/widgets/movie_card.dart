import 'package:anistar_tv/packages/features/movie/domain/models/movie_model.dart';
import 'package:flutter/material.dart';

class MovieCard extends StatelessWidget {
  final Movie movie;
  final bool isFocused;
  final VoidCallback? onTap;

  const MovieCard({super.key, required this.movie, required this.isFocused, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = isFocused ? theme.focusColor : theme.cardColor;
    // Ensure text color contrasts with the background
    final textColor = isFocused ? theme.colorScheme.onPrimary : theme.textTheme.bodyLarge?.color;

    // Define aspect ratio for horizontal card
    const double cardAspectRatio = 16 / 9;
    // Define a fixed height or calculate based on width constraints if needed
    const double cardHeight = 120.0; // Example fixed height
    final double cardWidth = cardHeight * cardAspectRatio;

    return GestureDetector(
      onTap: onTap,
      child: Card(
        color: cardColor,
        elevation: isFocused ? 8.0 : 2.0, // Add elevation for focus effect
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
          side:
              isFocused
                  ? BorderSide(color: theme.primaryColor, width: 2.0) // Highlight border when focused
                  : BorderSide.none,
        ),
        child: SizedBox(
          width: cardWidth,
          height: cardHeight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch, // Stretch children horizontally
            children: [
              Expanded(
                // Make the image container expand
                child: Stack(
                  fit: StackFit.expand, // Make stack children fill the space
                  children: [
                    // Movie Image
                    if (movie.imageUrl != null)
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(8.0)), // Rounded top corners
                        child: Image.network(
                          movie.imageUrl!,
                          fit: BoxFit.cover, // Cover the area
                          // Optional: Add loading/error builders for better UX
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value:
                                    loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                        : null,
                              ),
                            );
                          },
                          errorBuilder:
                              (context, error, stackTrace) => const Center(child: Icon(Icons.movie, size: 40)),
                        ),
                      )
                    else
                      // Placeholder if no image URL
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(8.0)),
                        child: Container(
                          color: Colors.grey[800], // Placeholder background
                          child: const Center(child: Icon(Icons.movie, size: 40)),
                        ),
                      ),

                    // Watched Indicator (Top Right)
                    if (movie.isViewed)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5), // Semi-transparent background
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
                        ),
                      ),
                  ],
                ),
              ),
              // Movie Title (Below Image)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0), // Padding for the title
                child: Text(
                  movie.title,
                  style: theme.textTheme.bodyMedium?.copyWith(color: textColor),
                  textAlign: TextAlign.center,
                  maxLines: 1, // Limit title to 1 line for horizontal card
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
