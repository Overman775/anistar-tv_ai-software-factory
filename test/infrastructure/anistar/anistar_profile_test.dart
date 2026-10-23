import 'dart:convert';
import 'dart:typed_data';

import 'package:anistar/anistar.dart';
import 'package:anistar/html.dart';
import 'package:anistar/parsing.dart';
import 'package:anistar_tv/packages/features/auth/data/anistar_auth_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:networking/networking.dart';

import '../../mocks/storage/memory_secure_storage.dart';

void main() {
  final origin = Uri.parse('https://profiles.test/');

  group('AnistarProfileHtml', () {
    test('deduplicates relative and absolute trailing profile links in both menu contexts', () {
      const menus = [
        '''
          <div class="avatar"><a href="/user/viewer/">avatar</a></div>
          <li class="profile"><a href="https://profiles.test/user/viewer/">profile</a></li>
        ''',
        '''
          <div class="avatar"><a href="https://profiles.test/user/viewer/">avatar</a></div>
          <li class="profile"><a href="/user/viewer/">profile</a></li>
        ''',
      ];
      final profileUri = Uri.parse('${origin}user/viewer/');

      for (final menu in menus) {
        expect(_currentProfileUri(menu, origin), profileUri);
      }
    });

    test('rejects missing and unsafe account links', () {
      const missing = '<div class="avatar"><a href="/user/another">another account</a></div>';
      final unsafe = <String>[
        'http://profiles.test/user/viewer',
        'https://foreign.test/user/viewer',
        'https://name@profiles.test/user/viewer',
        'https://profiles.test/user/viewer?next=1',
        'https://profiles.test/user/viewer#profile',
        'https://profiles.test/user//viewer/',
        'https://profiles.test/user/viewer//',
        'https://profiles.test/user/viewer/extra',
      ];
      final profileFailure = throwsA(isA<AnistarFailure>());

      expect(() => _currentProfileUri(missing, origin), profileFailure);
      for (final href in unsafe) {
        expect(
          () => _currentProfileUri('<div class="avatar"><a href="$href">viewer</a></div>', origin),
          profileFailure,
        );
      }
    });

    test('distinguishes personal and default avatars from malformed or ambiguous markup', () {
      const personal =
          '<div class="user_info_cyber"><div class="avatar_cyber"><img class="main-img" src="/uploads/fotos/viewer.jpeg"></div></div>';
      const defaultAvatar =
          '<div class="user_info_cyber"><div class="avatar_cyber"><img class="main-img" src="/uploads/noavatar.png"></div></div>';
      const missing = '<div class="user_info_cyber"><div class="avatar_cyber"></div></div>';
      const ambiguous = '''
        <div class="user_info_cyber"><div class="avatar_cyber"><img class="main-img" src="/uploads/fotos/first.jpeg"></div></div>
        <div class="user_info_cyber"><div class="avatar_cyber"><img class="main-img" src="/uploads/fotos/second.jpeg"></div></div>
      ''';
      const unsafe =
          '<div class="user_info_cyber"><div class="avatar_cyber"><img class="main-img" src="https://profiles.test/uploads/fotos/viewer.jpeg?token=secret"></div></div>';
      final profileUri = Uri.parse('${origin}user/viewer');
      final profileFailure = throwsA(isA<AnistarFailure>());

      final personalProfile = _parseProfile(personal, profileUri, origin);
      final defaultProfile = _parseProfile(defaultAvatar, profileUri, origin);
      expect(personalProfile.imageUri, Uri.parse('https://profiles.test/uploads/fotos/viewer.jpeg'));
      expect(defaultProfile.imageUri, isNull);
      expect(() => _parseProfile(missing, profileUri, origin), profileFailure);
      expect(() => _parseProfile(ambiguous, profileUri, origin), profileFailure);
      expect(() => _parseProfile(unsafe, profileUri, origin), profileFailure);
    });
  });

  group('profile adapter and repository', () {
    late _ProfileFixtureAdapter adapter;
    late Dio dio;
    late AnistarSession session;
    late HtmlAnistarClient client;

    setUp(() {
      adapter = _ProfileFixtureAdapter();
      dio = Dio(BaseOptions(baseUrl: origin.toString()))..httpClientAdapter = adapter;
      session = AnistarSession(origin, MemorySecureStorage());
      client = HtmlAnistarClient(dio, session);
    });

    tearDown(() async {
      dio.close(force: true);
      await session.close();
    });

    test('preserves the trailing profile URI and returns personal or default avatar metadata', () async {
      final personal = await client.profile('viewer');
      final requests = adapter.requests;

      expect(personal.imageUri, Uri.parse('https://profiles.test/uploads/fotos/viewer.jpeg'));
      _expectProfileDocumentRequests(requests);
      expect(requests.where((request) => request.uri.path.startsWith('/uploads/')), isEmpty);
      for (final request in requests) {
        expect(request.headers.containsKey('Referer'), isFalse);
        expect(request.headers.containsKey('Authorization'), isFalse);
      }

      adapter.profileHtml = _defaultProfileHtml;
      requests.clear();
      final defaultProfile = await client.profile('viewer');
      expect(defaultProfile.imageUri, isNull);
      _expectProfileDocumentRequests(requests);
    });

    test('maps transport and parser failures to typed Result values without retrying', () async {
      final repository = AnistarAuthRepository(client);
      final requests = adapter.requests;
      final loadProfile = repository.loadProfile;

      adapter.menuStatus = 503;
      final transport = await loadProfile('viewer');
      expect(transport.failureOrNull, isA<ServerFailure>());
      expect(requests, hasLength(1));

      adapter
        ..menuStatus = 200
        ..profileHtml = '<div class="user_info_cyber"></div>';
      requests.clear();
      final malformed = await loadProfile('viewer');
      expect(malformed.failureOrNull, isA<RequestFailure>());
      expect(requests.map((request) => request.uri.path), ['/anime/', '/user/viewer/']);
      expect(malformed.successOrNull, isNull);
    });
  });
}

