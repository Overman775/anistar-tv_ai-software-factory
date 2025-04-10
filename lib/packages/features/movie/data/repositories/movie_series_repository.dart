import 'package:anistar_tv/packages/core/services/jw_scraper/jw_player_scraper_service.dart';
import 'package:anistar_tv/packages/core/services/jw_scraper/models/jw_video_info.dart';
import 'package:anistar_tv/packages/features/series_list/domain/models/series_model.dart';

/// Repository for fetching and mapping series data for MovieScreen.
class MovieSeriesRepository {
  final JwPlayerScraperService scraperService;

  MovieSeriesRepository({required this.scraperService});

  /// Fetches series data from the given [url] and maps it to a list of [Series].
  Future<List<Series>> fetchSeriesList(String url) async {
    final List<JwVideoInfo> jwSeriesList = await scraperService.scrape(url);

    // Map each JwVideoInfo to Series.
    final List<Series> seriesList = [
      for (int i = 0; i < jwSeriesList.length; i++)
        Series(seriesNumber: (i + 1).toString(), title: 'Series ${(i + 1)}', dataUrl: jwSeriesList[i].videoUrl),
    ];

    return seriesList;
  }
}
