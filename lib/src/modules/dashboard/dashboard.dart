import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kumbha_path/main_layout.dart';
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_bloc.dart';
import 'package:kumbha_path/src/bloc/app_details_bloc/app_details_event.dart';
import 'package:kumbha_path/src/bloc/main_bloc/app_bloc.dart';
import 'package:kumbha_path/src/bloc/main_bloc/app_state.dart';
import 'package:kumbha_path/src/bloc/user_bloc/user_bloc.dart';
import 'package:kumbha_path/src/bloc/user_bloc/user_event.dart';
import 'package:kumbha_path/src/bloc/user_bloc/user_state.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/constant/language_helper.dart';
import 'package:kumbha_path/src/models/near_temple.dart';
import 'package:kumbha_path/src/modules/dashboard/dashboard_controller.dart';
import 'package:kumbha_path/src/modules/dashboard/widgets/companion_cards.dart';
import 'package:kumbha_path/src/modules/dashboard/widgets/crowd_summary.dart';
import 'package:kumbha_path/src/modules/dashboard/widgets/dashboard_section.dart';
import 'package:kumbha_path/src/modules/dashboard/widgets/featured_event_card.dart';
import 'package:kumbha_path/src/modules/dashboard/widgets/nearby_temples_section.dart';
import 'package:kumbha_path/src/modules/dashboard/widgets/quick_actions.dart';
import 'package:kumbha_path/src/modules/dashboard/widgets/upcoming_events_section.dart';
import 'package:kumbha_path/src/modules/dashboard/widgets/welcome_hero.dart';
import 'package:kumbha_path/src/modules/temple_explorer/temple_detail_screen.dart'
    show TempleDetailArgs;

/// Home tab: the pilgrim's overview of the Nashik Kumbh.
///
/// Section order follows what a pilgrim needs first: where they are and
/// what's next (welcome, active alerts, featured event), how to get around
/// (quick actions, crowd status, nearby temples), then planning and
/// reflection (upcoming events, AI Explorer, journal).
class Dashboard extends StatefulWidget {
  const Dashboard({super.key, this.controller});

  /// Injected in tests; created from the app-wide blocs otherwise.
  final DashboardController? controller;

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  late final DashboardController _controller;
  late final bool _ownsController;

  static const double _maxContentWidth = 720;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller =
        widget.controller ??
        DashboardController(templesBloc: context.read<AppBloc>());
    _controller.start();

