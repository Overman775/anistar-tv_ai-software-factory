/// Catalog link retaining the existing percent-encoded path.
final class AnistarCatalogFilterDto {
  final String label;
  final String path;
  final Uri? imageUri;

  const AnistarCatalogFilterDto({required this.label, required this.path, this.imageUri});
}
