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
    final baseUrl = '${uri.scheme}://${uri.host}/';

    // Extract series number
    final pathSegment = uri.pathSegments.first;
    final seriesNumber = pathSegment.split('-').first;

    final seriesIframeUrl = '$baseUrl/test/player2/videoas.php?id=10283&hash=909bfcd31586a790885455da4910b469';

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
          final normalizedJson = normalize_json(playlistStr);
          final playlistJson = jsonDecode(normalizedJson) as List;
          logger.d('Successfully parsed playlst variable.');
          for (final item in playlistJson) {
            if (item is Map<String, dynamic>) {
              final videoUrl = item['file_h'] as String? ?? item['file'] as String?;
              final posterUrl = item['image'] as String? ?? item['poster'] as String?;
              if (videoUrl != null) {
                videos.add(JwVideoInfo(videoUrl: videoUrl, posterUrl: posterUrl));
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

  String normalize_json(String json) {
    return json;
  }
}

/// Exception thrown when JWPlayer config is missing or invalid.
class JwPlayerConfigParseException implements Exception {
  final String message;
  JwPlayerConfigParseException(this.message);
  @override
  String toString() => 'JwPlayerConfigParseException: $message';
}
