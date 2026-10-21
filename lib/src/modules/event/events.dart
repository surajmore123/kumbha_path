import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kumbha_path/main_layout.dart';
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_event.dart';
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_feed.dart';
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_state.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/constant/display_format.dart';
import 'package:kumbha_path/src/modules/event/event_detail_screen.dart';
import 'package:kumbha_path/src/modules/event/event_item.dart';
import 'package:kumbha_path/src/modules/event/widgets/event_cards.dart';
import 'package:kumbha_path/src/modules/event/widgets/event_reminder_button.dart';

/// `/shahiEvents`: the featured event plus the upcoming schedule.
///
/// Data comes from the same requests as before, `FeaturedEvent` and
/// `UpcomingEvent(date)` (the date picker is the API's own filter). Each
/// uses a private AppDetailsBloc instance so one request's loading or
/// failure no longer blanks the whole screen. Reminders keep using the
/// app-wide AppDetailsBloc (see [EventReminderButton]).
class ShahiEvents extends StatefulWidget {
  const ShahiEvents({
    super.key,
    this.featuredBloc,
    this.upcomingBloc,
    this.now,
    this.notificationsBlocked,
  });

  /// Injected in tests (any bloc of AppDetailsBloc's types). By default
  /// each feed creates its own AppDetailsBloc.
  final Bloc<AppDetailsEvent, AppDetailsState>? featuredBloc;
  final Bloc<AppDetailsEvent, AppDetailsState>? upcomingBloc;
  final DateTime Function()? now;
  final NotificationsBlockedCheck? notificationsBlocked;

  @override
  State<ShahiEvents> createState() => _ShahiEventsState();
}

class _ShahiEventsState extends State<ShahiEvents> {
  late final AppDetailsFeed _featured;
  late final AppDetailsFeed _upcoming;

  /// API date filter (`UpcomingEvent(date)`); null = default upcoming list.
  DateTime? _date;

  /// Client-side filter over the loaded events' own categories.
  String? _category;

  static const double _maxWidth = 760;

  DateTime get _now => (widget.now ?? DateTime.now)();

  String get _dateParam =>
      _date == null
          ? ''
          : '${_date!.year.toString().padLeft(4, '0')}-'
              '${_date!.month.toString().padLeft(2, '0')}-'
              '${_date!.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _featured = AppDetailsFeed(
      bloc: widget.featuredBloc,
      request: FeaturedEvent.new,
      isReady: (s) => s == AppDetailsStatus.success,
      isFailed: (s) => s == AppDetailsStatus.failed,
    );
    _upcoming = AppDetailsFeed(
      bloc: widget.upcomingBloc,
      request: () => UpcomingEvent(_dateParam),
      isReady: (s) => s == AppDetailsStatus.success,
      isFailed: (s) => s == AppDetailsStatus.failed,
    );
    _featured.load();
    _upcoming.load();
  }

  @override
  void dispose() {
    _featured.dispose();
    _upcoming.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      // Same range as before.
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _date = picked;
      _category = null;
    });
    _upcoming.load();
  }

  void _clearDate() {
    setState(() {
      _date = null;
      _category = null;
    });
    _upcoming.load();
  }

  void _open(EventItem event) {
    Navigator.push(
      context,
      EventDetailScreen.route(
        event,
        // Same clock as the list, so phases and countdowns agree.
        now: _now,
        notificationsBlocked: widget.notificationsBlocked,
      ),
    );
  }

  String get _locale =>
      EasyLocalization.of(context)?.locale.languageCode ??
      Localizations.localeOf(context).languageCode;

  @override
  Widget build(BuildContext context) {
    final locale = _locale;
    return MainLayout(
      showDefaultBottom: true,
      ctx: 2,
      appBar: AppAppBar(
        title: 'events_appbar_title'.tr(),
        actions: [
          ValueListenableBuilder<FeedStatus>(
            valueListenable: _upcoming.status,
            builder:
                (context, status, _) => AppIconButton(
                  icon: Icons.calendar_month_outlined,
                  tooltip: 'events_pick_date'.tr(),
                  onPressed: status == FeedStatus.loading ? null : _pickDate,
                ),
          ),
          AppSpacing.gapXs,
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => Future.wait([_featured.load(), _upcoming.load()]),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final side = math.max(
              AppSpacing.pageGutter,
              (constraints.maxWidth - _maxWidth) / 2,
            );
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                side,
                AppSpacing.sm,
                side,
                AppSpacing.huge,
              ),
              children: [
                Text(
                  'events_intro'.tr(),
                  style: context.textTheme.bodyLarge?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
                AppSpacing.gapLg,
                _featuredSection(locale),
                AppSpacing.gapXxl,
                AppSectionHeader(title: 'events_schedule'.tr()),
                AppSpacing.gapMd,
                _scheduleSection(locale),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _featuredSection(String locale) {
    return ValueListenableBuilder<FeedStatus>(
      valueListenable: _featured.status,
      builder: (context, status, _) {
        switch (status) {
          case FeedStatus.loading:
            return const _Skeleton(height: 280);
          case FeedStatus.failed:
            return AppCard(
              variant: AppCardVariant.filled,
              child: Row(
                children: [
                  Icon(
                    Icons.cloud_off_rounded,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                  AppSpacing.gapMd,
                  Expanded(
                    child: Text(
                      'events_featured_failed'.tr(),
                      style: context.textTheme.bodyMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: _featured.load,
                    child: Text('common_retry'.tr()),
                  ),
                ],
              ),
            );
          case FeedStatus.ready:
            final event = EventItem.fromFeatured(
              _featured.bloc.state.eventDetailsModel,
            );
            // Nothing featured: no placeholder card.
            if (!event.hasName) return const SizedBox.shrink();
            return FeaturedEventPanel(
              event: event,
              locale: locale,
              now: _now,
              onOpen: () => _open(event),
              notificationsBlocked: widget.notificationsBlocked,
            );
        }
      },
    );
  }

  Widget _scheduleSection(String locale) {
    return ListenableBuilder(
      // Re-filter when the featured event (excluded from the list) loads.
      listenable: Listenable.merge([_upcoming.status, _featured.status]),
      builder: (context, _) {
        final status = _upcoming.status.value;
        final filters = _ActiveDateChip(
          date: _date,
          locale: locale,
          onClear: _clearDate,
        );

        if (status == FeedStatus.loading) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              filters,
              const _Skeleton(height: 96),
              AppSpacing.gapMd,
              const _Skeleton(height: 96),
            ],
          );
        }
        if (status == FeedStatus.failed) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              filters,
              AppCard(
                padding: EdgeInsets.zero,
                child: AppErrorView(compact: true, onRetry: _upcoming.load),
              ),
            ],
          );
        }

        final featuredId =
            _featured.status.value == FeedStatus.ready
                ? EventItem.fromFeatured(
                  _featured.bloc.state.eventDetailsModel,
                ).id
                : null;
        final events = dedupeEvents(
          sortChronologically([
            for (final e in _upcoming.bloc.state.upcomingEvents)
              EventItem.fromSummary(e),
          ]),
          excludeId: featuredId,
        );
        final categories =
            <String>{
              for (final e in events)
                if (e.filterCategory != null) e.filterCategory!,
            }.toList();
        final category = categories.contains(_category) ? _category : null;
        final visible =
            category == null
                ? events
                : events.where((e) => e.filterCategory == category).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            filters,
            if (categories.length >= 2) ...[
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  ChoiceChip(
                    label: Text('events_all_categories'.tr()),
                    selected: category == null,
                    onSelected: (_) => setState(() => _category = null),
                  ),
                  for (final c in categories)
                    ChoiceChip(
                      label: Text(c),
                      selected: category == c,
                      onSelected: (_) => setState(() => _category = c),
                    ),
                ],
              ),
              AppSpacing.gapLg,
            ],
            if (visible.isEmpty)
              AppCard(
                padding: EdgeInsets.zero,
                child: AppEmptyState(
                  compact: true,
                  icon: Icons.event_available_outlined,
                  title:
                      _date == null
                          ? 'dash_upcoming_empty'.tr()
                          : 'events_empty_on_date'.tr(
                            args: [formatEventDate(_dateParam, locale) ?? ''],
                          ),
                  actionLabel: _date == null ? null : 'events_clear_date'.tr(),
                  onAction: _date == null ? null : _clearDate,
                ),
              )
            else
              _Timeline(
                events: visible,
                locale: locale,
                now: _now,
                onOpen: _open,
                notificationsBlocked: widget.notificationsBlocked,
              ),
          ],
        );
      },
    );
  }
}

