import 'package:anistar_tv/app/app_routes.dart';
import 'package:anistar_tv/packages/features/video_list/domain/models/video_model.dart';
import 'package:anistar_tv/packages/features/video_list/presentation/screens/video_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MovieScreen extends StatelessWidget {
  final VideoModel movie;

  const MovieScreen({super.key, required this.movie});

  @override
  Widget build(BuildContext context) {
    // Basic structure: AppBar + Column with placeholder details + Related videos list
    return Scaffold(
      appBar: AppBar(
        title: Text(movie.title), // Display the movie title
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Placeholder for Movie Details - Replace with actual implementation later
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              height: 150, // Example height
              color: Colors.blueGrey[100],
              child: Center(child: Text('Details for Movie ${movie.title} will go here')),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text('Related Videos', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ),
          // VideoListScreen for related videos, taking remaining space
          Expanded(
            child: VideoListScreen(
              // Construct the baseUrl for related videos using the movieId
              baseUrl: '/movie/${movie.id}/related',
              onVideoTap: (newVideoId) {
                // Navigate to another movie screen when a related video is tapped
                // Use push to keep the navigation history
                context.push(AppRoutes.movie.replaceFirst(':movieId', newVideoId.id));
              },
            ),
          ),
        ],
      ),
    );
  }
}
