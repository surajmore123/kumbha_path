import 'package:flutter/material.dart';

/// Legacy width-scaled text theme, kept so existing references compile.
///
/// It hardcodes light-mode colors and scales by screen width, which conflicts
/// with dark mode and the global font-scale preference. New code uses
/// `Theme.of(context).textTheme`, built by `AppTypography` and scaled once
/// globally by `AppFontScaleScope`.
class AppTextTheme {
  @Deprecated(
    'Use Theme.of(context).textTheme (AppTypography). Font scale is applied '
    'globally; do not scale by screen width.',
  )
  static TextTheme textTheme(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    double scale = (width / 400).clamp(0.9, 1.4);

    return TextTheme(
      displayLarge: TextStyle(
        fontSize: 32 * scale,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.3,
        color: Colors.black,
      ),

      displayMedium: TextStyle(
        fontSize: 26 * scale,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: Colors.black,
      ),

      displaySmall: TextStyle(
        fontSize: 22 * scale,
        fontWeight: FontWeight.w600,
        color: Colors.black,
      ),

      headlineLarge: TextStyle(
        fontSize: 20 * scale,
        fontWeight: FontWeight.w700,
        color: Colors.black,
      ),

      headlineMedium: TextStyle(
        fontSize: 18 * scale,
        fontWeight: FontWeight.w600,
        color: Colors.black,
      ),

      headlineSmall: TextStyle(
        fontSize: 16 * scale,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),

      bodyLarge: TextStyle(
        fontSize: 16 * scale,
        fontWeight: FontWeight.w500,
        color: Colors.black87,
      ),

      bodyMedium: TextStyle(
        fontSize: 14 * scale,
        fontWeight: FontWeight.normal,
        color: Colors.black54,
      ),

      bodySmall: TextStyle(
        fontSize: 12 * scale,
        fontWeight: FontWeight.normal,
        color: Colors.black45,
      ),

      labelLarge: TextStyle(
        fontSize: 16 * scale,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    );
  }
}
