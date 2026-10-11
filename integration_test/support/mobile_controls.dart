// Touches and frame pumps must run after each separate UI transition.
// ignore_for_file: prefer-moving-to-variable

import 'package:anistar_tv/packages/features/anime/presentation/screens/anime_screen.dart';
import 'package:anistar_tv/packages/features/catalog/presentation/mobile/mobile_anime_card.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:video_player/video_player.dart';

import 'e2e_harness.dart';

/// Phone tests activate visible controls by touch and use actual device dimensions.
abstract final class MobileControls {
  static Finder card(int id) => find.byWidgetPredicate((widget) => widget is MobileAnimeCard && widget.anime.id == id);

  static Future<void> tap(WidgetTester tester, Finder finder, String step) async {
    await E2eHarness.waitFor(tester, () => finder.evaluate().isNotEmpty, '$step available');
    await tester.ensureVisible(finder);
    await E2eHarness.waitFor(tester, () {
      final target = finder.hitTestable();
      if (target.evaluate().isEmpty) {
        return false;
      }
      final animation = ModalRoute.of(tester.element(target))?.animation;

      return animation == null || animation.status == AnimationStatus.completed;
    }, '$step ready');
    await tester.tap(finder.hitTestable());
    await tester.pump(const Duration(milliseconds: 300));
  }

  static Future<void> tab(WidgetTester tester, String label) => tap(
    tester,
    find.descendant(of: find.byKey(const ValueKey('mobile-navigation')), matching: find.text(label)),
    'tab $label',
  );

  static Future<void> login(WidgetTester tester, {String password = 'пароль'}) async {
    final submit = find.byKey(const ValueKey('login_submit'));
    await E2eHarness.waitFor(
      tester,
      () => submit.evaluate().isNotEmpty && tester.widget<FilledButton>(submit).onPressed != null,
      'touch login ready',
    );
    await tester.enterText(find.byKey(const ValueKey('login_username')), 'тест');
    await tester.enterText(find.byKey(const ValueKey('login_password')), password);
    FocusManager.instance.primaryFocus?.unfocus();
    await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    await tap(tester, submit, 'touch login submit');
  }

  static Future<void> openAnime(WidgetTester tester) async {
    await tap(tester, card(10938), 'touch anime card');
    await E2eHarness.waitFor(
      tester,
      () => find.byType(AnimeScreen).evaluate().isNotEmpty && find.text('Смотреть серию 1').evaluate().isNotEmpty,
      'mobile details',
    );
  }

  static Future<void> openVideo(WidgetTester tester) async {
    await tap(tester, find.text('Смотреть серию 1'), 'touch first episode');
    await E2eHarness.waitFor(
      tester,
      () => E2eHarness.player(tester)?.value.isInitialized == true,
      'native mobile HLS initialized',
    );
    await E2eHarness.waitFor(
      tester,
      () => (E2eHarness.player(tester)?.value.position.inMilliseconds ?? 0) > 500,
      'native mobile HLS advancing',
    );
  }

  static Future<void> showPlayerControls(WidgetTester tester) async {
    if (find.byKey(const ValueKey('player-play')).hitTestable().evaluate().isEmpty) {
      await tester.tapAt(tester.getCenter(find.byType(VideoPlayer)));
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  static Future<void> playerAction(WidgetTester tester, String key) async {
    await showPlayerControls(tester);
    await tap(tester, find.byKey(ValueKey(key)), key);
  }

  /// A real paused Flutter lifecycle disables frames in the live test binding.
  /// Native controller events and channel replies still use the Dart event loop.
  static Future<void> expectPausedPlaybackWithoutFrames(WidgetTester tester, VideoPlayerController controller) async {
    debugPrint('E2E: paused lifecycle stops native playback and releases screen flag');
    const channel = MethodChannel('anistar_tv/playback_screen_awake');
    final verified = await tester.runAsync<bool>(() async {
      final deadline = DateTime.now().add(const Duration(seconds: 10));
      while (DateTime.now().isBefore(deadline)) {
        final enabled = await channel.invokeMethod<bool>('isEnabled').timeout(const Duration(seconds: 2));
        if (!controller.value.isPlaying && enabled == false) {
          return true;
        }
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }

      return false;
    });
    expect(tester.takeException(), isNull, reason: 'paused native playback observation');
    expect(verified, isTrue, reason: 'Paused native playback and FLAG_KEEP_SCREEN_ON must stop without frame pumping');
  }
}
