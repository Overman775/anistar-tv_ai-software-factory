import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:video_player/video_player.dart';

import '../../domain/models/playback_session.dart';
import 'player_overlay.dart';
import 'player_retry_view.dart';

class PlayerView extends StatelessWidget {
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
    super.key,
  });

  final VideoPlayerController controller;
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
  Widget build(BuildContext context) => ValueListenableBuilder<VideoPlayerValue>(
    valueListenable: controller,
    builder: (context, value, child) {
      if (value.hasError) {
        return PlayerRetryView(
          icon: Icons.play_disabled_rounded,
          title: 'Воспроизведение прервано',
          message: 'Не удалось продолжить поток. Повторите попытку или выберите другое качество.',
          onRetry: onRetry,
        );
      }
      final aspectRatio = value.aspectRatio == 0 ? 16 / 9 : value.aspectRatio;

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onShowControls,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: AspectRatio(aspectRatio: aspectRatio, child: VideoPlayer(controller)),
            ),
            AnimatedOpacity(
              opacity: controlsVisible ? 1 : 0,
              duration: AppMotion.fast,
              child: IgnorePointer(
                ignoring: !controlsVisible,
                child: ExcludeFocus(
                  child: PlayerOverlay(
                    title: title,
                    episodeNumber: episodeNumber,
                    session: session,
                    value: value,
                    onPlayPause: onPlayPause,
                    onSelectQuality: onSelectQuality,
                    onSelectEpisode: onSelectEpisode,
                    onSeek: onSeek,
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
    },
  );
}
