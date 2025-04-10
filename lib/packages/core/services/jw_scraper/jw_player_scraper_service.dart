import 'package:html/parser.dart' as html_parser;
import 'package:logger/logger.dart';

import '../html_parser_service.dart';
import 'models/jw_video_info.dart';
import 'parsers/jw_config_extractor.dart';

/// Orchestrates the workflow to scrape JW Player video and poster URLs from a web page.
class JwPlayerScraperService {
  final HtmlParserService htmlParserService;
  final JwConfigExtractor configExtractor;
  final Logger logger;

  JwPlayerScraperService({required this.htmlParserService, required this.configExtractor, Logger? logger})
    : logger = logger ?? Logger();

  /// Scrapes the given [url] for JW Player video and poster URLs.
  ///
  /// Returns a list of [JwVideoInfo].
  Future<List<JwVideoInfo>> scrape(String url) async {
    final html = await htmlParserService.fetchHtml(url);
    if (html == null) {
      logger.w('Failed to fetch HTML for \$url');
      return [];
    }
    // Extract JW Player config scripts from HTML
    final document = html_parser.parse(html);
    final scripts = document.getElementsByTagName('script');
    final jwConfigs = <String>[];

    for (final script in scripts) {
      final scriptContent = script.text;
      if (scriptContent.contains('jwplayer') && scriptContent.contains('setup')) {
        jwConfigs.add(scriptContent);
      }
    }

    final videoInfos = configExtractor.extractVideoInfos(jwConfigs);
    return videoInfos;
  }
}
