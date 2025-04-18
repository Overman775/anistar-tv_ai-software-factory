import 'dart:convert';

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
    logger.i('Scraping JWPlayer config from URL: $url');
    // return [];
    // 1. Fetch HTML
    final html = await htmlParserService.fetchHtml(url);
    if (html == null || html.isEmpty) {
      logger.e('Failed to fetch HTML for $url');
      throw JwPlayerConfigParseException('Failed to fetch HTML for $url');
    }
    logger.i('Successfully fetched HTML for $url');

    // 2. Extract JWPlayer config string using multiple strategies
    String? configStr;

    // Strategy 1: jwplayer("...").setup({...})
    logger.d('Attempting config extraction strategy 1: jwplayer("...").setup({...})');
    final jwplayerSetupRegex = RegExp(r'''jwplayer\(["'][^"']*["']\)\.setup\((\{.*?\})\)''', dotAll: true);
    final setupMatch = jwplayerSetupRegex.firstMatch(html);
    if (setupMatch != null) {
      configStr = setupMatch.group(1);
      logger.d('Strategy 1 successful.');
    }

    // Strategy 2: window.jwplayerConfig = {...}
    if (configStr == null) {
      logger.d('Attempting config extraction strategy 2: window.jwplayerConfig = {...}');
      final windowConfigRegex = RegExp(r'window\.jwplayerConfig\s*=\s*(\{.*?\});', dotAll: true);
      final windowMatch = windowConfigRegex.firstMatch(html);
      if (windowMatch != null) {
        configStr = windowMatch.group(1);
        logger.d('Strategy 2 successful.');
      }
    }

    // Strategy 3: <script>var playerConfig = {...}</script>
    if (configStr == null) {
      logger.d('Attempting config extraction strategy 3: <script>var playerConfig = {...}</script>');
      final scriptConfigRegex = RegExp(r'var\s+\w+\s*=\s*(\{.*?\});', dotAll: true);
      final scriptMatch = scriptConfigRegex.firstMatch(html);
      if (scriptMatch != null) {
        configStr = scriptMatch.group(1);
        logger.d('Strategy 3 successful.');
      }
    }

    if (configStr == null) {
      logger.e('JWPlayer config not found using any strategy.');
      throw JwPlayerConfigParseException('JWPlayer config not found');
    }
    logger.d('Successfully extracted JWPlayer config string.');

    // 3. Parse the config string (try JSON, fallback to JS object)
    logger.d('Attempting to parse JWPlayer config string.');
    Map<String, dynamic>? configObj;
    try {
      configObj = _parseJsonLike(configStr);
      logger.d('Successfully parsed JWPlayer config string.');
    } catch (e) {
      logger.e('Failed to parse JWPlayer config: $e');
      throw JwPlayerConfigParseException('Invalid JWPlayer config');
    }

    if (configObj == null) {
      logger.e('Parsed config object is null.');
      throw JwPlayerConfigParseException('Invalid JWPlayer config');
    }

    // 4. Extract and normalize sources
    logger.d('Extracting video sources from config.');
    final sourcesRaw = configObj['sources'];
    if (sourcesRaw == null || sourcesRaw is! List) {
      logger.e('No valid video sources found in config.');
      throw JwPlayerConfigParseException('No valid video sources found');
    }
    logger.d('Successfully extracted raw sources.');

    final List<JwVideoInfo> videos = [];
    for (final source in sourcesRaw) {
      if (source is Map && source['file'] is String) {
        final videoUrl = source['file'] as String;
        final posterUrl = configObj['image'] as String? ?? configObj['poster'] as String?;
        videos.add(JwVideoInfo(videoUrl: videoUrl, posterUrl: posterUrl));
      }
    }

    if (videos.isEmpty) {
      logger.e('No valid video sources found after processing.');
      throw JwPlayerConfigParseException('No valid video sources found');
    }

    logger.i('Successfully scraped ${videos.length} video sources.');
    return videos;
  }

  /// Attempts to parse a JSON-like string into a Map.
  /// Handles some JS object edge cases (e.g., single quotes, trailing commas).
  Map<String, dynamic>? _parseJsonLike(String input) {
    // Try direct JSON decode first
    try {
      return input.contains("'")
          ? _parseLooseJsObject(input)
          : (input.isNotEmpty ? (input.startsWith('{') ? jsonDecode(input) as Map<String, dynamic> : null) : null);
    } catch (_) {
      // Fallback to loose JS object parsing
      return _parseLooseJsObject(input);
    }
  }

  /// Very basic JS object to Map parser (for common JWPlayer configs).
  Map<String, dynamic>? _parseLooseJsObject(String input) {
    // Remove JS function definitions: "key": function(...) { ... }, key: function(...) { ... }
    String withoutFunctions = input.replaceAllMapped(
      RegExp(
        r'''(["']?\w+["']?\s*:\s*)function\s*\([^)]*\)\s*\{(?:[^{}]|\{[^{}]*\})*\}\s*,?''',
        multiLine: true,
        dotAll: true,
      ),
      (m) => '',
    );
    // Replace single quotes with double quotes, remove trailing commas
    final normalized = withoutFunctions
        .replaceAllMapped(RegExp(r'(\w+)\s*:'), (m) => '"${m[1]}":') // unquoted keys
        .replaceAll("'", '"')
        .replaceAllMapped(RegExp(r',(\s*[}\]])'), (m) => m[1]!);
    try {
      return jsonDecode(normalized) as Map<String, dynamic>;
    } catch (e) {
      logger.e('Loose JS object parse failed: $e');
      return null;
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
