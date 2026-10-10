import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;
import 'package:json5/json5.dart';

import 'anistar_failure.dart';
import 'anistar_favorites_html.dart';
import 'direct_anime.dart';
import 'direct_catalog_page.dart';
import 'direct_episode.dart';
import 'playlist_literal.dart';

final class AnistarHtmlParser {
  final Uri baseUri;

  const AnistarHtmlParser(this.baseUri);

  DirectCatalogPage catalog(String source, int page, {bool favorites = false}) {
    final document = _document(source);
    final items = <DirectAnime>[];
    final ids = <int>{};
    for (final card in document.querySelectorAll('.news, .plash')) {
      final item = _card(card);
      if (item != null && item.id != 9493 && ids.add(item.id)) {
        items.add(item);
      }
    }
    if (items.isEmpty && (!favorites || !AnistarFavoritesHtml.isEmpty(document))) {
      throw const AnistarFailure(message: 'Не удалось разобрать каталог AniStar. Возможно, сайт изменился.');
    }
    final hasNext = document.querySelectorAll('a[href]').any((link) {
      final uri = _uri(link.attributes['href']);
      final pageNumber = favorites
          ? _favoritePage(uri)
          : RegExp(r'^/anime/page/(\d+)/?$').firstMatch(uri?.path ?? '')?.group(1);
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
      slug: uri.pathSegments.last.replaceFirst(RegExp(r'\.html$'), ''),
      title: title,
      posterUri: _uri(card.querySelector('img[itemprop="image"], .poster img')?.attributes['src']),
    );
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

    return DirectEpisode(
      number: number,
      title: title.trim(),
      isWatched: item['viewing'] == true,
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
