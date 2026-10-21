import 'package:flutter/material.dart';

class AppBreakpoints {
  static const double mobile = 600;
  static const double tablet = 1024;
}

/// Screen-size helpers for layout only. Do not derive font sizes from these:
/// text size comes from the theme's text styles plus the global font scale
/// (see design_system/app_typography.dart).
extension ResponsiveContext on BuildContext {
  Size get screenSize => MediaQuery.of(this).size;
  double get screenWidth => screenSize.width;
  double get screenHeight => screenSize.height;

  bool get isMobile => screenWidth < AppBreakpoints.mobile;
  bool get isTablet =>
      screenWidth >= AppBreakpoints.mobile &&
      screenWidth < AppBreakpoints.tablet;
  bool get isDesktop => screenWidth >= AppBreakpoints.tablet;

  /// width % helper -> context.w(0.4) = 40% of width
  double w(double factor) => screenWidth * factor;

  /// height % helper
  double h(double factor) => screenHeight * factor;
}
