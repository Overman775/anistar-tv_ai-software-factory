// import 'package:core/storages.dart';

// const _refreshTokenKey = 'KEY_REFRESH_TOKEN';

// class AuthTokenStorage {
//   AuthTokenStorage(this._secureStorage);

//   final SecureStorage _secureStorage;

//   String? _token;

//   String? get token => _token;

//   Future<String?> getRefreshToken() => _secureStorage.get(_refreshTokenKey);

//   Future<void> saveTokens(AuthTokens tokens) async {
//     await _secureStorage.set(_refreshTokenKey, tokens.refreshToken);

//     _token = tokens.accessToken;
//   }

//   Future<void> clearData() async {
//     _token = null;

//     await _secureStorage.remove(_refreshTokenKey);
//   }
// }
