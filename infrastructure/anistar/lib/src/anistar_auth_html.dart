import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;

import 'anistar_failure.dart';
import 'html_form_encoder.dart';

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

  static String encodeForm(Map<String, String> fields, String? contentType) =>
      HtmlFormEncoder.encode(fields, contentType, characterError: 'Этот символ нельзя передать в форме входа AniStar.');
}
