import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;
import 'package:json5/json5.dart';

import 'anistar_failure.dart';
import 'anistar_favorites_html.dart';
import 'direct_anime.dart';
import 'direct_catalog_filter.dart';
import 'direct_catalog_page.dart';
import 'direct_episode.dart';
import 'playlist_literal.dart';

final class AnistarHtmlParser {
  final Uri baseUri;

  const AnistarHtmlParser(this.baseUri);

  DirectCatalogPage catalog(String source, int page, {bool favorites = false, String? filterPath}) {
    final document = _document(source);
    final items = <DirectAnime>[];
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
          final pageNumber = favorites
              ? _favoritePage(uri)
              : RegExp(filterPath == null ? r'^/anime/page/(\d+)/?$' : r'^/.+/page/(\d+)/?$')
                    .firstMatch(uri?.path ?? '')
                    ?.group(1);
          final number = int.tryParse(pageNumber ?? '');

          return uri?.origin == baseUri.origin && number != null && number > page;
        });

    return DirectCatalogPage(items: List.unmodifiable(items), page: page, hasNext: hasNext);
  }

  DirectAnime details(String source, String slug) {
    final document = _document(source);
    final title = document.querySelector('h1[itemprop="name"]')?.text.trim();
    final head = document.querySelector('ul.head');
    if (title == null || title.isEmpty || head == null) {
      throw const AnistarFailure(message: 'Не удалось разобрать карточку AniStar. Возможно, сайт изменился.');
    }
    final id = int.parse(slug.split('-').first);
    final genres = _metadata(head, 'Жанр');
    final category = document.querySelector('.ful-cat, .tags')?.text.toLowerCase() ?? '';

    return DirectAnime(
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
      description: document.querySelector('.descripts')?.text.trim(),
      isOngoing: category.contains('новинки') || category.contains('онгоинг'),
    );
  }

  List<DirectCatalogFilter> genres(String source) {
    final document = _document(source);
    final filters = _filters(document.querySelectorAll('.block-janrs a[href]'));
    if (filters.isEmpty) {
      throw const AnistarFailure(message: 'Не удалось загрузить жанры AniStar. Попробуйте снова.');
    }

    return filters;
  }

  List<DirectEpisode> episodes(String source) {
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
    final items = <DirectEpisode>[];
    final numbers = <int>{};
    for (final value in decoded) {
      if (value is! Map<String, Object?>) {
        continue;
      }
      final episode = _episode(value);
      if (episode != null && numbers.add(episode.number)) {
        items.add(episode);
      }
    }
    if (items.isEmpty) {
      throw const AnistarFailure(message: 'У этого аниме пока нет доступных серий.');
    }
    items.sort((left, right) => left.number.compareTo(right.number));

    return List.unmodifiable(items);
  }

  List<DirectCatalogFilter> _filters(List<Element> links, {bool detail = false}) {
    final paths = <String>{};
    final labels = <String>{};
    final result = <DirectCatalogFilter>[];
    for (final link in links) {
      final uri = _uri(link.attributes['href']);
      final label = link.text.trim();
      if (uri == null ||
          uri.origin != baseUri.origin ||
          uri.hasQuery ||
          uri.hasFragment ||
          label.isEmpty ||
          !DirectCatalogFilter.isValidPath(uri.path)) {
        continue;
      }
      if (detail &&
          uri.path != '/new/' &&
          uri.path != '/anime/' &&
          !uri.path.startsWith('/anime/') &&
          !uri.path.startsWith('/filter/janrs/')) {
        continue;
      }
      if (paths.add(uri.path) && labels.add(label.toLowerCase())) {
        result.add(DirectCatalogFilter(label: label, path: uri.path));
      }
    }

    return List.unmodifiable(result);
  }

  String? _favoritePage(Uri? uri) => uri?.queryParameters['do'] == 'favorites'
      ? uri?.queryParameters['cstart']
      : RegExp(r'^/favorites/page/(\d+)/?$').firstMatch(uri?.path ?? '')?.group(1);

  DirectAnime? _card(Element card) {
    final link = card.querySelector('.title_left a') ?? card.querySelector('a[href]');
    final uri = _uri(link?.attributes['href']);
    final match = RegExp(r'^/(\d+)-[^/]+\.html$').firstMatch(uri?.path ?? '');
    final id = int.tryParse(match?.group(1) ?? '');
    if (id == null || uri == null || uri.host != baseUri.host) {
      return null;
    }
    final title = (card.querySelector('.title-top')?.text ?? link?.text ?? '').trim();
    if (title.isEmpty) {
      return null;
    }

    return DirectAnime(
      id: id,
      isFavorite: AnistarFavoritesHtml.status(card, id),
      rating: _rating(card),
      slug: uri.pathSegments.last.replaceFirst(RegExp(r'\.html$'), ''),
      title: title,
      posterUri: _uri(card.querySelector('img[itemprop="image"], .poster img')?.attributes['src']),
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

  DirectEpisode? _episode(Map<String, Object?> item) {
    final title = item['title'];
    if (title is! String) {
      return null;
    }
    final number = int.tryParse(RegExp(r'\d+').firstMatch(title)?.group(0) ?? '');
    if (number == null || number <= 0) {
      return null;
    }
    final sources = <String, Uri>{};
    final files = item['files'];
    if (files is List<Object?>) {
      for (final file in files.whereType<Map<String, Object?>>()) {
        final quality = file['title'];
        final value = file['file'];
        final uri = value is String ? _uri(value) : null;
        if (quality is String && (quality == '360' || quality == '720') && uri != null && uri.scheme == 'https') {
          sources[quality] = uri;
        }
      }
    }
    final image = item['image'];
    final mediaId = item['media_id'];

    return DirectEpisode(
      number: number,
      title: title.trim(),
      isWatched: item['viewing'] == true,
      mediaId: mediaId is String && mediaId.isNotEmpty ? mediaId : null,
      sources: Map.unmodifiable(sources),
      previewUri: image is String ? _uri(image) : null,
    );
  }

  String? _metadata(Element head, String name) {
    for (final line in head.querySelectorAll('li')) {
      final text = line.text.trim();
      if (text.startsWith('$name:')) {
        return text.substring(name.length + 1).trim();
      }
    }

    return null;
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
