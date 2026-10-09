import 'dart:convert';

import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'package:json5/json5.dart';

/// Research adapter, deliberately independent of the production API client.
final class DirectAnistar {
  DirectAnistar(this.client, {String mirror = 'https://v30.astar.bz/'})
    : base = Uri.parse(mirror);

  final http.Client client;
  final Uri base;

  Uri playerUri(int id) =>
      base.resolve('test/player2/videoas_p2p_new.php?id=$id');
  Map<String, String> videoHeaders(int id) => {
    'Referer': playerUri(id).toString(),
  };

  Future<http.Response> get(
    Uri uri, {
    Map<String, String> headers = const {},
  }) => client.get(uri, headers: headers).timeout(const Duration(seconds: 25));

  Future<List<CatalogEntry>> catalog(int page) async {
    final response = await get(
      base.resolve(page == 1 ? 'anime/' : 'anime/page/$page/'),
    );
    requireSuccess(response);
    return parseCatalog(decodeHtml(response), base);
  }

  Future<Map<String, Object?>> detail(CatalogEntry entry) async {
    final response = await get(entry.uri);
    requireSuccess(response);
    final document = html.parse(decodeHtml(response));
    final title =
        document.querySelector('h1[itemprop="name"]')?.text ??
        document.querySelector('title')?.text;
    return {
      'id': entry.id,
      'title': title?.trim(),
      'metadata': document.querySelector('ul.head')?.text.trim(),
      'description': document.querySelector('.descripts')?.text.trim(),
      'charset': response.headers['content-type'],
    };
  }

  Future<List<DirectEpisode>> episodes(int id) async {
    final response = await get(
      playerUri(id),
      headers: {'Cache-Control': 'no-cache'},
    );
    requireSuccess(response);
    return parseEpisodes(decodeHtml(response));
  }

  /// Exactly one player-page refresh. A repeated 403 terminates the experiment.
  Future<({http.Response response, int refreshes})> manifestWithRefresh(
    int id,
    int episode,
    String quality, {
    required Uri initial,
  }) async {
    var response = await get(initial, headers: videoHeaders(id));
    if (response.statusCode != 403 && response.statusCode != 410)
      return (response: response, refreshes: 0);
    final fresh = (await episodes(id))
        .singleWhere((item) => item.number == episode)
        .sources['files']![quality]!;
    response = await get(fresh, headers: videoHeaders(id));
    return (response: response, refreshes: 1);
  }
}

final class CatalogEntry {
  const CatalogEntry(this.id, this.title, this.uri, this.poster);
  final int id;
  final String title;
  final Uri uri;
  final Uri? poster;
}

final class DirectEpisode {
  const DirectEpisode(this.number, this.title, this.sources);
  final int number;
  final String title;
  final Map<String, Map<String, Uri>> sources;
}

List<CatalogEntry> parseCatalog(String source, Uri base) {
  final document = html.parse(source);
  final result = <CatalogEntry>[];
  for (final card in document.querySelectorAll('.news')) {
    final link = card.querySelector('.title_left a');
    final href = link?.attributes['href'];
    if (href == null) continue;
    final uri = base.resolve(href);
    final match = RegExp(r'^/(\d+)-.*\.html$').firstMatch(uri.path);
    if (match == null) continue;
    final id = int.parse(match[1]!);
    if (id == 9493) continue;
    final poster = card
        .querySelector('img[itemprop="image"]')
        ?.attributes['src'];
    result.add(
      CatalogEntry(
        id,
        link!.text.trim(),
        uri,
        poster == null ? null : base.resolve(poster),
      ),
    );
  }
  if (result.isEmpty)
    throw const FormatException(
      'No catalog cards: possible changed markup or challenge',
    );
  return result;
}

