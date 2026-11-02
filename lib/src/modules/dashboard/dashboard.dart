import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kumbha_path/src/modules/emergency/widgets/sos_parts.dart';
import 'package:kumbha_path/src/modules/notification_centre/notification_centre_screen.dart';
import 'package:kumbha_path/src/modules/operations/ops_home_screen.dart';
import 'package:kumbha_path/src/modules/reunion/reunion_map_screen.dart';
import 'package:kumbha_path/src/modules/location/data/location_tracker.dart';
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
import 'package:kumbha_path/src/modules/dashboard/widgets/explore_hub.dart';
import 'package:kumbha_path/src/modules/dashboard/widgets/featured_event_card.dart';
import 'package:kumbha_path/src/modules/dashboard/widgets/nearby_temples_section.dart';
import 'package:kumbha_path/src/modules/dashboard/widgets/upcoming_events_section.dart';
import 'package:kumbha_path/src/modules/dashboard/widgets/welcome_hero.dart';
import 'package:kumbha_path/src/modules/family/invite_links.dart';
import 'package:kumbha_path/src/modules/family/widgets/family_dashboard_entry.dart';
import 'package:kumbha_path/src/modules/journey/models/journey_models.dart';
import 'package:kumbha_path/src/modules/lostfound/lostfound_home_screen.dart';
import 'package:kumbha_path/src/modules/journey/widgets/journey_dashboard_panel.dart';
import 'package:kumbha_path/src/modules/patrika/widgets/discover_panel.dart';
import 'package:kumbha_path/src/services/notification_router.dart';
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

    // A notification tapped while the app was starting opens now.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationRouter.consumePending();
      InviteLinkRouter.consumePending();
      // Carries on a session this person already agreed to.
      final tracker = LocationSharing.tracker
        ..notificationTitle = 'loc_notification_title'.tr()
        ..notificationText = 'loc_notification_text'.tr();
      tracker.start();
      // Operational accounts go to their own dashboard. Pilgrims see no change.
      openOperationsIfAllowed(Navigator.of(context));
    });

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

  /// New plan from the dashboard: the form, then the saved plan.
  Future<void> _createJourney() async {
    final created = await Navigator.of(context).pushNamed('/journeyForm');
    if (!mounted || created is! JourneyPlan) return;
    _push('/journeyDetail', arguments: created.id);
  }

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
          const NotificationBell(),
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
      // Greeting with the AI Guru bar.
      BlocSelector<UserBloc, UserState, String?>(
        selector: (state) => state.profileData?.fullName,
        builder:
            (context, name) =>
                WelcomeHero(fullName: name, onAsk: () => _push('/aichat')),
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

      // Journey planning, crowd, temples, events and journal share one panel: every feature
      // is visible as a tab, but only one preview takes space. (Updates
      // are the bell in the app bar.)
      AppSpacing.gapSm,
      // Side by side, so safety tools add one line to the first screen.
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: FamilyDashboardEntry(
                onOpen: () => Navigator.of(context).pushNamed('/family'),
              ),
            ),
            AppSpacing.gapSm,
            Expanded(
              child: LostFoundDashboardEntry(onOpen: () => _push('/lostFound')),
            ),
          ],
        ),
      ),
      AppSpacing.gapXs,
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ReunionDashboardEntry(
                onOpen: () => _push('/reunionMap'),
              ),
            ),
            AppSpacing.gapSm,
            Expanded(child: SosDashboardEntry(onOpen: () => _push('/sos'))),
          ],
        ),
      ),
      AppSpacing.gapSm,
      // Plan sits first; Crowd (live, safety-related) stays selected.
      ExploreHub(
        initialIndex: 1,
        tabs: [
          ExploreTab(
            icon: Icons.route_outlined,
            labelKey: 'dash_tab_plan',
            builder:
                (context) => JourneyDashboardPanel(
                  onOpenList: () => _push('/journeys'),
                  onOpen: (id) => _push('/journeyDetail', arguments: id),
                  onCreate: _createJourney,
                ),
          ),
          ExploreTab(
            icon: Icons.groups_outlined,
            labelKey: 'dash_tab_crowd',
            builder:
                (context) => FeedBuilder(
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
          ExploreTab(
            icon: Icons.temple_hindu_outlined,
            labelKey: 'dash_tab_temples',
            actionLabelKey: 'dash_see_all',
            onAction: _exploreTemples,
            builder:
                (context) => NearbyTemplesSection(
                  showHeader: false,
                  access: c.locationAccess,
                  templesBloc: c.templesBloc,
                  locale: locale,
                  onAllowLocation: () async {
                    await c.requestLocation();
                    if (mounted &&
                        c.locationAccess.value != LocationAccess.available) {
                      _showLocationError();
                    }
                  },
                  onRetry: c.loadTemples,
                  onOpenTemple: _openTemple,
                  onSeeAll:
                      () => _push('/nearTemples', arguments: _positionArgs),
                ),
          ),
          ExploreTab(
            icon: Icons.event_outlined,
            labelKey: 'dash_tab_events',
            actionLabelKey: 'dash_see_all',
            onAction: () => _push('/shahiEvents'),
            builder:
                (context) => FeedBuilder(
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
                                  c
                                      .featured
                                      .bloc
                                      .state
                                      .eventDetailsModel
                                      .eventId,
                              locale: locale,
                              onTap: () => _push('/shahiEvents'),
                            ),
                      ),
                ),
          ),
          ExploreTab(
            icon: Icons.auto_stories_outlined,
            labelKey: 'dash_tab_discover',
            builder: (context) => DiscoverPanel(onOpen: _push),
          ),
          ExploreTab(
            icon: Icons.menu_book_outlined,
            labelKey: 'dash_tab_journal',
            builder:
                (context) => FeedBuilder(
                  feed: c.journal,
                  loading: const SkeletonBlock(height: 160),
                  builder:
                      (context) => JournalPreviewCard(
                        entries:
                            c
                                .journal
                                .bloc
                                .state
                                .journalEntryListModel
                                ?.results ??
                            const [],
                        locale: locale,
                        onOpen: () => _push('/journal'),
                      ),
                ),
          ),
        ],
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

      AppSpacing.gapLg,
      const PilgrimTip(),
    ];
  }
}

class _BrandTitle extends StatelessWidget {
  const _BrandTitle();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const AppLogo(size: 36),
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
