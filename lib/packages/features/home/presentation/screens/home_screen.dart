import 'package:anistar_tv/app/app_routes.dart';
import 'package:anistar_tv/packages/features/video_list/presentation/screens/video_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return VideoListScreen(
      baseUrl: 'https://v6.astar.bz', // Base URL for the home page videos
      onVideoTap: (videoId) {
        // Navigate to the movie screen when a video is tapped
        context.go(AppRoutes.movie.replaceFirst(':movieId', videoId.id));
      },
    );
  }
}
