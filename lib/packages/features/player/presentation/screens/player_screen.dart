import 'dart:async';

import 'package:app_logging/app_logging.dart';
import 'package:app_logging/providers.dart';
import 'package:core/data.dart';
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
import '../playback_quality_label.dart';
import '../playback_screen_awake.dart';
import '../player_route_observer.dart';
import '../player_seek_hold.dart';
import '../widgets/player_choices_dialog.dart';
import '../widgets/player_control_button.dart';
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

class _PlayerScreenState extends ConsumerState<PlayerScreen> with WidgetsBindingObserver, RouteAware {
  late Future<_PlayerData> _future;
  late final Logger _logger;
  late final PlaybackScreenAwake _screenAwake;
  PageRoute<Object?>? _route;
  PlayerRouteObserver? _routeObserver;
  bool _routeActive = true;
  bool _appResumed = false;
  bool _lifecycleResumePlaying = false;
  final FocusNode _focusNode = FocusNode(debugLabel: 'Видео', skipTraversal: true);
  final _controlsFocus = FocusNode(debugLabel: 'Меню видео', skipTraversal: true);
  final _backFocus = FocusNode(debugLabel: 'К сериям');
  final _playFocus = FocusNode(debugLabel: 'Пауза / воспроизведение');
  Timer? _controlsTimer;
  late final PlayerSeekHold _seekHold;
  FocusNode? _seekFocus;
  Duration? _seekTarget;
  Duration? _seekPreview;
  Duration? _pendingSeek;
  VideoPlayerController? _seekingPlayer;
  VideoPlayerController? _controller;
  bool _controlsVisible = true;
  bool _disposed = false;
  bool _isTv = true;
  bool _scrubbing = false;
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
    _screenAwake = PlaybackScreenAwake(_logger);
    _seekHold = PlayerSeekHold(_previewSeek, onRelease: _releaseSeek, onCancel: _cancelSeekPreview);
    HardwareKeyboard.instance.addHandler(_observeKey);
    FocusManager.instance.addListener(_onFocusChanged);
    _appResumed = WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    unawaited(_screenAwake.setEnabled(false));
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky));
    _episodeNumber = widget.episodeNumber;
    _future = _initialize(++_initializationId);
    _focusNode.requestFocus();
  }

  Widget _buildFuture(BuildContext context, AsyncSnapshot<_PlayerData> snapshot) {
    if (snapshot.connectionState != ConnectionState.done) {
      const progress = TvProgressView(label: 'Загружаем видео…');
      if (_isTv) {
        return progress;
      }

      return Stack(
        fit: StackFit.expand,
        children: [
          progress,
          Positioned(
            top: 8,
            left: 8,
            child: SafeArea(
              child: PlayerControlButton(
                buttonKey: 'player-back',
                label: 'К сериям',
                onPressed: _backToEpisodes,
                child: const AppIcon(AppIconType.arrowLeft),
              ),
            ),
          ),
        ],
      );
    }
    final error = snapshot.error;
    if (error != null) {
      return PlayerRetryView(
        icon: Icons.wifi_off_rounded,
        title: 'Видео не запустилось',
        message: error is Failure
            ? error.message
            : 'Не удалось загрузить видео. Повторите попытку или вернитесь к сериалу.',
        onRetry: _retry,
        onBack: _backToEpisodes,
      );
    }

    final data = snapshot.requireData;

    return PlayerView(
      onPreviousEpisode: data.session.previousEpisode(_episodeNumber) == null ? null : _previousEpisode,
      onNextEpisode: data.session.nextEpisode(_episodeNumber) == null ? null : _nextEpisode,
      onBack: _backToEpisodes,
      onReturnToVideo: _returnToVideo,
      controlsFocusNode: _controlsFocus,
      backFocusNode: _backFocus,
      playFocusNode: _playFocus,
      controller: data.controller,
      controlsVisible: _controlsVisible,
      previewPosition: _seekPreview,
      episodeNumber: _episodeNumber,
      onSelectQuality: _selectQuality,
      onSelectEpisode: _selectEpisode,
      onPlayPause: _togglePlayback,
      onRetry: _retry,
      onSeek: _seek,
      onSeekRelative: _seekRelative,
      onSeekKeyEvent: _handleSeekKey,
      onShowControls: _onVideoTap,
      onRotate: _isTv ? null : _rotateScreen,
      onInteractionStart: _startScrubbing,
      onInteractionEnd: _endScrubbing,
      session: data.session,
      title: widget.title,
    );
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (_focusNode.hasPrimaryFocus && _controller != null && _handleSeekKey(event)) {
      return KeyEventResult.handled;
    }
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
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _focusMenu(_backFocus);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _focusMenu(_playFocus);
    } else {
      return KeyEventResult.ignored;
    }

    return KeyEventResult.handled;
  }

  bool _observeKey(KeyEvent event) {
    if (_disposed || !_appResumed || !_routeActive || !(_route?.isCurrent ?? true) || !_focusNode.hasFocus) {
      return false;
    }
    if (event is KeyUpEvent) {
      _seekHold.handle(event);
    } else if (event is KeyDownEvent || event is KeyRepeatEvent) {
      if (event.logicalKey != LogicalKeyboardKey.arrowLeft && event.logicalKey != LogicalKeyboardKey.arrowRight) {
        _seekHold.stop();
      }
      _showControls();
    }

    return false;
  }

  bool _handleSeekKey(KeyEvent event) {
    final player = _controller;
    if (!_isTv ||
        !_appResumed ||
        !_routeActive ||
        !(_route?.isCurrent ?? true) ||
        player == null ||
        !player.value.isInitialized ||
        player.value.hasError) {
      return false;
    }
    if (event is KeyDownEvent) {
      _seekFocus = FocusManager.instance.primaryFocus;
    }

    return _seekHold.handle(event);
  }

  void _onFocusChanged() {
    if (_seekHold.isActive && FocusManager.instance.primaryFocus != _seekFocus) {
      _seekHold.stop();
    }
    if (!_disposed && _controlsVisible && _appResumed && (_route?.isCurrent ?? true) && _focusNode.hasFocus) {
      _scheduleControlsHide();
    }
  }

  void _backToEpisodes() {
    _seekHold.stop();
    unawaited(Navigator.of(context).maybePop());
  }

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
      // This screen owns foreground pause/resume together with its screen flag.
      videoPlayerOptions: VideoPlayerOptions(
        allowBackgroundPlayback: true,
        preventsDisplaySleepDuringVideoPlayback: false,
      ),
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
      if (_resumePlaying && _appResumed) {
        await player.play();
      } else if (_resumePlaying) {
        _lifecycleResumePlaying = true;
      }
      if (!_isCurrent(initializationId)) {
        throw const _PlaybackInitializationCancelled();
      }
      _session = session;
      player.addListener(_onPlayerChanged);
      _updateScreenAwake();
      _markStarted(player);
      _scheduleControlsHide();
      _logger.infoFor<PlayerScreen>('Playback started (episode $_episodeNumber, ${session.selectedQuality.height}p)');

      return _PlayerData(controller: player, session: session);
    } on Object catch (_, stackTrace) {
      if (identical(_controller, player)) {
        _controller = null;
        _updateScreenAwake();
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
    _updateScreenAwake();
    if (player.value.hasError) {
      _seekHold.stop();
    }
    if (!player.value.hasError) {
      _markStarted(player);
      _resumePosition = player.value.position;
      final wasPlaying = _resumePlaying;
      _resumePlaying = player.value.isPlaying;
      if (!player.value.isPlaying || player.value.isCompleted) {
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
    final value = _controller?.value;
    if (!mounted ||
        !_appResumed ||
        !(_route?.isCurrent ?? true) ||
        value == null ||
        !value.isPlaying ||
        value.isCompleted ||
        value.hasError) {
      return;
    }
    if (_seekHold.isActive || _scrubbing) {
      _scheduleControlsHide();

      return;
    }
    setState(() => _controlsVisible = false);
    _focusNode.requestFocus();
  }

  void _retry() => _reload(resetBudget: true, preservePosition: true);

  void _reload({required bool resetBudget, required bool preservePosition}) =>
      setState(() => _restart(resetBudget: resetBudget, preservePosition: preservePosition));

  void _restart({required bool resetBudget, required bool preservePosition}) {
    if (_disposed) {
      return;
    }
    _controlsTimer?.cancel();
    _scrubbing = false;
    _seekHold.stop();
    _pendingSeek = null;
    _seekTarget = null;
    if (resetBudget) {
      _refreshBudget.reset();
      _markedEpisodes.clear();
    }
    final player = _controller;
    if (preservePosition && player != null && !player.value.hasError) {
      _resumePosition = player.value.position;
      _resumePlaying = _appResumed ? player.value.isPlaying : _lifecycleResumePlaying;
    } else if (!preservePosition) {
      _resumePosition = Duration.zero;
      _resumePlaying = true;
    }
    _controller = null;
    _updateScreenAwake();
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
    _seekHold.stop();
    final choice = await showAppActionSheet<PlaybackQuality>(
      context: context,
      builder: (context) => PlayerChoicesDialog<PlaybackQuality>(
        title: 'Качество видео',
        choices: session.availableQualities,
        selected: session.selectedQuality,
        label: (quality) => quality.label,
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

  void _previousEpisode() => _switchEpisode(_session?.previousEpisode(_episodeNumber));

  void _nextEpisode() => _switchEpisode(_session?.nextEpisode(_episodeNumber));

  void _switchEpisode(int? number) {
    if (number == null || number == _episodeNumber) {
      return;
    }
    _episodeNumber = number;
    _reload(resetBudget: true, preservePosition: false);
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
    _seekHold.stop();
    final choice = await showAppActionSheet<int>(
      context: context,
      builder: (context) => PlayerChoicesDialog<int>(
        title: 'Выбор серии',
        choices: episodes,
        selected: _episodeNumber,
        label: (number) => watched.contains(number) || session.watchedEpisodes.contains(number)
            ? 'Серия $number — просмотрена'
            : 'Серия $number',
      ),
    );
    if (_isCurrent(initializationId)) {
      _returnToVideo();
    }
    if (!_isCurrent(initializationId) || choice == null || choice == _episodeNumber) {
      return;
    }
    _switchEpisode(choice);
  }

  void _scheduleControlsHide() {
    _controlsTimer?.cancel();
    if (_seekHold.isActive) {
      return;
    }
    _controlsTimer = Timer(const Duration(seconds: 4), _onControlsTimer);
  }

  void _previewSeek(Duration offset) {
    final player = _controller;
    if (player == null || !player.value.isInitialized || player.value.hasError) {
      _seekHold.stop();

      return;
    }
    final target = (_seekPreview ?? _seekTarget ?? player.value.position) + offset;
    setState(() {
      _seekPreview = Duration(milliseconds: target.inMilliseconds.clamp(0, player.value.duration.inMilliseconds));
      _controlsVisible = true;
    });
    _controlsTimer?.cancel();
  }

  void _releaseSeek() {
    final target = _seekPreview;
    _cancelSeekPreview();
    if (target != null) {
      _seek(target);
    }
    _scheduleControlsHide();
  }

  void _cancelSeekPreview() {
    if (_seekPreview == null) {
      return;
    }
    if (_disposed) {
      _seekPreview = null;
    } else {
      setState(() => _seekPreview = null);
    }
  }

  void _seek(Duration position) {
    _seekHold.stop();
    final player = _controller;
    if (player == null || !player.value.isInitialized || player.value.hasError) {
      return;
    }
    final target = Duration(milliseconds: position.inMilliseconds.clamp(0, player.value.duration.inMilliseconds));
    final previous = _seekTarget ?? player.value.position;
    _showControls();
    if (target == previous) {
      return;
    }
    _seekTarget = target;
    _pendingSeek = target;
    if (!identical(_seekingPlayer, player)) {
      unawaited(_drainSeeks(player));
    }
  }

  Future<void> _drainSeeks(VideoPlayerController player) async {
    _seekingPlayer = player;
    try {
      while (!_disposed && identical(player, _controller) && !player.value.hasError) {
        final target = _pendingSeek;
        if (target == null) {
          break;
        }
        _pendingSeek = null;
        await _runPlayerCommand((current) => current.seekTo(target));
      }
    } finally {
      if (identical(_seekingPlayer, player)) {
        _seekingPlayer = null;
        if (identical(player, _controller)) {
          _seekTarget = null;
          _pendingSeek = null;
        }
      }
    }
  }

  void _seekRelative(Duration offset) {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    final duration = controller.value.duration;
    final target = (_seekTarget ?? controller.value.position) + offset;
    final clamped = Duration(milliseconds: target.inMilliseconds.clamp(0, duration.inMilliseconds));
    _seek(clamped);
  }

  void _onPointerDown(PointerDownEvent event) {
    _seekHold.stop();
    if (_isTv) {
      _showControls();
    } else {
      _scheduleControlsHide();
    }
  }

  void _rotateScreen() {
    final landscape = MediaQuery.orientationOf(context) == Orientation.landscape;
    unawaited(
      SystemChrome.setPreferredOrientations(
        landscape
            ? [DeviceOrientation.portraitUp]
            : [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight],
      ),
    );
    _showControls();
  }

  void _startScrubbing() {
    _seekHold.stop();
    _scrubbing = true;
    _controlsTimer?.cancel();
  }

  void _endScrubbing() {
    _scrubbing = false;
    _showControls();
  }

  void _onVideoTap() {
    final value = _controller?.value;
    if (!_isTv && _controlsVisible && value != null && value.isPlaying && !value.isCompleted) {
      _controlsTimer?.cancel();
      setState(() => _controlsVisible = false);
      _focusNode.requestFocus();
    } else {
      _showControls();
    }
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
    _seekHold.stop();
    if (!_appResumed) {
      _lifecycleResumePlaying = playing;
      if (playing) {
        return;
      }
    }
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

  void _updateScreenAwake() {
    final value = _controller?.value;
    final enabled =
        !_disposed &&
        _routeActive &&
        _appResumed &&
        value != null &&
        value.isInitialized &&
        value.isPlaying &&
        !value.isBuffering &&
        !value.isCompleted &&
        !value.hasError;
    unawaited(_screenAwake.setEnabled(enabled));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _isTv = AppLayoutScope.isTvOf(context);
    final route = ModalRoute.of(context);
    final observer = Navigator.of(context).widget.observers.whereType<PlayerRouteObserver>().firstOrNull;
    if (route is PageRoute<Object?> && (!identical(_route, route) || !identical(_routeObserver, observer))) {
      _routeObserver?.unsubscribe(this);
      _route = route;
      _routeObserver = observer;
      _routeActive = route.isCurrent;
      observer?.subscribe(this, route);
      _updateScreenAwake();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final resumed = state == AppLifecycleState.resumed;
    if (_appResumed && !resumed) {
      _lifecycleResumePlaying = _controller?.value.isPlaying ?? _resumePlaying;
      _appResumed = false;
      _scrubbing = false;
      _seekHold.stop();
      _controlsTimer?.cancel();
      _updateScreenAwake();
      unawaited(_runPlayerCommand((player) => player.pause()));
    } else if (!_appResumed && resumed) {
      _appResumed = true;
      if (_lifecycleResumePlaying) {
        _lifecycleResumePlaying = false;
        _setPlaying(true);
      }
      _updateScreenAwake();
    }
  }

  @override
  void didPushNext() {
    _routeActive = false;
    _seekHold.stop();
    _controlsTimer?.cancel();
    _updateScreenAwake();
  }

  @override
  void didPopNext() {
    _routeActive = true;
    _updateScreenAwake();
  }

  @override
  void didPop() {
    _routeActive = false;
    _seekHold.stop();
    _controlsTimer?.cancel();
    _updateScreenAwake();
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
    _seekHold.stop();
    HardwareKeyboard.instance.removeHandler(_observeKey);
    FocusManager.instance.removeListener(_onFocusChanged);
    _updateScreenAwake();
    WidgetsBinding.instance.removeObserver(this);
    _routeObserver?.unsubscribe(this);
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
    if (_isTv) {
      unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []));
    } else {
      unawaited(SystemChrome.setPreferredOrientations([]));
      unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppPalette.playerBackground,
    body: Listener(
      onPointerDown: _onPointerDown,
      child: Focus(
        autofocus: true,
        focusNode: _focusNode,
        onKeyEvent: _handleKey,
        child: FutureBuilder<_PlayerData>(future: _future, builder: _buildFuture),
      ),
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
