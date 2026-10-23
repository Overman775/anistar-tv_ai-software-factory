import 'dart:async';

import 'package:anistar/providers.dart';
import 'package:anistar_tv/app/authenticated_app.dart';
import 'package:anistar_tv/packages/features/anime/anime_providers.dart';
import 'package:anistar_tv/packages/features/auth/auth_providers.dart';
import 'package:anistar_tv/packages/features/catalog/catalog_providers.dart';
import 'package:anistar_tv/packages/features/favorites/favorites_providers.dart';
import 'package:anistar_tv/packages/features/home/presentation/screens/home_screen.dart';
import 'package:core/data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui_kit/ui_kit.dart';

import '../mocks/features/anime/fake_anime_screen_repository.dart';
import '../mocks/features/auth/fake_auth_repository.dart';
import '../mocks/features/catalog/fake_catalog_browse_repository.dart';
import '../mocks/features/catalog/fake_catalog_screen_repository.dart';
import '../mocks/features/favorites/fake_favorites_repository.dart';
import '../support/test_app.dart';

void main() {
  testWidgets('authenticated shell passes a matching loaded profile image to the account avatar', (tester) async {
    const imageUri = 'https://v30.astar.bz/uploads/avatar.jpg';
    final auth = FakeAuthRepository()
      ..restoreResult = const Result.success('Анна Каренина')
      ..profileOrigin = Uri.parse('https://v30.astar.bz/')
      ..profileResult = Result.success(AuthProfile(imageUri: Uri.parse(imageUri)));
    addTearDown(auth.close);

    await pumpTvApp(tester, const AuthenticatedApp(), wrapInScaffold: false, overrides: _overrides(auth));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(_accountAvatarImageWithUrl(imageUri), findsOneWidget);
  });

  testWidgets('authenticated shell keeps initials when loaded metadata belongs to a different origin', (tester) async {
    final auth = FakeAuthRepository()
      ..restoreResult = const Result.success('Анна Каренина')
      ..profileOrigin = Uri.parse('https://other.example/')
      ..profileResult = Result.success(AuthProfile(imageUri: Uri.parse('https://other.example/avatar.jpg')));
    addTearDown(auth.close);

    await pumpTvApp(tester, const AuthenticatedApp(), wrapInScaffold: false, overrides: _overrides(auth));
    await tester.pumpAndSettle();

    _expectInitialsWithoutImage(tester);
  });

  testWidgets('authenticated shell keeps initials for an absent avatar and failed metadata', (tester) async {
    final absent = FakeAuthRepository()
      ..restoreResult = const Result.success('Анна Каренина')
      ..profileOrigin = _origin;
    final settle = tester.pumpAndSettle;
    addTearDown(absent.close);
    await pumpTvApp(tester, const AuthenticatedApp(), wrapInScaffold: false, overrides: _overrides(absent));
    await settle();
    _expectInitialsWithoutImage(tester);

    final failed = FakeAuthRepository()
      ..restoreResult = const Result.success('Анна Каренина')
      ..profileOrigin = _origin
      ..profileResult = const Result.failure(UnknownFailure());
    addTearDown(failed.close);
    await pumpTvApp(tester, const AuthenticatedApp(), wrapInScaffold: false, overrides: _overrides(failed));
    await settle();
    _expectInitialsWithoutImage(tester);
  });

  testWidgets('guest shell never passes profile metadata to the account avatar', (tester) async {
    final auth = FakeAuthRepository()..restoreResult = const Result.success(null);
    addTearDown(auth.close);
    await pumpTvApp(tester, const AuthenticatedApp(), wrapInScaffold: false, overrides: _overrides(auth));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(_accountAvatarImage(), findsNothing);
  });

  testWidgets('loading metadata keeps initials, then exposes only the current matching image', (tester) async {
    final pending = Completer<Result<AuthProfile, Failure>>();
    final auth = FakeAuthRepository()
      ..restoreResult = const Result.success('Анна Каренина')
      ..profileOrigin = _origin
      ..pendingProfile = pending;
    addTearDown(auth.close);
    await pumpTvApp(tester, const AuthenticatedApp(), wrapInScaffold: false, overrides: _overrides(auth));
    await tester.pump();
    _expectInitialsWithoutImage(tester);

    pending.complete(Result.success(AuthProfile(imageUri: Uri.parse('https://v30.astar.bz/current.jpg'))));
    await tester.pumpAndSettle();
    expect(_accountAvatarImageWithUrl('https://v30.astar.bz/current.jpg'), findsOneWidget);
  });

  testWidgets('account and generation mismatches clear the routed avatar without replacing the router', (tester) async {
    const imageUri = 'https://v30.astar.bz/current.jpg';
    final auth = FakeAuthRepository()
      ..restoreResult = const Result.success('Анна Каренина')
      ..profileOrigin = _origin
      ..profileResult = Result.success(AuthProfile(imageUri: Uri.parse(imageUri)));
    final settle = tester.pumpAndSettle;
    addTearDown(auth.close);
    await pumpTvApp(tester, const AuthenticatedApp(), wrapInScaffold: false, overrides: _overrides(auth));
    await settle();
    final app = find.byType(AuthenticatedApp);
    final avatar = _accountAvatarImage();
    final matchingImage = _accountAvatarImageWithUrl(imageUri);
    final router = tester.widget<AuthenticatedApp>(app);
    expect(matchingImage, findsOneWidget);
    void expectFallbackWithoutRouterReplacement() {
      expect(tester.widget<AppNetworkImage>(avatar).imageUrl, isNull);
      expect(tester.widget<AuthenticatedApp>(app), same(router));
    }

    final profile = ProviderScope.containerOf(tester.element(app)).read(authProfileStateProvider.notifier);
    void loadProfile(String account, int contextGeneration) {
      profile.load(account: account, origin: _origin, contextGeneration: contextGeneration);
    }

    loadProfile('Другой аккаунт', 1);
    await settle();
    expectFallbackWithoutRouterReplacement();

    loadProfile('Анна Каренина', 2);
    await settle();
    expectFallbackWithoutRouterReplacement();
  });
}

final Uri _origin = Uri.parse('https://v30.astar.bz/');

void _expectInitialsWithoutImage(WidgetTester tester) {
  expect(find.text('АК'), findsOneWidget);
  _expectAvatarWithoutImage(tester);
}

void _expectAvatarWithoutImage(WidgetTester tester) {
  expect(tester.widget<AppNetworkImage>(_accountAvatarImage()).imageUrl, isNull);
}

Finder _accountAvatarImage() => find.descendant(of: find.byType(AppAvatar), matching: find.byType(AppNetworkImage));

Finder _accountAvatarImageWithUrl(String imageUrl) => find.descendant(
  of: find.byType(AppAvatar),
  matching: find.byWidgetPredicate((widget) => widget is AppNetworkImage && widget.imageUrl == imageUrl),
);

List<Override> _overrides(FakeAuthRepository auth) => [
  anistarMirrorManagerProvider.overrideWithValue(null),
  authRepositoryProvider.overrideWithValue(auth),
  catalogRepositoryProvider.overrideWithValue(const FakeCatalogScreenRepository()),
  catalogBrowseRepositoryProvider.overrideWithValue(
    FakeCatalogBrowseRepository(load: (_, page) => const FakeCatalogScreenRepository().getPage(page)),
  ),
  animeRepositoryProvider.overrideWithValue(const FakeAnimeScreenRepository()),
  favoritesRepositoryProvider.overrideWithValue(FakeFavoritesRepository()),
];
