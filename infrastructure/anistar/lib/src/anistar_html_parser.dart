import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;
import 'package:json5/json5.dart';

import 'anistar_failure.dart';
import 'anistar_favorites_html.dart';
import 'anistar_search_html.dart';
import 'contract/anistar_anime_details_dto.dart';
import 'contract/anistar_anime_part_dto.dart';
import 'contract/anistar_anime_summary_dto.dart';
import 'contract/anistar_catalog_filter_dto.dart';
import 'contract/anistar_catalog_page_dto.dart';
import 'contract/anistar_episode_dto.dart';
import 'contract/anistar_video_source_dto.dart';
import 'html_catalog_parameters.dart';
import 'parsed_episode.dart';
import 'playlist_literal.dart';

final class AnistarHtmlParser {
  static final _linkedPathPattern = RegExp(r'^(?:(?:https?:)?//([^/?#]+))?([^?#]+)$', caseSensitive: false);
  static final _titlePathPattern = RegExp(r'^/(\d+-[^/\\?#]*)\.html$');
  static final _encodedTitleSeparators = RegExp('%(?:2f|5c|2e|25)', caseSensitive: false);
  static final _detailMetadataFilter = RegExp('^/filter/(author|director|year)/');

  final Uri baseUri;

  const AnistarHtmlParser(this.baseUri);

  AnistarCatalogPageDto search(String source, int page) {
    if (page < 1) {
      throw const AnistarFailure(message: 'Некорректный номер страницы поиска.');
    }
    final document = _document(source);
    final items = <AnistarAnimeSummaryDto>[];
    final ids = <int>{};
    final content = document.querySelector('#dle-content') ?? document;
    for (final card in content.querySelectorAll('.short.news')) {
      final item = _card(card);
      if (item != null && item.id != 9493 && ids.add(item.id)) {
        items.add(item);
      }
    }
    if (items.isEmpty) {
      if (AnistarSearchHtml.isEmpty(document)) {
        return AnistarCatalogPageDto(items: const [], page: page, hasNext: false);
      }
      throw const AnistarFailure(message: 'Не удалось разобрать результаты поиска AniStar. Попробуйте снова.');
    }
    if (document.querySelector('form#fullsearch') == null) {
      throw const AnistarFailure(message: 'AniStar не подтвердил страницу результатов поиска.');
    }
    final hasNext = AnistarSearchHtml.hasNext(document, page);

    return AnistarCatalogPageDto(items: items, page: page, hasNext: hasNext);
  }

  AnistarCatalogPageDto catalog(String source, int page, {bool favorites = false, String? filterPath}) {
    final document = _document(source);
    final items = <AnistarAnimeSummaryDto>[];
    final ids = <int>{};
    final content = favorites ? document.querySelector('#dle-content') ?? document : document;
    for (final card in content.querySelectorAll('.news, .plash')) {
      final item = _card(card);
      if (item != null && item.id != 9493 && ids.add(item.id)) {
        items.add(item);
      }
    }
    if (items.isEmpty && (!favorites || !AnistarFavoritesHtml.isEmpty(document, baseUri))) {
      throw const AnistarFailure(message: 'Не удалось разобрать каталог AniStar. Возможно, сайт изменился.');
    }
    final hasNext = document
        .querySelectorAll(filterPath == null ? 'a[href]' : '.pages a[href], .navigation a[href]')
        .any((link) {
          final uri = _uri(link.attributes['href']);
          final pageNumber = favorites ? _favoritePage(uri) : _catalogPage(uri, filterPath);
          final number = int.tryParse(pageNumber ?? '');

          return uri?.origin == baseUri.origin && number != null && number > page;
        });

    return AnistarCatalogPageDto(items: List.unmodifiable(items), page: page, hasNext: hasNext);
  }

