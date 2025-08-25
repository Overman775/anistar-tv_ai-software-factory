import 'package:anistar_tv/packages/core/services/jw_scraper/jw_player_scraper_service.dart';
import 'package:anistar_tv/packages/features/movie/data/repositories/movie_series_repository.dart';
import 'package:anistar_tv/packages/features/movie/presentation/widgets/movie_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import for KeyEvent
import 'package:provider/provider.dart';

import '../../domain/models/movie_model.dart';

class MovieScreen extends StatefulWidget {
  final String title;
  final String videoUrl;
  final void Function(MovieModel) onMovieTap;

  const MovieScreen({super.key, required this.title, required this.videoUrl, required this.onMovieTap});

  @override
  State<MovieScreen> createState() => _MovieScreenState();
}

class _MovieScreenState extends State<MovieScreen> {
  late Future<Iterable<MovieModel>> _moviesFuture;
  int _selectedIndex = 0; // Track selected index
  final FocusNode _gridFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  // Add state variable for movies list
  List<MovieModel> _moviesList = [];

  @override
  void initState() {
    super.initState();
    final scraperService = context.read<JwPlayerScraperService>();
    final repo = MovieSeriesRepository(scraperService: scraperService);
    _moviesFuture = repo.fetchSeriesList(widget.videoUrl);

    _gridFocusNode.requestFocus();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _gridFocusNode.dispose();
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    if (_moviesList.isEmpty) return;

    const int itemsPerRow = 3; // Fixed number of items per row
    final int rowCount = (_moviesList.length / itemsPerRow).ceil();
    int newSelectedIndex = _selectedIndex;

    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      if (_selectedIndex < _moviesList.length - 1) {
        newSelectedIndex++;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      if (_selectedIndex > 0) {
        newSelectedIndex--;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      final int currentRow = _selectedIndex ~/ itemsPerRow;
      if (currentRow < rowCount - 1) {
        final int potentialNextIndex = _selectedIndex + itemsPerRow;
        newSelectedIndex = potentialNextIndex < _moviesList.length ? potentialNextIndex : _moviesList.length - 1;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      final int currentRow = _selectedIndex ~/ itemsPerRow;
      if (currentRow > 0) {
        newSelectedIndex -= itemsPerRow;
        if (newSelectedIndex < 0) newSelectedIndex = 0;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.select || event.logicalKey == LogicalKeyboardKey.enter) {
      if (_selectedIndex < _moviesList.length) {
        widget.onMovieTap(_moviesList[_selectedIndex]);
      }
      return; // Don't update state or scroll for select/enter
    }

    if (newSelectedIndex != _selectedIndex) {
      setState(() {
        _selectedIndex = newSelectedIndex;
        _ensureItemVisible(itemsPerRow);
      });
    }
  }

  void _ensureItemVisible(int itemsPerRow) {
    if (_moviesList.isEmpty || _selectedIndex >= _moviesList.length) return;

    // Calculate item height based on aspect ratio and fixed cross axis count
    final double screenWidth = MediaQuery.of(context).size.width;
    final double totalHorizontalPadding = 2 * 16; // Padding on both sides of the grid
    final double totalHorizontalSpacing = 16 * (itemsPerRow - 1); // Spacing between items
    final double availableWidth = screenWidth - totalHorizontalPadding - totalHorizontalSpacing;
    final double itemWidth = availableWidth / itemsPerRow;
    final double itemHeight = itemWidth / (16 / 11) + 16; // Use MovieCard's aspect ratio and add main axis spacing

    final double targetPosition = ((_selectedIndex ~/ itemsPerRow) * itemHeight);

    final double currentScroll = _scrollController.position.pixels;
    final double viewportHeight = _scrollController.position.viewportDimension;

    double scrollTarget = currentScroll;

    if (targetPosition < currentScroll) {
      scrollTarget = targetPosition;
    } else if (targetPosition + itemHeight > currentScroll + viewportHeight) {
      scrollTarget = targetPosition + itemHeight - viewportHeight;
    } else {
      return;
    }

    scrollTarget = scrollTarget.clamp(
      _scrollController.position.minScrollExtent,
      _scrollController.position.maxScrollExtent,
    );

    _scrollController.animateTo(scrollTarget, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  void _onMovieCardTap(MovieModel movieItem, int index) {
    setState(() {
      _selectedIndex = index;
    });
    widget.onMovieTap(movieItem);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: KeyboardListener(
        focusNode: _gridFocusNode,
        onKeyEvent: _handleKeyEvent,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: FutureBuilder<Iterable<MovieModel>>(
            future: _moviesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text('Failed to load movies: ${snapshot.error}'));
              } else if (snapshot.hasData) {
                // Store the movies list in the state
                _moviesList = snapshot.data?.toList() ?? [];
                if (_moviesList.isEmpty) {
                  return const Center(child: Text('No movies available'));
                }

                // Use GridView.builder for 3 columns

                return GridView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(0), // Padding is already on the parent Padding widget
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, // 3 items per row
                    crossAxisSpacing: 16.0, // Spacing between columns
                    mainAxisSpacing: 16.0, // Spacing between rows
                    childAspectRatio: 16 / 11, // Adjust aspect ratio (width/height) for horizontal card + title
                  ),
                  itemCount: _moviesList.length,
                  itemBuilder: (context, index) {
                    final movieItem = _moviesList[index];
                    final isSelected = _selectedIndex == index;

                    return MovieCard(
                      movie: movieItem,
                      isFocused: isSelected, // Use isSelected for isFocused
                      onTap: () => _onMovieCardTap(movieItem, index),
                    );
                  },
                );
              } else {
                return const Center(child: Text('No movies found'));
              }
            },
          ),
        ),
      ),
    );
  }
}
