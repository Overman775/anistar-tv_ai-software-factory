import 'package:anistar/anistar.dart';
import 'package:core/data.dart';
import 'package:networking/networking.dart';

import '../../common/data/anistar_errors.dart';
import '../domain/auth_repository.dart';

final class AnistarAuthRepository extends BaseRepository implements AuthRepository {
  final AnistarClient _client;

  @override
  Stream<void> get expired => _client.expired;

  AnistarAuthRepository(this._client, [super.logger]);

  @override
  Future<Result<String?, Failure>> restore({void Function()? onSessionCheck}) =>
      makeApiCall(() => mapAnistarErrors(() => _client.restore(onSessionCheck: onSessionCheck)));

  @override
  Future<Result<String, Failure>> signIn(String username, String password) =>
      makeApiCall(() => mapAnistarErrors(() => _client.signIn(username, password)));

  @override
  Future<Result<void, Failure>> signOut() => makeApiCall(() => mapAnistarErrors(_client.signOut));
}
