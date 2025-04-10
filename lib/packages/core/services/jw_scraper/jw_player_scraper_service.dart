import 'package:html/parser.dart' as html_parser;
import 'package:logger/logger.dart';

import '../html_parser_service.dart';
import 'models/jw_video_info.dart';

/// Orchestrates the workflow to scrape JW Player video and poster URLs from a web page.
class JwPlayerScraperService {
  final HtmlParserService htmlParserService;
  final Logger logger;

  JwPlayerScraperService({required this.htmlParserService, Logger? logger}) : logger = logger ?? Logger();

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

    final videoInfos = _extractVideoInfos(jwConfigs);
    return videoInfos;
  }

  /// Parses JW Player config scripts and returns a list of [JwVideoInfo].
  ///
  /// Handles both direct file/poster fields and playlist arrays.
  List<JwVideoInfo> _extractVideoInfos(List<String> jwConfigs) {
    final results = <JwVideoInfo>[];

    for (final config in jwConfigs) {
      // Try to extract the setup({ ... }) object using regex.
      final setupRegExp = RegExp(r'setup\s*\(\s*({.*?})\s*\)', dotAll: true);
      final setupMatch = setupRegExp.firstMatch(config);
      if (setupMatch == null) continue;

      final configJsonLike = setupMatch.group(1)!;

      // Use triple quotes for RegExp to avoid quote confusion.
      final fileRegExp = RegExp(r"""file\s*:\s*['"]([^'"]+)['"]""");
      final fileMatch = fileRegExp.firstMatch(configJsonLike);

      final posterRegExp = RegExp(r"""(image|poster)\s*:\s*['"]([^'"]+)['"]""");
      final posterMatch = posterRegExp.firstMatch(configJsonLike);

      if (fileMatch != null) {
        results.add(JwVideoInfo(videoUrl: fileMatch.group(1)!, posterUrl: posterMatch?.group(2)));
        continue;
      }

      // Try to extract from playlist: [{file:..., image:...}]
      final playlistRegExp = RegExp(r'playlist\s*:\s*\[(.*?)\]', dotAll: true);
      final playlistMatch = playlistRegExp.firstMatch(configJsonLike);
      if (playlistMatch != null) {
        final playlistContent = playlistMatch.group(1)!;
        final fileInPlaylistRegExp = RegExp(r"""file\s*:\s*['"]([^'"]+)['"]""");
        final fileInPlaylist = fileInPlaylistRegExp.firstMatch(playlistContent);

        final posterInPlaylistRegExp = RegExp(r"""(image|poster)\s*:\s*['"]([^'"]+)['"]""");
        final posterInPlaylist = posterInPlaylistRegExp.firstMatch(playlistContent);

        if (fileInPlaylist != null) {
          results.add(JwVideoInfo(videoUrl: fileInPlaylist.group(1)!, posterUrl: posterInPlaylist?.group(2)));
        }
      }
    }

    return results;
  }
}
