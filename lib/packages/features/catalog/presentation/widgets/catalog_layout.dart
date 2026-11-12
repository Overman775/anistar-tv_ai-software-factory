/// Geometry shared by the catalog, its placeholders and remote navigation.
abstract final class CatalogLayout {
  /// Safety ceiling for small TV viewports; the inspector sizes to its content.
  static double inspectorHeight(double viewportHeight, double textScale) =>
      viewportHeight * (textScale > 1 ? 0.58 : 0.5);

  static double horizontalInset(double viewportWidth) => viewportWidth >= 1440 ? 64 : 48;

  static double posterGap(double viewportWidth) => viewportWidth >= 1440 ? 32 : 24;

  static double posterWidth(double viewportHeight) => (viewportHeight * 0.17).clamp(104, 232);

  static const focusGutter = 8.0;
  static const railTopPadding = 24.0;
  static const railBottomPadding = 32.0;
  static const inspectorActionMinHeight = 48.0;
  static const railMotion = Duration(milliseconds: 64);
  static const defaultPageSize = 10;

  static int continuationSlots(int? nextPageSize) =>
      nextPageSize != null && nextPageSize > 0 ? nextPageSize : defaultPageSize;

  static const mobilePosterGap = 12.0;

  static int mobileColumnCount(double availableWidth, double textScale, {required bool landscape}) {
    final minimumWidth = textScale > 1.5 ? 200 : 132;
    final columns = ((availableWidth + mobilePosterGap) / (minimumWidth + mobilePosterGap)).floor();

    return columns.clamp(1, landscape ? 4 : 2);
  }

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
