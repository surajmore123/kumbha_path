import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/modules/dashboard/dashboard_controller.dart';

export 'package:kumbha_path/src/components/feedback/status_pill.dart'
    show StatusPill;

/// Header + content block with the dashboard's standard vertical rhythm.
class DashboardSection extends StatelessWidget {
  const DashboardSection({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionHeader(
          title: title,
          subtitle: subtitle,
          actionLabel: actionLabel,
          onAction: onAction,
        ),
        AppSpacing.gapMd,
        child,
      ],
    );
  }
}

/// Switches between loading, error and content for one [DashboardFeed].
class FeedBuilder extends StatelessWidget {
  const FeedBuilder({
    super.key,
    required this.feed,
    required this.builder,
    this.loading,
  });

  final DashboardFeed feed;
  final WidgetBuilder builder;

  /// Skeleton shown while loading. Defaults to a single card-sized block.
  final Widget? loading;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<FeedStatus>(
      valueListenable: feed.status,
      builder: (context, status, _) {
        final Widget child = switch (status) {
          FeedStatus.loading =>
            loading ?? const SkeletonBlock(height: 120, key: ValueKey('l')),
          FeedStatus.failed => AppCard(
            key: const ValueKey('e'),
            padding: EdgeInsets.zero,
            child: AppErrorView(compact: true, onRetry: feed.load),
          ),
          FeedStatus.ready => KeyedSubtree(
            key: const ValueKey('r'),
            child: builder(context),
          ),
        };
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: child,
        );
      },
    );
  }
}

/// Static placeholder block in the shape of the content that's loading.
/// Deliberately not animated: calmer, and cheaper on low-end phones.
class SkeletonBlock extends StatelessWidget {
  const SkeletonBlock({
    super.key,
    required this.height,
    this.width,
    this.radius = AppRadius.cardAll,
  });

  final double height;
  final double? width;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'common_loading'.tr(),
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: context.colorScheme.surfaceContainerHigh,
          borderRadius: radius,
        ),
      ),
    );
  }
}
