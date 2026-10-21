import 'dart:ui';

import 'package:flutter/material.dart';

Color textColor = const Color(0xff875FD2);

Color loginButtonLeft = const Color(0xFF885FD2);
Color loginButtonRight = const Color(0xFF493BB8);
Color dropdown = const Color(0xFF2BA079);
const Color primaryColor = Color.fromRGBO(255, 213, 59, 1.0);

Color buttonColor = const Color.fromARGB(229, 233, 176, 4);

Color launcherLeft = const Color(0xFF5C23C3);
Color launcherRight = const Color(0xFF9048d7);
Color whiteColor = Colors.white;
Color blackColor = Colors.black;
Color redColor = Colors.red;
Color greyColor = Colors.grey;
Color lightblackColor = Colors.black.withOpacity(0.1);
Color bulletColor1 = const Color(0xFFB52776);
Color selectedCountryColor = const Color(0xFF875FD2);
Color statutsBox = const Color(0xFFdb94bc);
Color liveText = const Color(0xFFb12876);
Color pauseBox = const Color(0xFFf7bf90);
Color statusText = const Color(0xFFf17f20);
Color blueArc = const Color(0xFF396AF0);

LinearGradient loginButton = LinearGradient(
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
  colors: [loginButtonLeft, loginButtonRight],
);

LinearGradient topUpButton = LinearGradient(
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
  colors: [loginButtonRight, loginButtonLeft],
);

LinearGradient launchScreen = LinearGradient(
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
  colors: [launcherLeft, launcherRight],
);

LinearGradient followersBox = LinearGradient(
  begin: Alignment.bottomLeft,
  end: Alignment.topRight,
  colors: [Color(0xFF00E0FF), Color(0xFF0049FF)],
);

final commentBox = LinearGradient(
  colors: [Color(0xFF00FFB2), Color(0xFF00BD4C)],
  begin: Alignment.bottomLeft,
  end: Alignment.topRight,
);

final sharesBox = LinearGradient(
  colors: [Color(0xFFFFE500), Color(0xFFF07F20)],
  begin: Alignment.bottomLeft,
  end: Alignment.topRight,
);

final spentBox = LinearGradient(
  colors: [Color(0xFFE36363), Color(0xFFFF7AC4)],
  begin: Alignment.bottomLeft,
  end: Alignment.topRight,
);

final graphColor = LinearGradient(
  colors: [whiteColor, Color.fromARGB(255, 34, 170, 125)],
  begin: Alignment.bottomCenter,
  end: Alignment.topCenter,
);

