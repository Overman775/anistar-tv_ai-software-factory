/// A labeled link to a catalog on the active site.
final class CatalogFilter {
  final String label;
  final String path;
  final Uri? imageUri;

  const CatalogFilter({required this.label, required this.path, this.imageUri});
}
