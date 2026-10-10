import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;
import 'package:json5/json5.dart';

import 'anistar_auth_html.dart';
import 'anistar_failure.dart';

/// Reads DLE favorite controls as data; never executes the site's scripts.
abstract final class AnistarFavoritesHtml {
  static bool? status(Element root, int animeId) =>
      _status([root, ...root.querySelectorAll('[onclick], a[href]')], animeId);

  static bool? documentStatus(Document document, int animeId) =>
      _status(document.querySelectorAll('[onclick], a[href]'), animeId);

  static bool? fragmentStatus(String source, int animeId) => documentStatus(html.parse(source), animeId);

  static String skin(String source) {
    final skin = _variable(source, 'dle_skin');
    if (skin == null || !RegExp(r'^[a-zA-Z0-9_-]{1,64}$').hasMatch(skin)) {
      throw const AnistarFailure(message: 'Не удалось прочитать настройки избранного AniStar.');
    }

    return skin;
  }

  static bool isEmpty(Document document, Uri origin) {
    final content = document.querySelector('#dle-content');
    final text = content?.text.toLowerCase() ?? '';
    final canonical = Uri.tryParse(document.querySelector('link[rel="canonical"]')?.attributes['href'] ?? '');
    final title = document.querySelector('title')?.text.toLowerCase() ?? '';
    if (content != null &&
        content.children.isEmpty &&
        text.trim().isEmpty &&
        title.contains('мои закладки') &&
        canonical?.hasAuthority == true &&
        canonical?.scheme == origin.scheme &&
        canonical?.origin == origin.origin &&
        canonical?.queryParameters['do'] == 'favorites' &&
        AnistarAuthHtml.isAuthenticated(document.outerHtml, origin)) {
      return true;
    }

    return RegExp(
      '(?:ещ[её].*(?:не|ничего)|(?:нет|пуст|не добав)).*(?:избран|заклад)|(?:избран|заклад).*(?:пуст|нет|не добав)',
      dotAll: true,
    ).hasMatch(text);
  }

  static bool? _status(Iterable<Element> controls, int animeId) {
    final states = <bool>{};
    for (final control in controls) {
      final action = RegExp(r'''doFavorites\s*\(\s*['"]?(\d+)['"]?\s*,\s*['"](plus|minus)['"]''')
          .firstMatch(control.attributes['onclick'] ?? '');
      if (int.tryParse(action?.group(1) ?? '') == animeId) {
        states.add(action?.group(2) == 'minus');
        continue;
      }
      final link = Uri.tryParse(control.attributes['href'] ?? '');
      if (link?.queryParameters['do'] == 'favorites' && int.tryParse(link?.queryParameters['id'] ?? '') == animeId) {
        final operation = link?.queryParameters['doaction'];
        if (operation == 'add' || operation == 'del') {
          states.add(operation == 'del');
        }
      }
    }

    return states.length == 1 ? states.single : null;
  }

  static String? _variable(String source, String name) {
    final document = html.parse(source);
    final expression = RegExp(
      '\\b$name\\s*=\\s*('
      r'''"(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*')''',
    );
    for (final script in document.querySelectorAll('script:not([src])')) {
      final value = expression.firstMatch(script.text)?.group(1);
      if (value != null) {
        final Object? decoded = json5Decode(value);

        return decoded is String ? decoded : null;
      }
    }

    return null;
  }
}
