import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

/// Reads imports, exports and parts, including conditional library branches.
Iterable<String> libraryUris(String source, {String? path}) sync* {
  final unit = parseString(content: source, path: path).unit;
  for (final directive in unit.directives) {
    if (directive is UriBasedDirective) {
      final uri = directive.uri.stringValue;
      if (uri != null) {
        yield uri;
      }
    }
    if (directive is NamespaceDirective) {
      for (final configuration in directive.configurations) {
        final uri = configuration.uri.stringValue;
        if (uri != null) {
          yield uri;
        }
      }
    }
  }
}