  AnistarAnimeDetailsDto details(String source, String slug) {
    final document = _document(source);
    final titleElement = document.querySelector('h1[itemprop="name"]');
    final title = titleElement?.text.trim();
    final head = document.querySelector('ul.head');
    if (title == null || title.isEmpty || head == null) {
      throw const AnistarFailure(message: 'Не удалось разобрать карточку AniStar. Возможно, сайт изменился.');
    }
    final id = int.parse(slug.split('-').first);
    final genres = _metadata(head, 'Жанр');
    final category = document.querySelector('.ful-cat, .tags')?.text.toLowerCase() ?? '';
    var header = titleElement?.parent;
    while (header != null && !header.classes.contains('news_header')) {
      header = header.parent;
    }
    final rating = header?.querySelector('.rating');

    return AnistarAnimeDetailsDto(
      id: id,
      isFavorite: AnistarFavoritesHtml.documentStatus(document, id),
      filters: _filters(document.querySelectorAll('.ful-cat a[href], .tags a[href], ul.head li a[href]'), detail: true),
      slug: slug,
      title: title,
      posterUri: _uri(document.querySelector('.news_avatar img, img[itemprop="image"]')?.attributes['src']),
      year: _metadata(head, 'Год выпуска'),
      genres:
          genres?.split(',').map((genre) => genre.trim()).where((genre) => genre.isNotEmpty).toList(growable: false) ??
          const [],
      voiceover: _metadata(head, 'Озвучка'),
      seriesInfo: _metadata(head, 'Серии'),
      description: _description(document.querySelector('.news_text .descripts, .descripts')),
      isOngoing: category.contains('новинки') || category.contains('онгоинг'),
      rating: rating == null ? null : _rating(rating),
      director: _metadata(head, 'Режиссёр') ?? _metadata(head, 'Режиссер'),
      author: _metadata(head, 'Автор'),
      updateMessage: _text(document.querySelector('.reason')),
      publicationDate: _text(document.querySelector('.date-icon')),
      parts: _parts(document),
    );
  }

  List<AnistarCatalogFilterDto> genres(String source) {
    final document = _document(source);
    final filters = _filters(document.querySelectorAll('.block-janrs a[href]'));
    if (filters.isEmpty) {
      throw const AnistarFailure(message: 'Не удалось загрузить жанры AniStar. Попробуйте снова.');
    }

    return filters;
  }

  List<AnistarEpisodeDto> episodes(String source, {Map<String, String> httpHeaders = const {}}) =>
      List.unmodifiable(parsedEpisodes(source, httpHeaders: httpHeaders).map((item) => item.episode));

  List<ParsedEpisode> parsedEpisodes(String source, {Map<String, String> httpHeaders = const {}}) {
    _checkChallenge(source);
    final literal = PlaylistLiteral().extract(source);
    Object? decoded;
    try {
      decoded = json5Decode(literal);
    } on Exception catch (_, stackTrace) {
      Error.throwWithStackTrace(
        const AnistarFailure(message: 'Список серий AniStar имеет неизвестный формат.'),
        stackTrace,
      );
    }
    if (decoded is! List<Object?>) {
      throw const AnistarFailure(message: 'Не удалось прочитать серии AniStar.');
    }
    final items = <ParsedEpisode>[];
    final numbers = <int>{};
    for (final value in decoded) {
      if (value is! Map<String, Object?>) {
        continue;
      }
      final episode = _episode(value, httpHeaders);
      if (episode != null && numbers.add(episode.episode.number)) {
        items.add(episode);
      }
    }
    if (items.isEmpty) {
      throw const AnistarFailure(message: 'У этого аниме пока нет доступных серий.');
    }
    items.sort((left, right) => left.episode.number.compareTo(right.episode.number));

    return List.unmodifiable(items);
  }

  List<AnistarCatalogFilterDto> _filters(List<Element> links, {bool detail = false}) {
    final paths = <String>{};
    final labels = <(String?, String)>{};
    final result = <AnistarCatalogFilterDto>[];
    for (final link in links) {
      final href = link.attributes['href'];
      final uri = _uri(href);
      final path = uri?.scheme == 'https' ? _linkedPath(href, uri) : null;
      final label = link.text.trim();
      if (path == null || label.isEmpty || !HtmlCatalogParameters.isValidPath(path)) {
        continue;
      }
      if (detail &&
          path != '/new/' &&
          path != '/anime/' &&
          !path.startsWith('/anime/') &&
          !path.startsWith('/filter/')) {
        continue;
      }
      final metadataField = detail ? _detailMetadataFilter.firstMatch(path)?.group(1) : null;
      if (paths.add(Uri.parse(path).path) && labels.add((metadataField, label.toLowerCase()))) {
        result.add(
          AnistarCatalogFilterDto(
            label: label,
            path: path,
            imageUri: _uri(link.querySelector('img')?.attributes['src']),
          ),
        );
      }
    }

    return List.unmodifiable(result);
  }

