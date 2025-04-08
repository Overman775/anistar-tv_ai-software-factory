import 'package:anistar_tv/packages/core/services/html_parser_service.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' show parse;
import 'package:logger/logger.dart';

import '../models/page_model.dart'; // Import PageModel
import '../models/video_model.dart';

/// Service for managing videos
class VideoService {
  final HtmlParserService parser;
  final Logger logger;

  VideoService(this.parser, {Logger? logger}) : logger = logger ?? Logger();

  // Placeholder data removed

  /// Get a paginated list of videos
  /// [page] - The page number (starting from 1)
  Future<PageModel?> getVideosPaginated(int page) async {
    // Construct the URL for the requested page
    // Note: The base URL might need adjustment depending on how pagination works (e.g., /page/2/, /?page=2)
    // Assuming '/page/N/' structure based on the example HTML
    final url =
        page <= 1
            ? 'https://v6.astar.bz/?action_skin_change=1&skin_name=new36'
            : 'https://v6.astar.bz/page/$page/?action_skin_change=1&skin_name=new36';

    try {
      logger.i('Attempting to fetch page data from: $url');
      final pageModel = await _fetchHtml(url, logger: logger);
      if (pageModel != null) {
        logger.i('Successfully fetched page: ${pageModel.title} (${pageModel.videos.length} videos)');
      } else {
        logger.w('Failed to fetch or parse page data from: $url');
      }
      return pageModel;
    } catch (e, stackTrace) {
      logger.e('Error fetching page data in getVideosPaginated for URL: $url', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  // hasMoreVideos method removed as this info is now in PageModel

  /// Get a video by ID
  // getVideoById might need adjustment if IDs change or if fetching single items is required differently
  VideoModel? getVideoById(String id) {
    // This is now inefficient as it requires fetching a whole page.
    // Consider implementing a dedicated fetch for single video details if needed.
    // For now, returning null or throwing an error might be appropriate.
    logger.w('getVideoById is not efficiently implemented with page-based fetching.');
    return null; // Or throw UnimplementedError('Single video fetching not implemented');
  }

  // Additional utility for fetching HTML title using HtmlParserService

  /// Fetches and parses the HTML content from the given [url] to extract
  /// video cards, page title, and pagination status.
  /// Returns a [PageModel] containing the extracted data, or null if fetching/parsing fails.
  Future<PageModel?> _fetchHtml(String url, {Logger? logger}) async {
    final log = logger ?? Logger();
    try {
      final htmlParserService = HtmlParserService();
      final html = await htmlParserService.fetchHtml(url);

      if (html == null || html.isEmpty) {
        log.w('Received empty HTML content from $url');
        return null;
      }

      log.i('Successfully fetched HTML from: $url');
      final document = parse(html); // Parse the HTML once

      // Extract video cards
      final videoCards = _extractVideoCardsFromHtml(document, url, logger: log); // Correct parameter name

      // Extract page title
      final titleElement = document.querySelector('title');
      final pageTitle = titleElement?.text.trim() ?? 'Unknown Title';
      log.t('Extracted page title: $pageTitle');

      // Determine if there are more pages
      // Check if the right navigation button contains an 'a' tag
      final nextPageButton = document.querySelector('div.pagenav div.button_nav.r a');
      final hasMorePages = nextPageButton != null;
      log.t('Has more pages: $hasMorePages');

      // Construct and return the PageModel
      return PageModel(title: pageTitle, videos: videoCards, hasMorePages: hasMorePages);
    } catch (e, stackTrace) {
      log.e('Error fetching or parsing HTML for URL: $url', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Extracts video card information from the provided HTML content.
  ///
  /// Parses the HTML string and looks for elements matching the structure
  /// of movie cards on the site (e.g., div.news). Extracts title, image URL,
  /// rating (if available), and the link to the movie page.
  ///
  /// Returns a list of [VideoModel] objects representing the found movie cards.
  /// Returns an empty list if no cards are found or if parsing fails.
  List<VideoModel> _extractVideoCardsFromHtml(dom.Document document, String baseUrl, {Logger? logger}) {
    final log = logger ?? Logger(); // Use provided logger or create a new one
    final List<VideoModel> videoCards = [];

    try {
      log.t('Extracting video cards from parsed document...');
      // Document is already parsed and passed as an argument

      // Select all news items - simplified selector for debugging
      final newsElements = document.querySelectorAll('div.news');
      log.t('Found ${newsElements.length} potential video card elements.');

      for (final element in newsElements) {
        try {
          // --- Extract Title and Link ---
          final titleElement = element.querySelector('div.news_header div.title_left a');
          final String? title = titleElement?.text.trim();
          final String? relativeLink = titleElement?.attributes['href'];

          if (title == null || title.isEmpty || relativeLink == null || relativeLink.isEmpty) {
            log.w('Skipping card: Missing title or link.');
            continue; // Skip if essential info is missing
          }
          final String absoluteLink = Uri.parse(baseUrl).resolve(relativeLink).toString();

          // --- Extract Thumbnail ---
          final imgElement = element.querySelector('div.news_avatar img.main-img');
          final String? relativeThumbnailUrl = imgElement?.attributes['src'];
          Uri? thumbnailUrl;
          if (relativeThumbnailUrl != null && relativeThumbnailUrl.isNotEmpty) {
            // Ensure the URL is absolute
            thumbnailUrl = Uri.parse(baseUrl).resolve(relativeThumbnailUrl);
          } else {
            log.w('Missing thumbnail for card: $title');
            // Assign a default/placeholder or skip, here we allow null/default handling later
            // For VideoModel, thumbnailUrl is required, so we need a placeholder or skip.
            // Let's use a placeholder for now, assuming Uri.parse won't fail with an empty string (it might).
            // A better approach might be to skip or use a real placeholder image URL.
            // Using the link itself as a fallback ID if thumbnail is missing.
            // However, VideoModel requires a Uri. Let's skip if thumbnail is missing.
            log.w('Skipping card due to missing thumbnail: $title');
            continue;
          }

          // --- Extract Rating (Optional) ---
          double? rating;
          final ratingElement = element.querySelector('div.title_right div.rating span[itemprop="ratingValue"]');
          final ratingText = ratingElement?.text.trim();
          if (ratingText != null && ratingText.isNotEmpty) {
            rating = double.tryParse(ratingText);
            if (rating == null) {
              log.w('Failed to parse rating "$ratingText" for card: $title');
            }
          }

          // --- Create VideoModel ---
          // Using link as ID and videoUrl for now. Description, duration, category are defaults.
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
          log.t('Successfully extracted card: ${video.title}');
        } catch (e, stackTrace) {
          // Log error for a specific card but continue with others
          log.e('Error processing a video card element', error: e, stackTrace: stackTrace);
        }
      }
    } catch (e, stackTrace) {
      log.e('Failed to parse HTML content or extract video cards', error: e, stackTrace: stackTrace);
      // Return empty list on major parsing failure
      return [];
    }

    log.i('Finished extraction. Found ${videoCards.length} video cards.');
    return videoCards;
  }
}
