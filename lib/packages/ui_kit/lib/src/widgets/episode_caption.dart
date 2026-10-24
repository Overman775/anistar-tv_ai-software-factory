/// Neutral episode caption for visual surfaces and their accessibility labels.
class EpisodeCaption {
  const EpisodeCaption({required this.number, required this.title});

  final int number;
  final String title;

  String get numberLabel => 'Серия $number';

  String? get descriptiveTitle {
    final normalized = title.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

    return normalized == numberLabel.toLowerCase() ? null : title;
  }

  String semanticLabel({required bool isWatched}) {
    final description = descriptiveTitle;

    return '$numberLabel${description == null ? '' : ', $description'}${isWatched ? ', просмотрена' : ''}';
  }
}
