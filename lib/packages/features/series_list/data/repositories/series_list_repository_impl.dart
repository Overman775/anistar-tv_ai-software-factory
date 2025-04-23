import 'package:anistar_tv/packages/features/series_list/data/datasources/series_list_remote_datasource.dart';
import 'package:anistar_tv/packages/features/series_list/domain/models/series_model.dart';
import 'package:anistar_tv/packages/features/series_list/domain/repositories/series_list_repository.dart';
import 'package:html/parser.dart' show parse;
import 'package:logger/logger.dart';

class SeriesListRepositoryImpl implements SeriesListRepository {
  final SeriesListRemoteDatasource _remoteDatasource;
  final Logger _logger;

  SeriesListRepositoryImpl({required SeriesListRemoteDatasource remoteDatasource, Logger? logger})
    : _remoteDatasource = remoteDatasource,
      _logger = logger ?? Logger();

  @override
  Future<List<Series>> getSeriesList(String url) async {
    _logger.i('Fetching series list for URL: $url');
    try {
      final htmlContent = await _remoteDatasource.fetchSeriesHtml(url);
      _logger.t('Received HTML content for parsing series list.');

      final seriesList = _parseSeriesList(htmlContent, url);
      _logger.i('Successfully parsed ${seriesList.length} series from $url');
      return seriesList;
    } catch (e, stackTrace) {
      _logger.e('Failed to get series list for $url', error: e, stackTrace: stackTrace);
      // Re-throw or handle as appropriate for the application's error strategy
      throw Exception('Could not fetch or parse series list: $e');
    }
  }

