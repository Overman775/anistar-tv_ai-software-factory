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
      onVideoTap: (video) {
        // Assuming VideoModel is passed here, adjust if it's just an ID
        // Navigate to the movie screen under favorites
        // The 'video' object (or videoId) will be passed as extra
        context.go('${AppRoutes.favorites}/${AppRoutes.movie}', extra: video);
      },
    );
  }
}
