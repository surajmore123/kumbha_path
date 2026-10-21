import 'package:flutter/material.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';

enum AppIconButtonVariant {
  /// Icon only, no container. App bars, inline actions.
  standard,

  /// Soft tinted container. Floating over content or for emphasis.
  tonal,

  /// Solid saffron container. Rare, for a single key action.
  filled,

  /// Bordered container.
  outlined,
}

/// Icon button with a guaranteed 48 dp hit target and a required tooltip,
/// which doubles as the screen-reader label.
///
/// Icon sizes are fixed tokens and intentionally don't follow the font scale.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.variant = AppIconButtonVariant.standard,
    this.isSelected,
    this.selectedIcon,
    this.color,
  });

  final IconData icon;
  final String tooltip;

  /// `null` disables the button.
  final VoidCallback? onPressed;
  final AppIconButtonVariant variant;

  /// Set for toggle buttons (e.g. bookmark, mute).
  final bool? isSelected;
  final IconData? selectedIcon;

  /// Overrides the foreground for the [AppIconButtonVariant.standard]
  /// variant, e.g. icons placed on an image. Prefer theme colors.
  final Color? color;

  static const double iconSize = 24;
  static const BoxConstraints _constraints = BoxConstraints(
    minWidth: AppSpacing.minTouchTarget,
    minHeight: AppSpacing.minTouchTarget,
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final iconWidget = Icon(icon);
    final selected = selectedIcon != null ? Icon(selectedIcon) : null;

    switch (variant) {
      case AppIconButtonVariant.standard:
        return IconButton(
          icon: iconWidget,
          selectedIcon: selected,
          isSelected: isSelected,
          tooltip: tooltip,
          onPressed: onPressed,
          iconSize: iconSize,
          constraints: _constraints,
          color: color ?? colors.onSurfaceVariant,
        );
      case AppIconButtonVariant.tonal:
        return IconButton.filledTonal(
          icon: iconWidget,
          selectedIcon: selected,
          isSelected: isSelected,
          tooltip: tooltip,
          onPressed: onPressed,
          iconSize: iconSize,
          constraints: _constraints,
          style: IconButton.styleFrom(
            backgroundColor: colors.surfaceContainerHigh,
            foregroundColor: colors.onSurface,
          ),
        );
      case AppIconButtonVariant.filled:
        return IconButton.filled(
          icon: iconWidget,
          selectedIcon: selected,
          isSelected: isSelected,
          tooltip: tooltip,
          onPressed: onPressed,
          iconSize: iconSize,
          constraints: _constraints,
        );
      case AppIconButtonVariant.outlined:
        return IconButton.outlined(
          icon: iconWidget,
          selectedIcon: selected,
          isSelected: isSelected,
          tooltip: tooltip,
          onPressed: onPressed,
          iconSize: iconSize,
          constraints: _constraints,
          style: IconButton.styleFrom(
            foregroundColor: colors.onSurface,
            side: BorderSide(color: context.semanticColors.border),
          ),
        );
    }
  }
}
