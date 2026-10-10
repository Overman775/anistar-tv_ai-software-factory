/// Geometry shared by the catalog, its placeholders and remote navigation.
abstract final class CatalogLayout {
  static int columnCount(double width) {
    if (width >= 1700) {
      return 6;
    }
    if (width >= 1180) {
      return 5;
    }
    if (width >= 820) {
      return 4;
    }

    return width >= 600 ? 3 : 2;
  }
}
