import 'dart:async';

import 'package:app_logging/app_logging.dart';
import 'package:app_logging/providers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:video_player/video_player.dart';

import '../../../watch_history/watched_episodes.dart';
import '../../domain/models/playback_failure.dart';
import '../../domain/models/playback_quality.dart';
import '../../domain/models/playback_refresh_budget.dart';
import '../../domain/models/playback_session.dart';
import '../../player_providers.dart';
import '../widgets/player_choices_dialog.dart';
import '../widgets/player_retry_view.dart';
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
  late final Logger _logger;
  final FocusNode _focusNode = FocusNode(debugLabel: 'Видео', skipTraversal: true);
  final _controlsFocus = FocusNode(debugLabel: 'Меню видео', skipTraversal: true);
  final _backFocus = FocusNode(debugLabel: 'К сериям');
  final _playFocus = FocusNode(debugLabel: 'Пауза / воспроизведение');
  Timer? _controlsTimer;
  VideoPlayerController? _controller;
  bool _controlsVisible = true;
  bool _disposed = false;
  int _initializationId = 0;
  late int _episodeNumber;
  PlaybackQuality _quality = PlaybackQuality.high;
  PlaybackSession? _session;
  final PlaybackRefreshBudget _refreshBudget = PlaybackRefreshBudget();
  final Set<int> _markedEpisodes = {};
  Duration _resumePosition = Duration.zero;
  bool _resumePlaying = true;

  @override
  void initState() {
    super.initState();
    _logger = ref.read(loggerProvider);
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky));
    _episodeNumber = widget.episodeNumber;
    _future = _initialize(++_initializationId);
    _focusNode.requestFocus();
  }

  Widget _buildFuture(BuildContext context, AsyncSnapshot<_PlayerData> snapshot) {
    if (snapshot.connectionState != ConnectionState.done) {
      return const TvProgressView(label: 'Загружаем видео…');
    }
    if (snapshot.hasError) {
      return PlayerRetryView(
        icon: Icons.wifi_off_rounded,
        title: 'Видео не запустилось',
        message: snapshot.error?.toString() ?? 'Неизвестная ошибка',
        onRetry: _retry,
      );
    }

    final data = snapshot.requireData;

    return PlayerView(
      onBack: _backToEpisodes,
      onReturnToVideo: _returnToVideo,
      controlsFocusNode: _controlsFocus,
      backFocusNode: _backFocus,
      playFocusNode: _playFocus,
      controller: data.controller,
      controlsVisible: _controlsVisible,
      episodeNumber: _episodeNumber,
      onSelectQuality: _selectQuality,
      onSelectEpisode: _selectEpisode,
      onPlayPause: _togglePlayback,
      onRetry: _retry,
      onSeek: _seek,
      onShowControls: _showControls,
      session: data.session,
      title: widget.title,
    );
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || _controller == null) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.mediaPlay ||
        event.logicalKey == LogicalKeyboardKey.mediaPause ||
        event.logicalKey == LogicalKeyboardKey.mediaPlayPause) {
      _showControls();
      if (event.logicalKey == LogicalKeyboardKey.mediaPlayPause) {
        _togglePlayback();
      } else {
        _setPlaying(event.logicalKey == LogicalKeyboardKey.mediaPlay);
      }

      return KeyEventResult.handled;
    }
    if (!_focusNode.hasPrimaryFocus) {
      return KeyEventResult.ignored;
    }
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
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _focusMenu(_backFocus);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _focusMenu(_playFocus);
    } else {
      return KeyEventResult.ignored;
    }

    return KeyEventResult.handled;
  }

  void _backToEpisodes() => unawaited(Navigator.of(context).maybePop());

  void _focusMenu(FocusNode target) {
    // Hidden controls are excluded from focus until the next frame.
    WidgetsBinding.instance
      ..addPostFrameCallback((_) {
        if (mounted && !_disposed && target.context != null) {
          target.requestFocus();
        }
      })
      // Paused video and already visible controls may not schedule a frame.
      ..scheduleFrame();
  }

  void _returnToVideo() {
    _focusNode.requestFocus();
    _showControls();
  }

  Future<_PlayerData> _initialize(int initializationId) async {
    if (!_isCurrent(initializationId)) {
      throw const _PlaybackInitializationCancelled();
    }
    try {
      return await _openSource(initializationId);
    } on _PlaybackInitializationCancelled {
      rethrow;
    } on Object catch (_, stackTrace) {
      if (!_isCurrent(initializationId)) {
        Error.throwWithStackTrace(const _PlaybackInitializationCancelled(), stackTrace);
      }
      if (!_refreshBudget.take()) {
        Error.throwWithStackTrace(
          const PlaybackFailure(message: 'Не удалось загрузить видео. Повторите попытку или выберите другое качество.'),
          stackTrace,
        );
      }
      _logger.warningFor<PlayerScreen>('Refreshing source after playback initialization error');

      return _openSource(initializationId);
    }
  }

  Future<_PlayerData> _openSource(int initializationId) async {
    final sessionResult = await ref
        .read(playbackRepositoryProvider)
        .createSession(animeId: widget.animeId, episodeNumber: _episodeNumber, quality: _quality);
    final session = sessionResult.when(failure: (failure) => throw failure, success: (session) => session);
    if (!_isCurrent(initializationId)) {
      throw const _PlaybackInitializationCancelled();
    }
    final player = VideoPlayerController.networkUrl(
      session.manifestUri,
      httpHeaders: session.httpHeaders,
      formatHint: VideoFormat.hls,
      videoPlayerOptions: VideoPlayerOptions(),
    );
    _controller = player;
    try {
      await player.initialize().timeout(const Duration(seconds: 35));
      if (!_isCurrent(initializationId)) {
        throw const _PlaybackInitializationCancelled();
      }
      final duration = player.value.duration;
      final position = _resumePosition > duration ? duration : _resumePosition;
      if (position > Duration.zero) {
        await player.seekTo(position);
      }
      if (!_isCurrent(initializationId)) {
        throw const _PlaybackInitializationCancelled();
      }
      if (_resumePlaying) {
        await player.play();
      }
      if (!_isCurrent(initializationId)) {
        throw const _PlaybackInitializationCancelled();
      }
      _session = session;
      player.addListener(_onPlayerChanged);
      _markStarted(player);
      _scheduleControlsHide();
      _logger.infoFor<PlayerScreen>('Playback started (episode $_episodeNumber, ${session.selectedQuality.apiValue}p)');

      return _PlayerData(controller: player, session: session);
    } on Object catch (_, stackTrace) {
      if (identical(_controller, player)) {
        _controller = null;
        await player.dispose();
      }
      if (!_isCurrent(initializationId)) {
        Error.throwWithStackTrace(const _PlaybackInitializationCancelled(), stackTrace);
      }
      Error.throwWithStackTrace(const PlaybackFailure(message: 'Не удалось открыть видеопоток AniStar.'), stackTrace);
    }
  }

  void _onPlayerChanged() {
    final player = _controller;
    if (_disposed || player == null) {
      return;
    }
    if (!player.value.hasError) {
      _markStarted(player);
      _resumePosition = player.value.position;
      final wasPlaying = _resumePlaying;
      _resumePlaying = player.value.isPlaying;
      if (!player.value.isPlaying) {
        _controlsTimer?.cancel();
        if (!_controlsVisible) {
          setState(() => _controlsVisible = true);
        }
      } else if (!wasPlaying) {
        _scheduleControlsHide();
      }

      return;
    }
    final refreshAllowed = _refreshBudget.take();
    if (refreshAllowed) {
      _logger.warningFor<PlayerScreen>('Refreshing interrupted HLS source');
      final initializationId = _initializationId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_isCurrent(initializationId)) {
          _reload(resetBudget: false, preservePosition: true);
        }
      });
    }
  }

  void _markStarted(VideoPlayerController player) {
    if (!player.value.isPlaying || !_markedEpisodes.add(_episodeNumber)) {
      return;
    }
    final account = ref.read(watchHistoryAccountProvider);
    if (account == null) {
      return;
    }
    final history = ref.read(watchedEpisodesProvider(widget.animeId).notifier);
    final initializationId = _initializationId;
    unawaited(
      history.markStarted(_episodeNumber).then((saved) {
        if (!saved && mounted && _isCurrent(initializationId)) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Не удалось сохранить отметку просмотра.')));
        }
      }),
    );
  }

  void _onControlsTimer() {
    if (!mounted || _controlsFocus.hasFocus || !(_controller?.value.isPlaying ?? false)) {
      return;
    }
    setState(() => _controlsVisible = false);
  }

  void _retry() => _reload(resetBudget: true, preservePosition: true);

  void _reload({required bool resetBudget, required bool preservePosition}) =>
      setState(() => _restart(resetBudget: resetBudget, preservePosition: preservePosition));

  void _restart({required bool resetBudget, required bool preservePosition}) {
    if (_disposed) {
      return;
    }
    _controlsTimer?.cancel();
    if (resetBudget) {
      _refreshBudget.reset();
      _markedEpisodes.clear();
    }
    final player = _controller;
    if (preservePosition && player != null && !player.value.hasError) {
      _resumePosition = player.value.position;
      _resumePlaying = player.value.isPlaying;
    } else if (!preservePosition) {
      _resumePosition = Duration.zero;
      _resumePlaying = true;
    }
    _controller = null;
    _session = null;
    player?.removeListener(_onPlayerChanged);
    final initializationId = ++_initializationId;
    final disposal = player?.dispose() ?? Future<void>.value();
    _controlsVisible = true;
    _future = disposal.then((_) => _initialize(initializationId));
    _focusNode.requestFocus();
  }

  void _selectQuality() => unawaited(_chooseQuality());

  Future<void> _chooseQuality() async {
    final initializationId = _initializationId;
    final session = _session;
    if (session == null) {
      return;
    }
    final choice = await showDialog<PlaybackQuality>(
      context: context,
      builder: (context) => PlayerChoicesDialog<PlaybackQuality>(
        title: 'Качество видео',
        choices: session.availableQualities,
        selected: session.selectedQuality,
        label: (quality) => '${quality.apiValue}p',
      ),
    );
    if (_isCurrent(initializationId)) {
      _returnToVideo();
    }
    if (!_isCurrent(initializationId) || choice == null || choice == session.selectedQuality) {
      return;
    }
    _quality = choice;
    _reload(resetBudget: true, preservePosition: true);
  }

  void _selectEpisode() => unawaited(_chooseEpisode());

  Future<void> _chooseEpisode() async {
    final initializationId = _initializationId;
    final session = _session;
    if (session == null) {
      return;
    }
    final watched = ref.read(watchedEpisodesProvider(widget.animeId)).value ?? const <int>{};
    final episodes = session.episodeNumbers.toList()..sort((a, b) => b.compareTo(a));
    final choice = await showDialog<int>(
      context: context,
      builder: (context) => PlayerChoicesDialog<int>(
        title: 'Выбор серии',
        choices: episodes,
        selected: _episodeNumber,
        label: (number) => watched.contains(number) || session.watchedEpisodes.contains(number)
            ? 'Серия $number — просмотрена ✓'
            : 'Серия $number',
      ),
    );
    if (_isCurrent(initializationId)) {
      _returnToVideo();
    }
    if (!_isCurrent(initializationId) || choice == null || choice == _episodeNumber) {
      return;
    }
    _episodeNumber = choice;
    _reload(resetBudget: true, preservePosition: false);
  }

  void _scheduleControlsHide() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 4), _onControlsTimer);
  }

  void _seek(Duration position) {
    final controller = _controller;
    if (controller != null) {
      _logger.debugFor<PlayerScreen>('Seeking to ${position.inSeconds}s');
      unawaited(_runPlayerCommand((player) => player.seekTo(position)));
    }
    _showControls();
  }

  void _seekRelative(Duration offset) {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    final duration = controller.value.duration;
    final target = controller.value.position + offset;
    final clamped = Duration(milliseconds: target.inMilliseconds.clamp(0, duration.inMilliseconds));
    _seek(clamped);
  }

  void _showControls() {
    if (!_controlsVisible) {
      setState(() => _controlsVisible = true);
    }
    _scheduleControlsHide();
  }

  void _togglePlayback() {
    final controller = _controller;
    if (controller == null) {
      return;
    }

    _setPlaying(!controller.value.isPlaying);
  }

  void _setPlaying(bool playing) {
    if (playing) {
      _logger.debugFor<PlayerScreen>('Resuming playback');
      unawaited(_runPlayerCommand((player) => player.play()));
      _scheduleControlsHide();
    } else {
      _logger.debugFor<PlayerScreen>('Pausing playback');
      unawaited(_runPlayerCommand((player) => player.pause()));
      _controlsTimer?.cancel();
      if (!_controlsVisible) {
        setState(() => _controlsVisible = true);
      }
    }
  }

  bool _isCurrent(int initializationId) => !_disposed && initializationId == _initializationId;

  Future<void> _runPlayerCommand(Future<void> Function(VideoPlayerController) command) async {
    final player = _controller;
    if (player == null || !player.value.isInitialized || player.value.hasError) {
      return;
    }
    try {
      await command(player);
    } on Object {
      if (!_disposed && identical(player, _controller)) {
        // A failed native command follows the same bounded recovery as a
        // stream error instead of escaping an unawaited UI callback.
        player.value = player.value.copyWith(errorDescription: 'Не удалось выполнить команду видеоплеера.');
      }
    }
  }

  @override
  void didUpdateWidget(covariant PlayerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animeId != widget.animeId || oldWidget.episodeNumber != widget.episodeNumber) {
      if (oldWidget.animeId != widget.animeId) {
        _markedEpisodes.clear();
      }
      _episodeNumber = widget.episodeNumber;
      _quality = PlaybackQuality.high;
      _restart(resetBudget: true, preservePosition: false);
    }
  }

  @override
  void dispose() {
    _logger.debugFor<PlayerScreen>('Disposing player');
    _disposed = true;
    _initializationId++;
    _controlsTimer?.cancel();
    final controller = _controller;
    _controller = null;
    controller?.removeListener(_onPlayerChanged);
    if (controller != null) {
      unawaited(controller.dispose());
    }
    _focusNode.dispose();
    _controlsFocus.dispose();
    _backFocus.dispose();
    _playFocus.dispose();
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
