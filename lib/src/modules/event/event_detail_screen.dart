import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:kumbha_path/main_layout.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/constant/display_format.dart';
import 'package:kumbha_path/src/constant/place_format.dart';
import 'package:kumbha_path/src/modules/event/event_item.dart';
import 'package:kumbha_path/src/modules/event/widgets/event_cards.dart';
import 'package:kumbha_path/src/modules/event/widgets/event_reminder_button.dart';

/// Full view of one event, opened from the Events list.
///
/// There is no event-detail endpoint or route: the featured and upcoming
/// responses already contain every field, so this screen shows the event
/// it was given. Only those fields are displayed: no venue details,
/// instructions or restrictions are invented.
class EventDetailScreen extends StatelessWidget {
  const EventDetailScreen({
    super.key,
    required this.event,
    this.now,
    this.notificationsBlocked,
  });

  final EventItem event;

  /// Injectable clock for tests.
  final DateTime? now;
  final NotificationsBlockedCheck? notificationsBlocked;

  static const double _maxWidth = 760;

  static Route<void> route(
    EventItem event, {
    DateTime? now,
    NotificationsBlockedCheck? notificationsBlocked,
  }) => MaterialPageRoute(
    builder:
        (_) => EventDetailScreen(
          event: event,
          now: now,
          notificationsBlocked: notificationsBlocked,
        ),
  );

  @override
  Widget build(BuildContext context) {
    final locale =
        EasyLocalization.of(context)?.locale.languageCode ??
        Localizations.localeOf(context).languageCode;
    final clock = now ?? DateTime.now();
    final text = context.textTheme;
    final colors = context.colorScheme;

    final date = formatEventDate(event.date, locale);
    final time = eventTimeLabel(event, locale);
    final countdown = countdownLabel(event, clock);
    final crowdLevel = crowdLevelOf(event.expectedCrowdLevel);
    final place = [
      if (event.locationName != null) event.locationName!,
      if (prettifyCode(event.locationType) case final type?) type,
    ];

    return MainLayout(
      showDefaultBottom: false,
      ctx: 2,
      appBar: AppAppBar(title: 'events_details_title'.tr()),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final side =
              constraints.maxWidth > _maxWidth + AppSpacing.pageGutter * 2
                  ? (constraints.maxWidth - _maxWidth) / 2
                  : AppSpacing.pageGutter;
          return ListView(
            padding: EdgeInsets.fromLTRB(
              side,
              AppSpacing.md,
              side,
              AppSpacing.huge,
            ),
            children: [
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  if (event.categoryLabel != null)
                    StatusPill(
                      label: event.categoryLabel!,
                      foreground: colors.onPrimaryContainer,
                      background: colors.primaryContainer,
                    ),
                  if (countdown != null)
                    StatusPill(
                      label: countdown,
                      icon: Icons.hourglass_bottom_rounded,
                      foreground: colors.onSurface,
                      background: colors.surfaceContainerHigh,
                    )
                  else
                    EventPhasePill(phase: event.phaseAt(clock)),
                ],
              ),
              AppSpacing.gapMd,
              Semantics(
                header: true,
                child: Text(
                  event.name,
                  style: text.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              AppSpacing.gapXl,
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _InfoRow(
                      icon: Icons.calendar_today_outlined,
                      label: 'events_when'.tr(),
                      lines: [
                        date ?? 'events_date_tba'.tr(),
                        if (time != null) time,
                      ],
                    ),
                    if (place.isNotEmpty) ...[
                      const Divider(height: AppSpacing.xxl),
                      _InfoRow(
                        icon: Icons.place_outlined,
                        label: 'events_where'.tr(),
                        lines: place,
                      ),
                    ],
                    if (crowdLevel != CrowdLevel.unknown) ...[
                      const Divider(height: AppSpacing.xxl),
                      _InfoRow(
                        icon: Icons.groups_outlined,
                        label: 'events_expected_crowd'.tr(),
                        trailing: Builder(
                          builder: (context) {
                            final s = crowdStyle(
                              context,
                              crowdLevel,
                              event.expectedCrowdLevel,
                            );
                            return StatusPill(
                              label: s.label,
                              foreground: s.fg,
                              background: s.bg,
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (event.canRemind &&
                  event.phaseAt(clock) != EventPhase.past) ...[
                AppSpacing.gapXl,
                EventReminderButton(
                  event: event,
                  notificationsBlocked: notificationsBlocked,
                ),
                AppSpacing.gapSm,
                Text('events_reminder_note'.tr(), style: text.bodySmall),
              ],
              if (event.fullDescription != null) ...[
                AppSpacing.gapXxl,
                AppSectionHeader(title: 'events_about'.tr()),
                AppSpacing.gapMd,
                Text(
                  event.fullDescription!,
                  style: text.bodyLarge?.copyWith(height: 1.6),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    this.lines = const [],
    this.trailing,
  });

  final IconData icon;
  final String label;
  final List<String> lines;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final text = context.textTheme;
    final colors = context.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: colors.onPrimaryContainer),
        ),
        AppSpacing.gapMd,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: text.labelMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              for (var i = 0; i < lines.length; i++)
                Text(
                  lines[i],
                  style: i == 0 ? text.titleMedium : text.bodyMedium,
                ),
              if (trailing != null) ...[AppSpacing.gapXs, trailing!],
            ],
          ),
        ),
      ],
    );
  }
}
