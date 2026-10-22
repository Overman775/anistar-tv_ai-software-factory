// Successive pumps deliberately observe mutable native and repository state.
// ignore_for_file: prefer-moving-to-variable

import 'dart:async';
import 'dart:ui' show SemanticsAction;

import 'package:anistar_tv/packages/features/player/domain/models/playback_quality.dart';
import 'package:anistar_tv/packages/features/player/domain/models/playback_session.dart';
import 'package:anistar_tv/packages/features/player/player_providers.dart';
import 'package:anistar_tv/packages/features/player/presentation/screens/player_screen.dart';
import 'package:anistar_tv/packages/features/player/presentation/widgets/player_choices_dialog.dart';
import 'package:anistar_tv/packages/features/player/presentation/widgets/player_view.dart';
import 'package:core/data.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import '../../../../../mocks/features/player/fake_playback_repository.dart';
import '../../../../../mocks/features/player/fake_video_platform.dart';
import '../../../../../support/test_app.dart';

void main() {
  late FakePlaybackRepository repository;
  late FakeVideoPlatform video;
  late VideoPlayerPlatform previous;
  const qualityButton = ValueKey('player-quality');

  setUp(() {
    TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    previous = VideoPlayerPlatform.instance;
    video = FakeVideoPlatform();
    repository = FakePlaybackRepository();
    VideoPlayerPlatform.instance = video;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('anistar_tv/playback_screen_awake'),
      (_) async => null,
    );
  });

  tearDown(() {
    VideoPlayerPlatform.instance = previous;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('anistar_tv/playback_screen_awake'),
      null,
    );
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    }
    await tester.pumpAndSettle();
  }

  Future<void> mount(WidgetTester tester, {required bool mobile, int episode = 1}) async {
    final screen = PlayerScreen(animeId: 10938, episodeNumber: episode, title: 'Аниме');
    final overrides = [playbackRepositoryProvider.overrideWithValue(repository)];
    if (mobile) {
      await pumpMobileApp(tester, screen, overrides: overrides, wrapInScaffold: false);
    } else {
      await pumpTvApp(tester, screen, overrides: overrides, wrapInScaffold: false);
    }
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
    expect(tester.takeException(), isNull);
  }

  Future<void> open(WidgetTester tester, {required bool mobile}) async {
    if (mobile) {
      await tester.tap(find.byKey(qualityButton));
    } else {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      for (var i = 0; i < 8 && FocusManager.instance.primaryFocus?.debugLabel != 'Качество'; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
      }
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'Качество');
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
    }
    await settle(tester);
    expect(find.byType(PlayerChoicesDialog<PlaybackQuality>), findsOneWidget);
    expect(find.byType(mobile ? BottomSheet : TvSideSheet), findsOneWidget);
  }

  for (final mobile in [false, true]) {
    final profile = mobile ? 'mobile' : 'TV';
    for (final (quality, short, label) in [
      (PlaybackQuality.low, 'SD', 'SD 360p'),
      (PlaybackQuality.high, 'HD', 'HD 720p'),
    ]) {
      testWidgets('$profile $short reflects opened session and semantic activation opens actual choices', (
        tester,
      ) async {
        repository.selectedQuality = quality;
        final semantics = tester.ensureSemantics();
        await mount(tester, mobile: mobile);
        final view = tester.widget<PlayerView>(find.byType(PlayerView));
        expect(view.session.selectedQuality, quality);
        expect(find.descendant(of: find.byKey(qualityButton), matching: find.text(short)), findsOneWidget);
        final node = tester.semantics.simulatedAccessibilityTraversal().singleWhere(
          (node) => node.label == 'Качество: $label',
        );
        expect(node.label, 'Качество: $label');
        expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
        node.owner?.performAction(node.id, SemanticsAction.tap);
        await settle(tester);
        expect(find.text('SD 360p'), findsOneWidget);
        expect(find.text('HD 720p'), findsOneWidget);
        expect(find.byType(TvChoiceTile), findsNWidgets(2));
        final selected = tester
            .widgetList<TvChoiceTile>(find.byType(TvChoiceTile))
            .singleWhere((tile) => tile.selected);
        expect(selected.label, label);
        if (!mobile) {
          expect(FocusManager.instance.primaryFocus?.debugLabel, label);
          expect(find.text(label).hitTestable(), findsOneWidget);
        }
        await tester.binding.handlePopRoute();
        await settle(tester);
        expect(repository.calls, 1);
        expect(video.sources, hasLength(1));
        if (!mobile) {
          expect(FocusManager.instance.primaryFocus?.debugLabel, 'Видео');
        }
        await open(tester, mobile: mobile);
        if (mobile) {
          await tester.tap(find.text(label));
        } else {
          await tester.sendKeyEvent(LogicalKeyboardKey.select);
        }
        await settle(tester);
        expect(find.byType(PlayerChoicesDialog<PlaybackQuality>), findsNothing);
        expect(video.disposed, isEmpty);
        // Choosing the current row has the same no-reload contract as cancel.
        // ignore: avoid-duplicate-test-assertions
        expect(repository.calls, 1);
        await unmount(tester);
        semantics.dispose();
      });
    }

    testWidgets('$profile fallback to the only available SD stays selectable and never reloads current choice', (
      tester,
    ) async {
      repository
        ..selectedQuality = PlaybackQuality.low
        ..availableQualities = [PlaybackQuality.low];
      await mount(tester, mobile: mobile);
      expect(repository.quality, PlaybackQuality.high);
      final view = tester.widget<PlayerView>(find.byType(PlayerView));
      expect(view.session.requestedQuality, PlaybackQuality.high);
      expect(view.session.selectedQuality, PlaybackQuality.low);
      expect(find.text('SD'), findsOneWidget);
      expect(find.text('HD'), findsNothing);
      await open(tester, mobile: mobile);
      expect(find.text('HD 720p'), findsNothing);
      expect(find.byType(TvChoiceTile), findsOneWidget);
      if (mobile) {
        await tester.tap(find.text('SD 360p'));
      } else {
        expect(FocusManager.instance.primaryFocus?.debugLabel, 'SD 360p');
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
      }
      await settle(tester);
      expect(find.byType(PlayerChoicesDialog<PlaybackQuality>), findsNothing);
      expect(repository.calls, 1);
      expect(video.sources, hasLength(1));
      expect(video.disposed, isEmpty);
      if (!mobile) {
        expect(FocusManager.instance.primaryFocus?.debugLabel, 'Видео');
      }
      await unmount(tester);
    });

    for (final playing in [false, true]) {
      testWidgets('$profile real quality choice preserves position and playing=$playing', (tester) async {
        await mount(tester, mobile: mobile);
        final original = tester.widget<PlayerView>(find.byType(PlayerView)).controller;
        await original.seekTo(const Duration(seconds: 120));
        if (!playing) {
          await original.pause();
        }
        await open(tester, mobile: mobile);
        await tester.sendKeyEvent(LogicalKeyboardKey.mediaPlayPause);
        await tester.pump();
        expect(original.value.isPlaying, playing);
        expect(original.value.position, const Duration(seconds: 120));
        if (mobile) {
          await tester.tap(find.text('SD 360p'));
        } else {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
          await tester.sendKeyEvent(LogicalKeyboardKey.select);
        }
        await settle(tester);
        final replacement = tester.widget<PlayerView>(find.byType(PlayerView));
        expect(replacement.controller, isNot(same(original)));
        expect(replacement.controller.value.position, const Duration(seconds: 120));
        expect(replacement.controller.value.isPlaying, playing);
        expect(replacement.session.selectedQuality, PlaybackQuality.low);
        expect(find.text('SD'), findsOneWidget);
        expect(repository.quality, PlaybackQuality.low);
        expect(repository.calls, 2);
        expect(video.disposed, [1]);
        await unmount(tester);
      });
    }

    testWidgets('$profile opening and failed quality never announce requested SD; manual retry confirms it', (
      tester,
    ) async {
      await mount(tester, mobile: mobile);
      final original = tester.widget<PlayerView>(find.byType(PlayerView)).controller;
      await original.seekTo(const Duration(seconds: 90));
      await original.pause();
      final pending = Completer<Result<PlaybackSession, Failure>>();
      repository.pending = pending;
      await open(tester, mobile: mobile);
      await tester.tap(find.text('SD 360p'));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      expect(find.byKey(qualityButton), findsNothing);
      expect(find.bySemanticsLabel('Качество: SD 360p'), findsNothing);
      video.failInitialization = true;
      repository.pending = null;
      pending.complete(Result.success(repository.session));
      await settle(tester);
      expect(find.text('Видео не запустилось'), findsOneWidget);
      expect(find.text('SD'), findsNothing);
      expect(repository.calls, 3);
      video.failInitialization = false;
      await tester.tap(find.text('Повторить'));
      await settle(tester);
      final retried = tester.widget<PlayerView>(find.byType(PlayerView));
      expect(retried.session.selectedQuality, PlaybackQuality.low);
      expect(find.text('SD'), findsOneWidget);
      expect(retried.controller.value.position, const Duration(seconds: 90));
      expect(retried.controller.value.isPlaying, isFalse);
      expect(repository.calls, 4);
      await unmount(tester);
    });

    testWidgets('$profile late quality fetch cannot replace a newer episode or its HD label', (tester) async {
      await mount(tester, mobile: mobile);
      final pending = Completer<Result<PlaybackSession, Failure>>();
      repository.pending = pending;
      await open(tester, mobile: mobile);
      await tester.tap(find.text('SD 360p'));
      await tester.pump(const Duration(milliseconds: 400));
      for (var i = 0; i < 8; i++) {
        await tester.pump();
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      }
      expect(repository.quality, PlaybackQuality.low);
      final stale = repository.session;
      repository.pending = null;
      await mount(tester, mobile: mobile, episode: 2);
      pending.complete(Result.success(stale));
      await settle(tester);
      final view = tester.widget<PlayerView>(find.byType(PlayerView));
      expect(view.episodeNumber, 2);
      expect(view.session.selectedQuality, PlaybackQuality.high);
      expect(find.text('HD'), findsOneWidget);
      expect(find.text('SD'), findsNothing);
      expect(repository.calls, 3);
      expect(video.sources, hasLength(2));
      expect(video.disposed, [1]);
      await unmount(tester);
    });
  }
}
