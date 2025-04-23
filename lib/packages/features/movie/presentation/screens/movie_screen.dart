import 'package:anistar_tv/packages/core/services/jw_scraper/jw_player_scraper_service.dart';
import 'package:anistar_tv/packages/features/movie/data/repositories/movie_series_repository.dart';
import 'package:anistar_tv/packages/features/movie/presentation/widgets/movie_card.dart'; // Import MovieCard
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../video_list/domain/models/video_model.dart';
import '../../domain/models/movie_model.dart';

class MovieScreen extends StatefulWidget {
  // Use Movie model instead of VideoModel
  final VideoModel video;
  // Rename callback and update type
  final void Function(Movie) onMovieTap;

  const MovieScreen({
    super.key,
    required this.video,
    required this.onMovieTap, // Updated parameter name
  });

  @override
  State<MovieScreen> createState() => _MovieScreenState();
}

class _MovieScreenState extends State<MovieScreen> {
  // Rename future variable
  late Future<Iterable<Movie>> _moviesFuture;
  int _focusedIndex = -1; // Track focused index, -1 means none

  @override
  void initState() {
    super.initState();
    final scraperService = context.read<JwPlayerScraperService>();
    final repo = MovieSeriesRepository(scraperService: scraperService);
    // Assuming fetchSeriesList actually fetches related movies or episodes based on the URL
    // If this needs to fetch *this* movie's details, the logic might need adjustment
    // For now, we assume it fetches a list of movies related to the input movie's videoUrl
    _moviesFuture = repo.fetchSeriesList(widget.video.videoUrl);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Use the movie title passed in the constructor
      appBar: AppBar(title: Text(widget.video.title)),
      body: FutureBuilder<Iterable<Movie>>(
        future: _moviesFuture, // Use renamed future
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            // Provide more specific error feedback if possible
            return Center(child: Text('Failed to load movies: ${snapshot.error}'));
          } else if (snapshot.hasData) {
            // Convert Iterable to List to use index operator [] or elementAt
            final moviesList = snapshot.data!.toList();
            if (moviesList.isEmpty) {
              return const Center(child: Text('No movies available'));
            }

            // Use GridView.builder for 3 columns
            return GridView.builder(
              padding: const EdgeInsets.all(16.0), // Add padding around the grid
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, // 3 items per row
                crossAxisSpacing: 16.0, // Spacing between columns
                mainAxisSpacing: 16.0, // Spacing between rows
                childAspectRatio: 16 / 11, // Adjust aspect ratio (width/height) for horizontal card + title
              ),
              itemCount: moviesList.length,
              itemBuilder: (context, index) {
                final movieItem = moviesList[index];
                final isFocused = _focusedIndex == index;

                // Use Focus widget to manage focus state
                return Focus(
                  onFocusChange: (hasFocus) {
                    setState(() {
                      _focusedIndex = hasFocus ? index : -1;
                    });
                  },
                  child: MovieCard(
                    movie: movieItem,
                    isFocused: isFocused,
                    onTap: () => widget.onMovieTap(movieItem), // Use updated callback
                  ),
                );
              },
            );
          } else {
            // This case might indicate an empty but non-error state from the future
            return const Center(child: Text('No movies found'));
          }
        },
      ),
    );
  }
}
