import 'package:flutter/material.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';

/// Title row for a content section ("Nearby Temples", "Upcoming Snans")
/// with an optional subtitle and trailing action such as "See all".
class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.trailing,
    this.padding = EdgeInsets.zero,
  }) : assert(
         trailing == null || actionLabel == null,
         'Provide either trailing or actionLabel, not both.',
       );

  final String title;
  final String? subtitle;

  /// Text action shown at the end, e.g. "See all".
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Custom trailing widget instead of [actionLabel].
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final text = context.textTheme;
    final colors = context.colorScheme;

    Widget? end = trailing;
    if (end == null && actionLabel != null) {
      end = TextButton(onPressed: onAction, child: Text(actionLabel!));
    }

    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  header: true,
                  child: Text(title, style: text.titleLarge),
                ),
                if (subtitle != null) ...[
                  AppSpacing.gapXs,
                  Text(
                    subtitle!,
                    style: text.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (end != null) ...[AppSpacing.gapSm, end],
        ],
      ),
    );
  }
}
