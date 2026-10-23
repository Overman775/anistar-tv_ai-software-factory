import 'package:anistar_tv/packages/features/catalog/catalog_providers.dart';
import 'package:anistar_tv/packages/features/catalog/domain/models/anime_summary.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/screens/catalog_screen.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/widgets/catalog_inspector.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/widgets/catalog_inspector_copy.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/widgets/catalog_inspector_rating.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/widgets/catalog_layout.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../../../mocks/features/catalog/fake_catalog_screen_repository.dart';
import '../../../../../support/test_app.dart';

const _first = AnimeSummary(id: 1, slug: '1-first', title: 'Первый тайтл');
const _second = AnimeSummary(id: 2, slug: '2-second', title: 'Второй тайтл');
const _last = AnimeSummary(id: 3, slug: '3-last', title: 'Последний тайтл');

void main() {
  testWidgets('TV inspector presents a valid rating without an outlined metadata badge', (tester) async {
    final semantics = tester.ensureSemantics();
    const anime = AnimeSummary(id: 1, slug: '1-first', title: 'Первый тайтл', rating: 8.7);
    await pumpTvApp(tester, const CatalogInspector(anime: anime));
    final rating = find.byType(CatalogInspectorRating);
    final ratingValue = find.text('8,7');
    final ratingScale = find.text('/ 10');
    final ratingSemantics = find.bySemanticsLabel('Рейтинг 8,7 из 10');
    final atLeastOne = findsAtLeastNWidgets(1);

    expect(rating, atLeastOne);
    expect(find.descendant(of: rating, matching: ratingValue), atLeastOne);
    expect(find.descendant(of: rating, matching: ratingScale), atLeastOne);
    expect(find.descendant(of: rating, matching: find.byType(AppMetadataBadge)), findsNothing);
    expect(ratingSemantics, atLeastOne);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('inspector dwell does not rebuild the grid or issue another catalog query', (tester) async {
    var requests = 0;
    await pumpTvApp(
      tester,
      CatalogScreen(onAnimeTap: (_) => fail('Unexpected navigation')),
      wrapInScaffold: false,
      overrides: [
        catalogRepositoryProvider.overrideWithValue(
          FakeCatalogScreenRepository(
            load: (page) {
              requests++;

              return const FakeCatalogScreenRepository().getPage(page);
            },
          ),
        ),
      ],
    );
    await tester.pumpAndSettle();
    var gridBuilds = 0;
    final previous = debugOnRebuildDirtyWidget;
    debugOnRebuildDirtyWidget = (element, builtOnce) {
      previous?.call(element, builtOnce);
      if (element.widget is SliverGrid) {
        gridBuilds++;
      }
    };
    addTearDown(() => debugOnRebuildDirtyWidget = previous);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 280));
    debugOnRebuildDirtyWidget = previous;
    expect(requests, 1);
    expect(gridBuilds, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('natural inspector copy changes do not animate the grid height', (tester) async {
    const rich = AnimeSummary(
      id: 4,
      slug: '4-rich',
      title: 'Полное длинное название истории о путешествии друзей через незнакомые города',
      genreText: 'Приключения, Драма, Фантастика',
      description: 'Друзья отправляются в путь и постепенно узнают историю своей семьи. Новые встречи меняют их планы.',
      updateMessage: 'Добавлена новая серия с русской озвучкой',
      publicationDate: 'Вчера, 23:59',
    );
    final selected = ValueNotifier(_first);
    addTearDown(selected.dispose);
    const anchorKey = ValueKey('inspector-grid-anchor');
    await pumpTvApp(
      tester,
      Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: 1100,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValueListenableBuilder(
                valueListenable: selected,
                builder: (context, anime, _) => CatalogInspector(anime: anime),
              ),
              const SizedBox(key: anchorKey, height: 1),
            ],
          ),
        ),
      ),
      size: wideTvSize,
    );
    await tester.pumpAndSettle();
    final initialHeight = tester.getSize(find.byType(CatalogInspector)).height;
    expect(
      initialHeight,
      lessThan(CatalogLayout.inspectorHeight(wideTvSize.height, 1)),
      reason: 'short content must not reserve a viewport-sized blank band',
    );
    final anchor = find.byKey(anchorKey);
    double anchorTop() => tester.getTopLeft(anchor).dy;
    final initialTop = anchorTop();
    selected.value = rich;
    await tester.pump();
    final samples = <double>[];
    for (var frame = 0; frame < 46; frame++) {
      await tester.pump(const Duration(milliseconds: 10));
      samples.add(anchorTop());
    }
    final finalTop = samples.last;
    expect(
      samples.every((top) => (top - initialTop).abs() < 0.01 || (top - finalTop).abs() < 0.01),
      isTrue,
      reason: 'copy crossfades may change natural height discretely, but grid height must not animate: $samples',
    );
    selected.value = _first;
    await tester.pump();
    final reverseSamples = <double>[];
    for (var frame = 0; frame < 46; frame++) {
      await tester.pump(const Duration(milliseconds: 10));
      reverseSamples.add(anchorTop());
    }
    expect(reverseSamples.last, closeTo(initialTop, 0.01), reason: 'fade finish releases the old larger natural copy');
    expect(
      reverseSamples.every((top) => (top - initialTop).abs() < 0.01 || (top - finalTop).abs() < 0.01),
      isTrue,
      reason: 'reverse crossfade also avoids interpolated grid heights: $reverseSamples',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('150ms dwell cancels obsolete targets and keeps two sequential text buffers', (tester) async {
    final semantics = tester.ensureSemantics();
    final selected = ValueNotifier(_first);
    addTearDown(selected.dispose);
    await pumpTvApp(
      tester,
      SizedBox(
        height: 220,
        child: ValueListenableBuilder(
          valueListenable: selected,
          builder: (context, anime, _) => CatalogInspector(anime: anime),
        ),
      ),
    );
    await tester.pumpAndSettle();
    selected.value = _second;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 149));
    expect(
      tester.widgetList<CatalogInspectorCopy>(find.byType(CatalogInspectorCopy)).map((copy) => copy.anime.id).toSet(),
      {1},
    );
    selected.value = _last;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 149));
    expect(find.text(_second.title), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    final crossFade = tester.widget<AnimatedCrossFade>(find.byType(AnimatedCrossFade));
    expect(
      (crossFade.duration, crossFade.reverseDuration),
      (const Duration(milliseconds: 280), const Duration(milliseconds: 280)),
    );
    expect(crossFade.firstCurve.transform(0.75), 1);
    expect(crossFade.secondCurve.transform(0.25), 0);
    expect(find.byType(CatalogInspectorCopy), findsNWidgets(2));
    await tester.pump(const Duration(milliseconds: 280));
    final labels = tester.semantics.simulatedAccessibilityTraversal().map((node) => node.label);
    expect(labels, contains(_last.title));
    expect(labels, isNot(contains(_first.title)));
    expect(labels, isNot(contains(_second.title)));
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('focus during an unfinished fade never exposes two readable copies and the last target wins', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final settle = tester.pumpAndSettle;
    final selected = ValueNotifier(_first);
    addTearDown(selected.dispose);
    await pumpTvApp(
      tester,
      SizedBox(
        height: 220,
        child: ValueListenableBuilder(
          valueListenable: selected,
          builder: (context, anime, _) => CatalogInspector(anime: anime),
        ),
      ),
    );
    await settle();
    selected.value = _second;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 30));
    selected.value = _last;
    await tester.pump();
    for (var frame = 0; frame < 45; frame++) {
      await tester.pump(const Duration(milliseconds: 10));
      final opacities = tester
          .widgetList<CatalogInspectorCopy>(find.byType(CatalogInspectorCopy))
          .map((copy) => find.byWidget(copy))
          .map(
            (copy) => tester
                .widget<FadeTransition>(find.ancestor(of: copy, matching: find.byType(FadeTransition)).first)
                .opacity
                .value,
          )
          .toList();
      expect(opacities.where((opacity) => opacity > 0.001), hasLength(lessThanOrEqualTo(1)));
      expect(find.byType(CatalogInspectorCopy), findsNWidgets(2));
    }
    await settle();
    final labels = tester.semantics.simulatedAccessibilityTraversal().map((node) => node.label);
    expect(labels, contains(_last.title));
    expect(labels, isNot(contains(_second.title)));
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('reduced motion applies last selection immediately without a pending dwell', (tester) async {
    final semantics = tester.ensureSemantics();
    final selected = ValueNotifier(_first);
    addTearDown(selected.dispose);
    await pumpTvApp(
      tester,
      MediaQuery(
        data: const MediaQueryData(size: compactTvSize, disableAnimations: true),
        child: SizedBox(
          height: 220,
          child: ValueListenableBuilder(
            valueListenable: selected,
            builder: (context, anime, _) => CatalogInspector(anime: anime),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final initialError = tester.takeException();
    selected.value = _last;
    await tester.pump();
    final updateError = tester.takeException();
    final labels = tester.semantics.simulatedAccessibilityTraversal().map((node) => node.label);
    expect(labels, contains(_last.title));
    expect(labels, isNot(contains(_first.title)));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    final error = tester.takeException();
    semantics.dispose();
    expect(initialError, isNull, reason: 'initial reduced-motion layout');
    expect(updateError, isNull, reason: 'immediate reduced-motion selection');
    expect(error, isNull, reason: 'dispose after reduced-motion selection');
  });

  testWidgets('compact TV inspector at 200% text has no overflow', (tester) async {
    const anime = AnimeSummary(
      id: 1,
      slug: '1-first',
      title: 'Длинное название аниме для проверки',
      year: '2026',
      genreText: 'Приключения, Фантастика',
      description: 'Полное описание тайтла.',
      updateMessage: 'Добавлена новая серия',
      publicationDate: 'Вчера, 23:59',
      rating: 8.7,
    );
    await pumpTvApp(
      tester,
      MediaQuery(
        data: const MediaQueryData(size: compactTvSize, textScaler: TextScaler.linear(2)),
        child: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: compactTvSize.width - 88,
            child: const CatalogInspector(anime: anime),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(CatalogInspector)).bottom, lessThanOrEqualTo(compactTvSize.height));
    expect(tester.takeException(), isNull);
  });
}
