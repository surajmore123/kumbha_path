import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:kumbha_path/src/components/feedback/app_status_view.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';

/// Error state for a screen or section with an optional retry.
///
/// Presentation only: callers keep their existing error handling and simply
/// render this for the error state, passing the retry they already have
/// (e.g. re-dispatching a BLoC event).
class AppErrorView extends StatelessWidget {
  const AppErrorView({
    super.key,
    this.title,
    this.message,
    this.onRetry,
    this.retryLabel,
    this.icon = Icons.cloud_off_rounded,
    this.compact = false,
  });

  /// Defaults to the localized "Something went wrong".
  final String? title;

  /// User-facing explanation. Don't pass raw exception text.
  final String? message;
  final VoidCallback? onRetry;

  /// Defaults to the localized "Try again".
  final String? retryLabel;
  final IconData icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return AppStatusView(
      icon: icon,
      iconColor: colors.onErrorContainer,
      iconBackground: colors.errorContainer,
      title: title ?? 'common_error_title'.tr(),
      message: message,
      actionLabel: onRetry != null ? (retryLabel ?? 'common_retry'.tr()) : null,
      actionIcon: Icons.refresh_rounded,
      onAction: onRetry,
      compact: compact,
    );
  }
}