Uri _currentProfileUri(String source, Uri origin) =>
    AnistarProfileHtml.currentProfileUri(source, origin: origin, account: 'viewer');

AnistarProfileDto _parseProfile(String source, Uri profileUri, Uri origin) =>
    AnistarProfileHtml.profile(source, profileUri: profileUri, origin: origin);

void _expectProfileDocumentRequests(List<RequestOptions> requests) {
  final paths = requests.map((request) => request.uri.path).toList();
  final profileRequest = requests.last;
  expect(paths, ['/anime/', '/user/viewer/']);
  expect(profileRequest.uri, Uri.parse('https://profiles.test/user/viewer/'));
}

// The narrow in-file transport fixture belongs only to this adapter test.
// ignore: prefer-match-file-name
final class _ProfileFixtureAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  int menuStatus = 200;
  String profileHtml = _personalProfileHtml;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);

    return switch (options.uri.path) {
      '/anime/' => _html(_menuHtml, menuStatus),
      '/user/viewer/' => _html(profileHtml, 200),
      _ => _html('Not found', 404),
    };
  }

  @override
  void close({bool force = false}) => requests.clear();

  ResponseBody _html(String body, int status) => ResponseBody.fromBytes(
    utf8.encode(body),
    status,
    headers: const {
      'content-type': ['text/html; charset=UTF-8'],
    },
  );
}

const _menuHtml = '''
  <div class="avatar"><a href="/user/viewer/">avatar</a></div>
  <li class="profile"><a href="https://profiles.test/user/viewer/">profile</a></li>
''';

const _personalProfileHtml = '''
  <div class="user_info_cyber"><div class="avatar_cyber"><img class="main-img" src="/uploads/fotos/viewer.jpeg"></div></div>
''';

const _defaultProfileHtml = '''
  <div class="user_info_cyber"><div class="avatar_cyber"><img class="main-img" src="/uploads/noavatar.png"></div></div>
''';
