import 'dart:async';

import 'package:app_logger/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:video_player/video_player.dart';

import '../../../../../app/app_providers.dart';
import '../../domain/models/playback_session.dart';
import '../widgets/player_view.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({required this.animeId, required this.episodeNumber, required this.title, super.key});

  final int animeId;
  final int episodeNumber;
  final String title;

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  late Future<_PlayerData> _future;
  final FocusNode _focusNode = FocusNode();
  Timer? _controlsTimer;
  VideoPlayerController? _controller;
  bool _controlsVisible = true;
  bool _disposed = false;
  int _initializationId = 0;

  @override
  void initState() {
    super.initState();
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky));
    _future = _initialize(++_initializationId);
    _focusNode.requestFocus();
  }

  Widget _buildFuture(BuildContext context, AsyncSnapshot<_PlayerData> snapshot) {
    if (snapshot.connectionState != ConnectionState.done) {
      return const TvProgressView(label: 'Готовим защищённый видеопоток…');
    }
    if (snapshot.hasError) {
      return TvStateView(
        icon: Icons.wifi_off_rounded,
        title: 'Видео не запустилось',
        message: snapshot.error?.toString() ?? 'Неизвестная ошибка',
        actionLabel: 'Создать новую сессию',
        onAction: _retry,
      );
    }

    final data = snapshot.requireData;

    return PlayerView(
      controller: data.controller,
      controlsVisible: _controlsVisible,
      episodeNumber: widget.episodeNumber,
      onPlayPause: _togglePlayback,
      onRetry: _retry,
      onSeek: _seek,
      onShowControls: _showControls,
      session: data.session,
      title: widget.title,
    );
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || _controller == null) return KeyEventResult.ignored;
    _showControls();
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.space ||
        event.logicalKey == LogicalKeyboardKey.mediaPlayPause ||
        event.logicalKey == LogicalKeyboardKey.gameButtonA) {
      _togglePlayback();
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _seekRelative(const Duration(seconds: -10));
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _seekRelative(const Duration(seconds: 10));
    } else if (event.logicalKey != LogicalKeyboardKey.arrowUp && event.logicalKey != LogicalKeyboardKey.arrowDown) {
      return KeyEventResult.ignored;
    }

    return KeyEventResult.handled;
  }

  Future<_PlayerData> _initialize(int initializationId) async {
    final logger = ref.read(loggerProvider);
    final stopwatch = Stopwatch()..start();
    final repository = ref.read(playbackRepositoryProvider);
    final sessionResult = await repository.createSession(animeId: widget.animeId, episodeNumber: widget.episodeNumber);
    final session = sessionResult.fold(
      onLeft: (failure) {
        throw failure;
      },
      onRight: (session) => session,
    );
    if (!_isCurrent(initializationId)) throw const _PlaybackInitializationCancelled();
    final controller = VideoPlayerController.networkUrl(
      session.manifestUri,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false, allowBackgroundPlayback: false),
    );
    try {
      await controller.initialize();
      if (!_isCurrent(initializationId)) {
        throw const _PlaybackInitializationCancelled();
      }
      _controller = controller;
      await controller.play();
      _scheduleControlsHide();
      logger.infoFor<PlayerScreen>(
        'Playback started (${session.selectedQuality.name}, ${controller.value.duration.inSeconds}s, ${stopwatch.elapsedMilliseconds}ms)',
      );

      return _PlayerData(controller: controller, session: session);
    } on _PlaybackInitializationCancelled {
      logger.debugFor<PlayerScreen>('Discarded outdated player initialization');
      await controller.dispose();
      _controller = null;
      rethrow;
    } on Object catch (error, stackTrace) {
      logger.errorFor<PlayerScreen>('Video controller initialization failed', error: error, stackTrace: stackTrace);
      await controller.dispose();
      _controller = null;
      rethrow;
    }
  }

  void _onControlsTimer() {
    if (!mounted || !(_controller?.value.isPlaying ?? false)) return;
    setState(() => _controlsVisible = false);
  }

  void _retry() {
    ref.read(loggerProvider).infoFor<PlayerScreen>('Retrying playback session');
    _controlsTimer?.cancel();
    final initializationId = ++_initializationId;
    final oldController = _controller;
    _controller = null;
    if (oldController != null) unawaited(oldController.dispose());
    setState(() {
      _controlsVisible = true;
      _future = _initialize(initializationId);
    });
  }

  void _scheduleControlsHide() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 4), _onControlsTimer);
  }

  void _seek(Duration position) {
    final controller = _controller;
    if (controller != null) {
      ref.read(loggerProvider).debugFor<PlayerScreen>('Seeking to ${position.inSeconds}s');
      unawaited(controller.seekTo(position));
    }
    _showControls();
  }

  void _seekRelative(Duration offset) {
    final controller = _controller;
    if (controller == null) return;
    final duration = controller.value.duration;
    final target = controller.value.position + offset;
    final clamped = Duration(milliseconds: target.inMilliseconds.clamp(0, duration.inMilliseconds));
    _seek(clamped);
  }

  void _showControls() {
    if (!_controlsVisible) setState(() => _controlsVisible = true);
    _scheduleControlsHide();
  }

  void _togglePlayback() {
    final controller = _controller;
    if (controller == null) return;
    if (controller.value.isPlaying) {
      ref.read(loggerProvider).debugFor<PlayerScreen>('Pausing playback');
      unawaited(controller.pause());
      _controlsTimer?.cancel();
      if (!_controlsVisible) setState(() => _controlsVisible = true);
    } else {
      ref.read(loggerProvider).debugFor<PlayerScreen>('Resuming playback');
      unawaited(controller.play());
      _scheduleControlsHide();
    }
  }

  bool _isCurrent(int initializationId) => !_disposed && initializationId == _initializationId;

  @override
  void dispose() {
    ref.read(loggerProvider).debugFor<PlayerScreen>('Disposing player');
    _disposed = true;
    _initializationId++;
    _controlsTimer?.cancel();
    final controller = _controller;
    if (controller != null) unawaited(controller.dispose());
    _focusNode.dispose();
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: Focus(
      autofocus: true,
      focusNode: _focusNode,
      onKeyEvent: _handleKey,
      child: FutureBuilder<_PlayerData>(future: _future, builder: _buildFuture),
    ),
  );
}

final class _PlayerData {
  final VideoPlayerController controller;
  final PlaybackSession session;

  const _PlayerData({required this.controller, required this.session});
}

final class _PlaybackInitializationCancelled implements Exception {
  const _PlaybackInitializationCancelled();
}
