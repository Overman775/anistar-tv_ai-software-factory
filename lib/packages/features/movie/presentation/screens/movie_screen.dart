import 'package:anistar_tv/packages/core/services/jw_scraper/jw_player_scraper_service.dart';
import 'package:anistar_tv/packages/features/movie/data/repositories/movie_series_repository.dart';
import 'package:anistar_tv/packages/features/series_list/domain/models/series_model.dart';
import 'package:anistar_tv/packages/features/series_list/presentation/widgets/series_card.dart';
import 'package:anistar_tv/packages/features/video_list/domain/models/video_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MovieScreen extends StatefulWidget {
  final VideoModel movie;
  final void Function(Series) onSeriesTap;

  const MovieScreen({super.key, required this.movie, required this.onSeriesTap});

  @override
  State<MovieScreen> createState() => _MovieScreenState();
}

class _MovieScreenState extends State<MovieScreen> {
  late Future<List<Series>> _seriesFuture;

  @override
  void initState() {
    super.initState();
    final scraperService = context.read<JwPlayerScraperService>();
    final repo = MovieSeriesRepository(scraperService: scraperService);
    // Use movie.url or similar as the source for series scraping
    _seriesFuture = repo.fetchSeriesList(widget.movie.videoUrl);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.movie.title)),
      body: FutureBuilder<List<Series>>(
        future: _seriesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return const Center(child: Text('Failed to load series'));
          } else if (snapshot.hasData) {
            final seriesList = snapshot.data!;
            if (seriesList.isEmpty) {
              return const Center(child: Text('No series available'));
            }
            return ListView.builder(
              itemCount: seriesList.length,
              itemBuilder: (context, index) {
                final series = seriesList[index];
                return SeriesCard(series: series, isFocused: false, onTap: () => widget.onSeriesTap(series));
              },
            );
          } else {
            return const Center(child: Text('No series available'));
          }
        },
      ),
    );
  }
}
