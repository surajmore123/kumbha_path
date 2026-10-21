import 'package:flutter/widgets.dart';

/// Spacing scale for padding, margins and gaps (4-point grid).
///
/// Spacing is layout, not typography: it does not change with the user's
/// font-scale preference. Screen-size adaptations belong in
/// `app_responsive.dart`, not here.
abstract final class AppSpacing {
  static const double none = 0;
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 48;

  // Semantic aliases
  /// Horizontal page gutter on phones.
  static const double pageGutter = lg;

  /// Inner padding of cards and tiles.
  static const double cardPadding = lg;

  /// Gap between stacked sections of a screen.
  static const double sectionGap = xxl;

  /// Gap between related items in a list or row.
  static const double itemGap = md;

  /// Minimum interactive target (Material / WCAG guidance).
  static const double minTouchTarget = 48;

  // Ready-made insets
  static const EdgeInsets page = EdgeInsets.symmetric(horizontal: pageGutter);
  static const EdgeInsets card = EdgeInsets.all(cardPadding);
  static const EdgeInsets input = EdgeInsets.symmetric(
    horizontal: lg,
    vertical: md,
  );
  static const EdgeInsets button = EdgeInsets.symmetric(
    horizontal: xxl,
    vertical: md,
  );

  // Gap widgets for Rows / Columns
  static const SizedBox gapXs = SizedBox(width: xs, height: xs);
  static const SizedBox gapSm = SizedBox(width: sm, height: sm);
  static const SizedBox gapMd = SizedBox(width: md, height: md);
  static const SizedBox gapLg = SizedBox(width: lg, height: lg);
  static const SizedBox gapXl = SizedBox(width: xl, height: xl);
  static const SizedBox gapXxl = SizedBox(width: xxl, height: xxl);
}
