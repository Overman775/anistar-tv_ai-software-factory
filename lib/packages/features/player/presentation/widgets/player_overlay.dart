import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:video_player/video_player.dart';

import '../../domain/models/playback_session.dart';

class PlayerOverlay extends StatefulWidget {
  const PlayerOverlay({
    required this.title,
    required this.episodeNumber,
    required this.session,
    required this.value,
    required this.onPlayPause,
    required this.onSeek,
    this.onSelectQuality,
    this.onSelectEpisode,
    this.onBack,
    this.onReturnToVideo,
    this.backFocusNode,
    this.playFocusNode,
    super.key,
  });

  static String _format(Duration value) {
    final hours = value.inHours;
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');

    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  final int episodeNumber;
  final VoidCallback? onBack;
  final VoidCallback? onReturnToVideo;
  final FocusNode? backFocusNode;
  final FocusNode? playFocusNode;
  final VoidCallback onPlayPause;
  final VoidCallback? onSelectQuality;
  final VoidCallback? onSelectEpisode;
  final ValueChanged<Duration> onSeek;
  final PlaybackSession session;
  final String title;
  final VideoPlayerValue value;

  @override
  State<PlayerOverlay> createState() => _PlayerOverlayState();
}

class _PlayerOverlayState extends State<PlayerOverlay> {
  final _timeline = FocusNode(debugLabel: 'Позиция видео');
  int _transportIndex = 0;
  final _back = FocusNode(debugLabel: 'К сериям');
  final _quality = FocusNode(debugLabel: 'Качество');
  final _episodes = FocusNode(debugLabel: 'Серии');
  final _rewind = FocusNode(debugLabel: 'Назад на 10 секунд');
  final _play = FocusNode(debugLabel: 'Пауза / воспроизведение');
  final _forward = FocusNode(debugLabel: 'Вперёд на 10 секунд');

  bool _timelineFocused = false;

  int get _bufferedPosition {
    final duration = widget.value.duration.inMilliseconds;
    var buffered = 0;
    for (final range in widget.value.buffered) {
      final end = range.end.inMilliseconds;
      if (end > buffered) {
        buffered = end;
      }
    }

    return buffered.clamp(0, duration <= 0 ? 1 : duration);
  }

  String _formatSliderPosition(double value) => PlayerOverlay._format(Duration(milliseconds: value.round()));

  void _onTimelineFocusChanged(bool focused) => setState(() => _timelineFocused = focused);

