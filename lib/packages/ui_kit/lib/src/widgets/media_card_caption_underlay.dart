import 'package:material_ui/material_ui.dart';

import '../theme/app_palette.dart';

class MediaCardCaptionUnderlay extends StatelessWidget {
  const MediaCardCaptionUnderlay({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => Positioned(
    left: 0,
    right: 0,
    bottom: 0,
    child: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, AppPalette.mediaCaptionShade, AppPalette.media],
          stops: [0, 0.48, 1],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xxl, AppSpacing.md, AppSpacing.md),
        child: child,
      ),
    ),
  );
}
