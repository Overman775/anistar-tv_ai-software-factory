import 'package:material_ui/material_ui.dart';
import 'package:sizer/sizer.dart';

import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import 'app_icon.dart';
import 'app_layout_scope.dart';

class TvProgressView extends StatelessWidget {
  const TvProgressView({super.key, this.label = 'Загрузка…', this.adaptiveTv = false});

  final String label;
  final bool adaptiveTv;

  @override
  Widget build(BuildContext context) {
    final adaptive = adaptiveTv && AppLayoutScope.isTvOf(context);
    final extent = adaptive ? 5.84.vmin.clamp(32.0, 42.0) : 42.0;
    final padding = adaptive ? 4.45.h.clamp(24.0, 32.0) : AppSpacing.lg;

    return Semantics(
      liveRegion: true,
      label: label,
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.hasBoundedHeight ? constraints.maxHeight : 0),
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(padding),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox.square(
                      dimension: extent,
                      child: AppMotion.reducedOf(context)
                          ? const AppIcon(AppIconType.loaderCircle, color: AppPalette.primary)
                          : const CircularProgressIndicator(strokeWidth: 3),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style:
                          (adaptive ? AppTypography.playerEpisodeOf(context) : Theme.of(context).textTheme.titleMedium)
                              ?.copyWith(color: AppPalette.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
