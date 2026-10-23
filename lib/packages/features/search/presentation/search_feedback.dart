import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

class SearchFeedback extends StatelessWidget {
  const SearchFeedback({required this.icon, required this.title, this.message, super.key});

  final IconData icon;
  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.hasBoundedHeight ? constraints.maxHeight : 0),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Semantics(
                liveRegion: true,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppIcon.fromMaterial(icon, size: 48, color: AppPalette.textSecondary),
                    const SizedBox(height: AppSpacing.lg),
                    Text(title, style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
                    if (message case final String message) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        message,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppPalette.textSecondary),
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