  List<Series> _parseSeriesList(String htmlContent, String baseUrl) {
    final document = parse(htmlContent);
    final List<Series> seriesList = [];
    _logger.t('Starting series list parsing from HTML.');

    // --- CSS Selector Assumption ---
    // This selector targets links within list items inside a 'ul' with class 'video_list'.
    // This is a common pattern but MIGHT NEED ADJUSTMENT based on the actual site structure of astar.bz.
    // Inspecting the target page's HTML is crucial for accuracy.
    const String seriesLinkSelector = 'ul.video_list li a'; // Example selector
    // Alternative selectors to consider if the above fails:
    // 'div.series-container .episode-link'
    // '#episodeList > li > a'

    final seriesElements = document.querySelectorAll(seriesLinkSelector);
    _logger.t('Found ${seriesElements.length} potential series elements using selector "$seriesLinkSelector".');

    if (seriesElements.isEmpty) {
      _logger.w('No series elements found using selector "$seriesLinkSelector". Trying alternative selector...');
      // Try an alternative selector if the first one fails
      const String alternativeSelector = 'div.playlists-lists ul li span.serial'; // Based on inspecting astar.bz
      final alternativeElements = document.querySelectorAll(alternativeSelector);
      _logger.t('Found ${alternativeElements.length} potential series elements using selector "$alternativeSelector".');

      if (alternativeElements.isEmpty) {
        _logger.w(
          'No series elements found using alternative selector "$alternativeSelector" either. Returning empty list.',
        );
        return [];
      }
      // If alternative elements found, process them
      for (final element in alternativeElements) {
        try {
          // Example for 'div.playlists-lists ul li span.serial' structure
          final String titleAndNumber = element.text.trim();
          // The data-file attribute seems to hold the relevant URL part on astar.bz
          final String? dataUrl = element.attributes['data-file'];

          if (titleAndNumber.isEmpty || dataUrl == null || dataUrl.isEmpty) {
            _logger.w('Skipping series element: Missing text or data-file attribute.');
            continue;
          }

          // Attempt to parse "Серия X - Title" or just "Серия X"
          String seriesNumber = '';
          String title = titleAndNumber; // Default title is the full text

          final RegExp seriesRegex = RegExp(r'^(?:Серия\s*)?(\d+)\s*(?:[-:]\s*(.*))?$', caseSensitive: false);
          final match = seriesRegex.firstMatch(titleAndNumber);

          if (match != null) {
            seriesNumber = match.group(1) ?? ''; // Group 1 is the number
            title =
                match.group(2)?.trim() ?? titleAndNumber; // Group 2 is the title after separator, fallback to full text
            if (title.isEmpty) title = "Серия $seriesNumber"; // Handle cases like "Серия 1"
          } else {
            // Fallback if regex doesn't match expected format
            seriesNumber = titleAndNumber.replaceAll(RegExp(r'\D'), ''); // Extract digits as number
            _logger.w(
              'Could not parse series number/title reliably from "$titleAndNumber". Using extracted number: "$seriesNumber", title: "$title"',
            );
          }

          final series = Series(
            seriesNumber: seriesNumber.isNotEmpty ? seriesNumber : titleAndNumber, // Fallback number
            title: title,
            dataUrl: dataUrl, // Use the value from data-file
          );
          seriesList.add(series);
          _logger.t('Successfully parsed series: #${series.seriesNumber} - ${series.title} (URL: ${series.dataUrl})');
        } catch (e, stackTrace) {
          _logger.e(
            'Error processing a specific series element (alternative selector)',
            error: e,
            stackTrace: stackTrace,
          );
        }
      }
    } else {
      // Process elements found with the primary selector
      for (final element in seriesElements) {
        try {
          final String titleAndNumber = element.text.trim();
          // Prefer 'data-url' if available, otherwise use 'href'
          String? dataUrl = element.attributes['data-url'];
          if (dataUrl == null || dataUrl.isEmpty) {
            // Check if null or empty
            dataUrl = element.attributes['href'];
          }

          if (titleAndNumber.isEmpty || dataUrl == null || dataUrl.isEmpty) {
            // Check if dataUrl is null or empty
            _logger.w('Skipping series element: Missing text or href/data-url attribute.');
            continue;
          }

          // Resolve relative URL if needed (assuming dataUrl might be relative)
          final String absoluteDataUrl = Uri.parse(baseUrl).resolve(dataUrl).toString();

          // Attempt to parse "Серия X - Title" or just "Серия X"
          String seriesNumber = '';
          String title = titleAndNumber; // Default title is the full text

          // Regex to capture "Серия" (optional), the number, and the title (optional, after a separator)
          final RegExp seriesRegex = RegExp(r'^(?:Серия\s*)?(\d+)\s*(?:[-:]\s*(.*))?$', caseSensitive: false);
          final match = seriesRegex.firstMatch(titleAndNumber);

          if (match != null) {
            seriesNumber = match.group(1) ?? ''; // Group 1 is the number
            title =
                match.group(2)?.trim() ?? titleAndNumber; // Group 2 is the title after separator, fallback to full text
            if (title.isEmpty) title = "Серия $seriesNumber"; // Handle cases like "Серия 1"
          } else {
            // Fallback if regex doesn't match expected format
            seriesNumber = titleAndNumber.replaceAll(RegExp(r'\D'), ''); // Extract digits as number
            _logger.w(
              'Could not parse series number/title reliably from "$titleAndNumber". Using extracted number: "$seriesNumber", title: "$title"',
            );
          }

          final series = Series(
            seriesNumber: seriesNumber.isNotEmpty ? seriesNumber : titleAndNumber, // Fallback number
            title: title,
            dataUrl: absoluteDataUrl,
          );
          seriesList.add(series);
          _logger.t('Successfully parsed series: #${series.seriesNumber} - ${series.title} (URL: ${series.dataUrl})');
        } catch (e, stackTrace) {
          _logger.e('Error processing a specific series element (primary selector)', error: e, stackTrace: stackTrace);
        }
      }
    }

    if (seriesList.isEmpty) {
      _logger.w('Parsing finished, but no series were successfully extracted from the HTML for $baseUrl.');
    } else {
      _logger.i('Finished parsing. Extracted ${seriesList.length} series.');
    }

    return seriesList;
  }
}
