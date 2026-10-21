import 'package:flutter/material.dart';
import 'package:kumbha_path/src/components/buttons/app_button.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';

/// Shared layout for [AppErrorView] and [AppEmptyState]: a tinted icon,
/// a title, an optional message and an optional action, centered and
/// scrollable so long translations and large font scales never overflow.
class AppStatusView extends StatelessWidget {
  const AppStatusView({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.actionIcon,
    this.compact = false,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? actionIcon;

  /// Smaller icon and padding for use inside a card or section.
  final bool compact;

  static const double _maxContentWidth = 420;

  @override
  Widget build(BuildContext context) {
    final text = context.textTheme;
    final colors = context.colorScheme;
    final badge = compact ? 56.0 : 72.0;

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(compact ? AppSpacing.lg : AppSpacing.xxl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxContentWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Container(
                  width: badge,
                  height: badge,
                  decoration: BoxDecoration(
                    color: iconBackground,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: badge / 2, color: iconColor),
                ),
              ),
              compact ? AppSpacing.gapMd : AppSpacing.gapXl,
              Semantics(
                header: true,
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: compact ? text.titleMedium : text.titleLarge,
                ),
              ),
              if (message != null) ...[
                AppSpacing.gapSm,
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: text.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
              if (actionLabel != null && onAction != null) ...[
                compact ? AppSpacing.gapLg : AppSpacing.gapXxl,
                AppButton.secondary(
                  label: actionLabel!,
                  leadingIcon: actionIcon,
                  onPressed: onAction,
                  expand: false,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
