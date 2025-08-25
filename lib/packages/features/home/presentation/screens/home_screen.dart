import 'package:anistar_tv/packages/features/video_list/domain/models/video_model.dart';
import 'package:anistar_tv/packages/features/video_list/presentation/screens/video_list_screen.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onVideoTap});

  final void Function(VideoModel) onVideoTap;

  @override
  Widget build(BuildContext context) {
    return VideoListScreen(
      baseUrl: 'https://v7.astar.bz', // Base URL for the home page videos
      onVideoTap: onVideoTap,
    );
  }
}
