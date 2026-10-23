import 'package:meta/meta.dart';

/// Optional presentation metadata for one confirmed account.
@immutable
final class AuthProfile {
  final Uri? imageUri;

  const AuthProfile({this.imageUri});
}
