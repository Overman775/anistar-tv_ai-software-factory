import 'package:material_ui/material_ui.dart';
import 'package:sizer/sizer.dart';
import 'package:ui_kit/ui_kit.dart';

class SearchFeedback extends StatelessWidget {
  const SearchFeedback({required this.icon, required this.title, this.message, super.key});

  final IconData icon;
  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final tv = AppLayoutScope.isTvOf(context);

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.hasBoundedHeight ? constraints.maxHeight : 0),
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: TvStateView.headingInsetOf(context, title, constraints.maxWidth),
                vertical: tv ? 3.34.h.clamp(18.0, 24.0) : AppSpacing.xl,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Semantics(
                  liveRegion: true,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppIcon.fromMaterial(
                        icon,
                        size: tv ? 6.67.vmin.clamp(36.0, 48.0) : 48.0,
                        color: AppPalette.textSecondary,
                      ),
                      SizedBox(height: tv ? 3.34.h.clamp(18.0, 24.0) : AppSpacing.lg),
                      Text(
                        title,
                        style: tv ? AppTypography.stateTitleOf(context) : Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      if (message case final String message) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          message,
                          style: (tv ? AppTypography.stateBodyOf(context) : Theme.of(context).textTheme.bodyLarge)
                              ?.copyWith(color: AppPalette.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
