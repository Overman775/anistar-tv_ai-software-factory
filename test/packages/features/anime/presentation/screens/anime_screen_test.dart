import 'dart:async';

import 'package:anistar_tv/packages/features/anime/anime_providers.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_details.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_episode.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_part.dart';
import 'package:anistar_tv/packages/features/anime/domain/models/anime_screen_data.dart';
import 'package:anistar_tv/packages/features/anime/presentation/screens/anime_screen.dart';
import 'package:anistar_tv/packages/features/anime/presentation/widgets/anime_hero.dart';
import 'package:anistar_tv/packages/features/anime/presentation/widgets/episode_card.dart';
import 'package:anistar_tv/packages/features/anime/presentation/widgets/mobile_anime_poster_header.dart';
import 'package:anistar_tv/packages/features/auth/auth_providers.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/catalog_filter.dart';
import 'package:anistar_tv/packages/features/favorites/favorites_providers.dart';
import 'package:core/data.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/semantics.dart' show SemanticsAction;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../../../mocks/features/anime/fake_anime_screen_repository.dart';
import '../../../../../support/test_app.dart';

// Focus is mutable: each assertion reads the result of the preceding key event.

void main() {
  for (final reduced in [false, true]) {
    testWidgets('disclosure reverses from current progress and restores focus; reduced=$reduced', (tester) async {
      final data = AnimeScreenData(
        details: AnimeDetails(
          id: 1,
          slug: 'test',
          title: 'Тест',
          genres: const ['Комедия'],
          isOngoing: false,
          filters: const [CatalogFilter(label: 'Комедия', path: '/anime/comedy/')],
        ),
        episodes: const [AnimeEpisode(number: 1, title: 'Серия 1')],
      );
      await pumpTvApp(
        tester,
        MediaQuery(
          data: MediaQueryData(size: compactTvSize, disableAnimations: reduced, textScaler: const TextScaler.linear(2)),
          child: AnimeScreen(
            animeId: 1,
            slug: 'test',
            fallbackTitle: 'Тест',
            onEpisodeTap: (episode) => fail('Unexpected episode ${episode.number}'),
          ),
        ),
        wrapInScaffold: false,
        overrides: [
          animeRepositoryProvider.overrideWithValue(
            FakeAnimeScreenRepository(load: (_, _) async => Result.success(data)),
          ),
        ],
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      double progress() => tester.widget<AnimeDisclosure>(find.byType(AnimeDisclosure)).progress.value;
      final opening = progress();
      if (reduced) {
        expect(opening, 1);
      } else {
        expect(opening, inExclusiveRange(0, 1));
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pump();
      if (reduced) {
        expect(find.byType(AnimeDisclosure), findsNothing);
      } else {
        expect(progress(), closeTo(opening, 0.02));
      }
      await tester.pump(const Duration(milliseconds: 40));
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(progress(), 1);
      expect(find.text('Комедия'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'Подробнее');
      expect(find.byType(AnimeDisclosure), reduced ? findsNothing : findsOneWidget);
      if (!reduced) expect(tester.widget<AnimeDisclosure>(find.byType(AnimeDisclosure)).expanded, isFalse);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('filter, part and player returns restore the selected disclosure context', (tester) async {
    const filter = CatalogFilter(label: 'Автор', path: '/filter/author/%f1%E8+%fd/');
    final part = AnimePart(
      label: 'Следующая часть',
      uri: Uri.parse('https://fixture.test/2-next.html'),
      id: 2,
      slug: '2-next',
    );
    final data = AnimeScreenData(
      details: AnimeDetails(
        id: 1,
        slug: 'test',
        title: 'Тест',
        genres: const [],
        isOngoing: false,
        author: 'Автор',
        filters: const [filter],
        parts: [part],
      ),
      episodes: const [AnimeEpisode(number: 1, title: 'Серия 1')],
    );
    final opened = <String>[];
    await pumpTvApp(
      tester,
      Builder(
        builder: (context) {
          void open(String label) {
            opened.add(label);
            unawaited(Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => Text('Route $label'))));
          }

          return AnimeScreen(
            animeId: 1,
            slug: 'test',
            fallbackTitle: 'Тест',
            onFilterTap: (value) => open(value.path),
            onPartTap: (value) => open(value.label),
            onEpisodeTap: (value) => open('episode ${value.number}'),
          );
        },
      ),
      wrapInScaffold: false,
      overrides: [
        animeRepositoryProvider.overrideWithValue(
          FakeAnimeScreenRepository(load: (_, _) async => Result.success(data)),
        ),
      ],
    );
    await tester.pumpAndSettle();
    Future<void> key(LogicalKeyboardKey key) async {
      await tester.sendKeyEvent(key);
      await tester.pumpAndSettle();
    }

    Future<void> returnFrom(String route, String label) async {
      expect(find.text('Route $route'), findsOneWidget);
      Navigator.of(tester.element(find.text('Route $route'))).pop();
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus?.debugLabel, label);
      expect(tester.widget<AnimeDisclosure>(find.byType(AnimeDisclosure)).expanded, isTrue);
    }

    await key(LogicalKeyboardKey.arrowUp);
    await key(LogicalKeyboardKey.select);
    await key(LogicalKeyboardKey.arrowDown);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'Автор');
    await key(LogicalKeyboardKey.select);
    await returnFrom(filter.path, 'Автор');
    await key(LogicalKeyboardKey.arrowDown);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'Следующая часть');
    await key(LogicalKeyboardKey.select);
    await returnFrom('Следующая часть', 'Следующая часть');
    await key(LogicalKeyboardKey.arrowDown);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'Серия 1');
    await key(LogicalKeyboardKey.select);
    await returnFrom('episode 1', 'Серия 1');
    expect(opened, [filter.path, 'Следующая часть', 'episode 1']);
    await key(LogicalKeyboardKey.escape);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'Подробнее');
    expect(find.text('Следующая часть'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('common remote retry for an unusable playlist stays single-flight', (tester) async {
    var calls = 0;
    final pending = Completer<Result<AnimeScreenData, Failure>>();
    final repository = FakeAnimeScreenRepository(
      load: (_, _) async {
        calls++;

        return calls == 1
            ? Result.success(
                AnimeScreenData(
                  details: AnimeDetails(id: 1, slug: 'test', title: 'Тест', genres: [], isOngoing: false),
                  episodes: [],
                ),
              )
            : pending.future;
      },
    );
    await pumpTvApp(
      tester,
      AnimeScreen(animeId: 1, slug: 'test', fallbackTitle: 'Тест', onEpisodeTap: (_) => fail('Unexpected episode')),
      wrapInScaffold: false,
      disableAnimations: true,
      overrides: [
        authAccessProvider.overrideWithValue(const AuthenticatedAccess('test')),
        favoritesAccountProvider.overrideWithValue('test'),
        animeRepositoryProvider.overrideWithValue(repository),
      ],
    );
    await tester.pumpAndSettle();
    expect(find.text('Не удалось загрузить аниме'), findsOneWidget);
    final reload = find.widgetWithText(AppButton, 'Повторить');
    expect(reload.hitTestable(), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(find.byType(TvSkeleton), findsOneWidget);
    expect(reload, findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(calls, 2);
    pending.complete(Result.success(_routeData(1, 'Готовая карточка')));
    await tester.pumpAndSettle();
    expect(find.text('Подробнее'), findsOneWidget);
    expect(find.byType(EpisodeCard), findsAtLeastNWidgets(1));
    expect(tester.takeException(), isNull);
  });
  testWidgets('unexpected detail error stays safe and remote retry recovers', (tester) async {
    var attempts = 0;
    final repository = FakeAnimeScreenRepository(
      load: (id, slug) {
        attempts++;
        if (attempts == 1) {
          throw StateError('https://cdn.test/private?token=secret');
        }

        return const FakeAnimeScreenRepository().getAnime(id: id, slug: slug);
      },
    );
    await pumpTvApp(
      tester,
      AnimeScreen(animeId: 1, slug: 'test', fallbackTitle: 'Тест', onEpisodeTap: (_) => fail('Unexpected episode')),
      wrapInScaffold: false,
      overrides: [
        authAccessProvider.overrideWithValue(const AuthenticatedAccess('test')),
        favoritesAccountProvider.overrideWithValue('test'),
        animeRepositoryProvider.overrideWithValue(repository),
      ],
    );
    await tester.pumpAndSettle();
    expect(find.text('Не удалось загрузить данные аниме. Повторите попытку.'), findsOneWidget);
    expect(find.textContaining('secret'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.byType(EpisodeCard), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('obsolete detail response cannot overwrite latest favorite state', (tester) async {
    final pending = Completer<Result<AnimeScreenData, Failure>>();
    AnimeScreenData data(bool favorite) => AnimeScreenData(
      details: AnimeDetails(
        id: 1,
        slug: 'test',
        title: 'Тест',
        genres: const [],
        isOngoing: false,
        isFavorite: favorite,
      ),
      episodes: const [AnimeEpisode(number: 1, title: 'Серия 1')],
    );
    final repository = FakeAnimeScreenRepository(
      load: (_, slug) => slug == 'old' ? pending.future : Future.value(Result.success(data(false))),
    );
    AnimeScreen screen(String slug) =>
        AnimeScreen(animeId: 1, slug: slug, fallbackTitle: 'Тест', onEpisodeTap: (_) => fail('Unexpected episode'));
    final overrides = [
      authAccessProvider.overrideWithValue(const AuthenticatedAccess('test')),
      favoritesAccountProvider.overrideWithValue('test'),
      animeRepositoryProvider.overrideWithValue(repository),
    ];
    await pumpTvApp(tester, screen('old'), wrapInScaffold: false, overrides: overrides);
    await tester.pump();
    await pumpTvApp(tester, screen('new'), wrapInScaffold: false, overrides: overrides);
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(tester.element(find.byType(AnimeScreen)));
    final latestKnown = container.read(favoritesControllerProvider).known;
    expect(find.text('В избранное'), findsOneWidget);
    pending.complete(Result.success(data(true)));
    await tester.pumpAndSettle();
    expect(container.read(favoritesControllerProvider).known, latestKnown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(find.text('В избранное'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final size in [compactTvSize, wideTvSize, const Size(640, 360)]) {
    for (final scale in [1.3, 2.0]) {
      testWidgets('scaled text $scale keeps disclosure and episode navigation reachable at $size', (tester) async {
        int? opened;
        final data = AnimeScreenData(
          details: AnimeDetails(
            id: 1,
            slug: 'anime',
            title: 'Пожалуйста, простите моих младших братьев / Please Forgive My Younger Brothers',
            genres: const ['Комедия', 'Повседневность', 'Романтика'],
            isOngoing: true,
            posterUri: Uri(),
            year: '2026',
            seriesInfo: '14 серий',
            voiceover: 'Озвучивание: AniStar',
            description: List.filled(8, 'История о семье, дружбе и неожиданных приключениях.').join(' '),
          ),
          episodes: const [AnimeEpisode(number: 1, title: 'Серия 1')],
        );
        await pumpTvApp(
          tester,
          MediaQuery(
            data: MediaQueryData(size: size, disableAnimations: true, textScaler: TextScaler.linear(scale)),
            child: AnimeScreen(
              animeId: 1,
              slug: 'anime',
              fallbackTitle: data.details.title,
              onEpisodeTap: (episode) => opened = episode.number,
            ),
          ),
          size: size,
          wrapInScaffold: false,
          overrides: [
            authAccessProvider.overrideWithValue(const AuthenticatedAccess('test')),
            favoritesAccountProvider.overrideWithValue('test'),
            animeRepositoryProvider.overrideWithValue(
              FakeAnimeScreenRepository(load: (_, _) async => Result.success(data)),
            ),
          ],
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final episode = find.byType(EpisodeCard);
        expect(episode.hitTestable(), findsOneWidget);
        expect(FocusManager.instance.primaryFocus?.debugLabel, 'Серия 1');
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
        expect(FocusManager.instance.primaryFocus?.debugLabel, 'Подробнее');
        expect(find.text('Подробнее').hitTestable(), findsOneWidget);
        final title = tester.widget<Text>(find.text(data.details.title));
        expect(title.maxLines, isNull);
        expect(title.overflow, isNull);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
        expect(FocusManager.instance.primaryFocus?.debugLabel, 'Избранное сериала');
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(episode.hitTestable(), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        expect(opened, 1);
        // Navigation must not introduce a new layout exception.
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final (width, stacked) in [(564.0, true), (640.0, false)]) {
    testWidgets('TV disclosure keeps the full rating on one line at ${width}dp and 200% text', (tester) async {
      const filter = CatalogFilter(label: 'Комедия', path: '/filter/janrs/comedy/');
      final data = AnimeScreenData(
        details: AnimeDetails(
          id: 1,
          slug: 'test',
          title: 'Аниме',
          genres: const ['Комедия'],
          isOngoing: false,
          rating: 10,
          filters: const [filter],
        ),
        episodes: const [AnimeEpisode(number: 1, title: 'Серия 1')],
      );
      await pumpTvApp(
        tester,
        // Reproduce the 48dp outer inset used in the review boundary fixture.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: AnimeScreen(
            animeId: 1,
            slug: 'test',
            fallbackTitle: 'Аниме',
            onEpisodeTap: (episode) => fail('Unexpected episode ${episode.number}'),
            onFilterTap: (selected) => fail('Unexpected filter ${selected.path}'),
          ),
        ),
        size: Size(width, 844),
        textScale: 2,
        wrapInScaffold: false,
        overrides: [
          animeRepositoryProvider.overrideWithValue(
            FakeAnimeScreenRepository(load: (_, _) async => Result.success(data)),
          ),
        ],
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(focusedControlLabel(tester), 'Подробнее');
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();

      final score = find.text('10,0 /\u00a010');
      final star = find.byIcon(AppIconType.star.glyph);
      final label = tester.getRect(find.text('Рейтинг'));
      final poster = tester.getRect(find.byType(AnimeDetailsPoster));
      final scoreRect = tester.getRect(score);
      final starRect = tester.getRect(star);
      final paragraph = tester.renderObject<RenderParagraph>(score);
      expect(paragraph.text.style?.fontFamily, TvTypography.fontFamily);
      expect(paragraph.text.style?.fontSize, 16);
      expect(paragraph.textScaler.scale(16), 32);
      final scoreBounds = paragraph.getBoxesForSelection(const TextSelection(baseOffset: 0, extentOffset: 4)).single;
      final suffixBounds = paragraph.getBoxesForSelection(const TextSelection(baseOffset: 5, extentOffset: 9)).single;
      expect(scoreBounds.bottom, closeTo(suffixBounds.bottom, 0.01));
      expect(suffixBounds.left, greaterThan(scoreBounds.right));
      // The last Manrope glyph slightly overhangs the paragraph's advance width.
      expect(suffixBounds.right, lessThanOrEqualTo(scoreRect.width + 0.5));
      expect(suffixBounds.right, lessThanOrEqualTo(paragraph.constraints.maxWidth));
      expect(starRect.size, const Size.square(20));
      expect(starRect.right + 8, closeTo(scoreRect.left, 0.01));
      expect(starRect.center.dy, closeTo(scoreRect.center.dy, 0.01));
      final labelParagraphs = [
        for (final heading in ['Рейтинг', 'Жанры']) tester.renderObject<RenderParagraph>(find.text(heading)),
      ];
      final naturalWidth = [
        96.0,
        for (final heading in labelParagraphs) heading.getMaxIntrinsicWidth(double.infinity),
      ].reduce((a, b) => a > b ? a : b).ceilToDouble();
      expect(label.width, naturalWidth);
      for (final heading in labelParagraphs) {
        expect(
          heading.getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: heading.text.toPlainText().length)),
          hasLength(1),
        );
      }

      expect(starRect.left - label.right, 8);
      if (stacked) {
        expect(label.left, poster.left);
        expect(starRect.top, greaterThan(poster.bottom));
      } else {
        expect(label.left - poster.right, 32);
        expect(starRect.center.dy, lessThan(poster.bottom));
      }
      final rating = find.bySemanticsLabel('Рейтинг 10,0 из 10');
      expect(rating, findsOneWidget);
      expect(tester.getSemantics(rating).getSemanticsData().hasAction(SemanticsAction.tap), isFalse);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(focusedControlLabel(tester), 'Комедия');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(focusedControlLabel(tester), 'Подробнее');
      expect(rating, findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in [compactTvSize, wideTvSize, const Size(390, 844)]) {
    testWidgets('disclosure makes the metadata row reachable by D-pad and Back hides it at $size', (tester) async {
      final filters = List.generate(
        9,
        (index) => CatalogFilter(label: 'Длинный жанр $index', path: '/filter/janrs/genre-$index/'),
      );
      CatalogFilter? selected;
      await pumpTvApp(
        tester,
        AnimeScreen(
          animeId: 1,
          slug: '1-test',
          fallbackTitle: 'Аниме',
          onEpisodeTap: (_) => fail('Unexpected episode'),
          onFilterTap: (filter) => selected = filter,
        ),
        size: size,
        wrapInScaffold: false,
        overrides: [
          authAccessProvider.overrideWithValue(const AuthenticatedAccess('test')),
          favoritesAccountProvider.overrideWithValue('test'),
          animeRepositoryProvider.overrideWithValue(
            FakeAnimeScreenRepository(
              load: (_, _) async => Result.success(
                AnimeScreenData(
                  details: AnimeDetails(
                    id: 1,
                    slug: '1-test',
                    title: 'Аниме',
                    genres: List.generate(9, (index) => 'Длинный жанр $index'),
                    isOngoing: true,
                    filters: filters,
                    posterUri: Uri(),
                    isFavorite: false,
                  ),
                  episodes: const [AnimeEpisode(number: 1, title: 'Серия 1')],
                ),
              ),
            ),
          ),
        ],
      );
      await tester.pumpAndSettle();
      expect(find.text('Длинный жанр 0'), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'Подробнее');
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'Длинный жанр 0');
      for (var i = 0; i < 9; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
      }
      expect(selected, isNull);
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'Длинный жанр 8');
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      expect(selected?.path, '/filter/janrs/genre-8/');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'Подробнее');
      expect(find.text('Длинный жанр 8'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('latest episode enters first and Up restores visible disclosure from a long grid', (tester) async {
    final key = tester.sendKeyEvent;
    final settle = tester.pumpAndSettle;
    String? focusedLabel() => FocusManager.instance.primaryFocus?.debugLabel;
    int? opened;
    await pumpTvApp(
      tester,
      AnimeScreen(
        animeId: 1,
        slug: 'anime',
        fallbackTitle: 'Аниме',
        onEpisodeTap: (episode) => opened = episode.number,
      ),
      size: wideTvSize,
      wrapInScaffold: false,
      overrides: [
        authAccessProvider.overrideWithValue(const AuthenticatedAccess('test')),
        favoritesAccountProvider.overrideWithValue('test'),
        animeRepositoryProvider.overrideWithValue(
          FakeAnimeScreenRepository(
            load: (_, _) async => Result.success(
              AnimeScreenData(
                details: AnimeDetails(
                  id: 1,
                  slug: 'anime',
                  title: 'Аниме',
                  genres: const [],
                  isOngoing: false,
                  posterUri: Uri.parse('https://image.test/poster.jpg'),
                  isFavorite: false,
                ),
                episodes: List.generate(32, (index) => AnimeEpisode(number: index + 1, title: 'Серия ${index + 1}')),
              ),
            ),
          ),
        ),
      ],
    );
    await settle();
    await key(LogicalKeyboardKey.select);
    expect(opened, 32);
    for (var row = 0; row < 5; row++) {
      await key(LogicalKeyboardKey.arrowDown);
      await settle();
    }
    final focus = FocusManager.instance.primaryFocus;
    final cardContext = focus?.context?.findAncestorWidgetOfExactType<EpisodeCard>();
    expect(cardContext?.episode.number, lessThan(32));
    for (var row = 0; row < 6; row++) {
      await key(LogicalKeyboardKey.arrowUp);
      await settle();
    }
    expect(focusedLabel(), 'Подробнее');
    final scroll = tester.widget<CustomScrollView>(find.byType(CustomScrollView)).controller;
    expect(scroll?.offset, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('changing route ID ignores the late response in the existing State', (tester) async {
    final requests = <int>[];
    final pending = Completer<Result<AnimeScreenData, Failure>>();
    final repository = FakeAnimeScreenRepository(
      load: (id, _) {
        requests.add(id);

        return id == 1 ? pending.future : Future.value(Result.success(_routeData(id, 'Новая карточка')));
      },
    );
    AnimeScreen screen(int id) => AnimeScreen(
      animeId: id,
      slug: '$id-anime',
      fallbackTitle: 'Аниме $id',
      onEpisodeTap: (episode) => expect(episode.number, id),
    );
    final screenFinder = find.byType(AnimeScreen);
    final overrides = [animeRepositoryProvider.overrideWithValue(repository)];
    await pumpTvApp(tester, screen(1), wrapInScaffold: false, disableAnimations: true, overrides: overrides);
    await tester.pumpAndSettle();
    expect(find.text('Аниме 1'), findsOneWidget);
    final state = tester.state(screenFinder);
    await pumpTvApp(tester, screen(2), wrapInScaffold: false, disableAnimations: true, overrides: overrides);
    await tester.pumpAndSettle();
    pending.complete(Result.success(_routeData(1, 'Устаревшая карточка')));
    await tester.pumpAndSettle();
    expect(tester.state(screenFinder), same(state));
    expect(requests, [1, 2]);
    expect(find.text('Новая карточка'), findsOneWidget);
    expect(find.text('Устаревшая карточка'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    expect(tester.takeException(), isNull);
  });

  for (final changesAccount in [true, false]) {
    testWidgets('late response from prior ${changesAccount ? 'account' : 'origin'} cannot overwrite ready data', (
      tester,
    ) async {
      final pending = Completer<Result<AnimeScreenData, Failure>>();
      var requests = 0;
      final old = FakeAnimeScreenRepository(
        load: (_, _) {
          requests++;

          return requests == 1 ? pending.future : Future.value(Result.success(_routeData(1, 'Новая карточка')));
        },
      );
      final replacement = FakeAnimeScreenRepository(
        load: (_, _) async {
          requests++;

          return Result.success(_routeData(1, 'Новая карточка'));
        },
      );
      await pumpTvApp(
        tester,
        AnimeScreen(
          animeId: 1,
          slug: '1-anime',
          fallbackTitle: 'Известное название',
          onEpisodeTap: (_) => fail('Unexpected episode'),
        ),
        disableAnimations: true,
        wrapInScaffold: false,
        overrides: [
          authAccessProvider.overrideWith((ref) {
            final current = ref.watch(_changedScope);
            return AuthenticatedAccess(changesAccount && current ? 'second' : 'first');
          }),
          animeRepositoryProvider.overrideWith((ref) {
            final current = ref.watch(_changedScope);
            return !changesAccount && current ? replacement : old;
          }),
        ],
      );
      await tester.pumpAndSettle();
      expect(requests, 1);
      expect(find.text('Известное название'), findsOneWidget);
      final container = ProviderScope.containerOf(tester.element(find.byType(AnimeScreen)));
      container.read(_changedScope.notifier).change();
      await tester.pumpAndSettle();
      expect(requests, 2);
      expect(find.text('Новая карточка'), findsOneWidget);

      pending.complete(Result.success(_routeData(1, 'Устаревшая карточка')));
      await tester.pumpAndSettle();
      expect(find.text('Новая карточка'), findsOneWidget);
      expect(find.text('Устаревшая карточка'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('initial episode focus does not steal focus after opening TV navigation during loading', (tester) async {
    final pending = Completer<Result<AnimeScreenData, Failure>>();
    final navigation = FocusNode(debugLabel: 'Меню');
    addTearDown(navigation.dispose);
    var opens = 0;
    await pumpTvApp(
      tester,
      Row(
        children: [
          SizedBox(
            width: 160,
            child: AppButton(label: 'Меню', focusNode: navigation, onPressed: () => opens++),
          ),
          Expanded(
            child: AnimeScreen(
              animeId: 1,
              slug: '1-anime',
              fallbackTitle: 'Известное название',
              embedded: true,
              onOpenNavigation: navigation.requestFocus,
              onEpisodeTap: (_) => fail('Late success stole focus from navigation'),
            ),
          ),
        ],
      ),
      disableAnimations: true,
      wrapInScaffold: false,
      overrides: [animeRepositoryProvider.overrideWithValue(FakeAnimeScreenRepository(load: (_, _) => pending.future))],
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(navigation.hasPrimaryFocus, isTrue);

    pending.complete(Result.success(_routeData(1, 'Новая карточка')));
    await tester.pumpAndSettle();
    expect(find.text('Новая карточка'), findsOneWidget);
    expect(navigation.hasPrimaryFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    expect(opens, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the latest episode visible and allows horizontal selection on a compact TV', (tester) async {
    int? openedEpisode;
    await pumpTvApp(
      tester,
      AnimeScreen(
        animeId: 1,
        slug: 'test-anime',
        fallbackTitle: 'Тестовое аниме',
        onEpisodeTap: (episode) => openedEpisode = episode.number,
      ),
      wrapInScaffold: false,
      overrides: [
        authAccessProvider.overrideWithValue(const AuthenticatedAccess('test')),
        favoritesAccountProvider.overrideWithValue('test'),
        animeRepositoryProvider.overrideWithValue(const FakeAnimeScreenRepository()),
      ],
    );
    final pumpAndSettle = tester.pumpAndSettle;
    final sendKeyEvent = tester.sendKeyEvent;
    await pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.widgetList<EpisodeCard>(find.byType(EpisodeCard)).map((card) => card.episode.number), [3, 2, 1]);
    await sendKeyEvent(LogicalKeyboardKey.select);
    expect(openedEpisode, 3);
    await sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(AppMotion.fast);
    await sendKeyEvent(LogicalKeyboardKey.select);
    expect(openedEpisode, 2);
  });
}

final _changedScope = NotifierProvider<_AnimeScreenTest, bool>(_AnimeScreenTest.new);

class _AnimeScreenTest extends Notifier<bool> {
  @override
  bool build() => false;

  void change() => state = true;
}

AnimeScreenData _routeData(int id, String title) => AnimeScreenData(
  details: AnimeDetails(id: id, slug: '$id-anime', title: title, genres: const [], isOngoing: false),
  episodes: [AnimeEpisode(number: id, title: 'Серия $id')],
);