const whiteBubbleColor = Colors.white;
final purpleGradient = LinearGradient(
  colors: [Color(0xFF6A5AE0), Color(0xFF9C6FE4)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

LinearGradient disabledGradient = LinearGradient(
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
  colors: [launcherLeft.withOpacity(0.4), launcherRight.withOpacity(0.4)],
);

LinearGradient buildThemeGradient(
  BuildContext context, {
  required bool isPrimary,
}) {
  final cs = Theme.of(context).colorScheme;
  final isDark = Theme.of(context).brightness == Brightness.dark;

  if (!isPrimary) {
    return const LinearGradient(
      colors: [Colors.transparent, Colors.transparent],
    );
  }

  return isDark
      ? LinearGradient(
        colors: [cs.primary, cs.primaryContainer],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      )
      : const LinearGradient(
        colors: [Color(0xFFFFA726), Color(0xFFFFC107)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
}

// ============================================================================
// Kumbh Path design system: semantic color tokens
// ============================================================================
//
// Everything above this banner is the legacy palette. It is kept unchanged so
// existing screens keep compiling; do not use it in new or redesigned code.
//
// New code reads colors from the theme, never from these constants directly:
//   Theme.of(context).colorScheme   (or context.colorScheme)
//       -> brand, surface, outline and error roles
//   Theme.of(context).extension<AppSemanticColors>()!   (or context.semanticColors)
//       -> success / warning / info / gold, borders, dividers and
//          card / input / dialog / navigation surfaces
//
// [AppColors.light] and [AppColors.dark] are the single source of truth both
// of those are generated from (see design_system/app_theme.dart).

/// Raw brand hues. Reference only: prefer the semantic roles in
/// [AppColorTokens] so light and dark appearances both stay correct.
abstract final class AppPalette {
  /// Deep saffron, the bhagwa of temple flags at the ghats.
  static const Color saffron = Color(0xFFB4510C);
  static const Color saffronLight = Color(0xFFFFB37A);

  /// Sacred vermilion (sindoor / kumkum).
  static const Color vermilion = Color(0xFFA3311D);
  static const Color vermilionLight = Color(0xFFFFB4A6);

  /// Muted antique gold (temple kalash, brass diyas).
  static const Color antiqueGold = Color(0xFF7A5C14);
  static const Color antiqueGoldLight = Color(0xFFE1C27A);

  /// Godavari river blue, used for informational states.
  static const Color godavari = Color(0xFF2B6390);
  static const Color godavariLight = Color(0xFF9CCBF2);

  /// Warm ivory and earthy neutrals.
  static const Color ivory = Color(0xFFFBF7EF);
  static const Color sandstone = Color(0xFFDDD3C4);
  static const Color earth = Color(0xFF5A5045);
  static const Color charcoal = Color(0xFF15120F);
}

/// One complete set of semantic color roles for a single appearance.
///
/// Material roles (primary, surface, outline, ...) become a [ColorScheme] via
/// [toColorScheme]. Roles Material does not model (success, warning, info,
/// gold accent, component surfaces) are exposed through `AppSemanticColors`
/// in design_system/app_theme_extensions.dart.
@immutable
class AppColorTokens {
  const AppColorTokens({
    required this.brightness,
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.secondary,
    required this.onSecondary,
    required this.secondaryContainer,
    required this.onSecondaryContainer,
    required this.tertiary,
    required this.onTertiary,
    required this.tertiaryContainer,
    required this.onTertiaryContainer,
    required this.background,
    required this.surface,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.surfaceContainerLowest,
    required this.surfaceContainerLow,
    required this.surfaceContainer,
    required this.surfaceContainerHigh,
    required this.surfaceContainerHighest,
    required this.inverseSurface,
    required this.onInverseSurface,
    required this.inversePrimary,
    required this.outline,
    required this.outlineVariant,
    required this.border,
    required this.divider,
    required this.error,
    required this.onError,
    required this.errorContainer,
    required this.onErrorContainer,
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.info,
    required this.onInfo,
    required this.infoContainer,
    required this.onInfoContainer,
    required this.gold,
    required this.onGold,
    required this.cardSurface,
    required this.inputFill,
    required this.dialogSurface,
    required this.navigationSurface,
    required this.navigationIndicator,
    required this.onImage,
    required this.imageScrim,
    required this.shadow,
    required this.scrim,
  });

  final Brightness brightness;

  // Brand
  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color secondary;
  final Color onSecondary;
  final Color secondaryContainer;
  final Color onSecondaryContainer;
  final Color tertiary;
  final Color onTertiary;
  final Color tertiaryContainer;
  final Color onTertiaryContainer;

  // Surfaces and foreground
  /// Page / scaffold background.
  final Color background;
  final Color surface;
  final Color onSurface;

  /// Secondary text, captions and inactive icons.
  final Color onSurfaceVariant;
  final Color surfaceContainerLowest;
  final Color surfaceContainerLow;
  final Color surfaceContainer;
  final Color surfaceContainerHigh;
  final Color surfaceContainerHighest;
  final Color inverseSurface;
  final Color onInverseSurface;
  final Color inversePrimary;

  // Lines
  /// Strong outline for focused / interactive boundaries.
  final Color outline;

  /// Subtle outline for decorative boundaries.
  final Color outlineVariant;

  /// Default resting border for cards, inputs and chips.
  final Color border;
  final Color divider;

  // Status
  final Color error;
  final Color onError;
  final Color errorContainer;
  final Color onErrorContainer;
  final Color success;
  final Color onSuccess;
  final Color successContainer;
  final Color onSuccessContainer;
  final Color warning;
  final Color onWarning;
  final Color warningContainer;
  final Color onWarningContainer;
  final Color info;
  final Color onInfo;
  final Color infoContainer;
  final Color onInfoContainer;

  // Accent
  /// Restrained antique-gold accent for highlights and badges. Not for large
  /// fills.
  final Color gold;
  final Color onGold;

  // Component surfaces
  final Color cardSurface;
  final Color inputFill;
  final Color dialogSurface;
  final Color navigationSurface;
  final Color navigationIndicator;

  // Imagery
  /// Text and icons placed over photography, always on top of [imageScrim].
  final Color onImage;

  /// Base color of the gradient laid over photos so [onImage] content stays
  /// legible regardless of the picture. Apply with partial opacity.
  final Color imageScrim;

  final Color shadow;
  final Color scrim;

  ColorScheme toColorScheme() => ColorScheme(
    brightness: brightness,
    primary: primary,
    onPrimary: onPrimary,
    primaryContainer: primaryContainer,
    onPrimaryContainer: onPrimaryContainer,
    secondary: secondary,
    onSecondary: onSecondary,
    secondaryContainer: secondaryContainer,
    onSecondaryContainer: onSecondaryContainer,
    tertiary: tertiary,
    onTertiary: onTertiary,
    tertiaryContainer: tertiaryContainer,
    onTertiaryContainer: onTertiaryContainer,
    error: error,
    onError: onError,
    errorContainer: errorContainer,
    onErrorContainer: onErrorContainer,
    surface: surface,
    onSurface: onSurface,
    onSurfaceVariant: onSurfaceVariant,
    surfaceContainerLowest: surfaceContainerLowest,
    surfaceContainerLow: surfaceContainerLow,
    surfaceContainer: surfaceContainer,
    surfaceContainerHigh: surfaceContainerHigh,
    surfaceContainerHighest: surfaceContainerHighest,
    surfaceTint: primary,
    inverseSurface: inverseSurface,
    onInverseSurface: onInverseSurface,
    inversePrimary: inversePrimary,
    outline: outline,
    outlineVariant: outlineVariant,
    shadow: shadow,
    scrim: scrim,
  );
}

/// The two designed appearances. Dark is a separately tuned palette of warm,
/// layered charcoals with restrained saffron and gold accents, not an
/// inversion of light.
abstract final class AppColors {
  static const AppColorTokens light = AppColorTokens(
    brightness: Brightness.light,
    primary: AppPalette.saffron,
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFFFE3CC),
    onPrimaryContainer: Color(0xFF3B1900),
    secondary: AppPalette.vermilion,
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFFFDAD3),
    onSecondaryContainer: Color(0xFF3F0400),
    tertiary: AppPalette.antiqueGold,
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFF6E3B4),
    onTertiaryContainer: Color(0xFF261A00),
    background: AppPalette.ivory,
    surface: Color(0xFFFFFCF7),
    onSurface: Color(0xFF1F1A14),
    onSurfaceVariant: AppPalette.earth,
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF8F2E8),
    surfaceContainer: Color(0xFFF3ECE1),
    surfaceContainerHigh: Color(0xFFEDE5D8),
    surfaceContainerHighest: Color(0xFFE7DECF),
    inverseSurface: Color(0xFF35302A),
    onInverseSurface: Color(0xFFF9F1E7),
    inversePrimary: AppPalette.saffronLight,
    outline: Color(0xFF8A7E70),
    outlineVariant: AppPalette.sandstone,
    border: Color(0xFFE3D9CA),
    divider: Color(0xFFEAE2D5),
    error: Color(0xFFB3261E),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFF9DEDC),
    onErrorContainer: Color(0xFF410E0B),
    success: Color(0xFF2A7148),
    onSuccess: Color(0xFFFFFFFF),
    successContainer: Color(0xFFD5F0DE),
    onSuccessContainer: Color(0xFF00210F),
    warning: Color(0xFF8A5A00),
    onWarning: Color(0xFFFFFFFF),
    warningContainer: Color(0xFFFFE6B8),
    onWarningContainer: Color(0xFF2B1A00),
    info: AppPalette.godavari,
    onInfo: Color(0xFFFFFFFF),
    infoContainer: Color(0xFFD4E6F7),
    onInfoContainer: Color(0xFF001D33),
    gold: AppPalette.antiqueGold,
    onGold: Color(0xFFFFFFFF),
    cardSurface: Color(0xFFFFFFFF),
    inputFill: Color(0xFFF8F2E8),
    dialogSurface: Color(0xFFFFFCF7),
    navigationSurface: Color(0xFFFFFCF7),
    navigationIndicator: Color(0xFFFFE3CC),
    onImage: Color(0xFFFFFBF5),
    imageScrim: Color(0xFF1A120B),
    shadow: Color(0xFF3B2A17),
    scrim: Color(0xFF000000),
  );

  static const AppColorTokens dark = AppColorTokens(
    brightness: Brightness.dark,
    primary: AppPalette.saffronLight,
    onPrimary: Color(0xFF4A2100),
    primaryContainer: Color(0xFF6E3407),
    onPrimaryContainer: Color(0xFFFFDCC4),
    secondary: AppPalette.vermilionLight,
    onSecondary: Color(0xFF5F150A),
    secondaryContainer: Color(0xFF7E2818),
    onSecondaryContainer: Color(0xFFFFDAD3),
    tertiary: AppPalette.antiqueGoldLight,
    onTertiary: Color(0xFF3E2E00),
    tertiaryContainer: Color(0xFF574306),
    onTertiaryContainer: Color(0xFFFEDF9A),
    background: AppPalette.charcoal,
    surface: Color(0xFF181511),
    onSurface: Color(0xFFEDE5DA),
    onSurfaceVariant: Color(0xFFC9BEB0),
    surfaceContainerLowest: Color(0xFF100D0B),
    surfaceContainerLow: Color(0xFF1E1A16),
    surfaceContainer: Color(0xFF231F1A),
    surfaceContainerHigh: Color(0xFF2D2822),
    surfaceContainerHighest: Color(0xFF38322B),
    inverseSurface: Color(0xFFEDE5DA),
    onInverseSurface: Color(0xFF35302A),
    inversePrimary: AppPalette.saffron,
    outline: Color(0xFF9A8F82),
    outlineVariant: Color(0xFF4A433B),
    border: Color(0xFF3B352E),
    divider: Color(0xFF2F2A24),
    error: Color(0xFFF2B8B5),
    onError: Color(0xFF601410),
    errorContainer: Color(0xFF8C1D18),
    onErrorContainer: Color(0xFFF9DEDC),
    success: Color(0xFF86D4A5),
    onSuccess: Color(0xFF00391D),
    successContainer: Color(0xFF14512F),
    onSuccessContainer: Color(0xFFD5F0DE),
    warning: Color(0xFFF2C46D),
    onWarning: Color(0xFF452B00),
    warningContainer: Color(0xFF634000),
    onWarningContainer: Color(0xFFFFE6B8),
    info: AppPalette.godavariLight,
    onInfo: Color(0xFF00324F),
    infoContainer: Color(0xFF184A70),
    onInfoContainer: Color(0xFFD4E6F7),
    gold: AppPalette.antiqueGoldLight,
    onGold: Color(0xFF3E2E00),
    cardSurface: Color(0xFF1E1A16),
    inputFill: Color(0xFF231F1A),
    dialogSurface: Color(0xFF231F1A),
    navigationSurface: Color(0xFF1E1A16),
    navigationIndicator: Color(0xFF6E3407),
    onImage: Color(0xFFFFFBF5),
    imageScrim: Color(0xFF0B0806),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
  );

  static AppColorTokens of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;
}
