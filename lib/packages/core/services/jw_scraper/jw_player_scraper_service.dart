import 'dart:convert';
import 'dart:core';

import 'package:logger/logger.dart';

import '../html_parser_service.dart';
import 'models/jw_video_info.dart';

/// Orchestrates the workflow to scrape JW Player video and poster URLs from a web page.
class JwPlayerScraperService {
  final HtmlParserService htmlParserService;
  final Logger logger;

  JwPlayerScraperService({required this.htmlParserService, Logger? logger}) : logger = logger ?? Logger();

  /// Scrapes JWPlayer video sources and poster from the given URL.
  /// Throws [JwPlayerConfigParseException] if config or sources are missing/invalid.
  Future<List<JwVideoInfo>> scrape(String url) async {
    final uri = Uri.parse(url);

    // Extract base URL
    final baseUrl = '${uri.scheme}://${uri.host}';

    logger.i('Fetching initial page HTML from URL: $url');
    final initialPageHtml = await htmlParserService.fetchHtml(url);
    if (initialPageHtml == null || initialPageHtml.isEmpty) {
      logger.e('Failed to fetch initial page HTML for $url');
      throw JwPlayerConfigParseException('Failed to fetch initial page HTML for $url');
    }
    logger.i('Successfully fetched initial page HTML for $url');

    // Find the iframe with videoas.php in its src
    final iframeRegex = RegExp(r'<iframe[^>]+src="([^"]*videoas\.php[^"]*)"');
    final iframeMatch = iframeRegex.firstMatch(initialPageHtml);

    if (iframeMatch == null) {
      logger.e('Could not find iframe with videoas.php in src on page: $url');
      throw JwPlayerConfigParseException('Could not find iframe with videoas.php in src');
    }

    final iframeSrc = iframeMatch.group(1)!;
    logger.i('Found iframe src: $iframeSrc');

    // Extract id and hash from iframe src
    final iframeUri = Uri.parse(iframeSrc);
    final id = iframeUri.queryParameters['id'];
    final hash = iframeUri.queryParameters['hash'];

    if (id == null || hash == null) {
      logger.e('Could not extract id or hash from iframe src: $iframeSrc');
      throw JwPlayerConfigParseException('Could not extract id or hash from iframe src');
    }

    logger.i('Extracted id: $id, hash: $hash');

    final seriesIframeUrl = '$baseUrl/test/player2/videoas.php?id=$id&hash=$hash';

    logger.i('Scraping JWPlayer config from URL: $seriesIframeUrl');
    // return [];
    // 1. Fetch HTML
    var html = await htmlParserService.fetchHtml(seriesIframeUrl);
    if (html == null || html.isEmpty) {
      logger.e('Failed to fetch HTML for $seriesIframeUrl');
      throw JwPlayerConfigParseException('Failed to fetch HTML for $seriesIframeUrl');
    }
    logger.i('Successfully fetched HTML for $seriesIframeUrl');

    final iframeHtml = await htmlParserService.fetchHtml(seriesIframeUrl);
    if (iframeHtml != null && iframeHtml.isNotEmpty) {
      html = iframeHtml; // Use iframe content for scraping
      logger.i('Successfully fetched and will use iframe HTML.');
    } else {
      logger.w(
        'Failed to fetch iframe HTML from $seriesIframeUrl or iframe HTML is empty. Proceeding with original HTML.',
      );
    }

    // 3. Extract video sources from playlst variable
    List<JwVideoInfo> videos = [];
    logger.d('Attempting to extract video sources from playlst variable.');
    final playlistRegex = RegExp(r'var\s+playlst\s*=\s*(\[.*?\]);', dotAll: true);
    final playlistMatch = playlistRegex.firstMatch(html);
    if (playlistMatch != null) {
      final playlistStr = playlistMatch.group(1);
      if (playlistStr != null) {
        try {
          final normalizedJson = normalizeJson(playlistStr);
          final playlistJson = jsonDecode(normalizedJson) as List;
          logger.d('Successfully parsed playlst variable.');
          for (final item in playlistJson) {
            if (item is Map<String, dynamic>) {
              final videoUrl = item['file_h'] as String? ?? item['file'] as String?;
              final title = item['title'] as String? ?? '';
              final posterUrl = item['image'] as String?;
              final viewing = item['viewing'] as bool? ?? false;
              if (videoUrl != null) {
                videos.add(JwVideoInfo(videoUrl: videoUrl, title: title, posterUrl: posterUrl, isViewed: viewing));
              }
            }
          }
        } catch (e) {
          logger.e('Failed to parse playlst variable: $e');
        }
      }
    }

    if (videos.isEmpty) {
      logger.e('No valid video sources found after processing playlst.');
      throw JwPlayerConfigParseException('No valid video sources found');
    }

    logger.i('Successfully scraped ${videos.length} video sources from playlst.');
    return videos;
  }

