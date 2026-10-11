import 'package:anistar/anistar.dart';
import 'package:core/data.dart';
import 'package:networking/networking.dart';

import '../domain/auth_repository.dart';

final class AnistarAuthRepository extends BaseRepository implements AuthRepository {
  final AnistarClient _client;

  @override
  Stream<void> get expired => _client.expired;

  AnistarAuthRepository(this._client, [super.logger]);

  @override
  Future<Result<String?, Failure>> restore({void Function()? onSessionCheck}) =>
      makeApiCall(() => _client.restore(onSessionCheck: onSessionCheck));

  @override
  Future<Result<String, Failure>> signIn(String username, String password) =>
      makeApiCall(() => _client.signIn(username, password));

  @override
  Future<Result<void, Failure>> signOut() => makeApiCall(_client.signOut);
}
