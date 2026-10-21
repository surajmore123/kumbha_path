import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/models/upcoming_events.dart';
import 'package:kumbha_path/src/modules/dashboard/dashboard_formatters.dart';

/// Next few events from the upcoming-events API, in API order. The featured
/// event is skipped here because it already has its own card above.
class UpcomingEventsList extends StatelessWidget {
  const UpcomingEventsList({
    super.key,
    required this.events,
    required this.locale,
    required this.onTap,
    this.excludeEventId,
  });

  final List<EventSummaryModel> events;
  final String locale;
  final VoidCallback onTap;
  final String? excludeEventId;

  static const int previewCount = 3;

  /// Events to display after removing the featured one and unnamed rows.
  static List<EventSummaryModel> visible(
    List<EventSummaryModel> events,
    String? excludeEventId,
  ) {
    final exclude = (excludeEventId ?? '').trim();
    return events
        .where((e) => (e.eventName ?? '').trim().isNotEmpty)
        .where((e) => exclude.isEmpty || e.eventId != exclude)
        .take(previewCount)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final items = visible(events, excludeEventId);
    if (items.isEmpty) {
      return AppCard(
        padding: EdgeInsets.zero,
        child: AppEmptyState(
          compact: true,
          icon: Icons.event_available_outlined,
          title: 'dash_upcoming_empty'.tr(),
        ),
      );
    }
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: AppSpacing.lg + 56),
            _EventRow(event: items[i], locale: locale, onTap: onTap),
          ],
        ],
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({
    required this.event,
    required this.locale,
    required this.onTap,
  });

  final EventSummaryModel event;
  final String locale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final text = context.textTheme;
    final badge = eventDateBadge(event.eventDate, locale);
    final time =
        event.isAllDay == true
            ? 'dash_all_day'.tr()
            : formatEventTimeRange(event.startTime, event.endTime, locale);
    final location = (event.locationName ?? '').trim();
    final meta = [if (time != null) time, if (location.isNotEmpty) location];

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                color: colors.secondaryContainer,
                borderRadius: AppRadius.mdAll,
              ),
              child:
                  badge == null
                      ? Icon(
                        Icons.event_outlined,
                        color: colors.onSecondaryContainer,
                      )
                      : Column(
                        children: [
                          Text(
                            badge.day,
                            style: text.titleLarge?.copyWith(
                              color: colors.onSecondaryContainer,
                              fontWeight: FontWeight.w700,
                              height: 1.1,
                            ),
                          ),
                          Text(
                            badge.month,
                            style: text.labelSmall?.copyWith(
                              color: colors.onSecondaryContainer,
                            ),
                          ),
                        ],
                      ),
            ),
            AppSpacing.gapMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.eventName!.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleMedium,
                  ),
                  if (meta.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xxs),
                      child: Text(meta.join(' · '), style: text.bodySmall),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