  String? _favoritePage(Uri? uri) => uri?.queryParameters['do'] == 'favorites'
      ? uri?.queryParameters['cstart']
      : RegExp(r'^/favorites/page/(\d+)/?$').firstMatch(uri?.path ?? '')?.group(1);

  String? _catalogPage(Uri? uri, String? filterPath) {
    if (uri == null || uri.hasQuery || uri.hasFragment || uri.userInfo.isNotEmpty) return null;
    final match = RegExp(r'^(/.+/)page/(\d+)/?$').firstMatch(uri.path);
    final path = match?.group(1);
    final expected = Uri.tryParse(filterPath ?? '/anime/')?.path;
    if (path == null || expected == null) return null;
    if (path == expected) return match?.group(2);
    if (expected == '/anime/' || expected.startsWith('/filter/')) return null;
    final alias = expected.startsWith('/anime/') ? expected.substring('/anime'.length) : '/anime$expected';

    return path == alias ? match?.group(2) : null;
  }

  AnistarAnimeSummaryDto? _card(Element card) {
    final link = card.querySelector('.title_left a') ?? card.querySelector('a[href]');
    final href = link?.attributes['href'];
    final (id, slug) = _titleIdentity(_linkedPath(href, _uri(href)));
    if (id == null || slug == null) {
      return null;
    }
    final title = (card.querySelector('.title-top')?.text ?? link?.text ?? '').trim();
    if (title.isEmpty) {
      return null;
    }
    final head = card.querySelector('ul.head');
    final genreLinks = _metadataRow(head, 'Жанр')?.querySelectorAll('a[href]') ?? const <Element>[];

    return AnistarAnimeSummaryDto.withGenreFilters(
      id: id,
      isFavorite: AnistarFavoritesHtml.status(card, id),
      rating: _rating(card),
      slug: slug,
      title: title,
      posterUri: _uri(card.querySelector('img[itemprop="image"], .poster img, .news_avatar img')?.attributes['src']),
      year: _metadata(head, 'Год выпуска'),
      genreText: _metadata(head, 'Жанр'),
      genreFilters: _filters(genreLinks),
      seriesInfo: _metadata(head, 'Серии'),
      voiceover: _metadata(head, 'Озвучка'),
      description: _description(card.querySelector('.news_text .descripts, .descripts')),
      updateMessage: _text(card.querySelector('.reason')),
      publicationDate: _text(card.querySelector('.date-icon')),
    );
  }

  double? _rating(Element card) {
    final value = card.querySelector('[itemprop="ratingValue"]');
    final raw =
        value?.attributes['content'] ??
        value?.text ??
        RegExp(r'(\d+(?:[.,]\d+)?)\s*/\s*10\b').firstMatch(card.text)?.group(1);
    final rating = double.tryParse((raw ?? '').trim().replaceAll(',', '.'));

    return rating != null && rating.isFinite && rating >= 0 && rating <= 10 ? rating : null;
  }

  String? _text(Element? element) {
    final value = element?.text.trim();

    return value == null || value.isEmpty ? null : value;
  }

  String? _description(Element? element) {
    final copy = element?.clone(true);
    if (copy == null) {
      return null;
    }
    for (final node in copy.querySelectorAll('.title_spoiler, .text_spoiler, .reason, script, style')) {
      node.remove();
    }

    return _text(copy);
  }

  List<AnistarAnimePartDto> _parts(Document document) {
    final result = <AnistarAnimePartDto>[];
    for (final title in document.querySelectorAll('.news_text .title_spoiler')) {
      final heading = title.text.trim().toLowerCase();
      if (!heading.startsWith('порядок просмотра') &&
          !heading.contains('в каком порядке') &&
          !heading.contains('серия состоит из')) {
        continue;
      }
      final content = title.nextElementSibling;
      if (content == null || !content.classes.contains('text_spoiler')) {
        continue;
      }
      for (final link in content.querySelectorAll('a[href]')) {
        final label = _text(link);
        if (label == null) {
          continue;
        }
        final href = link.attributes['href'];
        final uri = _uri(href);
        final (id, slug) = _titleIdentity(_linkedPath(href, uri));
        result.add(AnistarAnimePartDto(label: label, uri: uri, id: id, slug: slug));
      }
    }

    return List.unmodifiable(result);
  }

