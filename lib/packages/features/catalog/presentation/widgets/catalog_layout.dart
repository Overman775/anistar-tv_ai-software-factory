import 'package:sizer/sizer.dart';
import 'package:ui_kit/ui_kit.dart';

/// Geometry shared by the catalog, its placeholders and remote navigation.
abstract final class CatalogLayout {
  /// Safety ceiling for small TV viewports; the inspector sizes to its content.
  static double inspectorHeight(double viewportHeight, double textScale) =>
      viewportHeight * (textScale > 1 ? 0.58 : 0.5);

  static double horizontalInset(double viewportWidth) => viewportWidth >= 1440 ? 64 : 3.75.w.clamp(40.0, 48.0);

  static double posterGap(double viewportWidth) => viewportWidth >= 1440 ? 32 : 1.88.w.clamp(18.0, 24.0);

  static double posterWidth(double _) => 17.h.clamp(92.0, 232.0);

  static double get focusGutter => 0.63.w.clamp(6.0, 8.0);

  static double get railTopPadding => 3.34.h.clamp(18.0, 24.0);

  static double get railBottomPadding => 4.45.h.clamp(24.0, 32.0);

  static double get headingTopPadding => 2.23.h.clamp(12.0, 16.0);

  static double get headingBottomPadding => 1.12.h.clamp(6.0, 8.0);

  static double get inspectorTopPadding => 3.34.h.clamp(18.0, 24.0);

  static double get inspectorActionMinHeight => AppSizes.adaptiveTvControl;

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
    // after the persistent rail. Native small TV keeps its own adaptation.
    if (width >= 1352) {
      return 5;
    }
    if (width >= 820) {
      return 4;
    }

    return width >= 600 ? 3 : 2;
  }
}
