import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

import '../support/dart_directives.dart';

void main() {
  final workspace = _manifest(File('pubspec.yaml'))['workspace'] as YamlList;
  final packages = workspace.cast<String>().map(Directory.new).toList(growable: false);

  test('feature data uses client contracts without HTML, direct transport or DI imports', () {
    for (final file in _dartFiles(Directory('lib/packages/features'))) {
      if (!file.path.contains('/data/')) {
        continue;
      }
      for (final uri in _imports(file)) {
        expect(uri.startsWith('package:dio/'), isFalse, reason: '${file.path}: $uri');
        expect(uri.startsWith('package:http/'), isFalse, reason: '${file.path}: $uri');
        expect(uri.startsWith('package:html/'), isFalse, reason: '${file.path}: $uri');
        expect(uri, isNot('package:anistar/parsing.dart'), reason: file.path);
        expect(uri.startsWith('package:flutter_riverpod/'), isFalse, reason: '${file.path}: $uri');
        expect(uri.endsWith('/providers.dart'), isFalse, reason: '${file.path}: $uri');
      }
    }
  });

  test('workspace owns package resolution and a single lockfile', () {
    final manifest = _manifest(File('pubspec.yaml'));
    final workspace = manifest['workspace'];
    expect(workspace, isA<YamlList>());
    for (final directory in packages) {
      final package = _manifest(File('${directory.path}/pubspec.yaml'));
      expect(workspace, contains(directory.path));
      expect(package['resolution'], 'workspace', reason: directory.path);
      expect(File('${directory.path}/pubspec.lock').existsSync(), isFalse);
    }
    expect(File('pubspec.lock').existsSync(), isTrue);
  });

  test('Core is pure Dart and has no project or Flutter dependencies', () {
    final manifest = _manifest(File('infrastructure/core/pubspec.yaml'));
    expect(manifest['dependencies'], isNull);
    for (final file in _dartFiles(Directory('infrastructure/core/lib'))) {
      for (final uri in _imports(file)) {
        expect(uri.startsWith('package:'), isFalse, reason: '${file.path}: $uri');
      }
    }
  });

  test('workspace libraries use declared packages and cannot import app or features', () {
    for (final directory in packages) {
      final manifest = _manifest(File('${directory.path}/pubspec.yaml'));
      final name = manifest['name'];
      final Object? dependencies = manifest['dependencies'];
      final declared = dependencies is YamlMap ? dependencies.keys.whereType<String>().toSet() : <String>{};
      final library = Directory('${directory.path}/lib');
      for (final file in _dartFiles(library)) {
        for (final uri in _imports(file)) {
          if (uri.startsWith('dart:')) {
            continue;
          }
          if (uri.startsWith('package:')) {
            final package = uri.substring(8).split('/').first;
            expect(package == name || declared.contains(package), isTrue, reason: '${file.path}: $uri');
            expect(package, isNot('anistar_tv'), reason: file.path);
            expect(package == name || !uri.contains('/src/'), isTrue, reason: '${file.path}: private $uri');
          } else {
            final resolved = file.absolute.parent.uri.resolve(uri).normalizePath().toFilePath();
            expect(resolved.startsWith('${library.absolute.path}/'), isTrue, reason: '${file.path}: $uri');
          }
        }
      }
    }
  });

  test('feature domain uses neutral Core and feature UI cannot depend on app DI', () {
    for (final file in _dartFiles(Directory('lib/packages/features'))) {
      for (final uri in _imports(file)) {
        final packageImport = uri.startsWith('package:');
        if (file.path.contains('/domain/') && packageImport) {
          expect(uri, 'package:core/data.dart', reason: '${file.path}: domain dependency');
        }
        final resolved = packageImport ? uri : file.absolute.parent.uri.resolve(uri).normalizePath().toString();
        expect(resolved.contains('/app/'), isFalse, reason: '${file.path}: $uri');
        expect(uri.contains('/src/'), isFalse, reason: '${file.path}: private package API');
      }
    }
  });
}

YamlMap _manifest(File file) {
  final Object? value = loadYaml(file.readAsStringSync());
  if (value is! YamlMap) {
    throw FormatException('Invalid manifest: ${file.path}');
  }

  return value;
}

Iterable<File> _dartFiles(Directory directory) =>
    directory.listSync(recursive: true).whereType<File>().where((file) => file.path.endsWith('.dart'));

Iterable<String> _imports(File file) => libraryUris(file.readAsStringSync(), path: file.path);
