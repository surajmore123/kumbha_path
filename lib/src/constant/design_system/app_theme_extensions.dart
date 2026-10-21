import 'package:flutter/material.dart';
import 'package:kumbha_path/src/constant/app_color.dart';

/// Semantic colors that [ColorScheme] does not model.
///
/// Registered on both themes by [AppTheme], so it is always present:
/// `Theme.of(context).extension<AppSemanticColors>()!` or
/// `context.semanticColors`.
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
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
    required this.background,
    required this.border,
    required this.divider,
    required this.cardSurface,
    required this.inputFill,
    required this.dialogSurface,
    required this.navigationSurface,
    required this.navigationIndicator,
    required this.onImage,
    required this.imageScrim,
  });

  factory AppSemanticColors.fromTokens(AppColorTokens t) => AppSemanticColors(
    success: t.success,
    onSuccess: t.onSuccess,
    successContainer: t.successContainer,
    onSuccessContainer: t.onSuccessContainer,
    warning: t.warning,
    onWarning: t.onWarning,
    warningContainer: t.warningContainer,
    onWarningContainer: t.onWarningContainer,
    info: t.info,
    onInfo: t.onInfo,
    infoContainer: t.infoContainer,
    onInfoContainer: t.onInfoContainer,
    gold: t.gold,
    onGold: t.onGold,
    background: t.background,
    border: t.border,
    divider: t.divider,
    cardSurface: t.cardSurface,
    inputFill: t.inputFill,
    dialogSurface: t.dialogSurface,
    navigationSurface: t.navigationSurface,
    navigationIndicator: t.navigationIndicator,
    onImage: t.onImage,
    imageScrim: t.imageScrim,
  );

  static final AppSemanticColors light = AppSemanticColors.fromTokens(
    AppColors.light,
  );
  static final AppSemanticColors dark = AppSemanticColors.fromTokens(
    AppColors.dark,
  );

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
  final Color gold;
  final Color onGold;
  final Color background;
  final Color border;
  final Color divider;
  final Color cardSurface;
  final Color inputFill;
  final Color dialogSurface;
  final Color navigationSurface;
  final Color navigationIndicator;
  final Color onImage;
  final Color imageScrim;

  @override
  AppSemanticColors copyWith({
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? warning,
    Color? onWarning,
    Color? warningContainer,
    Color? onWarningContainer,
    Color? info,
    Color? onInfo,
    Color? infoContainer,
    Color? onInfoContainer,
    Color? gold,
    Color? onGold,
    Color? background,
    Color? border,
    Color? divider,
    Color? cardSurface,
    Color? inputFill,
    Color? dialogSurface,
    Color? navigationSurface,
    Color? navigationIndicator,
    Color? onImage,
    Color? imageScrim,
  }) {
    return AppSemanticColors(
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      successContainer: successContainer ?? this.successContainer,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
      info: info ?? this.info,
      onInfo: onInfo ?? this.onInfo,
      infoContainer: infoContainer ?? this.infoContainer,
      onInfoContainer: onInfoContainer ?? this.onInfoContainer,
      gold: gold ?? this.gold,
      onGold: onGold ?? this.onGold,
      background: background ?? this.background,
      border: border ?? this.border,
      divider: divider ?? this.divider,
      cardSurface: cardSurface ?? this.cardSurface,
      inputFill: inputFill ?? this.inputFill,
      dialogSurface: dialogSurface ?? this.dialogSurface,
      navigationSurface: navigationSurface ?? this.navigationSurface,
      navigationIndicator: navigationIndicator ?? this.navigationIndicator,
      onImage: onImage ?? this.onImage,
      imageScrim: imageScrim ?? this.imageScrim,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppSemanticColors(
      success: mix(success, other.success),
      onSuccess: mix(onSuccess, other.onSuccess),
      successContainer: mix(successContainer, other.successContainer),
      onSuccessContainer: mix(onSuccessContainer, other.onSuccessContainer),
      warning: mix(warning, other.warning),
      onWarning: mix(onWarning, other.onWarning),
      warningContainer: mix(warningContainer, other.warningContainer),
      onWarningContainer: mix(onWarningContainer, other.onWarningContainer),
      info: mix(info, other.info),
      onInfo: mix(onInfo, other.onInfo),
      infoContainer: mix(infoContainer, other.infoContainer),
      onInfoContainer: mix(onInfoContainer, other.onInfoContainer),
      gold: mix(gold, other.gold),
      onGold: mix(onGold, other.onGold),
      background: mix(background, other.background),
      border: mix(border, other.border),
      divider: mix(divider, other.divider),
      cardSurface: mix(cardSurface, other.cardSurface),
      inputFill: mix(inputFill, other.inputFill),
      dialogSurface: mix(dialogSurface, other.dialogSurface),
      navigationSurface: mix(navigationSurface, other.navigationSurface),
      navigationIndicator: mix(navigationIndicator, other.navigationIndicator),
      onImage: mix(onImage, other.onImage),
      imageScrim: mix(imageScrim, other.imageScrim),
    );
  }
}

/// Short accessors for design-system values from any [BuildContext].
extension AppThemeContext on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  TextTheme get textTheme => Theme.of(this).textTheme;

  AppSemanticColors get semanticColors =>
      Theme.of(this).extension<AppSemanticColors>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? AppSemanticColors.dark
          : AppSemanticColors.light);

  bool get isDarkTheme => Theme.of(this).brightness == Brightness.dark;
}
