import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/constant/display_format.dart';
import 'package:kumbha_path/src/models/quick_alert.dart';

/// Severity as sent by the alert / notification APIs (`LOW`, `MEDIUM`,
/// `HIGH`, plus `CRITICAL` if the backend uses it). Unknown values are
/// shown as given, never mapped to a guessed level.
enum Severity { low, medium, high, critical, other, none }

Severity severityOf(String? value) => switch ((value ?? '')
    .trim()
    .toUpperCase()) {
  'LOW' => Severity.low,
  'MEDIUM' || 'MODERATE' => Severity.medium,
  'HIGH' => Severity.high,
  'CRITICAL' => Severity.critical,
  '' => Severity.none,
  _ => Severity.other,
};

/// Style for a severity: colour, icon and label together, so meaning
/// never depends on colour alone. `null` for [Severity.none].
({Color fg, Color bg, IconData icon, String label})? severityStyle(
  BuildContext context,
  String? raw,
) {
  final c = context.colorScheme;
  final s = context.semanticColors;
  return switch (severityOf(raw)) {
    Severity.low => (
      fg: s.onInfoContainer,
      bg: s.infoContainer,
      icon: Icons.info_outline,
      label: 'sev_low'.tr(),
    ),
    Severity.medium => (
      fg: s.onWarningContainer,
      bg: s.warningContainer,
      icon: Icons.warning_amber_rounded,
      label: 'sev_medium'.tr(),
    ),
    Severity.high => (
      fg: c.onErrorContainer,
      bg: c.errorContainer,
      icon: Icons.error_outline,
      label: 'sev_high'.tr(),
    ),
    Severity.critical => (
      fg: c.onError,
      bg: c.error,
      icon: Icons.report_rounded,
      label: 'sev_critical'.tr(),
    ),
    Severity.other => (
      fg: c.onSurfaceVariant,
      bg: c.surfaceContainerHigh,
      icon: Icons.info_outline,
      label: prettifyCode(raw) ?? raw!.trim(),
    ),
    Severity.none => null,
  };
}

/// Is this item safety-relevant enough to stand out?
bool isUrgent(String? severity) {
  final s = severityOf(severity);
  return s == Severity.high || s == Severity.critical;
}

class SeverityPill extends StatelessWidget {
  const SeverityPill({super.key, required this.severity});

  final String? severity;

  @override
  Widget build(BuildContext context) {
    final style = severityStyle(context, severity);
    if (style == null) return const SizedBox.shrink();
    return StatusPill(
      label: style.label,
      icon: style.icon,
      foreground: style.fg,
      background: style.bg,
    );
  }
}

/// "Today, 10:42 AM" / "Yesterday, 6:05 PM" / "12 Jan 2027, 9:00 AM"
/// from a source timestamp, or null when there is no valid one.
String? sourceTimeLabel(String? iso, String locale, DateTime now) {
  final t = describeTimestamp(iso, locale, now);
  if (t == null) return null;
  if (t.isToday) return 'time_today'.tr(args: [t.time]);
  if (t.isYesterday) return 'time_yesterday'.tr(args: [t.time]);
  return '${t.date}, ${t.time}';
}

IconData alertTypeIcon(String? type) => switch ((type ?? '')
    .trim()
    .toUpperCase()) {
  'TRAFFIC' => Icons.traffic_outlined,
  'CROWD' => Icons.groups_outlined,
  _ => Icons.campaign_outlined,
};

/// One quick alert (`api/crowd/quick-alerts/`): type icon, title, zone,
/// severity, description and the API's start time.
class QuickAlertTile extends StatelessWidget {
  const QuickAlertTile({
    super.key,
    required this.alert,
    required this.locale,
    required this.now,
    this.onTap,
  });

  final AlertDetailsModel alert;
  final String locale;
  final DateTime now;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = context.textTheme;
    final colors = context.colorScheme;
    final urgent = isUrgent(alert.severity);
    final zone = (alert.zoneName ?? '').trim();
    final description = (alert.description ?? '').trim();
    final started = sourceTimeLabel(alert.startTime, locale, now);

    return AppCard(
      variant: urgent ? AppCardVariant.filled : AppCardVariant.outlined,
      color: urgent ? colors.errorContainer.withValues(alpha: 0.45) : null,
      onTap: onTap,
      semanticLabel: [
        alert.title ?? '',
        if (zone.isNotEmpty) zone,
        severityStyle(context, alert.severity)?.label ?? '',
      ].join(', '),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.surfaceContainerHigh,
              shape: BoxShape.circle,
            ),
            child: Icon(
              alertTypeIcon(alert.type),
              size: 20,
              color: colors.onSurface,
            ),
          ),
          AppSpacing.gapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SeverityPill(severity: alert.severity),
                    if (zone.isNotEmpty) Text(zone, style: text.labelLarge),
                  ],
                ),
                AppSpacing.gapXs,
                Text((alert.title ?? '').trim(), style: text.titleSmall),
                if (description.isNotEmpty)
                  Text(description, style: text.bodySmall),
                if (started != null) ...[
                  AppSpacing.gapXs,
                  Text(
                    'crowd_started'.tr(args: [started]),
                    style: text.labelSmall,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
