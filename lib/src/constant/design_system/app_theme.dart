import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kumbha_path/src/constant/app_color.dart';
import 'package:kumbha_path/src/constant/design_system/app_elevation.dart';
import 'package:kumbha_path/src/constant/design_system/app_radius.dart';
import 'package:kumbha_path/src/constant/design_system/app_spacing.dart';
import 'package:kumbha_path/src/constant/design_system/app_theme_extensions.dart';
import 'package:kumbha_path/src/constant/design_system/app_typography.dart';

/// Central [ThemeData] factory. `MaterialApp.theme` / `darkTheme` use
/// [light] and [dark]; nothing else in the app should construct ThemeData.
///
/// Themes are built from unscaled typography. The user's font-scale
/// preference is applied separately through `MediaQuery.textScaler`
/// (see [AppFontScaleScope]), so these objects never need rebuilding when it
/// changes.
abstract final class AppTheme {
  static final ThemeData light = _build(AppColors.light);
  static final ThemeData dark = _build(AppColors.dark);

  static ThemeData of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  /// Edge-to-edge system bars: transparent status bar with icons that
  /// contrast the theme, and a system navigation bar matching the surface
  /// beneath it ([navigationBarColor], e.g. the app's bottom navigation).
  static SystemUiOverlayStyle systemOverlayStyle(
    Brightness brightness, {
    Color? navigationBarColor,
  }) {
    final isDark = brightness == Brightness.dark;
    final icons = isDark ? Brightness.light : Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: icons,
      // iOS uses the opposite convention: brightness of the bar itself.
      statusBarBrightness: brightness,
      systemNavigationBarColor:
          navigationBarColor ?? AppColors.of(brightness).background,
      systemNavigationBarIconBrightness: icons,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
    );
  }

  static ThemeData _build(AppColorTokens t) {
    final colors = t.toColorScheme();
    final text = AppTypography.textTheme(colors);
    final semantic = AppSemanticColors.fromTokens(t);

    final buttonShape = RoundedRectangleBorder(
      borderRadius: AppRadius.buttonAll,
    );
    const buttonMinSize = Size(64, AppSpacing.minTouchTarget);
    final buttonText = text.labelLarge;

    OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: AppRadius.inputAll,
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: t.brightness,
      colorScheme: colors,
      fontFamily: AppTypography.fontFamily,
      textTheme: text,
      primaryTextTheme: AppTypography.textTheme(
        colors.copyWith(
          onSurface: colors.onPrimary,
          onSurfaceVariant: colors.onPrimary,
        ),
      ),
      scaffoldBackgroundColor: t.background,
      canvasColor: t.background,
      dividerColor: t.divider,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      extensions: <ThemeExtension<dynamic>>[semantic],

      iconTheme: IconThemeData(color: colors.onSurface, size: 24),
      primaryIconTheme: IconThemeData(color: colors.onPrimary, size: 24),

      appBarTheme: AppBarThemeData(
        backgroundColor: t.background,
        foregroundColor: colors.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: AppElevation.appBar,
        scrolledUnderElevation: AppElevation.appBarScrolledUnder,
        shadowColor: t.shadow.withValues(alpha: 0.12),
        centerTitle: false,
        titleTextStyle: text.titleLarge,
        toolbarTextStyle: text.bodyMedium,
        iconTheme: IconThemeData(color: colors.onSurface),
        actionsIconTheme: IconThemeData(color: colors.onSurfaceVariant),
        systemOverlayStyle: systemOverlayStyle(t.brightness),
      ),

      cardTheme: CardThemeData(
        color: t.cardSurface,
        surfaceTintColor: Colors.transparent,
        shadowColor: t.shadow,
        elevation: AppElevation.card,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardAll,
          side: BorderSide(color: t.border),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: t.divider,
        thickness: 1,
        space: AppSpacing.lg,
      ),

      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: t.inputFill,
        contentPadding: AppSpacing.input,
        hintStyle: text.bodyLarge?.copyWith(color: colors.onSurfaceVariant),
        labelStyle: text.bodyLarge?.copyWith(color: colors.onSurfaceVariant),
        floatingLabelStyle: text.bodyMedium?.copyWith(color: colors.primary),
        helperStyle: text.bodySmall,
        errorStyle: text.bodySmall?.copyWith(color: colors.error),
        prefixIconColor: colors.onSurfaceVariant,
        suffixIconColor: colors.onSurfaceVariant,
        border: inputBorder(t.border),
        enabledBorder: inputBorder(t.border),
        focusedBorder: inputBorder(colors.primary, 1.5),
        errorBorder: inputBorder(colors.error),
        focusedErrorBorder: inputBorder(colors.error, 1.5),
        disabledBorder: inputBorder(t.divider),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: buttonMinSize,
          padding: AppSpacing.button,
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          elevation: AppElevation.button,
          minimumSize: buttonMinSize,
          padding: AppSpacing.button,
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.primary,
          side: BorderSide(color: colors.outline),
          minimumSize: buttonMinSize,
          padding: AppSpacing.button,
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.primary,
          minimumSize: const Size(48, AppSpacing.minTouchTarget),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.primaryContainer,
        foregroundColor: colors.onPrimaryContainer,
        elevation: AppElevation.fab,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: colors.surfaceContainerLow,
        selectedColor: colors.primaryContainer,
        side: BorderSide(color: t.border),
        shape: const StadiumBorder(),
        labelStyle: text.labelLarge,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: t.dialogSurface,
        surfaceTintColor: Colors.transparent,
        elevation: AppElevation.dialog,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.dialogAll),
        titleTextStyle: text.headlineSmall,
        contentTextStyle: text.bodyMedium?.copyWith(
          color: colors.onSurfaceVariant,
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: t.dialogSurface,
        surfaceTintColor: Colors.transparent,
        elevation: AppElevation.bottomSheet,
        modalBackgroundColor: t.dialogSurface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheetTop),
        // Not forced on: several existing sheets draw their own handle.
        dragHandleColor: colors.outlineVariant,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(
          color: colors.onInverseSurface,
        ),
        actionTextColor: colors.inversePrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      ),

      listTileTheme: ListTileThemeData(
        iconColor: colors.onSurfaceVariant,
        textColor: colors.onSurface,
        titleTextStyle: text.bodyLarge,
        subtitleTextStyle: text.bodyMedium?.copyWith(
          color: colors.onSurfaceVariant,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: t.navigationSurface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: t.navigationIndicator,
        indicatorShape: const StadiumBorder(),
        elevation: AppElevation.navigationBar,
        height: 72,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => text.labelMedium?.copyWith(
            color:
                states.contains(WidgetState.selected)
                    ? colors.onSurface
                    : colors.onSurfaceVariant,
            fontWeight:
                states.contains(WidgetState.selected)
                    ? FontWeight.w600
                    : FontWeight.w500,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color:
                states.contains(WidgetState.selected)
                    ? colors.onPrimaryContainer
                    : colors.onSurfaceVariant,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: t.navigationSurface,
        indicatorColor: t.navigationIndicator,
        indicatorShape: const StadiumBorder(),
        elevation: AppElevation.navigationBar,
        minWidth: 88,
        selectedIconTheme: IconThemeData(color: colors.onPrimaryContainer),
        unselectedIconTheme: IconThemeData(color: colors.onSurfaceVariant),
        selectedLabelTextStyle: text.labelMedium?.copyWith(
          color: colors.onSurface,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: text.labelMedium?.copyWith(
          color: colors.onSurfaceVariant,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: t.navigationSurface,
        selectedItemColor: colors.primary,
        unselectedItemColor: colors.onSurfaceVariant,
        selectedLabelStyle: text.labelMedium,
        unselectedLabelStyle: text.labelMedium,
        elevation: AppElevation.navigationBar,
        type: BottomNavigationBarType.fixed,
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.primary,
        linearTrackColor: colors.surfaceContainerHighest,
        circularTrackColor: Colors.transparent,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected)
                  ? colors.onPrimary
                  : colors.outline,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected)
                  ? colors.primary
                  : colors.surfaceContainerHighest,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected)
                  ? Colors.transparent
                  : colors.outline,
        ),
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colors.inverseSurface,
          borderRadius: AppRadius.smAll,
        ),
        textStyle: text.bodySmall?.copyWith(color: colors.onInverseSurface),
      ),
    );
  }
}
