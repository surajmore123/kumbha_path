import 'package:flutter/material.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';

enum AppCardVariant {
  /// Card surface with a hairline border. The default.
  outlined,

  /// Tonal surface, no border. For grouped content inside other surfaces.
  filled,

  /// Card surface with a soft warm shadow. Use sparingly for hero content.
  elevated,
}

/// Standard surface container. Imposes no layout on [child]; only surface
/// color, border, radius, padding, elevation and tap feedback.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.variant = AppCardVariant.outlined,
    this.padding = AppSpacing.card,
    this.margin,
    this.onTap,
    this.onLongPress,
    this.borderRadius = AppRadius.cardAll,
    this.color,
    this.semanticLabel,
  });

  final Widget child;
  final AppCardVariant variant;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;

  /// Makes the whole card tappable with ink feedback.
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final BorderRadius borderRadius;

  /// Override for tinted cards, e.g. `colorScheme.primaryContainer` or a
  /// semantic container color. Must come from the theme.
  final Color? color;

  /// Read by screen readers when the card is tappable.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final semantic = context.semanticColors;

    final background =
        color ??
        switch (variant) {
          AppCardVariant.filled => colors.surfaceContainerLow,
          _ => semantic.cardSurface,
        };
    final side =
        variant == AppCardVariant.outlined
            ? BorderSide(color: semantic.border)
            : BorderSide.none;
    final shadows =
        variant == AppCardVariant.elevated
            ? AppElevation.shadow(2, context.theme.brightness)
            : const <BoxShadow>[];

    final interactive = onTap != null || onLongPress != null;
    Widget content = Padding(padding: padding, child: child);
    if (interactive) {
      content = InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: borderRadius,
        child: content,
      );
    }

    Widget card = DecoratedBox(
      decoration: BoxDecoration(borderRadius: borderRadius, boxShadow: shadows),
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(borderRadius: borderRadius, side: side),
        clipBehavior: Clip.antiAlias,
        child: content,
      ),
    );

    if (interactive) {
      card = Semantics(
        button: onTap != null,
        label: semanticLabel,
        child: card,
      );
    }
    if (margin != null) card = Padding(padding: margin!, child: card);
    return card;
  }
}
