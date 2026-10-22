/// An original watch-order link; identity is present only for a supported title.
final class AnistarAnimePartDto {
  final String label;
  final Uri uri;
  final int? id;
  final String? slug;

  const AnistarAnimePartDto({required this.label, required this.uri, this.id, this.slug});
}
