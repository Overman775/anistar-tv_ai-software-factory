/// Geometry shared by the details page and its loading placeholders.
abstract final class AnimeLayout {
  static double heroHeight(double width, {double textScale = 1}) =>
      baseHeroHeight(width) * textScale.clamp(1, double.infinity);

  static double baseHeroHeight(double width) {
    if (width >= 1200) {
      return 410;
    }

    return width >= 900 ? 380 : 470;
  }

  static int episodeColumns(double width) {
    if (width >= 1600) {
      return 4;
    }

    return width >= 900 ? 3 : 2;
  }
}
