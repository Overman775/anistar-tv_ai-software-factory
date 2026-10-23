import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../domain/models/anime_summary.dart';
import 'catalog_inspector_rating.dart';
import 'catalog_layout.dart';

class CatalogInspectorCopy extends StatelessWidget {
  const CatalogInspectorCopy({required this.anime, super.key});

  final AnimeSummary anime;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final facts = [?anime.year, ...anime.genres.take(2)].join(' · ');
    final viewport = MediaQuery.sizeOf(context);
    final verticalPadding = viewport.width <= 768 ? AppSpacing.lg : AppSpacing.xl;
    final heightBudget = CatalogLayout.inspectorHeight(
      viewport.height,
      MediaQuery.textScalerOf(context).scale(16) / 16,
    );

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: CatalogLayout.horizontalInset(viewport.width),
        vertical: verticalPadding,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  anime.title,
                  maxLines: heightBudget - verticalPadding * 2 < 180 ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.xs,
                  children: [
                    CatalogInspectorRating(rating: anime.rating),
                    if (facts.isNotEmpty)
                      Text(facts, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.bodyMedium),
                  ],
                ),
                if (anime.description case final description?) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Flexible(
                    child: Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.bodyMedium?.copyWith(color: AppPalette.textSecondary),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (anime.updateMessage != null || anime.publicationDate != null) ...[
            const SizedBox(width: AppSpacing.xl),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (anime.updateMessage case final message?) Text(message, style: theme.bodyMedium),
                    if (anime.publicationDate case final date?) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(date, style: theme.labelMedium?.copyWith(color: AppPalette.textSecondary)),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
