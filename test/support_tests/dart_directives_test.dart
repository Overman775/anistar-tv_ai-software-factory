import 'package:flutter_test/flutter_test.dart';

import '../support/dart_directives.dart';

void main() {
  test('boundary checks inspect conditional imports/exports and part directives', () {
    const source = '''
import 'dart:io' if (dart.library.html) 'package:foreign/src/private.dart';
export 'public.dart' if (dart.library.io) '../../app/app.dart';
part 'generated.g.dart';
''';
    expect(libraryUris(source), [
      'dart:io',
      'package:foreign/src/private.dart',
      'public.dart',
      '../../app/app.dart',
      'generated.g.dart',
    ]);
  });

  test('comments and ordinary strings cannot impersonate a dependency', () {
    const source = '''
// import 'package:fake/private.dart';
import 'dart:async';
const example = "export 'package:fake/private.dart';";
''';
    expect(libraryUris(source), ['dart:async']);
  });
}
