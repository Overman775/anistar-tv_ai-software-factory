import 'package:dio/dio.dart';
import 'package:networking/networking.dart';

import 'anistar_failure.dart';
import 'anistar_profile_html.dart';
import 'contract/anistar_profile_dto.dart';
import 'html_decoder.dart';

/// Reads one current-account profile projection through the existing session.
final class AnistarProfileSource {
  final Uri _origin;
  final Dio _dio;

  AnistarProfileSource(this._dio, this._origin);

  Future<AnistarProfileDto> profile(String account) async {
    if (account.isEmpty) {
      throw const AnistarFailure(message: 'AniStar не подтвердил аккаунт профиля.');
    }
    final menu = await _html(_origin.resolve('anime/'));
    final profileUri = AnistarProfileHtml.currentProfileUri(menu, origin: _origin, account: account);
    final profile = await _html(profileUri);

    return AnistarProfileHtml.profile(profile, profileUri: profileUri, origin: _origin);
  }

  Future<String> _html(Uri uri) async {
    final response = await _dio.get<List<int>>(
      uri.toString(),
      options: DioClient.withoutRetry(
        Options(
          responseType: ResponseType.bytes,
          headers: const {'Accept': 'text/html', 'User-Agent': 'AniStarTV/1.0', 'Cache-Control': 'no-cache'},
        ),
      ),
    );
    if (response.headers.value('cf-mitigated') == 'challenge') {
      throw const AnistarFailure(message: 'AniStar требует проверку браузера. Попробуйте другое зеркало.');
    }
    final data = response.data;
    if (data == null) {
      throw const AnistarFailure(message: 'AniStar вернул пустую страницу профиля.');
    }

    return HtmlDecoder.decode(data, response.headers.value('content-type'));
  }
}
