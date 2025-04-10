import 'package:anistar_tv/packages/features/series_list/domain/models/series_model.dart';
import 'package:flutter/material.dart';

class SeriesCard extends StatelessWidget {
  final Series series;
  final bool isFocused;
  final VoidCallback? onTap;

  const SeriesCard({super.key, required this.series, required this.isFocused, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = isFocused ? theme.focusColor : theme.cardColor;
    // Ensure text color contrasts with the background
    final textColor = isFocused ? theme.colorScheme.onPrimary : theme.textTheme.bodyLarge?.color;

    return GestureDetector(
      onTap: onTap, // Trigger onTap when the card is tapped
      child: Card(
        color: cardColor,
        child: Padding(
          padding: const EdgeInsets.all(8.0), // Add padding inside the card
          child: Center(
            child: Text(
              series.title, // Display the series title
              style: theme.textTheme.bodyLarge?.copyWith(color: textColor),
              textAlign: TextAlign.center,
              maxLines: 2, // Limit title to 2 lines
              overflow: TextOverflow.ellipsis, // Handle overflow
            ),
          ),
        ),
      ),
    );
  }
}
