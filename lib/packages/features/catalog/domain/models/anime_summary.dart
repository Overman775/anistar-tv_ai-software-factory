final class AnimeSummary {
  final int id;
  final Uri posterUri;
  final String slug;
  final String title;
  final String? year;

  const AnimeSummary({required this.id, required this.slug, required this.title, required this.posterUri, this.year});
}