  /// Normalizes a JavaScript-like array literal string into a valid JSON array string.
  /// Minimal version focusing on key quoting, comment removal, and trailing commas.
  String normalizeJson(String rawJson) {
    String processed = rawJson; // Start with raw input

    // Remove extra whitespace (tabs and spaces) while preserving necessary spaces within strings and structure.
    // This is a basic approach and might need refinement for complex cases.
    processed = processed.split('\n').map((line) => line.trim()).join('');
    processed = processed.replaceAll(RegExp(r'\s+', multiLine: true), ' ');

    // 1. Remove JS comments (single line) - Safely target comments at line ends
    // Matches optional whitespace followed by // and the rest of the line.
    // processed = processed.replaceAll(RegExp(r'\s*\/\/.*$', multiLine: true), '');
    // Remove single-line comments (match until next structural char or end)
    processed = processed.replaceAll(RegExp(r'(?<!https:)//[^{}\[\],]*'), '');

    // Replace single quotes around values with double quotes
    processed = processed.replaceAll(RegExp(r"'(.*?)'", multiLine: true), r'"$1"');

    // Add double quotes around keys that are not already quoted using replaceAllMapped
    processed = processed.replaceAllMapped(
      RegExp(r'(^|[\{,]\s*)(\w+)(?=\s*:)'),
      (match) => '${match.group(1)!}"${match.group(2)!}"',
    );

    // Remove commas followed immediately by another comma
    processed = processed.replaceAll(RegExp(r',(?=\s*,)'), '');

    // Remove trailing commas in objects and arrays (before } or ])
    processed = processed.replaceAll(RegExp(r',(\s*[}\]])'), '},');
    // // Remove commas followed immediately by another comma
    processed = processed.replaceAll(RegExp(r',(?=\s*,)'), '');
    processed = processed.replaceAll(',},', ']');

    // 4. Trim final result
    processed = processed.trim();

    // 5. Validate
    try {
      // Attempt to decode. If it fails, log details and re-throw.
      jsonDecode(processed);
      logger.i('Json valid');

      return processed; // It's valid JSON
    } catch (e) {
      logger.e('Error normalizing JSON (minimal attempt)', error: e);
      logger.e(
        'Problematic string fragment (minimal attempt): ${processed.substring(0, (processed.length > 400 ? 400 : processed.length))}...',
      ); // Log snippet
      // Re-throw a detailed exception
      throw FormatException(
        'Failed to normalize to valid JSON string (minimal attempt): $e\nOriginal (raw): ${rawJson.substring(0, (rawJson.length > 400 ? 400 : rawJson.length))}...',
      );
    }
  }
}

/// Exception thrown when JWPlayer config is missing or invalid.
class JwPlayerConfigParseException implements Exception {
  final String message;
  JwPlayerConfigParseException(this.message);
  @override
  String toString() => 'JwPlayerConfigParseException: $message';
}
