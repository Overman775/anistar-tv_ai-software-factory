import 'package:material_ui/material_ui.dart';

import '../theme/app_palette.dart';

class MediaCardCaptionUnderlay extends StatelessWidget {
  const MediaCardCaptionUnderlay({required this.child, this.compact = false, super.key});

  final Widget child;
  final bool compact;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, AppPalette.mediaCaptionShade, AppPalette.media],
        stops: [0, 0.48, 1],
      ),
    ),
    child: Padding(
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: AppSpacing.md)
          : const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xxl, AppSpacing.md, AppSpacing.md),
      child: child,
    ),
  );
}
