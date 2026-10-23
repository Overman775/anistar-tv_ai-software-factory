import 'anistar_client.dart';
import 'anistar_profile_dto.dart';

/// Optional AniStar capability for account-profile metadata.
///
/// The normal catalog contract stays usable for consumers that do not need a
/// profile request. Implementations are origin-bound and validate the supplied
/// confirmed account before returning metadata.
abstract interface class AnistarProfileClient implements AnistarClient {
  Uri get origin;

  Future<AnistarProfileDto> profile(String account);
}
