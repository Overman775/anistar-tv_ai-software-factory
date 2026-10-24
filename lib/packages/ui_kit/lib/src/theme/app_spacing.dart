import 'package:material_ui/material_ui.dart';

/// Shared spacing, radius and dimensional tokens.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double xxxl = 64;
}

abstract final class AppRadii {
  static const small = BorderRadius.all(Radius.circular(4));
  static const medium = BorderRadius.all(Radius.circular(10));
  static const large = BorderRadius.all(Radius.circular(12));
  static const edge = BorderRadius.zero;
  static const pill = BorderRadius.all(Radius.circular(999));
}

abstract final class AppSizes {
  static const double cardFocusScale = 1.025;
  static const double tvControl = 56;
  static const double touchControl = 48;
  static const double sideSheet = 440;
  static const double bottomSheetMaxWidth = 640;
  static const double posterRatio = 2 / 3;
  static const double landscapeRatio = 219 / 92;
  static const double episodeRatio = 16 / 9;
}
