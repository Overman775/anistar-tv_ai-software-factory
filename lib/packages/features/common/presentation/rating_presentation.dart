final class RatingPresentation {
  final String label;

  const RatingPresentation._(this.label);

  static RatingPresentation? from(double? value) {
    if (value == null || !value.isFinite || value < 0 || value > 10) {
      return null;
    }

    return RatingPresentation._(value.toStringAsFixed(1).replaceAll('.', ','));
  }

  String get semanticLabel => 'Рейтинг $label из 10';
}
