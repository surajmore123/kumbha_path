import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/constant/display_format.dart';
import 'package:kumbha_path/src/modules/event/event_item.dart';
import 'package:kumbha_path/src/modules/event/widgets/event_reminder_button.dart';

/// "Happening now" / "Today" / "Concluded" pill, only when the data
/// supports it. Upcoming events show their countdown instead.
class EventPhasePill extends StatelessWidget {
  const EventPhasePill({super.key, required this.phase});

  final EventPhase phase;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final semantic = context.semanticColors;
    final (String label, Color fg, Color bg, IconData icon)? style =
        switch (phase) {
          EventPhase.ongoing => (
            'events_phase_ongoing'.tr(),
            semantic.onSuccessContainer,
            semantic.successContainer,
            Icons.radio_button_checked,
          ),
          EventPhase.today => (
            'dash_countdown_today'.tr(),
            colors.onPrimaryContainer,
            colors.primaryContainer,
            Icons.today_outlined,
          ),
          EventPhase.past => (
            'dash_event_concluded'.tr(),
            colors.onSurfaceVariant,
            colors.surfaceContainerHigh,
            Icons.history,
          ),
          _ => null,
        };
    if (style == null) return const SizedBox.shrink();
    return StatusPill(
      label: style.$1,
      foreground: style.$2,
      background: style.$3,
      icon: style.$4,
    );
  }
}

/// "In 12 days" / "Tomorrow" for upcoming events with a valid date.
String? countdownLabel(EventItem e, DateTime now) {
  if (e.phaseAt(now) != EventPhase.upcoming) return null;
  return switch (eventTiming(e.date, now)) {
    EventToday() => null, // later today: the time is shown instead
    EventTomorrow() => 'dash_countdown_tomorrow'.tr(),
    EventInDays(:final days) => 'dash_countdown_days'.tr(args: ['$days']),
    _ => null,
  };
}

/// "6:00 AM – 9:00 AM", "All day", or null when no valid time.
String? eventTimeLabel(EventItem e, String locale) =>
    e.isAllDay
        ? 'dash_all_day'.tr()
        : formatEventTimeRange(e.startTime, e.endTime, locale);

/// The featured event (from `api/events/featured/`): the one large card.
class FeaturedEventPanel extends StatelessWidget {
  const FeaturedEventPanel({
    super.key,
    required this.event,
    required this.locale,
    required this.now,
    required this.onOpen,
    this.notificationsBlocked,
  });

  final EventItem event;
  final String locale;
  final DateTime now;
  final VoidCallback onOpen;
  final NotificationsBlockedCheck? notificationsBlocked;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final semantic = context.semanticColors;
    final text = context.textTheme;
    final fg = colors.onPrimaryContainer;
    final date = formatEventDate(event.date, locale);
    final time = eventTimeLabel(event, locale);
    final countdown = countdownLabel(event, now);
    final category = event.categoryLabel;

