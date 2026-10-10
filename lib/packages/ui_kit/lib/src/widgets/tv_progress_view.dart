import 'package:material_ui/material_ui.dart';

import '../theme/app_palette.dart';

class TvProgressView extends StatelessWidget {
  const TvProgressView({super.key, this.label = 'Загрузка…'});

  final String label;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox.square(dimension: 42, child: CircularProgressIndicator(strokeWidth: 3)),
        const SizedBox(height: AppSpacing.md),
        Text(label, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppPalette.textSecondary)),
      ],
    ),
  );
}
