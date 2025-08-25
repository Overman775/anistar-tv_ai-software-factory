import 'package:anistar_tv/packages/core/services/html_parser_service.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' show parse;
import 'package:logger/logger.dart';

import '../../domain/models/page_model.dart';
import '../../domain/models/video_model.dart';

/// Abstract interface for the remote data source fetching video list data.
abstract class VideoListRemoteDataSource {
  /// Fetches a paginated list of videos from the specified base [url].
  ///
  /// The [page] parameter indicates the page number to fetch (starting from 1).
  /// The actual URL construction based on the base [url] and [page]
  /// will be handled by the implementation.
  ///
  /// Returns a [PageModel] containing the videos and pagination info,
  /// or null/throws an error if fetching fails.
  Future<PageModel?> fetchVideoPage(String baseUrl, int page);
}

/// Implementation of [VideoListRemoteDataSource] that fetches data by parsing HTML.
class VideoListRemoteDataSourceImpl implements VideoListRemoteDataSource {
  final HtmlParserService _htmlParserService;
  final Logger _logger;

  VideoListRemoteDataSourceImpl({required HtmlParserService htmlParserService, Logger? logger})
    : _htmlParserService = htmlParserService,
      _logger = logger ?? Logger();

  @override
  Future<PageModel?> fetchVideoPage(String baseUrl, int page) async {
    // Construct the URL for the requested page.
    // This logic is specific to the source site (e.g., astar.bz)
    // Consider making this part more configurable if supporting multiple site structures.
    final String url = page <= 1
        ? '$baseUrl?action_skin_change=1&skin_name=new36'
        : '$baseUrl/page/$page/?action_skin_change=1&skin_name=new36';

    _logger.i('Attempting to fetch page data from: $url');

    try {
      final html = await _htmlParserService.fetchHtml(url);

      if (html == null || html.isEmpty) {
        _logger.w('Received empty HTML content from $url');

        return null;
      }

      _logger.t('Successfully fetched HTML from: $url. Parsing...');
      final document = parse(html); // Parse the HTML once

      // Extract video cards
      final videoCards = _extractVideoCardsFromHtml(document, baseUrl); // Pass base URL for resolving relative links

      // Extract page title
      final titleElement = document.querySelector('title');
      final pageTitle = titleElement?.text.trim() ?? 'Unknown Title';
      _logger.t('Extracted page title: $pageTitle');

      // Determine if there are more pages
      // Check if the right navigation button contains an 'a' tag (specific to astar.bz)
      final nextPageButton = document.querySelector('div.pagenav div.button_nav.r a');
      final hasMorePages = nextPageButton != null;
      _logger.t('Has more pages: $hasMorePages');

      // Construct and return the PageModel
      final pageModel = PageModel(title: pageTitle, videos: videoCards, hasMorePages: hasMorePages);
      _logger.i('Successfully parsed page: ${pageModel.title} (${pageModel.videos.length} videos)');

      return pageModel;
    } catch (e, stackTrace) {
      _logger.e('Error fetching or parsing HTML for URL: $url', error: e, stackTrace: stackTrace);
      // Depending on error handling strategy, could return null or throw specific exception

      return null;
    }
  }

  /// Extracts video card information from the provided HTML document.
  /// (Adapted from the original VideoService)
  List<VideoModel> _extractVideoCardsFromHtml(dom.Document document, String baseUrl) {
    final List<VideoModel> videoCards = [];
    _logger.t('Extracting video cards from parsed document...');

    try {
      // Selector specific to astar.bz
      final newsElements = document.querySelectorAll('div.news');
      _logger.t('Found ${newsElements.length} potential video card elements.');

      for (final element in newsElements) {
        try {
          // --- Extract Title and Link ---
          final titleElement = element.querySelector('div.news_header div.title_left a');
          final String? title = titleElement?.text.trim();
          final String? relativeLink = titleElement?.attributes['href'];

          if (title == null || title.isEmpty || relativeLink == null || relativeLink.isEmpty) {
            _logger.w('Skipping card: Missing title or link.');
            continue;
          }
          // Resolve relative link against the base URL of the fetched page
          final String absoluteLink = Uri.parse(baseUrl).resolve(relativeLink).toString();

          // --- Extract Thumbnail ---
          final imgElement = element.querySelector('div.news_avatar img.main-img');
          final String? relativeThumbnailUrl = imgElement?.attributes['src'];
          Uri? thumbnailUrl;
          if (relativeThumbnailUrl != null && relativeThumbnailUrl.isNotEmpty) {
            // Resolve relative thumbnail URL against the base URL
            thumbnailUrl = Uri.parse(baseUrl).resolve(relativeThumbnailUrl);
          } else {
            _logger.w('Skipping card due to missing thumbnail: $title');
            continue; // Skip if thumbnail is essential
          }

          // --- Extract Rating (Optional) ---
          double? rating;
          final ratingElement = element.querySelector('div.title_right div.rating span[itemprop="ratingValue"]');
          final ratingText = ratingElement?.text.trim();
          if (ratingText != null && ratingText.isNotEmpty) {
            rating = double.tryParse(ratingText);
            if (rating == null) {
              _logger.w('Failed to parse rating "$ratingText" for card: $title');
            }
          }

          // --- Create VideoModel ---
          final video = VideoModel(
            id: absoluteLink, // Use the movie page link as a unique ID
            title: title,
            description: '', // No description available in the card
            thumbnailUrl: thumbnailUrl,
            videoUrl: absoluteLink, // Use the movie page link as the video URL for now
            duration: Duration.zero, // No duration available
            category: '', // No category available in the card
            rating: rating,
          );
          videoCards.add(video);
          _logger.t('Successfully extracted card: ${video.title}');
        } catch (e, stackTrace) {
          _logger.e('Error processing a specific video card element', error: e, stackTrace: stackTrace);
        }
      }
    } catch (e, stackTrace) {
      _logger.e('Failed to parse HTML content or extract video cards', error: e, stackTrace: stackTrace);

      return []; // Return empty list on major parsing failure
    }

    _logger.i('Finished extraction. Found ${videoCards.length} video cards.');

    return videoCards;
  }
}
