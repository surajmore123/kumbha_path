import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:kumbha_path/src/components/feedback/app_status_view.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';

/// Empty state for lists and sections (no journal entries, no nearby
/// temples, no updates) with an optional call to action.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
    this.actionIcon,
    this.compact = false,
  });

  /// Defaults to the localized "Nothing here yet".
  final String? title;
  final String? message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? actionIcon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return AppStatusView(
      icon: icon,
      iconColor: colors.onPrimaryContainer,
      iconBackground: colors.primaryContainer,
      title: title ?? 'common_empty_title'.tr(),
      message: message,
      actionLabel: actionLabel,
      actionIcon: actionIcon,
      onAction: onAction,
      compact: compact,
    );
  }
}
