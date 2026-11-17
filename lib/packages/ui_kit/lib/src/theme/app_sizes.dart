import 'package:material_ui/material_ui.dart';
import 'package:sizer/sizer.dart';

/// Shared spacing, radius and dimensional tokens.
abstract final class AppSizes {
  static const double focusStroke = 2;
  static const double focusBlur = 12;
  static const double metadataControl = 36;
  static const double cardFocusScale = 1.025;
  static const double tvControl = 56;
  static const double touchControl = 48;
  static const double sideSheet = 440;
  static const double bottomSheetMaxWidth = 640;
  static const double posterRatio = 2 / 3;
  static const double landscapeRatio = 219 / 92;
  static const double episodeRatio = 16 / 9;

  /// Standard TV action and menu-row height: 48 at 960×540, 56 at 1280×720.
  static double get adaptiveTvControl => 7.78.h.clamp(48.0, tvControl);

  /// Compact TV metadata filter height, keeping a 48 dp interaction area.
  static double get adaptiveTvMetadataControl => 5.h.clamp(36.0, 48.0);
}

abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double xxxl = 64;

  /// Gap between adjacent standard TV controls, such as the search row.
  static double get adaptiveTvControlGap => 1.12.h.clamp(6.0, 8.0);
}

abstract final class AppRadii {
  static const small = BorderRadius.all(Radius.circular(4));
  static const medium = BorderRadius.all(Radius.circular(10));
  static const large = BorderRadius.all(Radius.circular(12));
  static const edge = BorderRadius.zero;
  static const pill = BorderRadius.all(Radius.circular(999));
}
