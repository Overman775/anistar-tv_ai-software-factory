import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;

import 'anistar_failure.dart';

/// Reads DLE search controls as data; it never runs the page's JavaScript.
abstract final class AnistarSearchHtml {
  static AnistarSearchForm form(
    String source,
    Uri pageUri,
    String? contentType, {
    bool continuation = false,
    String? query,
  }) {
    final document = html.parse(source);
    final form = continuation
        ? document.querySelector('form#fullsearch')
        : document
              .querySelectorAll('form')
              .where(
                (element) =>
                    element.querySelector('[name="story"]') != null &&
                    element.querySelector('input[name="do"]')?.attributes['value'] == 'search' &&
                    element.querySelector('input[name="subaction"]')?.attributes['value'] == 'search',
              )
              .firstOrNull;
    if (form == null ||
        form.attributes['method']?.toLowerCase() != 'post' ||
        form.querySelector('[name="login_password"]') != null) {
      throw const AnistarFailure(message: 'Форма поиска AniStar изменилась.');
    }
    final reference = Uri.tryParse(form.attributes['action'] ?? '');
    final action = reference == null ? null : pageUri.resolveUri(reference);
    if (action == null ||
        action.scheme != 'https' ||
        !action.hasAuthority ||
        action.host.isEmpty ||
        action.userInfo.isNotEmpty ||
        action.origin != pageUri.origin ||
        action.hasFragment ||
        (continuation
            ? action.path != '/index.php' || action.query != 'do=search'
            : action.path != '/' || action.hasQuery)) {
      throw const AnistarFailure(message: 'AniStar вернул неподдерживаемый адрес формы поиска.');
    }
    final fields = <String, String>{
      for (final input in form.querySelectorAll('input[type="hidden"][name]'))
        input.attributes['name']!: input.attributes['value'] ?? '',
    };
    if (fields['do'] != 'search' || fields['subaction'] != 'search') {
      throw const AnistarFailure(message: 'Параметры поиска AniStar изменились.');
    }
    if (continuation &&
        (fields['full_search'] != '0' ||
            !fields.containsKey('search_start') ||
            !fields.containsKey('result_from') ||
            form.querySelector('[name="story"]')?.attributes['value'] != query)) {
      throw const AnistarFailure(message: 'Не удалось подтвердить продолжение поиска AniStar.');
    }
    final charset = charsetOf(form.attributes['accept-charset'] ?? contentType);

    return AnistarSearchForm(action: action, fields: fields, contentType: charset);
  }

  static bool hasNext(Document document, int page) {
    var next = false;
    for (final control in document.querySelectorAll('.pagenav a')) {
      final script = control.attributes['onclick'] ?? '';
      final match = RegExp(r'^\s*(?:return\s+)?list_submit\(\s*(\d+)\s*\)\s*;?\s*(?:return\s+false\s*;?)?\s*$')
          .firstMatch(script);
      final number = int.tryParse(match?.group(1) ?? '');
      if (number == page + 1) {
        next = true;
      } else if (number == null && RegExp(r'^\d+$').hasMatch(control.text.trim())) {
        throw const AnistarFailure(message: 'Переходы страниц поиска AniStar изменились.');
      }
    }

    return next;
  }

  static bool isEmpty(Document document) => document.querySelectorAll('.berrors').any((element) {
    final text = element.text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

    return text.contains('поиск по сайту не дал никаких результатов');
  });

  static String charsetOf(String? source) {
    if (source == null || source.trim().isEmpty) {
      return 'charset=utf-8';
    }
    final value = source.toLowerCase();
    if (value.contains('windows-1251') || value.contains('cp1251')) {
      return 'charset=windows-1251';
    }
    if (value.contains('utf-8') || value.contains('utf8') || !value.contains('charset')) {
      // A bare accept-charset value must also be one of the supported encodings.
      if (value.contains('/') || value == 'utf-8' || value == 'utf8') {
        return 'charset=utf-8';
      }
    }
    throw const AnistarFailure(message: 'Кодировка формы поиска AniStar не поддерживается.');
  }
}

final class AnistarSearchForm {
  final Uri action;
  final Map<String, String> fields;
  final String contentType;

  AnistarSearchForm({required this.action, required Map<String, String> fields, required this.contentType})
    : fields = Map.unmodifiable(fields);
}
