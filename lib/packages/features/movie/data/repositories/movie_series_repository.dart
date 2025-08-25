import 'package:anistar_tv/packages/core/services/jw_scraper/jw_player_scraper_service.dart';
import 'package:anistar_tv/packages/core/services/jw_scraper/models/jw_video_info.dart';

import '../../domain/models/movie_model.dart';

/// Repository for fetching and mapping series data for MovieScreen.
class MovieSeriesRepository {
  final JwPlayerScraperService scraperService;

  MovieSeriesRepository({required this.scraperService});

  /// Fetches series data from the given [url] and maps it to a list of [Series].
  Future<Iterable<MovieModel>> fetchSeriesList(String url) async {
    final List<JwVideoInfo> jwSeriesList = await scraperService.scrape(url);

    final Iterable<MovieModel> movieList = jwSeriesList.map(
      (info) =>
          MovieModel(title: info.title, imageUrl: info.posterUrl, isViewed: info.isViewed, videoUrl: info.videoUrl),
    );

    return movieList;
  }
}
