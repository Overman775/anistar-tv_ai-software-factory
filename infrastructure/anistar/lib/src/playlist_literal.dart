import 'anistar_failure.dart';

/// Finds a complete array literal without executing any upstream JavaScript.
final class PlaylistLiteral {
  int _depth = 0;
  bool _escaped = false;
  bool _lineComment = false;
  bool _blockComment = false;
  String? _quote;

  String extract(String source) {
    final match = RegExp(r'\b(?:var|let|const)\s+playlst\s*=\s*\[').firstMatch(source);
    if (match == null) {
      throw const AnistarFailure(message: 'На странице AniStar не найден список серий.');
    }
    final start = match.end - 1;
    for (var i = start; i < source.length; i++) {
      final c = source[i];
      final next = i + 1 < source.length ? source[i + 1] : '';
      if (_lineComment) {
        if (c == '\n') {
          _lineComment = false;
        }
      } else if (_blockComment) {
        if (c == '*' && next == '/') {
          _blockComment = false;
          i++;
        }
      } else if (_quote != null) {
        _readQuoted(c);
      } else if (c == '/' && (next == '/' || next == '*')) {
        _lineComment = next == '/';
        _blockComment = next == '*';
        i++;
      } else if (c == '"' || c == "'") {
        _quote = c;
      } else if (c == '[') {
        _depth++;
      } else if (c == ']' && --_depth == 0) {
        return source.substring(start, i + 1);
      }
    }
    throw const AnistarFailure(message: 'Список серий AniStar имеет неизвестный формат.');
  }

  void _readQuoted(String c) {
    if (_escaped) {
      _escaped = false;
    } else if (c == r'\') {
      _escaped = true;
    } else if (c == _quote) {
      _quote = null;
    }
  }
}
