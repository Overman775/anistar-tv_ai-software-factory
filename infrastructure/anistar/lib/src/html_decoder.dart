import 'dart:convert';

import 'anistar_failure.dart';

abstract final class HtmlDecoder {
  static String decode(List<int> bytes, String? contentType) {
    final type = contentType?.toLowerCase() ?? '';
    if (!type.contains('windows-1251') && !type.contains('cp1251')) {
      try {
        return utf8.decode(bytes);
      } on FormatException catch (_, stackTrace) {
        Error.throwWithStackTrace(
          const AnistarFailure(message: 'Не удалось прочитать кодировку страницы AniStar.'),
          stackTrace,
        );
      }
    }
    const special =
        '\u0402\u0403\u201a\u0453\u201e\u2026\u2020\u2021\u20ac\u2030\u0409\u2039\u040a\u040c\u040b\u040f'
        '\u0452\u2018\u2019\u201c\u201d\u2022\u2013\u2014\ufffd\u2122\u0459\u203a\u045a\u045c\u045b\u045f'
        '\u00a0\u040e\u045e\u0408\u00a4\u0490\u00a6\u00a7\u0401\u00a9\u0404\u00ab\u00ac\u00ad\u00ae\u0407'
        '\u00b0\u00b1\u0406\u0456\u0491\u00b5\u00b6\u00b7\u0451\u2116\u0454\u00bb\u0458\u0405\u0455\u0457';

    return String.fromCharCodes(
      bytes.map((byte) {
        if (byte < 128) {
          return byte;
        }
        if (byte >= 192) {
          return byte + 848;
        }

        return special.codeUnitAt(byte - 128);
      }),
    );
  }
}
