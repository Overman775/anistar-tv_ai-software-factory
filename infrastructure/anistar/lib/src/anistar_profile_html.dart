import 'package:html/parser.dart' as html;

import 'anistar_failure.dart';
import 'contract/anistar_profile_dto.dart';

/// Parses only the evidenced current-account profile and avatar markup.
abstract final class AnistarProfileHtml {
  static const _avatarSelector = '.user_info_cyber .avatar_cyber img.main-img';

  static Uri currentProfileUri(String source, {required Uri origin, required String account}) {
    final profiles = <Uri>{};
    final document = html.parse(source);
    for (final selector in const ['div.avatar > a[href]', 'li.profile > a[href]']) {
      for (final link in document.querySelectorAll(selector)) {
        final uri = _resolve(link.attributes['href'], origin);
        if (uri != null && _isCurrentProfile(uri, origin: origin, account: account)) {
          profiles.add(uri);
        }
      }
    }
    if (profiles.length != 1) {
      throw const AnistarFailure(message: 'AniStar не подтвердил профиль текущего аккаунта.');
    }

    return profiles.single;
  }

  static AnistarProfileDto profile(String source, {required Uri profileUri, required Uri origin}) {
    final images = html.parse(source).querySelectorAll(_avatarSelector);
    if (images.length != 1) {
      throw const AnistarFailure(message: 'AniStar не подтвердил изображение профиля.');
    }
    final imageUri = _resolve(images.single.attributes['src'], profileUri);
    if (imageUri == null || !_isSafeImage(imageUri, origin)) {
      throw const AnistarFailure(message: 'AniStar вернул небезопасный адрес изображения профиля.');
    }
    if (imageUri.pathSegments.isNotEmpty && imageUri.pathSegments.last == 'noavatar.png') {
      return const AnistarProfileDto();
    }
    if (!imageUri.path.startsWith('/uploads/fotos/') || !imageUri.path.toLowerCase().endsWith('.jpeg')) {
      throw const AnistarFailure(message: 'AniStar вернул неизвестный адрес изображения профиля.');
    }

    return AnistarProfileDto(imageUri: imageUri);
  }

  static Uri? _resolve(String? value, Uri baseUri) {
    final reference = Uri.tryParse(value ?? '');
    if (reference == null) {
      return null;
    }

    return baseUri.resolveUri(reference);
  }

  static bool _isCurrentProfile(Uri uri, {required Uri origin, required String account}) {
    final pathSegments = uri.pathSegments;
    final hasCurrentProfilePath =
        (pathSegments.length == 2 || (pathSegments.length == 3 && pathSegments.last.isEmpty)) &&
        pathSegments.first == 'user' &&
        pathSegments[1] == account;

    return uri.scheme == 'https' &&
        uri.userInfo.isEmpty &&
        uri.host == origin.host &&
        uri.port == origin.port &&
        !uri.hasQuery &&
        !uri.hasFragment &&
        hasCurrentProfilePath;
  }

  static bool _isSafeImage(Uri uri, Uri origin) =>
      uri.scheme == 'https' &&
      uri.userInfo.isEmpty &&
      uri.host == origin.host &&
      uri.port == origin.port &&
      !uri.hasQuery &&
      !uri.hasFragment;
}
