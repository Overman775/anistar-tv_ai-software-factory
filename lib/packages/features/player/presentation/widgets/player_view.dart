import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:video_player/video_player.dart';

import '../../domain/models/playback_session.dart';
import 'player_overlay.dart';
import 'player_retry_view.dart';

class PlayerView extends StatefulWidget {
  const PlayerView({
    required this.controller,
    required this.controlsVisible,
    required this.episodeNumber,
    required this.onPlayPause,
    required this.onSelectQuality,
    required this.onSelectEpisode,
    required this.onRetry,
    required this.onSeek,
    required this.onShowControls,
    required this.session,
    required this.title,
    this.onSeekKeyEvent,
    this.onPreviousEpisode,
    this.onNextEpisode,
    this.onBack,
    this.onReturnToVideo,
    this.controlsFocusNode,
    this.backFocusNode,
    this.playFocusNode,
    super.key,
  });

  final bool Function(KeyEvent)? onSeekKeyEvent;
  final VideoPlayerController controller;
  final VoidCallback? onPreviousEpisode;
  final VoidCallback? onNextEpisode;
  final VoidCallback? onBack;
  final VoidCallback? onReturnToVideo;
  final FocusNode? controlsFocusNode;
  final FocusNode? backFocusNode;
  final FocusNode? playFocusNode;
  final bool controlsVisible;
  final int episodeNumber;
  final VoidCallback onPlayPause;
  final VoidCallback onSelectQuality;
  final VoidCallback onSelectEpisode;
  final VoidCallback onRetry;
  final ValueChanged<Duration> onSeek;
  final VoidCallback onShowControls;
  final PlaybackSession session;
  final String title;

  @override
  State<PlayerView> createState() => _PlayerViewState();
}

class _PlayerViewState extends State<PlayerView> {
  late VideoPlayerValue _value;

  @override
  void initState() {
    super.initState();
    _value = widget.controller.value;
    widget.controller.addListener(_onValueChanged);
  }

  void _onValueChanged() {
    final next = widget.controller.value;
    final rebuild =
        widget.controlsVisible ||
        next.isBuffering != _value.isBuffering ||
        next.errorDescription != _value.errorDescription ||
        next.isInitialized != _value.isInitialized ||
        next.aspectRatio != _value.aspectRatio;
    // Keep the latest timeline for reveal, without rebuilding invisible controls.
    if (rebuild) {
      setState(() => _value = next);
    } else {
      _value = next;
    }
  }

  @override
  void didUpdateWidget(covariant PlayerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onValueChanged);
      widget.controller.addListener(_onValueChanged);
    }
    _value = widget.controller.value;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onValueChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = _value;
    if (value.hasError) {
      return PlayerRetryView(
        icon: Icons.play_disabled_rounded,
        title: 'Воспроизведение прервано',
        message: 'Не удалось продолжить поток. Повторите попытку или выберите другое качество.',
        onRetry: widget.onRetry,
      );
    }
    final aspectRatio = value.aspectRatio == 0 ? 16 / 9 : value.aspectRatio;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onShowControls,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: AspectRatio(aspectRatio: aspectRatio, child: VideoPlayer(widget.controller)),
          ),
          AnimatedOpacity(
            opacity: widget.controlsVisible ? 1 : 0,
            duration: AppMotion.durationOf(context, AppMotion.fast),
            child: IgnorePointer(
              ignoring: !widget.controlsVisible,
              child: ExcludeFocus(
                excluding: !widget.controlsVisible,
                child: Focus(
                  focusNode: widget.controlsFocusNode,
                  skipTraversal: true,
                  child: PlayerOverlay(
                    onPreviousEpisode: widget.onPreviousEpisode,
                    onNextEpisode: widget.onNextEpisode,
                    onBack: widget.onBack,
                    onReturnToVideo: widget.onReturnToVideo,
                    backFocusNode: widget.backFocusNode,
                    playFocusNode: widget.playFocusNode,
                    title: widget.title,
                    episodeNumber: widget.episodeNumber,
                    session: widget.session,
                    value: value,
                    onPlayPause: widget.onPlayPause,
                    onSelectQuality: widget.onSelectQuality,
                    onSelectEpisode: widget.onSelectEpisode,
                    onSeek: widget.onSeek,
                    onSeekKeyEvent: widget.onSeekKeyEvent,
                  ),
                ),
              ),
            ),
          ),
          if (value.isBuffering)
            const Center(
              child: DecoratedBox(
                decoration: BoxDecoration(color: Color(0xB8000000), shape: BoxShape.circle),
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: SizedBox.square(dimension: 48, child: CircularProgressIndicator(strokeWidth: 4)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
