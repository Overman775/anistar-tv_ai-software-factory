import 'dart:convert';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;

import 'anistar_failure.dart';
import 'html_decoder.dart';

/// DLE's login form and positive authentication marker, without executing scripts.
abstract final class AnistarAuthHtml {
  static bool isAuthenticated(String source, Uri baseUri) => logoutUri(source, baseUri) != null;

  static bool isGuest(String source) => html.parse(source).querySelector('input[name="login_password"]') != null;

  static Uri? logoutUri(String source, Uri baseUri) {
    for (final link in html.parse(source).querySelectorAll('a[href]')) {
      final reference = Uri.tryParse(link.attributes['href'] ?? '');
      if (reference == null) {
        continue;
      }
      final uri = baseUri.resolveUri(reference);
      // Menu links may be javascript:, mailto: or malformed HTML URLs. An
      // origin lookup on a non-HTTP URI throws instead of rejecting the link.
      if (uri.scheme != 'https' || uri.userInfo.isNotEmpty || uri.host != baseUri.host || uri.port != baseUri.port) {
        continue;
      }
      try {
        if (uri.queryParameters['action'] == 'logout') {
          return uri;
        }
      } on FormatException {
        continue;
      }
    }

    return null;
  }

  static Element loginForm(String source) {
    final input = html.parse(source).querySelector('input[name="login_password"]');
    var form = input?.parent;
    while (form != null && form.localName != 'form') {
      form = form.parent;
    }
    if (form == null || form.attributes['method']?.toLowerCase() != 'post') {
      throw const AnistarFailure(message: 'Форма входа AniStar изменилась.');
    }

    return form;
  }

  static String encodeForm(Map<String, String> fields, String? contentType) {
    final cp1251 = RegExp('windows-1251|cp1251', caseSensitive: false).hasMatch(contentType ?? '');
    final alphabet = HtmlDecoder.decode(List<int>.generate(256, (index) => index), 'charset=windows-1251');
    String encode(String value) {
      final List<int> bytes;
      bytes = cp1251
          ? value.runes
                .map((rune) {
                  final index = alphabet.indexOf(String.fromCharCode(rune));
                  if (index < 0 || rune == 0xfffd) {
                    throw const AnistarFailure(message: 'Этот символ нельзя передать в форме входа AniStar.');
                  }

                  return index;
                })
                .toList(growable: false)
          : utf8.encode(value);

      return bytes.map((byte) {
        if (byte == 32) {
          return '+';
        }
        if (byte >= 48 && byte <= 57 ||
            byte >= 65 && byte <= 90 ||
            byte >= 97 && byte <= 122 ||
            const [42, 45, 46, 95].contains(byte)) {
          return String.fromCharCode(byte);
        }

        return '%${byte.toRadixString(16).padLeft(2, '0').toUpperCase()}';
      }).join();
    }

    return fields.entries.map((entry) => '${encode(entry.key)}=${encode(entry.value)}').join('&');
  }
}
