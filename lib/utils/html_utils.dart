import 'dart:async';

import 'package:anistar_tv/packages/core/services/html_parser_service.dart';
import 'package:anistar_tv/packages/features/home/models/video_model.dart'; // Import VideoModel
import 'package:html/parser.dart' show parse;
import 'package:logger/logger.dart';

/// Additional utility for fetching HTML title using HtmlParserService

/// Fetches the HTML title from the given [url] using HtmlParserService.
/// This method is designed to parse HTML content directly.
/// Returns the text content of the <title> tag, or null if the operation fails.
Future<List<VideoModel>?> fetchHtmlTitleWithHtmlParserService(String url, {Logger? logger}) async {
  final log = logger ?? Logger();
  try {
    final htmlParserService = HtmlParserService();
    final html = await htmlParserService.fetchHtml(url);
    log.i('Successfully fetched title with HtmlParserService url: $url');
    final cards = extractVideoCardsFromHtml(html ?? '', url);
    return cards;
  } catch (e, stackTrace) {
    log.e('Error fetching title with HtmlParserService for URL: $url', error: e, stackTrace: stackTrace);
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
List<VideoModel> extractVideoCardsFromHtml(String htmlContent, String baseUrl, {Logger? logger}) {
  final log = logger ?? Logger();
  final List<VideoModel> videoCards = [];

  try {
    log.t('Parsing HTML content for video cards...');
    final document = parse(htmlContent);

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
