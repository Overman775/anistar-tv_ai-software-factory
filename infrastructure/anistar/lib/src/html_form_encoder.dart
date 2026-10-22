import 'dart:convert';

import 'anistar_failure.dart';
import 'html_decoder.dart';

/// Percent-encodes the bytes in the charset declared by a site form.
abstract final class HtmlFormEncoder {
  static String encode(Map<String, String> fields, String? contentType, {required String characterError}) {
    final cp1251 = RegExp('windows-1251|cp1251', caseSensitive: false).hasMatch(contentType ?? '');
    final alphabet = HtmlDecoder.decode(List<int>.generate(256, (index) => index), 'charset=windows-1251');
    String encode(String value) {
      final List<int> bytes;
      bytes = cp1251
          ? value.runes
                .map((rune) {
                  final index = alphabet.indexOf(String.fromCharCode(rune));
                  if (index < 0 || rune == 0xfffd) {
                    throw AnistarFailure(message: characterError);
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
