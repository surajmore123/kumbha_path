import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/models/quick_alert.dart';
import 'package:kumbha_path/src/models/zone_model.dart';
import 'package:kumbha_path/src/modules/dashboard/dashboard_formatters.dart';

export 'package:kumbha_path/src/components/feedback/status_pill.dart'
    show crowdStyle;

/// Compact summary of `api/crowd/live-status/` zones: how many zones are at
/// each level, the busiest few, and when the data was fetched.
class CrowdSummaryCard extends StatelessWidget {
  const CrowdSummaryCard({
    super.key,
    required this.zones,
    required this.locale,
    required this.onOpenMap,
    this.checkedAt,
  });

  final List<ZoneModel> zones;
  final String locale;
  final VoidCallback onOpenMap;

  /// Device time the response arrived; the API provides no timestamp.
  final DateTime? checkedAt;

  static const int _busiestCount = 3;

  @override
  Widget build(BuildContext context) {
    final text = context.textTheme;
    final colors = context.colorScheme;

    if (zones.isEmpty) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'dash_crowd_empty'.tr(),
              style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
            AppSpacing.gapMd,
            AppButton.outlined(
              label: 'dash_open_map'.tr(),
              leadingIcon: Icons.map_outlined,
              expand: false,
              onPressed: onOpenMap,
            ),
          ],
        ),
      );
    }

    final counts = <CrowdLevel, int>{};
    for (final zone in zones) {
      final level = crowdLevelOf(zone.status);
      counts[level] = (counts[level] ?? 0) + 1;
    }

    // Busiest first; zones without occupancy go last rather than as 0%.
    final busiest = [...zones]..sort((a, b) {
      final pa = a.occupancyPercent, pb = b.occupancyPercent;
      if (pa == null && pb == null) return 0;
      if (pa == null) return 1;
      if (pb == null) return -1;
      return pb.compareTo(pa);
    });

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final level in CrowdLevel.values)
                if ((counts[level] ?? 0) > 0 && level != CrowdLevel.other)
                  _LevelCount(level: level, count: counts[level]!),
            ],
          ),
          AppSpacing.gapSm,
          Text(
            [
              'dash_crowd_zones'.tr(args: ['${zones.length}']),
              if (checkedAt != null)
                'dash_crowd_checked_at'.tr(
                  args: [formatClockTime(checkedAt!, locale)],
                ),
            ].join(' · '),
            style: text.bodySmall,
          ),
          const Divider(height: AppSpacing.xxl),
          Text('dash_crowd_busiest'.tr(), style: text.titleSmall),
          AppSpacing.gapSm,
          for (final zone in busiest.take(_busiestCount))
            _ZoneRow(zone: zone, locale: locale),
          AppSpacing.gapMd,
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: AppButton.outlined(
              label: 'dash_open_map'.tr(),
              leadingIcon: Icons.map_outlined,
              expand: false,
              onPressed: onOpenMap,
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelCount extends StatelessWidget {
  const _LevelCount({required this.level, required this.count});

  final CrowdLevel level;
  final int count;

  @override
  Widget build(BuildContext context) {
    final style = crowdStyle(context, level, null);
    return StatusPill(
      label: '${style.label} · $count',
      foreground: style.fg,
      background: style.bg,
    );
  }
}

class _ZoneRow extends StatelessWidget {
  const _ZoneRow({required this.zone, required this.locale});

  final ZoneModel zone;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final text = context.textTheme;
    final level = crowdLevelOf(zone.status);
    final style = crowdStyle(context, level, zone.status);
    final occupancy = formatOccupancy(zone.occupancyPercent, locale);
    final name = (zone.name ?? '').trim().isNotEmpty ? zone.name! : zone.code;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name ?? '', style: text.bodyLarge),
                if (occupancy != null)
                  Text(
                    'dash_occupancy'.tr(args: [occupancy]),
                    style: text.bodySmall,
                  ),
              ],
            ),
          ),
          AppSpacing.gapSm,
          StatusPill(
            label: style.label,
            foreground: style.fg,
            background: style.bg,
          ),
        ],
      ),
    );
  }
}

/// Banner for real alerts from the quick-alerts API (QuickAlertsEvent). Renders nothing
/// when there are none; it never shows a placeholder "all clear".
class ActiveAlertBanner extends StatelessWidget {
  const ActiveAlertBanner({
    super.key,
    required this.alerts,
    required this.onTap,
  });

  final List<AlertDetailsModel> alerts;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final visible =
        alerts.where((a) => (a.title ?? '').trim().isNotEmpty).toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    final colors = context.colorScheme;
    final text = context.textTheme;
    final alert = visible.first;
    final more = visible.length - 1;
    final where = (alert.zoneName ?? '').trim();
    final details = (alert.description ?? '').trim();

    return AppCard(
      variant: AppCardVariant.filled,
      color: colors.errorContainer,
      onTap: onTap,
      semanticLabel: '${'dash_alert_label'.tr()}: ${alert.title}',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: colors.onErrorContainer),
          AppSpacing.gapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  [
                    'dash_alert_label'.tr(),
                    if (where.isNotEmpty) where,
                  ].join(' · '),
                  style: text.labelMedium?.copyWith(
                    color: colors.onErrorContainer,
                  ),
                ),
                AppSpacing.gapXs,
                Text(
                  alert.title!.trim(),
                  style: text.titleSmall?.copyWith(
                    color: colors.onErrorContainer,
                  ),
                ),
                if (details.isNotEmpty)
                  Text(
                    details,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(
                      color: colors.onErrorContainer,
                    ),
                  ),
                if (more > 0) ...[
                  AppSpacing.gapXs,
                  Text(
                    'dash_alerts_more'.tr(args: ['$more']),
                    style: text.labelMedium?.copyWith(
                      color: colors.onErrorContainer,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: colors.onErrorContainer),
        ],
      ),
    );
  }
}

/// The app's existing static advisory (peak-hours guidance), presented as
/// general advice, clearly separate from live data.
class PilgrimTip extends StatelessWidget {
  const PilgrimTip({super.key});

  @override
  Widget build(BuildContext context) {
    final semantic = context.semanticColors;
    final text = context.textTheme;
    return AppCard(
      variant: AppCardVariant.filled,
      color: semantic.infoContainer,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline, color: semantic.onInfoContainer),
          AppSpacing.gapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'dash_tip_label'.tr(),
                  style: text.labelMedium?.copyWith(
                    color: semantic.onInfoContainer,
                  ),
                ),
                AppSpacing.gapXs,
                Text(
                  'peak_hours_title'.tr(),
                  style: text.titleSmall?.copyWith(
                    color: semantic.onInfoContainer,
                  ),
                ),
                Text(
                  'peak_hours_message'.tr(),
                  style: text.bodySmall?.copyWith(
                    color: semantic.onInfoContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
