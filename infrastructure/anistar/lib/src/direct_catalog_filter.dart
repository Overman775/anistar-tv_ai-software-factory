/// A site-owned catalog link. The path retains the site's percent encoding.
final class DirectCatalogFilter {
  final String label;
  final String path;

  const DirectCatalogFilter({required this.label, required this.path});

  static bool isValidPath(String path) => RegExp(
    r'^/(?:[a-z][a-z0-9-]*/|anime/[a-z][a-z0-9-]*/|filter/janrs/(?:[a-zA-Z0-9+_-]|%(?:[89a-fA-F][a-fA-F0-9]|20))+/)$',
  ).hasMatch(path);
}
