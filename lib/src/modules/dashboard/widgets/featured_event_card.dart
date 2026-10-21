import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/models/featured_model.dart';
import 'package:kumbha_path/src/modules/dashboard/dashboard_formatters.dart';

/// The event the backend marks as featured (`api/events/featured/`).
///
/// Every line is optional and only rendered when the API supplied it. The
/// countdown is derived from `event_date`; past events say "Concluded"
/// instead of counting.
class FeaturedEventCard extends StatelessWidget {
  const FeaturedEventCard({
    super.key,
    required this.event,
    required this.locale,
    required this.onViewEvents,
    this.now,
  });

  final EventDetailsModel event;
  final String locale;
  final VoidCallback onViewEvents;

  /// Injectable clock for tests.
  final DateTime? now;

  static bool hasContent(EventDetailsModel e) =>
      (e.eventName ?? '').trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final semantic = context.semanticColors;
    final text = context.textTheme;

    final date = formatEventDate(event.eventDate, locale);
    final time =
        event.isAllDay == true
            ? 'dash_all_day'.tr()
            : formatEventTimeRange(event.startTime, event.endTime, locale);
    final location = (event.locationName ?? '').trim();
    final description =
        (event.shortDescription ?? '').trim().isNotEmpty
            ? event.shortDescription!.trim()
            : (event.description ?? '').trim();
    final timing = eventTiming(event.eventDate, now ?? DateTime.now());

    return AppCard(
      variant: AppCardVariant.filled,
      color: colors.primaryContainer,
      padding: const EdgeInsets.all(AppSpacing.xl),
      onTap: onViewEvents,
      semanticLabel: event.eventName,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusPill(
                label: 'dash_featured_label'.tr(),
                icon: Icons.auto_awesome,
                foreground: semantic.onGold,
                background: semantic.gold,
              ),
              if (timing != null) _CountdownPill(timing: timing),
            ],
          ),
          AppSpacing.gapLg,
          Text(
            event.eventName!.trim(),
            style: text.headlineSmall?.copyWith(
              color: colors.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (description.isNotEmpty) ...[
            AppSpacing.gapSm,
            Text(
              description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: text.bodyMedium?.copyWith(
                color: colors.onPrimaryContainer.withValues(alpha: 0.85),
              ),
            ),
          ],
          if (date != null || time != null || location.isNotEmpty) ...[
            AppSpacing.gapLg,
            if (date != null)
              _MetaLine(icon: Icons.calendar_today_outlined, text: date),
            if (time != null)
              _MetaLine(icon: Icons.schedule_outlined, text: time),
            if (location.isNotEmpty)
              _MetaLine(icon: Icons.place_outlined, text: location),
          ],
          AppSpacing.gapLg,
          AppButton(
            label: 'dash_view_event'.tr(),
            trailingIcon: Icons.arrow_forward,
            expand: false,
            onPressed: onViewEvents,
          ),
        ],
      ),
    );
  }
}

class _CountdownPill extends StatelessWidget {
  const _CountdownPill({required this.timing});

  final EventTiming timing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final label = switch (timing) {
      EventToday() => 'dash_countdown_today'.tr(),
      EventTomorrow() => 'dash_countdown_tomorrow'.tr(),
      EventInDays(:final days) => 'dash_countdown_days'.tr(args: ['$days']),
      EventPast() => 'dash_event_concluded'.tr(),
    };
    final isPast = timing is EventPast;
    return StatusPill(
      label: label,
      icon: isPast ? Icons.history : Icons.hourglass_bottom_rounded,
      foreground: isPast ? colors.onSurfaceVariant : colors.onSurface,
      background: colors.surfaceContainerLowest,
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = context.colorScheme.onPrimaryContainer;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xxs),
            child: Icon(icon, size: 16, color: color),
          ),
          AppSpacing.gapSm,
          Expanded(
            child: Text(
              text,
              style: context.textTheme.bodyMedium?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
