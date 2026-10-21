import 'package:flutter/material.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';

enum AppButtonVariant {
  /// Solid saffron. One per screen region, for the main action.
  primary,

  /// Soft saffron tint. Supporting actions that still need emphasis.
  secondary,

  /// Bordered, transparent. Alternative or cancel actions.
  outlined,
}

/// The app's standard text button.
///
/// Size, padding, radius and label style come from the button themes in
/// [AppTheme]; this widget only picks the variant colors from the
/// [ColorScheme]. Labels wrap instead of overflowing, so long Hindi / Marathi
/// text and large font scales stay readable.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.leadingIcon,
    this.trailingIcon,
    this.isLoading = false,
    this.expand = true,
    this.semanticsLabel,
  });

  const AppButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.leadingIcon,
    this.trailingIcon,
    this.isLoading = false,
    this.expand = true,
    this.semanticsLabel,
  }) : variant = AppButtonVariant.secondary;

  const AppButton.outlined({
    super.key,
    required this.label,
    required this.onPressed,
    this.leadingIcon,
    this.trailingIcon,
    this.isLoading = false,
    this.expand = true,
    this.semanticsLabel,
  }) : variant = AppButtonVariant.outlined;

  final String label;

  /// `null` disables the button.
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? leadingIcon;
  final IconData? trailingIcon;

  /// Shows a spinner in place of the leading icon and ignores taps, while
  /// keeping the enabled colors so the button doesn't flash grey.
  final bool isLoading;

  /// `true` fills the available width; `false` sizes to the content.
  final bool expand;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final (Color background, Color foreground) = switch (variant) {
      AppButtonVariant.primary => (colors.primary, colors.onPrimary),
      AppButtonVariant.secondary => (
        colors.primaryContainer,
        colors.onPrimaryContainer,
      ),
      AppButtonVariant.outlined => (Colors.transparent, colors.primary),
    };

    final enabled = onPressed != null && !isLoading;
    ButtonStyle? loadingStyle;
    if (isLoading) {
      loadingStyle = ButtonStyle(
        backgroundColor: WidgetStatePropertyAll(background),
        foregroundColor: WidgetStatePropertyAll(foreground),
        side:
            variant == AppButtonVariant.outlined
                ? WidgetStatePropertyAll(BorderSide(color: colors.outline))
                : null,
      );
    }

    final child = _ButtonContent(
      label: label,
      leadingIcon: leadingIcon,
      trailingIcon: trailingIcon,
      isLoading: isLoading,
      foreground: foreground,
      semanticsLabel: semanticsLabel,
    );
    final callback = enabled ? onPressed : null;

    final Widget button = switch (variant) {
      AppButtonVariant.primary => FilledButton(
        onPressed: callback,
        style: loadingStyle,
        child: child,
      ),
      AppButtonVariant.secondary => FilledButton.tonal(
        onPressed: callback,
        style: FilledButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
        ).merge(loadingStyle),
        child: child,
      ),
      AppButtonVariant.outlined => OutlinedButton(
        onPressed: callback,
        style: loadingStyle,
        child: child,
      ),
    };

    return SizedBox(width: expand ? double.infinity : null, child: button);
  }
}

class _ButtonContent extends StatelessWidget {
  const _ButtonContent({
    required this.label,
    required this.leadingIcon,
    required this.trailingIcon,
    required this.isLoading,
    required this.foreground,
    required this.semanticsLabel,
  });

  final String label;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final bool isLoading;
  final Color foreground;
  final String? semanticsLabel;

  static const double _iconSize = 20;

  @override
  Widget build(BuildContext context) {
    final Widget? leading =
        isLoading
            ? SizedBox.square(
              dimension: _iconSize,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: foreground,
              ),
            )
            : leadingIcon != null
            ? Icon(leadingIcon, size: _iconSize)
            : null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (leading != null) ...[leading, AppSpacing.gapSm],
        Flexible(
          child: Text(
            label,
            semanticsLabel: semanticsLabel,
            textAlign: TextAlign.center,
            softWrap: true,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (trailingIcon != null) ...[
          AppSpacing.gapSm,
          Icon(trailingIcon, size: _iconSize),
        ],
      ],
    );
  }
}
