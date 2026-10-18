import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

final class FakeVideoPlatform extends VideoPlayerPlatform {
  final List<DataSource> sources = [];
  final List<int> disposed = [];
  final Map<int, StreamController<VideoEvent>> events = {};
  final Map<int, Duration> positions = {};
  final List<Duration> seeks = [];
  final List<int> playCalls = [];
  final List<int> pauseCalls = [];
  bool failInitialization = false;
  bool failNextSeek = false;
  bool delayInitialization = false;
  Completer<void>? pendingSeek;
  int activeSeeks = 0;
  int maxActiveSeeks = 0;
  final List<Duration> seekRequests = [];

  @override
  Future<void> init() => Future<void>.value();

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    sources.add(options.dataSource);
    final id = sources.length;
    events[id] = StreamController<VideoEvent>.broadcast(
      onListen: () {
        if (failInitialization) {
          events[id]?.addError(PlatformException(code: 'VideoError', message: 'Simulated source error'));
        } else if (!delayInitialization) {
          events[id]?.add(
            VideoEvent(
              eventType: VideoEventType.initialized,
              duration: const Duration(minutes: 24),
              size: const Size(1280, 720),
            ),
          );
        }
      },
    );

    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => events[playerId]!.stream;

  @override
  Future<void> dispose(int playerId) async {
    disposed.add(playerId);
    await events[playerId]?.close();
  }

  @override
  Future<Duration> getPosition(int playerId) async => positions[playerId] ?? Duration.zero;

  @override
  Future<void> seekTo(int playerId, Duration position) async {
    if (failNextSeek) {
      failNextSeek = false;
      throw PlatformException(code: 'SeekError', message: 'Native command failed');
    }
    seekRequests.add(position);
    activeSeeks++;
    if (activeSeeks > maxActiveSeeks) {
      maxActiveSeeks = activeSeeks;
    }
    try {
      await pendingSeek?.future;
      positions[playerId] = position;
      seeks.add(position);
    } finally {
      activeSeeks--;
    }
  }

  @override
  Future<void> pause(int playerId) async => pauseCalls.add(playerId);

  @override
  Future<void> play(int playerId) async => playCalls.add(playerId);

  @override
  Future<void> setLooping(int playerId, bool looping) => Future<void>.value();

  @override
  Future<void> setVolume(int playerId, double volume) => Future<void>.value();

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) => Future<void>.value();

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) => Future<void>.value();

  @override
  Future<void> setAllowBackgroundPlayback(bool allowBackgroundPlayback) => Future<void>.value();

  @override
  Widget buildViewWithOptions(VideoViewOptions options) => const SizedBox();
}
