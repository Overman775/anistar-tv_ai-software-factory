/// Geometry shared by the catalog, its placeholders and remote navigation.
abstract final class CatalogLayout {
  /// Safety ceiling for small TV viewports; the inspector sizes to its content.
  static double inspectorHeight(double viewportHeight, double textScale) =>
      viewportHeight * (textScale > 1 ? 0.58 : 0.5);

  static double horizontalInset(double viewportWidth) => switch (viewportWidth) {
    >= 1440 => 64,
    >= 1024 => 40,
    >= 768 => 32,
    _ => 24,
  };

  static int columnCount(double width) {
    // The prototype's five-column TV layout starts at a 1440px viewport,
    // after the persistent 88px rail. Native small TV keeps its own adaptation.
    if (width >= 1352) {
      return 5;
    }
    if (width >= 820) {
      return 4;
    }

    return width >= 600 ? 3 : 2;
  }
}
