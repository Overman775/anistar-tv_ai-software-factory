import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:video_player/video_player.dart';

import '../../domain/models/playback_session.dart';
import '../playback_quality_label.dart';
import 'mobile_player_control_button.dart';

/// Touch controls use the same playback commands as the television overlay.
class MobilePlayerControls extends StatelessWidget {
  const MobilePlayerControls({
    required this.title,
    required this.episodeNumber,
    required this.session,
    required this.value,
    required this.onPlayPause,
    required this.onSeek,
    this.onSeekRelative,
    this.onBack,
    this.onSelectEpisode,
    this.onSelectQuality,
    this.onPreviousEpisode,
    this.onNextEpisode,
    this.onRotate,
    this.onInteractionStart,
    this.onInteractionEnd,
    super.key,
  });

  static String _format(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');

    return value.inHours > 0 ? '${value.inHours}:$minutes:$seconds' : '$minutes:$seconds';
  }

  final String title;
  final int episodeNumber;
  final PlaybackSession session;
  final VideoPlayerValue value;
  final VoidCallback onPlayPause;
  final ValueChanged<Duration> onSeek;
  final ValueChanged<Duration>? onSeekRelative;
  final VoidCallback? onBack;
  final VoidCallback? onSelectEpisode;
  final VoidCallback? onSelectQuality;
  final VoidCallback? onPreviousEpisode;
  final VoidCallback? onNextEpisode;
  final VoidCallback? onRotate;
  final VoidCallback? onInteractionStart;
  final VoidCallback? onInteractionEnd;

  void _seekRelative(int seconds) {
    final relativeSeek = onSeekRelative;
    if (relativeSeek != null) {
      relativeSeek(Duration(seconds: seconds));
    } else {
      onSeek(
        Duration(
          milliseconds: (value.position.inMilliseconds + seconds * 1000).clamp(0, value.duration.inMilliseconds),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final durationMs = value.duration.inMilliseconds;
    final position = value.position.inMilliseconds.clamp(0, durationMs <= 0 ? 1 : durationMs);
    final textTheme = Theme.of(context).textTheme;
    final selectedQuality = session.selectedQuality;
    final qualityLabel = 'Качество: ${selectedQuality.label}';

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xDC000000), Color(0x55000000), Color(0xEC000000)],
          stops: [0, 0.5, 1],
        ),
      ),
      child: SafeArea(
        minimum: const EdgeInsets.all(8),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: Row(
                children: [
                  if (onBack != null)
                    MobilePlayerControlButton(
                      buttonKey: 'player-back',
                      label: 'К сериям',
                      icon: Icons.arrow_back_rounded,
                      onPressed: onBack,
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleMedium?.copyWith(color: Colors.white),
                        ),
                        Text(
                          'Серия $episodeNumber',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  if (onRotate != null)
                    MobilePlayerControlButton(
                      buttonKey: 'player-rotate',
                      label: 'Повернуть экран',
                      icon: Icons.screen_rotation_rounded,
                      onPressed: onRotate,
                    ),
                ],
              ),
            ),
            Align(
              alignment: const Alignment(0, -0.3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MobilePlayerControlButton(
                    buttonKey: 'player-rewind',
                    label: 'Назад на 10 секунд',
                    icon: Icons.replay_10_rounded,
                    onPressed: () => _seekRelative(-10),
                  ),
                  const SizedBox(width: 24),
                  IconButton.filled(
                    key: const ValueKey('player-play'),
                    tooltip: value.isPlaying ? 'Пауза' : 'Воспроизвести',
                    onPressed: onPlayPause,
                    style: IconButton.styleFrom(
                      minimumSize: const Size(64, 64),
                      backgroundColor: AppPalette.primary,
                      foregroundColor: AppPalette.background,
                    ),
                    icon: Icon(value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 36),
                  ),
                  const SizedBox(width: 24),
                  MobilePlayerControlButton(
                    buttonKey: 'player-forward',
                    label: 'Вперёд на 10 секунд',
                    icon: Icons.forward_10_rounded,
                    onPressed: () => _seekRelative(10),
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${_format(Duration(milliseconds: position))} / ${_format(value.duration)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: Colors.white,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                  Slider(
                    key: const ValueKey('player-timeline'),
                    value: position.toDouble(),
                    max: durationMs <= 0 ? 1 : durationMs.toDouble(),
                    onChangeStart: (_) => onInteractionStart?.call(),
                    onChangeEnd: (_) => onInteractionEnd?.call(),
                    onChanged: durationMs > 0
                        ? (milliseconds) => onSeek(Duration(milliseconds: milliseconds.round()))
                        : null,
                    semanticFormatterCallback: (milliseconds) => _format(Duration(milliseconds: milliseconds.round())),
                  ),
                  Row(
                    children: [
                      if (onPreviousEpisode != null)
                        MobilePlayerControlButton(
                          buttonKey: 'player-previous-episode',
                          label: 'Предыдущая серия',
                          icon: Icons.skip_previous_rounded,
                          onPressed: onPreviousEpisode,
                        ),
                      if (onNextEpisode != null)
                        MobilePlayerControlButton(
                          buttonKey: 'player-next-episode',
                          label: 'Следующая серия',
                          icon: Icons.skip_next_rounded,
                          onPressed: onNextEpisode,
                        ),
                      const Spacer(),
                      if (onSelectEpisode != null)
                        MobilePlayerControlButton(
                          buttonKey: 'player-episodes',
                          label: 'Серии',
                          icon: Icons.playlist_play_rounded,
                          onPressed: onSelectEpisode,
                        ),
                      if (onSelectQuality != null)
                        Tooltip(
                          message: qualityLabel,
                          excludeFromSemantics: true,
                          child: TextButton(
                            key: const ValueKey('player-quality'),
                            style: TextButton.styleFrom(minimumSize: const Size(48, 48), foregroundColor: Colors.white),
                            onPressed: onSelectQuality,
                            child: Text(
                              selectedQuality.shortLabel,
                              semanticsLabel: qualityLabel,
                              style: textTheme.titleSmall?.copyWith(color: Colors.white),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
