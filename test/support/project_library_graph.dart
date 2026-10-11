import 'dart:io';

import 'dart_directives.dart';

/// Resolve only project libraries. External packages are leaves in this graph.
File? resolveProjectLibrary(File from, String uri, Map<String, Directory> packages) {
  if (uri.startsWith('dart:')) {
    return null;
  }
  if (uri.startsWith('package:')) {
    final parts = uri.substring(8).split('/');
    final root = packages[parts.first];

    return root == null ? null : File('${root.path}/${parts.skip(1).join('/')}').absolute;
  }

  return File.fromUri(from.absolute.parent.uri.resolve(uri).normalizePath());
}

/// Imports, exports, conditional branches and parts are visited exactly once.
Iterable<(File, String)> projectLibraryEdges(
  File root,
  Map<String, Directory> packages, {
  bool Function(File)? follow,
}) sync* {
  final visited = <String>{};
  final pending = [root.absolute];
  while (pending.isNotEmpty) {
    final file = pending.removeLast();
    if (!visited.add(file.path)) {
      continue;
    }
    for (final uri in libraryUris(file.readAsStringSync(), path: file.path)) {
      yield (file, uri);
      final resolved = resolveProjectLibrary(file, uri, packages);
      if (resolved != null && (follow?.call(resolved) ?? true)) {
        pending.add(resolved);
      }
    }
  }
}
