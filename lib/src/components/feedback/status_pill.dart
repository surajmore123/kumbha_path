import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/constant/place_format.dart';

/// Colors and label for a crowd level, from the semantic status tokens.
/// "Unavailable" is neutral, never green, so missing data can't read as safe.
({Color fg, Color bg, String label}) crowdStyle(
  BuildContext context,
  CrowdLevel level,
  String? rawStatus,
) {
  final s = context.semanticColors;
  final c = context.colorScheme;
  return switch (level) {
    CrowdLevel.low => (
      fg: s.onSuccessContainer,
      bg: s.successContainer,
      label: 'dash_crowd_low'.tr(),
    ),
    CrowdLevel.medium => (
      fg: s.onWarningContainer,
      bg: s.warningContainer,
      label: 'dash_crowd_medium'.tr(),
    ),
    CrowdLevel.high => (
      fg: c.onErrorContainer,
      bg: c.errorContainer,
      label: 'dash_crowd_high'.tr(),
    ),
    // Inverted (solid) so it stands apart from High without relying on hue.
    CrowdLevel.critical => (
      fg: c.onError,
      bg: c.error,
      label: 'dash_crowd_critical'.tr(),
    ),
    CrowdLevel.other => (
      fg: c.onSurfaceVariant,
      bg: c.surfaceContainerHigh,
      label: rawStatus!.trim(),
    ),
    CrowdLevel.unknown => (
      fg: c.onSurfaceVariant,
      bg: c.surfaceContainerHigh,
      label: 'dash_crowd_unknown'.tr(),
    ),
  };
}

/// Small rounded label, e.g. a crowd level or "Featured".
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.foreground,
    required this.background,
    this.icon,
  });

  final String label;
  final Color foreground;
  final Color background;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.pillAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foreground),
            AppSpacing.gapXs,
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.labelMedium?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Icon that accompanies a crowd level, so status never relies on colour
/// alone.
IconData crowdIcon(CrowdLevel level) => switch (level) {
  CrowdLevel.low => Icons.check_circle_outline,
  CrowdLevel.medium => Icons.people_outline,
  CrowdLevel.high => Icons.warning_amber_rounded,
  CrowdLevel.critical => Icons.report_rounded,
  CrowdLevel.other => Icons.info_outline,
  CrowdLevel.unknown => Icons.help_outline,
};
