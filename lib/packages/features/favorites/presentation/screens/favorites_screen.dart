import 'package:anistar_tv/app/app_routes.dart';
import 'package:anistar_tv/packages/features/video_list/presentation/screens/video_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return VideoListScreen(
      baseUrl: '/favorites', // Base URL for the favorites page videos
      onVideoTap: (videoId) {
        // Navigate to the movie screen when a video is tapped
        context.go(AppRoutes.movie.replaceFirst(':movieId', videoId.id));
      },
    );
  }
}
