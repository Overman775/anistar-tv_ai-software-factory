/// Geometry shared by the details page and its loading placeholders.
abstract final class AnimeLayout {
  static double heroHeight(double width) {
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
