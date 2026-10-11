import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

import '../support/dart_directives.dart';
import '../support/project_library_graph.dart';

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

  final roots = <String, Directory>{
    'anistar_tv': Directory('lib'),
    for (final directory in packages)
      (_manifest(File('${directory.path}/pubspec.yaml'))['name'] as String): Directory('${directory.path}/lib'),
  };

  test('common AniStar library transitively exposes only transport independent contract types', () {
    for (final (file, uri) in projectLibraryEdges(File('infrastructure/anistar/lib/anistar.dart'), roots)) {
      final resolved = resolveProjectLibrary(file, uri, roots);
      expect(uri.startsWith('package:'), isFalse, reason: '${file.path}: $uri');
      if (resolved != null) {
        expect(resolved.path.contains('/anistar/lib/src/contract/'), isTrue, reason: '${file.path}: $uri');
      }
    }
  });

  test('domain imports and re-exports stay within Dart Core and feature domain', () {
    for (final file in _dartFiles(Directory('lib/packages/features')).where((file) => file.path.contains('/domain/'))) {
      for (final (owner, uri) in projectLibraryEdges(file, roots)) {
        if (uri.startsWith('dart:')) {
          continue;
        }
        final resolved = resolveProjectLibrary(owner, uri, roots);
        expect(resolved, isNotNull, reason: '${owner.path}: external domain dependency $uri');
        final path = resolved?.path ?? '';
        expect(
          path.contains('/infrastructure/core/lib/') || path.contains('/features/') && path.contains('/domain/'),
          isTrue,
          reason: '${owner.path}: $uri',
        );
      }
    }
  });

  test('presentation uses domain and feature providers without importing data or AniStar', () {
    for (final file in _dartFiles(Directory('lib/packages/features'))) {
      for (final uri in _imports(file)) {
        final resolved = resolveProjectLibrary(file, uri, roots);
        final path = resolved?.path ?? uri;
        expect(path.contains('/app/'), isFalse, reason: '${file.path}: $uri');
        if (!file.path.contains('/presentation/')) {
          continue;
        }
        for (final (owner, dependency) in projectLibraryEdges(
          file,
          roots,
          follow: (target) => target.path.contains('/features/') && !target.path.endsWith('providers.dart'),
        )) {
          final target = resolveProjectLibrary(owner, dependency, roots);
          final dependencyPath = target?.path ?? dependency;
          expect(dependencyPath.contains('/data/'), isFalse, reason: '${owner.path}: $dependency');
          expect(dependencyPath.contains('/infrastructure/anistar/'), isFalse, reason: '${owner.path}: $dependency');
          expect(dependency.contains('/src/'), isFalse, reason: '${owner.path}: private $dependency');
        }
      }
    }
  });

  test('feature data graph does not reach HTML implementation transport or providers', () {
    for (final file in _dartFiles(Directory('lib/packages/features')).where((file) => file.path.contains('/data/'))) {
      for (final (owner, uri) in projectLibraryEdges(
        file,
        roots,
        follow: (target) => target.path.contains('/features/') || target.path.contains('/anistar/'),
      )) {
        final resolved = resolveProjectLibrary(owner, uri, roots);
        final path = resolved?.path ?? uri;
        // Networking and app_logging public APIs own their transport/Flutter internals.
        // Inspect the feature/client graph without traversing those packages.
        if (!owner.path.contains('/features/') && !owner.path.contains('/anistar/')) {
          continue;
        }
        expect(
          uri.startsWith('package:dio/') || uri.startsWith('package:html/') || uri.startsWith('package:http/'),
          isFalse,
          reason: '${owner.path}: $uri',
        );
        expect(uri.contains('riverpod') || path.endsWith('providers.dart'), isFalse, reason: '${owner.path}: $uri');
        expect(
          !path.contains('/anistar/') || path.endsWith('/anistar.dart') || path.contains('/contract/'),
          isTrue,
          reason: '${owner.path}: $uri',
        );
      }
    }
  });

  test('resolver catches relative re-exports and parts while allowing a domain contract', () {
    final temp = Directory.systemTemp.createTempSync('anistar-boundaries-');
    addTearDown(() => temp.deleteSync(recursive: true));
    final root = Directory('${temp.path}/features/sample/domain')..createSync(recursive: true);
    final data = Directory('${temp.path}/features/sample/data')..createSync();
    File('${data.path}/bad.dart').writeAsStringSync('');
    final entry = File('${root.path}/contract.dart')..writeAsStringSync("export 'allowed.dart';");
    File('${root.path}/allowed.dart').writeAsStringSync("import 'dart:async';");
    expect(projectLibraryEdges(entry, {}).map((edge) => edge.$2), ['allowed.dart', 'dart:async']);
    File('${root.path}/allowed.dart').writeAsStringSync("export '../data/bad.dart'; part 'piece.dart';");
    File('${root.path}/piece.dart').writeAsStringSync("part of 'allowed.dart';");
    final paths = projectLibraryEdges(
      entry,
      {},
    ).map((edge) => resolveProjectLibrary(edge.$1, edge.$2, {})?.path).toList();
    expect(paths, contains('${data.path}/bad.dart'));
    expect(paths, contains('${root.path}/piece.dart'));
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
