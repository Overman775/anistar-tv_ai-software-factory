/// Presentation-only caption; source titles and episode data remain unchanged.
class EpisodeCaption {
  final int number;
  final String title;

  String get numberLabel => 'Серия $number';

  String? get descriptiveTitle {
    final normalized = title.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

    return normalized == numberLabel.toLowerCase() ? null : title;
  }

  const EpisodeCaption({required this.number, required this.title});

  String semanticLabel({required bool isWatched}) {
    final description = descriptiveTitle;

    return '$numberLabel${description == null ? '' : ', $description'}${isWatched ? ', просмотрена' : ''}';
  }
}