/// The API date filter, shown as a removable chip while active.
class _ActiveDateChip extends StatelessWidget {
  const _ActiveDateChip({
    required this.date,
    required this.locale,
    required this.onClear,
  });

  final DateTime? date;
  final String locale;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final d = date;
    if (d == null) return const SizedBox.shrink();
    final label =
        formatEventDate(
          '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}',
          locale,
        ) ??
        '';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: InputChip(
          avatar: const Icon(Icons.event_outlined, size: 18),
          label: Text(label),
          onDeleted: onClear,
          deleteButtonTooltipMessage: 'events_clear_date'.tr(),
        ),
      ),
    );
  }
}

/// Events grouped by day in chronological order; undated events last.
class _Timeline extends StatelessWidget {
  const _Timeline({
    required this.events,
    required this.locale,
    required this.now,
    required this.onOpen,
    this.notificationsBlocked,
  });

  final List<EventItem> events;
  final String locale;
  final DateTime now;
  final ValueChanged<EventItem> onOpen;
  final NotificationsBlockedCheck? notificationsBlocked;

  String? _relative(EventItem e) => switch (eventTiming(e.date, now)) {
    EventToday() => 'dash_countdown_today'.tr(),
    EventTomorrow() => 'dash_countdown_tomorrow'.tr(),
    EventInDays(:final days) => 'dash_countdown_days'.tr(args: ['$days']),
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final groups = <({String key, List<EventItem> items})>[];
    for (final e in events) {
      final key = e.day?.toIso8601String() ?? 'tba';
      if (groups.isEmpty || groups.last.key != key) {
        groups.add((key: key, items: [e]));
      } else {
        groups.last.items.add(e);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var g = 0; g < groups.length; g++) ...[
          if (g > 0) AppSpacing.gapLg,
          TimelineDateHeader(
            label:
                formatEventDate(groups[g].items.first.date, locale) ??
                'events_date_tba'.tr(),
            relative: _relative(groups[g].items.first),
          ),
          for (var i = 0; i < groups[g].items.length; i++)
            TimelineEventTile(
              event: groups[g].items[i],
              locale: locale,
              now: now,
              isLast: i == groups[g].items.length - 1,
              onOpen: () => onOpen(groups[g].items[i]),
              notificationsBlocked: notificationsBlocked,
            ),
        ],
      ],
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'common_loading'.tr(),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: context.colorScheme.surfaceContainerHigh,
          borderRadius: AppRadius.cardAll,
        ),
      ),
    );
  }
}
