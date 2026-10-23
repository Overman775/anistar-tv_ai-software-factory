/// Optional public profile metadata for the confirmed AniStar account.
final class AnistarProfileDto {
  /// A public profile image URI, or null when AniStar confirms its default avatar.
  final Uri? imageUri;

  const AnistarProfileDto({this.imageUri});
}