    // Greeting name: reuse a profile already loaded (e.g. by Settings),
    // otherwise make the same request Settings makes.
    final user = context.read<UserBloc>();
    final hasName = (user.state.profileData?.fullName ?? '').trim().isNotEmpty;
    if (!hasName && user.state.status != UserStatus.loading) {
      user.add(ProfileGetEvent(status: UserStatus.profileLoaded));
    }
  }

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  // ---- Navigation (existing routes and flows) ----

  void _push(String route, {Object? arguments}) =>
      Navigator.pushNamed(context, route, arguments: arguments);

  void _showLocationError() {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('dash_location_error'.tr())));
  }

  Map<String, String>? get _positionArgs {
    final pos = _controller.position;
    if (pos == null) return null;
    return {'lat': pos.latitude.toString(), 'lng': pos.longitude.toString()};
  }

  /// Same flow as the previous Temple Explorer card: get location, load
  /// nearby temples into the shared AppBloc, open `/nearTemples` with the
  /// coordinates. Now reports a failure instead of throwing silently.
  Future<void> _exploreTemples() async {
    if (!await _controller.ensurePosition()) {
      if (mounted) _showLocationError();
      return;
    }
    if (!mounted) return;
    final alreadyLoaded =
        _controller.templesBloc.state.status == AppStatus.success;
    if (!alreadyLoaded) _controller.loadTemples();
    _push('/nearTemples', arguments: _positionArgs);
  }

  /// Same flow as the Temple Explorer list: request the detail into the
  /// shared AppDetailsBloc, then open `/templeDetail`.
  void _openTemple(TempleModel temple) {
    final pos = _controller.position;
    final args = TempleDetailArgs(
      templeId: temple.templeId.toString(),
      latitude: pos?.latitude.toString() ?? '',
      longitude: pos?.longitude.toString() ?? '',
    );
    context.read<AppDetailsBloc>().add(
      GetTempleDetail(
        templeId: args.templeId,
        latitude: args.latitude,
        longitude: args.longitude,
      ),
    );
    _push('/templeDetail', arguments: args);
  }

  // ---- Build ----

  @override
  Widget build(BuildContext context) {
    // Depend on the app locale so every section re-translates on change.
    final locale =
        EasyLocalization.of(context)?.locale.languageCode ??
        Localizations.localeOf(context).languageCode;

    return MainLayout(
      showDefaultBottom: true,
      ctx: 0,
      appBar: AppAppBar(
        titleWidget: const _BrandTitle(),
        actions: [
          AppIconButton(
            icon: Icons.notifications_none_rounded,
            tooltip: 'dash_notifications'.tr(),
            onPressed: () => _push('/notifications'),
          ),
          const LanguageIconButton(),
          AppSpacing.gapXs,
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _controller.refresh,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final side = math.max(
              AppSpacing.pageGutter,
              (constraints.maxWidth - _maxContentWidth) / 2,
            );
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                side,
                AppSpacing.sm,
                side,
                AppSpacing.huge,
              ),
              children: _sections(locale),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _sections(String locale) {
    final c = _controller;
    return [
      BlocSelector<UserBloc, UserState, String?>(
        selector: (state) => state.profileData?.fullName,
        builder: (context, name) => WelcomeHero(fullName: name),
      ),

      // Real alerts only; nothing is rendered while loading, on failure or
      // when there are none.
      ValueListenableBuilder<FeedStatus>(
        valueListenable: c.alerts.status,
        builder: (context, status, _) {
          if (status != FeedStatus.ready) return const SizedBox.shrink();
          final alerts = c.alerts.bloc.state.quickAlerts;
          if (alerts.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: AppSpacing.lg),
            child: ActiveAlertBanner(
              alerts: alerts,
              onTap: () => _push('/liveCroud'),
            ),
          );
        },
      ),

      // Featured event: hidden when the backend features nothing.
      ValueListenableBuilder<FeedStatus>(
        valueListenable: c.featured.status,
        builder: (context, status, _) {
          final event = c.featured.bloc.state.eventDetailsModel;
          if (status == FeedStatus.ready &&
              !FeaturedEventCard.hasContent(event)) {
            return const SizedBox.shrink();
          }
          return Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sectionGap),
            child: FeedBuilder(
              feed: c.featured,
              loading: const SkeletonBlock(height: 240),
              builder:
                  (context) => FeaturedEventCard(
                    event: event,
                    locale: locale,
                    onViewEvents: () => _push('/shahiEvents'),
                  ),
            ),
          );
        },
      ),

      _gap,
      DashboardSection(
        title: 'dash_quick_actions'.tr(),
        child: QuickActions(
          actions: [
            QuickAction(
              icon: Icons.temple_hindu_outlined,
              labelKey: 'dash_action_temples',
              onTap: _exploreTemples,
            ),
            QuickAction(
              icon: Icons.groups_outlined,
              labelKey: 'dash_action_crowd',
              onTap: () => _push('/liveCroud'),
            ),
            QuickAction(
              icon: Icons.event_outlined,
              labelKey: 'dash_action_events',
              onTap: () => _push('/shahiEvents'),
            ),
            QuickAction(
              icon: Icons.campaign_outlined,
              labelKey: 'dash_action_updates',
              onTap: () => _push('/notifications'),
            ),
          ],
        ),
      ),

      _gap,
      DashboardSection(
        title: 'dash_crowd_title'.tr(),
        child: FeedBuilder(
          feed: c.crowd,
          loading: const SkeletonBlock(height: 200),
          builder:
              (context) => CrowdSummaryCard(
                zones: c.crowd.bloc.state.zoneModel,
                checkedAt: c.crowd.lastUpdated,
                locale: locale,
                onOpenMap: () => _push('/liveCroud'),
              ),
        ),
      ),
      AppSpacing.gapMd,
      const PilgrimTip(),

      _gap,
      NearbyTemplesSection(
        access: c.locationAccess,
        templesBloc: c.templesBloc,
        locale: locale,
        onAllowLocation: () async {
          await c.requestLocation();
          if (mounted && c.locationAccess.value != LocationAccess.available) {
            _showLocationError();
          }
        },
        onRetry: c.loadTemples,
        onOpenTemple: _openTemple,
        onSeeAll: () => _push('/nearTemples', arguments: _positionArgs),
      ),

      _gap,
      DashboardSection(
        title: 'dash_upcoming_title'.tr(),
        actionLabel: 'dash_see_all'.tr(),
        onAction: () => _push('/shahiEvents'),
        child: FeedBuilder(
          feed: c.upcoming,
          loading: const SkeletonBlock(height: 180),
          builder:
              (context) => ValueListenableBuilder<FeedStatus>(
                // Re-filter once the featured event is known.
                valueListenable: c.featured.status,
                builder:
                    (context, _, __) => UpcomingEventsList(
                      events: c.upcoming.bloc.state.upcomingEvents,
                      excludeEventId:
                          c.featured.bloc.state.eventDetailsModel.eventId,
                      locale: locale,
                      onTap: () => _push('/shahiEvents'),
                    ),
              ),
        ),
      ),

      _gap,
      AiExplorerCard(onOpen: () => _push('/aichat')),

      _gap,
      DashboardSection(
        title: 'dash_journal_title'.tr(),
        child: FeedBuilder(
          feed: c.journal,
          loading: const SkeletonBlock(height: 160),
          builder:
              (context) => JournalPreviewCard(
                entries:
                    c.journal.bloc.state.journalEntryListModel?.results ??
                    const [],
                locale: locale,
                onOpen: () => _push('/journal'),
              ),
        ),
      ),
    ];
  }

  static const Widget _gap = SizedBox(
    height: AppSpacing.sectionGap + AppSpacing.sm,
  );
}

class _BrandTitle extends StatelessWidget {
  const _BrandTitle();

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.xs + AppSpacing.xxs),
          decoration: BoxDecoration(
            color: colors.primary,
            borderRadius: AppRadius.smAll,
          ),
          child: Icon(
            Icons.temple_hindu_rounded,
            size: 20,
            color: colors.onPrimary,
          ),
        ),
        AppSpacing.gapSm,
        Flexible(
          child: Text(
            'app_title'.tr(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