  KeyEventResult _handleNavigation(FocusNode node, KeyEvent event) {
    final transport = [
      widget.playFocusNode ?? _play,
      _rewind,
      _forward,
      if (widget.onSelectEpisode != null) _episodes,
      if (widget.onSelectQuality != null) _quality,
    ];
    final rows = [
      if (widget.onBack != null) [widget.backFocusNode ?? _back],
      [_timeline],
      transport,
    ];
    final current = FocusManager.instance.primaryFocus;
    final row = rows.indexWhere((nodes) => nodes.contains(current));
    if (row < 0) {
      return KeyEventResult.ignored;
    }
    final column = rows[row].indexOf(current ?? node);
    final key = event.logicalKey;
    FocusNode? target;
    var returnToVideo = false;
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.arrowRight) {
      if (current == _timeline) {
        if (event is KeyDownEvent || event is KeyRepeatEvent) {
          _seekRelative(Duration(seconds: key == LogicalKeyboardKey.arrowRight ? 10 : -10));
        }

        return KeyEventResult.handled;
      }
      final next = column + (key == LogicalKeyboardKey.arrowRight ? 1 : -1);
      target = rows[row][next.clamp(0, rows[row].length - 1)];
    } else if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.arrowDown) {
      final next = row + (key == LogicalKeyboardKey.arrowDown ? 1 : -1);
      returnToVideo = next < 0 || next >= rows.length;
      if (!returnToVideo) {
        if (row == rows.length - 1) {
          _transportIndex = column;
        }
        target = next == rows.length - 1 ? transport[_transportIndex.clamp(0, transport.length - 1)] : rows[next].first;
      }
    } else {
      return KeyEventResult.ignored;
    }
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      if (returnToVideo) {
        widget.onReturnToVideo?.call();
      } else {
        target?.requestFocus();
      }
    }

    return KeyEventResult.handled;
  }

  void _onSliderChanged(double milliseconds) => widget.onSeek(Duration(milliseconds: milliseconds.round()));

  void _seekBackward() => _seekRelative(const Duration(seconds: -10));

  void _seekForward() => _seekRelative(const Duration(seconds: 10));

  void _seekRelative(Duration offset) {
    final target = widget.value.position + offset;
    final durationMs = widget.value.duration.inMilliseconds;
    widget.onSeek(Duration(milliseconds: target.inMilliseconds.clamp(0, durationMs)));
  }

  @override
  void dispose() {
    for (final node in [_back, _quality, _episodes, _rewind, _play, _forward, _timeline]) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.value;
    final durationMs = value.duration.inMilliseconds;
    final positionMs = value.position.inMilliseconds.clamp(0, durationMs <= 0 ? 1 : durationMs);
    final buttonStyle =
        IconButton.styleFrom(foregroundColor: Colors.white, minimumSize: const Size(52, 52), iconSize: 30).copyWith(
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.focused) ? Colors.black : Colors.white,
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.focused) ? Colors.white : Colors.transparent,
          ),
        );

    return Focus(
      canRequestFocus: false,
      onKeyEvent: _handleNavigation,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xC9000000), Color(0x00000000), Color(0xE8000000)],
            stops: [0, 0.48, 1],
          ),
        ),
        child: SafeArea(
          minimum: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (widget.onBack != null) ...[
                    IconButton(
                      key: const ValueKey('player-back'),
                      style: buttonStyle,
                      focusNode: widget.backFocusNode ?? _back,
                      onPressed: widget.onBack,
                      tooltip: 'К сериям',
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: AppSpacing.md),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white),
                        ),
                        Text('Серия ${widget.episodeNumber}', style: const TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Focus(
                focusNode: _timeline,
                onFocusChange: _onTimelineFocusChanged,
                child: Semantics(
                  label: 'Позиция видео',
                  child: ExcludeFocus(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: _timelineFocused ? 6 : 3,
                        activeTrackColor: AppPalette.primary,
                        inactiveTrackColor: Colors.white30,
                        secondaryActiveTrackColor: Colors.white54,
                        thumbColor: Colors.white,
                        thumbShape: RoundSliderThumbShape(enabledThumbRadius: _timelineFocused ? 9 : 5),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                      ),
                      child: Slider(
                        key: const ValueKey('player-timeline'),
                        value: positionMs.toDouble(),
                        max: durationMs <= 0 ? 1 : durationMs.toDouble(),
                        secondaryTrackValue: _bufferedPosition.toDouble(),
                        onChanged: durationMs > 0 ? _onSliderChanged : null,
                        semanticFormatterCallback: _formatSliderPosition,
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  IconButton(
                    key: const ValueKey('player-play'),
                    style: buttonStyle,
                    focusNode: widget.playFocusNode ?? _play,
                    onPressed: widget.onPlayPause,
                    tooltip: value.isPlaying ? 'Пауза' : 'Воспроизвести',
                    icon: Icon(value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                  ),
                  IconButton(
                    style: buttonStyle,
                    focusNode: _rewind,
                    onPressed: _seekBackward,
                    tooltip: 'Назад на 10 секунд',
                    icon: const Icon(Icons.replay_10_rounded),
                  ),
                  IconButton(
                    style: buttonStyle,
                    focusNode: _forward,
                    onPressed: _seekForward,
                    tooltip: 'Вперёд на 10 секунд',
                    icon: const Icon(Icons.forward_10_rounded),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    '${PlayerOverlay._format(value.position)} / ${PlayerOverlay._format(value.duration)}',
                    style: const TextStyle(color: Colors.white),
                  ),
                  const Spacer(),
                  if (widget.onSelectEpisode != null)
                    IconButton(
                      key: const ValueKey('player-episodes'),
                      style: buttonStyle,
                      focusNode: _episodes,
                      onPressed: widget.onSelectEpisode,
                      tooltip: 'Серии',
                      icon: const Icon(Icons.playlist_play_rounded),
                    ),
                  if (widget.onSelectQuality != null)
                    IconButton(
                      key: const ValueKey('player-quality'),
                      style: buttonStyle,
                      focusNode: _quality,
                      onPressed: widget.onSelectQuality,
                      tooltip: 'Качество: ${widget.session.selectedQuality.apiValue}p',
                      icon: const Icon(Icons.settings_outlined),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
