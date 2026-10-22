/// A site-provided part in document order. Missing identity remains plain text.
final class AnimePart {
  final String label;
  final Uri uri;
  final int? id;
  final String? slug;

  bool get canOpen => id != null && slug != null;

  const AnimePart({required this.label, required this.uri, this.id, this.slug});
}
