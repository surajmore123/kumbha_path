import 'package:flutter/material.dart';
import 'package:kumbha_path/src/constant/design_system/app_theme_extensions.dart';
import 'package:kumbha_path/src/constant/design_system/app_typography.dart';

/// Editorial typography for long-form and journal screens (Kumbh Patrika).
///
/// Built from the theme's colours and the [AppTypography] scale, so light,
/// dark and font-size preferences all apply. Use `context.editorial` for
/// headlines and reading text; use `context.textTheme` for everything else.
/// Tiro Devanagari is a true serif for Latin and Devanagari alike, and the
/// family follows the language so Marathi keeps its own letterforms.
@immutable
class AppEditorial {
  const AppEditorial._({
    required this.masthead,
    required this.lead,
    required this.headline,
    required this.title,
    required this.quote,
    required this.kicker,
    required this.dek,
    required this.reading,
    required this.meta,
  });

  /// Journal name at the top of a screen.
  final TextStyle masthead;

  /// The one lead story or article title on a screen.
  final TextStyle lead;

  /// Section headings and secondary stories.
  final TextStyle headline;

  /// Compact story titles.
  final TextStyle title;

  /// Pull quotes and large display terms.
  final TextStyle quote;

  /// Small category label above a headline.
  final TextStyle kicker;

  /// The line under a headline, and an article's opening paragraph.
  final TextStyle dek;

  /// Long reading text.
  final TextStyle reading;

  /// Publisher, date and other small facts.
  final TextStyle meta;

  factory AppEditorial.of(BuildContext context) {
    final colors = context.colorScheme;
    final family =
        Localizations.localeOf(context).languageCode == 'mr'
            ? 'TiroMarathi'
            : 'TiroHindi';

    TextStyle serif(double size, double height, Color color) => TextStyle(
      fontFamily: family,
      fontSize: size,
      height: height,
      color: color,
      fontWeight: FontWeight.w400,
      leadingDistribution: TextLeadingDistribution.even,
    );

    final strong = colors.onSurface;
    final muted = colors.onSurfaceVariant;
    return AppEditorial._(
      masthead: serif(AppTypography.displaySmallSize, 1.25, strong),
      lead: serif(AppTypography.headlineLargeSize, 1.3, strong),
      headline: serif(AppTypography.headlineSmallSize, 1.35, strong),
      title: serif(AppTypography.titleLargeSize - 2, 1.4, strong),
      quote: serif(AppTypography.headlineSmallSize, 1.45, strong),
      kicker: TextStyle(
        fontSize: AppTypography.labelMediumSize,
        height: 1.4,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: colors.primary,
      ),
      dek: serif(AppTypography.titleLargeSize - 2, 1.55, muted),
      reading: TextStyle(
        fontSize: AppTypography.bodyLargeSize + 1,
        height: 1.75,
        color: strong,
      ),
      meta: TextStyle(
        fontSize: AppTypography.labelMediumSize,
        height: 1.4,
        color: muted,
      ),
    );
  }
}

extension AppEditorialContext on BuildContext {
  AppEditorial get editorial => AppEditorial.of(this);
}