List<DirectEpisode> parseEpisodes(String source) {
  final start = RegExp(r'\bvar\s+playlst\s*=\s*\[').firstMatch(source);
  if (start == null)
    throw const FormatException(
      'No playlst: possible changed markup or challenge',
    );
  final literal = extractArrayLiteral(source, start.end - 1);
  final entries = json5Decode(literal) as List<dynamic>;
  final episodes = <DirectEpisode>[];
  for (final entry in entries.cast<Map<String, dynamic>>()) {
    final title = entry['title'] as String;
    final number = int.tryParse(
      RegExp(r'\d+').firstMatch(title)?.group(0) ?? '',
    );
    if (number == null) continue;
    final groups = <String, Map<String, Uri>>{};
    for (final name in ['files', 'files_mp4', 'files_as']) {
      final sources = <String, Uri>{};
      for (final file
          in ((entry[name] as List<dynamic>?) ?? const [])
              .cast<Map<String, dynamic>>()) {
        final quality = file['title'] as String;
        final url = file['file'] as String;
        if (url.isEmpty) continue;
        final uri = Uri.parse(url);
        if (uri.scheme != 'https' || !uri.hasAuthority)
          throw const FormatException('Invalid media URL');
        sources[quality] = uri;
      }
      groups[name] = sources;
    }
    episodes.add(DirectEpisode(number, title, groups));
  }
  if (episodes.isEmpty) throw const FormatException('Empty playlist');
  return episodes;
}

/// Extract a data literal without evaluating upstream JavaScript.
String extractArrayLiteral(String source, int start) {
  var depth = 0;
  String? quote;
  var escaped = false;
  var lineComment = false;
  var blockComment = false;
  for (var i = start; i < source.length; i++) {
    final c = source[i];
    final next = i + 1 < source.length ? source[i + 1] : '';
    if (lineComment) {
      if (c == '\n') lineComment = false;
      continue;
    }
    if (blockComment) {
      if (c == '*' && next == '/') {
        blockComment = false;
        i++;
      }
      continue;
    }
    if (quote != null) {
      if (escaped) {
        escaped = false;
      } else if (c == r'\') {
        escaped = true;
      } else if (c == quote) {
        quote = null;
      }
      continue;
    }
    if (c == '/' && next == '/') {
      lineComment = true;
      i++;
      continue;
    }
    if (c == '/' && next == '*') {
      blockComment = true;
      i++;
      continue;
    }
    if (c == '"' || c == "'") {
      quote = c;
      continue;
    }
    if (c == '[') depth++;
    if (c == ']' && --depth == 0) return source.substring(start, i + 1);
  }
  throw const FormatException('Unterminated playlist');
}

String decodeHtml(http.Response response) {
  final contentType = response.headers['content-type']?.toLowerCase() ?? '';
  if (contentType.contains('windows-1251') || contentType.contains('cp1251')) {
    const special =
        '\u0402\u0403\u201a\u0453\u201e\u2026\u2020\u2021\u20ac\u2030\u0409\u2039\u040a\u040c\u040b\u040f'
        '\u0452\u2018\u2019\u201c\u201d\u2022\u2013\u2014\ufffd\u2122\u0459\u203a\u045a\u045c\u045b\u045f'
        '\u00a0\u040e\u045e\u0408\u00a4\u0490\u00a6\u00a7\u0401\u00a9\u0404\u00ab\u00ac\u00ad\u00ae\u0407'
        '\u00b0\u00b1\u0406\u0456\u0491\u00b5\u00b6\u00b7\u0451\u2116\u0454\u00bb\u0458\u0405\u0455\u0457';
    return String.fromCharCodes(
      response.bodyBytes.map(
        (byte) => byte < 128
            ? byte
            : byte >= 192
            ? byte + 848
            : special.codeUnitAt(byte - 128),
      ),
    );
  }
  return utf8.decode(response.bodyBytes);
}

void requireSuccess(http.Response response) {
  if (response.statusCode != 200 && response.statusCode != 206) {
    throw StateError(
      'HTTP ${response.statusCode} from ${response.request?.url.host}',
    );
  }
}

bool isHls(http.Response response) => utf8
    .decode(response.bodyBytes, allowMalformed: true)
    .trimLeft()
    .startsWith('#EXTM3U');

List<Uri> mediaLines(http.Response response, Uri manifest) =>
    const LineSplitter()
        .convert(utf8.decode(response.bodyBytes))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && !line.startsWith('#'))
        .map(manifest.resolve)
        .toList();