    Widget meta(IconData icon, String value) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xxs),
            child: Icon(icon, size: 16, color: fg),
          ),
          AppSpacing.gapSm,
          Expanded(
            child: Text(value, style: text.bodyMedium?.copyWith(color: fg)),
          ),
        ],
      ),
    );

    return AppCard(
      variant: AppCardVariant.filled,
      color: colors.primaryContainer,
      padding: const EdgeInsets.all(AppSpacing.xl),
      onTap: onOpen,
      semanticLabel: event.name,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              StatusPill(
                label: 'dash_featured_label'.tr(),
                icon: Icons.auto_awesome,
                foreground: semantic.onGold,
                background: semantic.gold,
              ),
              if (category != null)
                StatusPill(
                  label: category,
                  foreground: colors.onSurface,
                  background: colors.surfaceContainerLowest,
                ),
              if (countdown != null)
                StatusPill(
                  label: countdown,
                  icon: Icons.hourglass_bottom_rounded,
                  foreground: colors.onSurface,
                  background: colors.surfaceContainerLowest,
                )
              else
                EventPhasePill(phase: event.phaseAt(now)),
            ],
          ),
          AppSpacing.gapLg,
          Text(
            event.name,
            style: text.headlineSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (event.summary != null) ...[
            AppSpacing.gapSm,
            Text(
              event.summary!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: text.bodyMedium?.copyWith(
                color: fg.withValues(alpha: 0.85),
              ),
            ),
          ],
          AppSpacing.gapLg,
          if (date != null) meta(Icons.calendar_today_outlined, date),
          if (time != null) meta(Icons.schedule_outlined, time),
          if (event.locationName != null)
            meta(Icons.place_outlined, event.locationName!),
          AppSpacing.gapLg,
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              AppButton(
                label: 'events_view_details'.tr(),
                trailingIcon: Icons.arrow_forward,
                expand: false,
                onPressed: onOpen,
              ),
              if (event.canRemind)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 280),
                  child: EventReminderButton(
                    event: event,
                    notificationsBlocked: notificationsBlocked,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Date heading of a timeline group.
class TimelineDateHeader extends StatelessWidget {
  const TimelineDateHeader({super.key, required this.label, this.relative});

  final String label;
  final String? relative;

  @override
  Widget build(BuildContext context) {
    final text = context.textTheme;
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Wrap(
          spacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(label, style: text.titleMedium),
            if (relative != null)
              Text(
                relative!,
                style: text.labelLarge?.copyWith(
                  color: context.colorScheme.primary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One event on the timeline: a rail dot coloured by phase, then the
/// event's time, name, place and category, and a reminder toggle.
class TimelineEventTile extends StatelessWidget {
  const TimelineEventTile({
    super.key,
    required this.event,
    required this.locale,
    required this.now,
    required this.onOpen,
    this.isLast = false,
    this.notificationsBlocked,
  });

  final EventItem event;
  final String locale;
  final DateTime now;
  final VoidCallback onOpen;
  final bool isLast;
  final NotificationsBlockedCheck? notificationsBlocked;

  static const double _rail = 24;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final semantic = context.semanticColors;
    final text = context.textTheme;
    final phase = event.phaseAt(now);
    final past = phase == EventPhase.past;
    final dot = switch (phase) {
      EventPhase.ongoing => semantic.success,
      EventPhase.past => colors.outlineVariant,
      _ => colors.primary,
    };
    final time = eventTimeLabel(event, locale);
    final details = [
      if (event.locationName != null) event.locationName!,
      if (event.categoryLabel != null) event.categoryLabel!,
    ];

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: _rail,
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.xl),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: dot,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.surface, width: 2),
                  ),
                ),
                if (!isLast)
                  Expanded(child: Container(width: 2, color: semantic.divider)),
              ],
            ),
          ),
          AppSpacing.gapSm,
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.md),
              child: AppCard(
                onTap: onOpen,
                semanticLabel: [event.name, if (time != null) time].join(', '),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.xs,
                  AppSpacing.md,
                ),
                child: Opacity(
                  opacity: past ? 0.72 : 1,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (time != null)
                              Text(
                                time,
                                style: text.labelLarge?.copyWith(
                                  color: colors.primary,
                                ),
                              ),
                            Text(
                              event.name,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: text.titleMedium,
                            ),
                            if (details.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: AppSpacing.xxs,
                                ),
                                child: Text(
                                  details.join(' · '),
                                  style: text.bodySmall,
                                ),
                              ),
                            if (phase == EventPhase.ongoing ||
                                phase == EventPhase.past) ...[
                              AppSpacing.gapSm,
                              EventPhasePill(phase: phase),
                            ],
                          ],
                        ),
                      ),
                      if (!past)
                        EventReminderButton(
                          event: event,
                          compact: true,
                          notificationsBlocked: notificationsBlocked,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
