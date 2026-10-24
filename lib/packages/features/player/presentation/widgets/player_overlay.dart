import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:video_player/video_player.dart';

import '../../domain/models/playback_session.dart';
import '../playback_quality_label.dart';
import 'player_control_button.dart';
import 'player_progress.dart';

class PlayerOverlay extends StatefulWidget {
  const PlayerOverlay({
    required this.title,
    required this.episodeNumber,
    required this.session,
    required this.value,
    required this.onPlayPause,
    required this.onSeek,
    this.onSeekKeyEvent,
    this.onSeekRelative,
    this.previewPosition,
    this.onSelectQuality,
    this.onSelectEpisode,
    this.onPreviousEpisode,
    this.onNextEpisode,
    this.onBack,
    this.onReturnToVideo,
    this.backFocusNode,
    this.playFocusNode,
    super.key,
  });

  final bool Function(KeyEvent)? onSeekKeyEvent;
  final ValueChanged<Duration>? onSeekRelative;
  final Duration? previewPosition;
  final int episodeNumber;
  final VoidCallback? onPreviousEpisode;
  final VoidCallback? onNextEpisode;
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
  final _previousEpisode = FocusNode(debugLabel: 'Предыдущая серия');
  final _nextEpisode = FocusNode(debugLabel: 'Следующая серия');
  final _forward = FocusNode(debugLabel: 'Вперёд на 10 секунд');

  bool _timelineFocused = false;

  int get _bufferedPosition => playerBufferedPosition(widget.value.buffered, widget.value.duration);

  String _formatSliderPosition(double value) => formatPlayerTime(Duration(milliseconds: value.round()));

  void _onTimelineFocusChanged(bool focused) => setState(() => _timelineFocused = focused);

  KeyEventResult _handleNavigation(FocusNode node, KeyEvent event) {
    final transport = [
      widget.playFocusNode ?? _play,
      _rewind,
      _forward,
      if (widget.onPreviousEpisode != null) _previousEpisode,
      if (widget.onNextEpisode != null) _nextEpisode,
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
        if (widget.onSeekKeyEvent != null) {
          widget.onSeekKeyEvent?.call(event);
        } else if (event is KeyDownEvent || event is KeyRepeatEvent) {
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
    final relativeSeek = widget.onSeekRelative;
    if (relativeSeek != null) {
      relativeSeek(offset);

      return;
    }
    final target = widget.value.position + offset;
    widget.onSeek(Duration(milliseconds: playerSeekPosition(target, widget.value.duration)));
  }

  @override
  void dispose() {
    for (final node in [
      _back,
      _quality,
      _episodes,
      _rewind,
      _play,
      _forward,
      _previousEpisode,
      _nextEpisode,
      _timeline,
    ]) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final selectedQuality = widget.session.selectedQuality;
    final value = widget.value;
    final durationMs = playerSliderMaximum(value.duration);
    final position = widget.previewPosition ?? value.position;
    final positionMs = playerSliderPosition(position, value.duration);
    final time = '${formatPlayerTime(position)} / ${formatPlayerTime(value.duration)}';

    return Focus(
      canRequestFocus: false,
      onKeyEvent: _handleNavigation,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppPalette.playerShadeTop, Colors.transparent, Colors.transparent, AppPalette.playerShadeBottom],
            stops: [0, 0.32, 0.54, 1],
          ),
        ),
        child: SafeArea(
          minimum: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (widget.onBack != null) ...[
                    PlayerControlButton(
                      buttonKey: 'player-back',
                      label: 'К сериям',
                      focusNode: widget.backFocusNode ?? _back,
                      onPressed: widget.onBack,
                      child: const AppIcon(AppIconType.arrowLeft),
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
                          style: textTheme.headlineMedium?.copyWith(
                            color: AppPalette.playerText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Серия ${widget.episodeNumber}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodyLarge?.copyWith(color: AppPalette.playerMuted),
                        ),
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
                        inactiveTrackColor: AppPalette.playerMuted.withValues(alpha: 0.3),
                        secondaryActiveTrackColor: AppPalette.playerMuted.withValues(alpha: 0.6),
                        thumbColor: AppPalette.primary,
                        thumbShape: RoundSliderThumbShape(enabledThumbRadius: _timelineFocused ? 9 : 5),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                        padding: EdgeInsets.zero,
                      ),
                      child: Slider(
                        key: const ValueKey('player-timeline'),
                        value: positionMs.toDouble(),
                        max: durationMs.toDouble(),
                        secondaryTrackValue: _bufferedPosition.toDouble(),
                        onChanged: value.duration.inMilliseconds > 0 ? _onSliderChanged : null,
                        semanticFormatterCallback: _formatSliderPosition,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  PlayerControlButton(
                    buttonKey: 'player-play',
                    label: value.isPlaying ? 'Пауза' : 'Воспроизвести',
                    focusNode: widget.playFocusNode ?? _play,
                    onPressed: widget.onPlayPause,
                    primary: true,
                    child: AppIcon(value.isPlaying ? AppIconType.pause : AppIconType.play),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  PlayerControlButton(
                    buttonKey: 'player-rewind',
                    label: 'Назад на 10 секунд',
                    focusNode: _rewind,
                    onPressed: _seekBackward,
                    child: const AppIcon(AppIconType.rotateCcw),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  PlayerControlButton(
                    buttonKey: 'player-forward',
                    label: 'Вперёд на 10 секунд',
                    focusNode: _forward,
                    onPressed: _seekForward,
                    child: const AppIcon(AppIconType.rotateCw),
                  ),
                  if (widget.onPreviousEpisode != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    PlayerControlButton(
                      buttonKey: 'player-previous-episode',
                      label: 'Предыдущая серия',
                      focusNode: _previousEpisode,
                      onPressed: widget.onPreviousEpisode,
                      child: const AppIcon(AppIconType.skipBack),
                    ),
                  ],
                  if (widget.onNextEpisode != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    PlayerControlButton(
                      buttonKey: 'player-next-episode',
                      label: 'Следующая серия',
                      focusNode: _nextEpisode,
                      onPressed: widget.onNextEpisode,
                      child: const AppIcon(AppIconType.skipForward),
                    ),
                  ],
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      time,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyLarge?.copyWith(
                        color: AppPalette.playerText,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  if (widget.onSelectEpisode != null) ...[
                    const SizedBox(width: AppSpacing.md),
                    PlayerControlButton(
                      buttonKey: 'player-episodes',
                      label: 'Серии',
                      focusNode: _episodes,
                      onPressed: widget.onSelectEpisode,
                      child: const AppIcon(AppIconType.listVideo),
                    ),
                  ],
                  if (widget.onSelectQuality != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    PlayerControlButton(
                      buttonKey: 'player-quality',
                      label: 'Качество: ${selectedQuality.label}',
                      focusNode: _quality,
                      onPressed: widget.onSelectQuality,
                      child: Text(selectedQuality.shortLabel),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