  (int?, String?) _titleIdentity(String? path) {
    if (path == null || _encodedTitleSeparators.hasMatch(path)) {
      return (null, null);
    }
    final slug = _titlePathPattern.firstMatch(path)?.group(1);
    final id = int.tryParse(slug?.split('-').first ?? '');

    return id == null || id <= 0 ? (null, null) : (id, slug);
  }

  String? _linkedPath(String? href, Uri? uri) {
    if (uri == null || uri.host.isEmpty || uri.origin != baseUri.origin || uri.hasQuery || uri.hasFragment) {
      return null;
    }
    // Uri normalizes escapes, so retain the path spelling from the HTML.
    final match = _linkedPathPattern.firstMatch(href?.trim() ?? '');
    final path = match?.group(2);
    if (path == null || match?.group(1)?.contains('@') == true) {
      return null;
    }

    return path.startsWith('/') ? path : '/$path';
  }

  void _checkChallenge(String source) {
    if (RegExp(
      r'cf-mitigated|<title>\s*Just a moment|Проверяем ваш браузер|Checking your browser',
      caseSensitive: false,
    ).hasMatch(source)) {
      throw const AnistarFailure(
        message: 'AniStar запросил проверку браузера. Попробуйте позже или настройте другое зеркало.',
      );
    }
  }

  Document _document(String source) {
    _checkChallenge(source);

    return html.parse(source);
  }

  ParsedEpisode? _episode(Map<String, Object?> item, Map<String, String> httpHeaders) {
    final title = item['title'];
    if (title is! String) {
      return null;
    }
    final number = int.tryParse(RegExp(r'\d+').firstMatch(title)?.group(0) ?? '');
    if (number == null || number <= 0) {
      return null;
    }
    final sources = <int, AnistarVideoSourceDto>{};
    final files = item['files'];
    if (files is List<Object?>) {
      for (final file in files.whereType<Map<String, Object?>>()) {
        final quality = file['title'];
        final value = file['file'];
        final uri = value is String ? _uri(value) : null;
        if (quality is String && (quality == '360' || quality == '720') && uri != null && uri.scheme == 'https') {
          final height = int.parse(quality);
          sources[height] = AnistarVideoSourceDto(
            height: height,
            manifestUri: uri,
            httpHeaders: httpHeaders,
            expiresAt: _expiry(uri),
          );
        }
      }
    }
    final image = item['image'];
    final mediaId = item['media_id'];

    return ParsedEpisode(
      AnistarEpisodeDto(
        number: number,
        title: title.trim(),
        isWatched: item['viewing'] == true,
        sources: sources.values.toList(),
        previewUri: image is String ? _uri(image) : null,
      ),
      mediaId is String && mediaId.isNotEmpty ? mediaId : null,
    );
  }

  DateTime? _expiry(Uri uri) {
    final raw = RegExp(r'end=(\d+)').firstMatch(uri.toString())?.group(1);
    final seconds = int.tryParse(raw ?? '');

    return seconds == null || seconds > 8640000000000
        ? null
        : DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
  }

  Element? _metadataRow(Element? head, String name) {
    for (final line in head?.querySelectorAll('li') ?? const <Element>[]) {
      if (line.text.trimLeft().startsWith('$name:')) {
        return line;
      }
    }

    return null;
  }

  String? _metadata(Element? head, String name) {
    final value = _metadataRow(head, name)?.text.trimLeft().substring(name.length + 1).trim();

    return value == null || value.isEmpty ? null : value;
  }

  Uri? _uri(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final uri = Uri.tryParse(value.trim());
    if (uri == null) {
      return null;
    }
    final resolved = baseUri.resolveUri(uri);

    return (resolved.scheme == 'https' || resolved.scheme == 'http') && resolved.hasAuthority ? resolved : null;
  }
}
