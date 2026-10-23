import 'package:anistar/anistar.dart';
import 'package:core/data.dart';
import 'package:networking/networking.dart';

import '../../common/data/anistar_errors.dart';
import '../domain/auth_profile.dart';
import '../domain/auth_repository.dart';

final class AnistarAuthRepository extends BaseRepository implements AuthRepository {
  final AnistarClient _client;

  @override
  Stream<void> get expired => _client.expired;

  @override
  Uri? get profileOrigin {
    final client = _client;

    return client is AnistarProfileClient ? client.origin : null;
  }

  AnistarAuthRepository(this._client, [super.logger]);

  @override
  Future<Result<String?, Failure>> restore({void Function()? onSessionCheck}) =>
      makeApiCall(() => mapAnistarErrors(() => _client.restore(onSessionCheck: onSessionCheck)));

  @override
  Future<Result<String, Failure>> signIn(String username, String password, {RequestCancellation? cancellation}) =>
      makeApiCall(() => mapAnistarErrors(() => _client.signIn(username, password, cancellation: cancellation)));

  @override
  Future<Result<void, Failure>> cancelSignIn(RequestCancellation cancellation) =>
      makeApiCall(() => mapAnistarErrors(() => _client.cancelSignIn(cancellation)));

  @override
  Future<Result<void, Failure>> signOut() => makeApiCall(() => mapAnistarErrors(_client.signOut));

  @override
  Future<Result<AuthProfile, Failure>> loadProfile(String account) {
    final client = _client;
    if (client is! AnistarProfileClient) {
      return Future.value(const Result.success(AuthProfile()));
    }

    return makeApiCall(
      () => mapAnistarErrors(() async {
        final profile = await client.profile(account);

        return AuthProfile(imageUri: profile.imageUri);
      }),
    );
  }
}
