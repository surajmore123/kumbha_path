import 'package:flutter/material.dart';

/// Restrained elevation levels.
///
/// Kumbh Path separates surfaces mainly with tone (surfaceContainer*) and
/// borders, not heavy shadows. Use Material elevation values for Material
/// widgets and [shadow] for custom containers that need a soft lift.
abstract final class AppElevation {
  static const double level0 = 0;
  static const double level1 = 1;
  static const double level2 = 3;
  static const double level3 = 6;

  // Component aliases
  static const double card = level0;
  static const double appBar = level0;
  static const double appBarScrolledUnder = level1;
  static const double navigationBar = level0;
  static const double button = level0;
  static const double fab = level2;
  static const double menu = level2;
  static const double dialog = level3;
  static const double bottomSheet = level1;

  /// Soft, warm shadow for custom surfaces at [level] (0-3).
  ///
  /// Light mode uses a low-opacity warm brown so shadows don't look grey on
  /// ivory; dark mode relies on tonal surfaces and keeps shadows minimal.
  static List<BoxShadow> shadow(int level, Brightness brightness) {
    if (level <= 0) return const [];
    final isDark = brightness == Brightness.dark;
    final color = isDark ? const Color(0xFF000000) : const Color(0xFF3B2A17);
    switch (level) {
      case 1:
        return [
          BoxShadow(
            color: color.withValues(alpha: isDark ? 0.24 : 0.06),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ];
      case 2:
        return [
          BoxShadow(
            color: color.withValues(alpha: isDark ? 0.28 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ];
      default:
        return [
          BoxShadow(
            color: color.withValues(alpha: isDark ? 0.32 : 0.10),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ];
    }
  }
}
