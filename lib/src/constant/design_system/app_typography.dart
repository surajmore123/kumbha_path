import 'package:flutter/material.dart';

/// User-selectable font-size preference.
///
/// These are *font* multipliers. They never scale icons, spacing, radii or
/// layout, and they compose with (never replace) the device's accessibility
/// text size.
enum AppFontScale {
  small(0.90),
  standard(1.00),
  large(1.15);

  const AppFontScale(this.factor);

  final double factor;

  static const AppFontScale fallback = AppFontScale.standard;

  /// Parses a persisted value. Unknown or missing values fall back to
  /// [AppFontScale.standard].
  static AppFontScale fromName(String? name) {
    for (final scale in values) {
      if (scale.name == name) return scale;
    }
    return fallback;
  }
}

/// Central type scale.
///
/// ## Font-scale contract (read before styling text)
///
/// * Sizes here are **unscaled base sizes**. The user's [AppFontScale] is
///   applied exactly once, globally, by [AppFontScaleScope] (installed in
///   `MaterialApp.builder`), which composes it with the device text scaler in
///   `MediaQuery.textScaler`. Every `Text`, `TextField`, button label, dialog
///   and navigation label therefore scales automatically.
/// * Screens must take styles from `Theme.of(context).textTheme` (or
///   `context.textTheme`) and adjust with `copyWith(fontWeight:/color:)`.
/// * Never multiply a font size by the font scale or by screen width
///   yourself; that would apply the preference twice.
/// * Never override `MediaQuery.textScaler` in a feature screen.
/// * Line heights are ratios ([TextStyle.height]), so the hierarchy and
///   rhythm hold at every scale.
abstract final class AppTypography {
  /// `null` uses the platform font (Roboto / SF), whose system fallbacks
  /// render Devanagari for Hindi and Marathi.
  static const String? fontFamily = null;

  // Base sizes (logical pixels, before any scaling).
  static const double displayLargeSize = 48;
  static const double displayMediumSize = 40;
  static const double displaySmallSize = 34;
  static const double headlineLargeSize = 30;
  static const double headlineMediumSize = 26;
  static const double headlineSmallSize = 22;
  static const double titleLargeSize = 20;
  static const double titleMediumSize = 16;
  static const double titleSmallSize = 14;
  static const double bodyLargeSize = 16;
  static const double bodyMediumSize = 14;
  static const double bodySmallSize = 12;
  static const double labelLargeSize = 14;
  static const double labelMediumSize = 12;
  static const double labelSmallSize = 11;

  /// Builds the app [TextTheme] with foreground colors from [colors].
  ///
  /// Line heights are slightly more generous than Material defaults so
  /// Devanagari matras and conjuncts are not clipped.
  static TextTheme textTheme(ColorScheme colors) {
    final strong = colors.onSurface;
    final muted = colors.onSurfaceVariant;

    TextStyle style(
      double size,
      double height,
      FontWeight weight,
      Color color, {
      double letterSpacing = 0,
    }) {
      return TextStyle(
        fontFamily: fontFamily,
        fontSize: size,
        height: height,
        fontWeight: weight,
        letterSpacing: letterSpacing,
        color: color,
        leadingDistribution: TextLeadingDistribution.even,
      );
    }

    return TextTheme(
      displayLarge: style(
        displayLargeSize,
        1.17,
        FontWeight.w700,
        strong,
        letterSpacing: -0.5,
      ),
      displayMedium: style(
        displayMediumSize,
        1.2,
        FontWeight.w700,
        strong,
        letterSpacing: -0.25,
      ),
      displaySmall: style(displaySmallSize, 1.24, FontWeight.w600, strong),
      headlineLarge: style(headlineLargeSize, 1.27, FontWeight.w700, strong),
      headlineMedium: style(headlineMediumSize, 1.3, FontWeight.w600, strong),
      headlineSmall: style(headlineSmallSize, 1.36, FontWeight.w600, strong),
      titleLarge: style(titleLargeSize, 1.4, FontWeight.w600, strong),
      titleMedium: style(
        titleMediumSize,
        1.5,
        FontWeight.w600,
        strong,
        letterSpacing: 0.1,
      ),
      titleSmall: style(
        titleSmallSize,
        1.45,
        FontWeight.w600,
        strong,
        letterSpacing: 0.1,
      ),
      bodyLarge: style(
        bodyLargeSize,
        1.55,
        FontWeight.w400,
        strong,
        letterSpacing: 0.15,
      ),
      bodyMedium: style(
        bodyMediumSize,
        1.5,
        FontWeight.w400,
        strong,
        letterSpacing: 0.15,
      ),
      bodySmall: style(
        bodySmallSize,
        1.45,
        FontWeight.w400,
        muted,
        letterSpacing: 0.2,
      ),
      labelLarge: style(
        labelLargeSize,
        1.45,
        FontWeight.w600,
        strong,
        letterSpacing: 0.1,
      ),
      labelMedium: style(
        labelMediumSize,
        1.4,
        FontWeight.w500,
        strong,
        letterSpacing: 0.3,
      ),
      labelSmall: style(
        labelSmallSize,
        1.4,
        FontWeight.w500,
        muted,
        letterSpacing: 0.4,
      ),
    );
  }

  /// Composes the user's [fontScale] onto the device [deviceScaler].
  ///
  /// Idempotent: if [deviceScaler] already carries an app font scale, it is
  /// replaced rather than multiplied again.
  static TextScaler resolveTextScaler(
    TextScaler deviceScaler,
    AppFontScale fontScale,
  ) {
    final base =
        deviceScaler is AppFontScaleTextScaler
            ? deviceScaler.deviceScaler
            : deviceScaler;
    if (fontScale.factor == 1.0) return base;
    return AppFontScaleTextScaler(base, fontScale.factor);
  }
}

/// A [TextScaler] that multiplies the device scaler (which may be nonlinear
/// on Android 14+) by the app font-scale factor.
@immutable
class AppFontScaleTextScaler extends TextScaler {
  const AppFontScaleTextScaler(this.deviceScaler, this.factor);

  final TextScaler deviceScaler;
  final double factor;

  @override
  double scale(double fontSize) => deviceScaler.scale(fontSize) * factor;

  /// Estimate kept only because [TextScaler] still declares it; derived from
  /// [scale] at body size so it never reads the deprecated member.
  @override
  double get textScaleFactor =>
      scale(AppTypography.bodyMediumSize) / AppTypography.bodyMediumSize;

  @override
  bool operator ==(Object other) =>
      other is AppFontScaleTextScaler &&
      other.deviceScaler == deviceScaler &&
      other.factor == factor;

  @override
  int get hashCode => Object.hash(deviceScaler, factor);

  @override
  String toString() => 'AppFontScaleTextScaler($deviceScaler × $factor)';
}

/// Applies the app font scale to everything below it.
///
/// Installed once in `MaterialApp.builder`. Feature screens must not add
/// another one.
class AppFontScaleScope extends StatelessWidget {
  const AppFontScaleScope({
    super.key,
    required this.fontScale,
    required this.child,
  });

  final AppFontScale fontScale;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return MediaQuery(
      data: mediaQuery.copyWith(
        textScaler: AppTypography.resolveTextScaler(
          mediaQuery.textScaler,
          fontScale,
        ),
      ),
      child: child ?? const SizedBox.shrink(),
    );
  }
}
