import 'package:anistar_tv/packages/features/video_list/domain/models/video_model.dart';
import 'package:flutter/material.dart';

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
      body: Container(),
    );
  }
}
