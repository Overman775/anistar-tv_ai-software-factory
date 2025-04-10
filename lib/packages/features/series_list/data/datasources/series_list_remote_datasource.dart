import 'package:anistar_tv/packages/core/services/html_parser_service.dart';
import 'package:logger/logger.dart';

/// Abstract interface for the remote data source fetching series list HTML data.
abstract class SeriesListRemoteDatasource {
  /// Fetches the raw HTML content for a specific anime title page URL.
  ///
  /// Throws an exception if fetching fails.
  Future<String> fetchSeriesHtml(String url);
}

/// Implementation of [SeriesListRemoteDatasource] that fetches HTML content.
class SeriesListRemoteDatasourceImpl implements SeriesListRemoteDatasource {
  final HtmlParserService _htmlParserService;
  final Logger _logger;

  SeriesListRemoteDatasourceImpl({required HtmlParserService htmlParserService, Logger? logger})
    : _htmlParserService = htmlParserService,
      _logger = logger ?? Logger();

  @override
  Future<String> fetchSeriesHtml(String url) async {
    _logger.i('Attempting to fetch series HTML from: $url');
    try {
      // Append necessary parameters if needed (like skin change for astar.bz)
      // This might need adjustment based on the specific site structure.
      // Assuming the base URL already points to the correct series page.
      // If the site requires specific parameters for series pages, add them here.
      final effectiveUrl = '$url?action_skin_change=1&skin_name=new36'; // Example for astar.bz consistency
      _logger.t('Effective URL for fetching series HTML: $effectiveUrl');

      final html = await _htmlParserService.fetchHtml(effectiveUrl);

      if (html == null || html.isEmpty) {
        _logger.w('Received empty HTML content from $effectiveUrl');
        throw Exception('Failed to fetch HTML content from $effectiveUrl: Received empty response.');
      }

      _logger.t('Successfully fetched HTML from: $effectiveUrl.');
      return html;
    } catch (e, stackTrace) {
      _logger.e('Error fetching HTML for series list URL: $url', error: e, stackTrace: stackTrace);
      // Re-throw the exception to be handled by the repository layer.
      throw Exception('Failed to fetch HTML content from $url: $e');
    }
  }
}
