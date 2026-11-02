import 'dart:async';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/components/maps/app_map.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/modules/family/data/family_repository.dart';
import 'package:kumbha_path/src/modules/family/family_home_screen.dart'
    show FamilyArgs;
import 'package:kumbha_path/src/modules/family/models/family_models.dart';
import 'package:kumbha_path/src/modules/family/widgets/family_parts.dart';
import 'package:kumbha_path/src/modules/journey/widgets/journey_ui.dart'
    show confirmJourneyAction, showJourneySnack;
import 'package:kumbha_path/src/modules/location/data/location_repository.dart';
import 'package:kumbha_path/src/modules/location/data/location_tracker.dart';
import 'package:kumbha_path/src/modules/location/models/location_models.dart';
import 'package:kumbha_path/src/modules/location/widgets/location_parts.dart';
import 'package:kumbha_path/src/modules/lostfound/models/lf_models.dart';
import 'package:kumbha_path/src/modules/lostfound/widgets/lf_parts.dart'
    show dateTimeText;
import 'package:kumbha_path/src/modules/reunion/data/reunion_repository.dart';
import 'package:kumbha_path/src/modules/reunion/models/reunion_models.dart';
import 'package:kumbha_path/src/modules/reunion/point_explorer_screen.dart';
import 'package:kumbha_path/src/modules/reunion/route_preview_screen.dart'
    show PointExplorerArgs;
import 'package:kumbha_path/src/modules/reunion/widgets/reunion_parts.dart';

enum MapLayer { people, cases, help, meeting }

/// What's selected on the map.
sealed class _Selection {
  const _Selection();
}

class _PersonSelected extends _Selection {
  const _PersonSelected(this.id);
  final String id;
}

class _PointSelected extends _Selection {
  const _PointSelected(this.point);
  final MeetingPoint point;
}

class _CaseSelected extends _Selection {
  const _CaseSelected(this.item);
  final CaseMarker item;
}

class _SightingSelected extends _Selection {
  const _SightingSelected(this.item, this.sighting);
  final CaseMarker item;
  final Sighting sighting;
}

/// `/reunionMap`: everything a separated family may see, in one place.
///
/// It reads the existing location feed and Lost & Found rules through the
/// server, so what's shown is exactly what each of those allows. Positions are
/// held in memory and are never moved or estimated between updates.
class ReunionMapScreen extends StatefulWidget {
  const ReunionMapScreen({
    super.key,
    this.args,
    this.familyId,
    this.pointId,
    this.repository,
    this.locations,
    this.familyRepository,
    this.tracker,
  });

  final FamilyArgs? args;
  final String? familyId;

  /// A point a family member shared, to open straight away.
  final String? pointId;
  final ReunionRepository? repository;
  final LocationRepository? locations;
  final FamilyRepository? familyRepository;
  final LocationTracker? tracker;

  @override
  State<ReunionMapScreen> createState() => _ReunionMapScreenState();
}

class _ReunionMapScreenState extends State<ReunionMapScreen>
    with WidgetsBindingObserver {
  late final ReunionRepository _repo =
      widget.repository ?? ReunionServices.repository;
  late final LocationRepository _locations =
      widget.locations ?? LocationServices.repository;
  late final FamilyRepository _family =
      widget.familyRepository ?? FamilyServices.repository;
  late final LocationTracker _tracker =
      widget.tracker ?? LocationSharing.tracker;

  FamilyCircle? _circle;
  LocationFeed? _feed;
  ReunionOverview? _overview;
  List<MeetingPoint> _points = const [];
  DateTime? _pointsSavedAt;
  DateTime? _lastUpdate;
  bool _loading = true;
  bool _refreshing = false;
  int _failures = 0;
  Object? _error;
  final _layers = {...MapLayer.values};
  _Selection? _selected;
  GoogleMapController? _map;
  bool _fitted = false;
  Timer? _timer;
  final _icons = <String, BitmapDescriptor>{};

  bool get _selfProtected => _overview?.selfProtected ?? false;

  List<CaseMarker> get _cases => _overview?.cases ?? const [];

  bool get _anyProtected => _selfProtected || _cases.any((c) => c.isProtected);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tracker.addListener(_changed);
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tracker.removeListener(_changed);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_poll());
    } else {
      _timer?.cancel();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      var circle = widget.args?.circle;
      if (circle == null) {
        final circles = await _family.circles();
        final wanted = widget.familyId ?? widget.args?.circle.id;
        circle =
            circles.where((c) => c.id == wanted).firstOrNull ??
            circles.firstOrNull;
      }
      _circle = circle;
    } catch (_) {
      // Help points still work without the family.
    }
    final id = _circle?.id;
    if (id != null) _feed = LocationServices.lastFeed[id];
    _overview = ReunionServices.lastOverview;
    await _loadPoints();
    await _poll();
    _openSharedPoint();
  }

  /// Public points survive without a connection, with the date they were saved.
  Future<void> _loadPoints() async {
    try {
      final points = await _repo.points();
      await ReunionServices.saved.save(points);
      _points = points;
      _pointsSavedAt = null;
    } catch (_) {
      final saved = await ReunionServices.saved.load();
      if (saved != null) {
        _points = saved.points;
        _pointsSavedAt = saved.savedAt;
      }
    }
  }

  void _openSharedPoint() {
    final id = widget.pointId;
    if (id == null || !mounted) return;
    final point = _points.where((p) => p.id == id).firstOrNull;
    if (point != null) _select(_PointSelected(point));
  }

  Future<void> _poll() async {
    _timer?.cancel();
    if (!mounted) return;
    setState(() => _refreshing = true);
    final id = _circle?.id;
    Object? problem;
    LocationFeed? feed;
    ReunionOverview? overview;
    // Each source fails alone, so partial data still shows.
    try {
      if (id != null) feed = await _locations.feed(id);
    } catch (e) {
      problem = e;
    }
    try {
      overview = await _repo.overview(familyId: id);
    } catch (e) {
      problem ??= e;
    }
    if (!mounted) return;
    if (feed != null) LocationServices.lastFeed[id!] = feed;
    if (overview != null) ReunionServices.lastOverview = overview;
    await _drawIcons(feed ?? _feed, overview ?? _overview);
    if (!mounted) return;
    setState(() {
      _feed = feed ?? _feed;
      _overview = overview ?? _overview;
      _loading = false;
      _refreshing = false;
      if (problem == null) {
        _failures = 0;
        _lastUpdate = DateTime.now();
      } else {
        _failures++;
        if (_feed == null && _overview == null && _points.isEmpty) {
          _error = problem;
        }
      }
    });
    _fitOnce();
    final base = _feed?.pollSeconds ?? 20;
    final wait = (base * (1 << _failures.clamp(0, 3))).clamp(base, 120);
    _timer = Timer(Duration(seconds: wait), () {
      if (mounted) unawaited(_poll());
    });
  }

  String _pointIcon(MeetingPoint p) =>
      'point|${p.category}|${p.isVerified ? 'solid' : 'open'}';

  bool _isHelp(MeetingPoint p) => p.isVerified && !p.isFamilySpot;

  Future<void> _drawIcons(LocationFeed? feed, ReunionOverview? overview) async {
    final context = this.context;
    final s = context.semanticColors;
    final colors = context.colorScheme;
    final now = DateTime.now();
    for (final person in feed?.people ?? const <LocationPerson>[]) {
      final freshness = person.freshnessAt(now);
      _icons['${person.memberId}|${freshness.name}'] =
          await LocationMarkers.pin(
            initials: initialsOf(person.name),
            ring: freshnessColor(context, freshness),
            fill: colors.primary,
            text: colors.onPrimary,
            current: freshness == Freshness.live,
          );
    }
    for (final p in _points) {
      _icons[_pointIcon(p)] = await ReunionMarkers.icon(
        shape: _isHelp(p) ? MarkerShape.helpPoint : MarkerShape.meetingSpot,
        glyph: categoryIcon(p.category),
        color: _isHelp(p) ? s.success : s.warning,
        onColor: s.onSuccess,
      );
    }
    _icons['last_seen'] = await ReunionMarkers.icon(
      shape: MarkerShape.lastSeen,
      glyph: Icons.person_search_rounded,
      color: colors.error,
      onColor: colors.onError,
    );
    _icons['sighting_reported'] = await ReunionMarkers.icon(
      shape: MarkerShape.sightingReported,
      glyph: Icons.visibility_outlined,
      color: colors.error,
      onColor: colors.onError,
    );
    _icons['sighting_verified'] = await ReunionMarkers.icon(
      shape: MarkerShape.sightingVerified,
      glyph: Icons.visibility_outlined,
      color: colors.error,
      onColor: colors.onError,
    );
  }

  List<LocationPerson> _people(DateTime now) {
    final feed = _feed;
    return feed == null ? const [] : feed.visibleAt(now);
  }

  bool _placeable(LocationPerson p, DateTime now) =>
      p.hasPosition &&
      const {
        Freshness.live,
        Freshness.recent,
        Freshness.lastKnown,
      }.contains(p.freshnessAt(now));

  Set<Marker> _markers(DateTime now) {
    Marker marker(String id, LatLng at, String icon, _Selection selection) =>
        Marker(
          markerId: MarkerId(id),
          position: at,
          icon: _icons[icon] ?? BitmapDescriptor.defaultMarker,
          consumeTapEvents: true,
          onTap: () => _select(selection),
        );
    return {
      if (_layers.contains(MapLayer.people))
        for (final p in _people(now))
          if (_placeable(p, now))
            marker(
              'person:${p.memberId}',
              LatLng(p.latitude!, p.longitude!),
              '${p.memberId}|${p.freshnessAt(now).name}',
              _PersonSelected(p.memberId),
            ),
      for (final p in _points)
        if (_layers.contains(_isHelp(p) ? MapLayer.help : MapLayer.meeting))
          marker(
            'point:${p.id}',
            LatLng(p.latitude, p.longitude),
            _pointIcon(p),
            _PointSelected(p),
          ),
      if (_layers.contains(MapLayer.cases))
        for (final c in _cases) ...[
          if (c.hasPlace)
            marker(
              'case:${c.id}',
              LatLng(c.latitude!, c.longitude!),
              'last_seen',
              _CaseSelected(c),
            ),
          for (final s in c.sightings)
            if (s.latitude != null && s.longitude != null)
              marker(
                'sighting:${s.id}',
                LatLng(s.latitude!, s.longitude!),
                s.verified ? 'sighting_verified' : 'sighting_reported',
                _SightingSelected(c, s),
              ),
        ],
    };
  }

  void _fitOnce() {
    if (_fitted || _map == null) return;
    if (_markers(DateTime.now()).isEmpty) return;
    _fitted = true;
    _fitAll();
  }

  void _fitAll() {
    final map = _map;
    final points = [for (final m in _markers(DateTime.now())) m.position];
    if (map == null || points.isEmpty) return;
    final lats = points.map((p) => p.latitude);
    final lngs = points.map((p) => p.longitude);
    final south = lats.reduce((a, b) => a < b ? a : b);
    final north = lats.reduce((a, b) => a > b ? a : b);
    final west = lngs.reduce((a, b) => a < b ? a : b);
    final east = lngs.reduce((a, b) => a > b ? a : b);
    if (south == north && west == east) {
      map.animateCamera(CameraUpdate.newLatLngZoom(points.first, 16));
      return;
    }
    map.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(south, west),
          northeast: LatLng(north, east),
        ),
        80,
      ),
    );
  }

  void _select(_Selection selection) {
    setState(() => _selected = selection);
  }

  void _toggle(MapLayer layer) {
    setState(() {
      _layers.contains(layer) ? _layers.remove(layer) : _layers.add(layer);
      _selected = null;
    });
  }

  void _showLegend() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const _LegendSheet(),
    );
  }

  void _showSafety() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder:
          (sheet) => SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(editorialMargin),
              child: SafetyPanel(
                selfProtected: _selfProtected,
                action: AppButton(
                  label: 're_find_help'.tr(),
                  leadingIcon: Icons.support_agent_rounded,
                  onPressed: () {
                    Navigator.pop(sheet);
                    _openExplorer(safeOnly: true);
                  },
                ),
              ),
            ),
          ),
    );
  }

  Future<void> _openExplorer({bool safeOnly = false, String? caseId}) async {
    await Navigator.pushNamed(
      context,
      '/reunionPoints',
      arguments: PointExplorerArgs(
        safeOnly: safeOnly,
        caseId: caseId,
        familyId: _circle?.id,
      ),
    );
    if (!mounted) return;
    await _loadPoints();
    await _poll();
  }

  Future<void> _notifyFamily() async {
    final id = _circle?.id;
    if (id == null) return;
    final sure = await confirmJourneyAction(
      context,
      title: 're_nudge_title'.tr(),
      message: 're_nudge_body'.tr(),
      confirm: 're_send'.tr(),
    );
    if (!sure) return;
    try {
      await _repo.notifyFamily(id, 'check_map');
      if (mounted) showJourneySnack(context, 're_shared'.tr());
    } catch (e) {
      if (mounted) showJourneySnack(context, reunionErrorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _feed == null && _overview == null && _points.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text('re_map_title'.tr())),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final failed = _error;
    if (failed != null) {
      return Scaffold(
        appBar: AppBar(title: Text('re_map_title'.tr())),
        body: AppErrorView(message: reunionErrorText(failed), onRetry: _load),
      );
    }
    final now = DateTime.now();
    final markers = _markers(now);
    final everything =
        _points.isNotEmpty || _cases.isNotEmpty || _people(now).isNotEmpty;
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child:
                markers.isEmpty
                    ? ColoredBox(color: context.colorScheme.surfaceContainer)
                    : AppMap(
                      config: AppMapConfig(
                        target: markers.first.position,
                        zoom: 14,
                        markers: markers,
                        showMyLocation: _tracker.collecting,
                        padding: const EdgeInsets.only(top: 170, bottom: 240),
                        onMapCreated: (controller) {
                          _map = controller;
                          _fitOnce();
                        },
                        onTap: (_) => setState(() => _selected = null),
                      ),
                    ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.sm,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _RoundButton(
                        icon: Icons.arrow_back_rounded,
                        tooltip:
                            MaterialLocalizations.of(context).backButtonTooltip,
                        onTap: () => Navigator.maybePop(context),
                      ),
                      AppSpacing.gapSm,
                      Expanded(child: _heading()),
                      AppSpacing.gapSm,
                      _RoundButton(
                        icon: Icons.layers_outlined,
                        tooltip: 're_legend'.tr(),
                        onTap: _showLegend,
                      ),
                    ],
                  ),
                  AppSpacing.gapSm,
                  _LayerChips(layers: _layers, onToggle: _toggle),
                  if (_anyProtected) ...[
                    AppSpacing.gapSm,
                    _SafetyBanner(
                      selfProtected: _selfProtected,
                      onTap: _showSafety,
                    ),
                  ],
                ],
              ),
            ),
          ),
          PositionedDirectional(
            end: AppSpacing.sm,
            top: MediaQuery.paddingOf(context).top + 200,
            child: Column(
              children: [
                _RoundButton(
                  icon: Icons.fit_screen_rounded,
                  tooltip: 'loc_fit_all'.tr(),
                  onTap: _fitAll,
                ),
                AppSpacing.gapSm,
                _RoundButton(
                  icon: Icons.refresh_rounded,
                  tooltip: 'loc_refresh'.tr(),
                  onTap: _refreshing ? null : _poll,
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _BottomSheet(
              child:
                  _selected != null
                      ? _panel(_selected!, now)
                      : _summary(now, everything),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heading() {
    final e = context.editorial;
    final last = _lastUpdate;
    final line =
        _failures == 0
            ? 'loc_not_realtime'.tr()
            : last == null
            ? 're_offline_none'.tr()
            : 're_offline_since'.tr(
              args: [TimeOfDay.fromDateTime(last).format(context)],
            );
    return Material(
      color: context.colorScheme.surface,
      elevation: 2,
      borderRadius: AppRadius.lgAll,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              header: true,
              child: Text(
                're_map_title'.tr(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: e.title,
              ),
            ),
            Text(line, style: e.meta),
          ],
        ),
      ),
    );
  }

  Widget _summary(DateTime now, bool anything) {
    final e = context.editorial;
    final people = _people(now);
    final circle = _circle;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!anything) ...[
          Text('re_empty_title'.tr(), style: e.title),
          AppSpacing.gapXs,
          Text('re_empty_body'.tr(), style: e.meta),
          AppSpacing.gapSm,
        ],
        if (_pointsSavedAt != null) ...[
          Text(
            're_points_saved'.tr(
              args: [dateTimeText(context, _pointsSavedAt!)],
            ),
            style: e.meta,
          ),
          AppSpacing.gapSm,
        ],
        for (final c in _cases.take(2))
          _CaseStrip(item: c, onTap: () => _select(_CaseSelected(c))),
        if (people.isNotEmpty && circle != null) ...[
          SizedBox(
            height: MediaQuery.textScalerOf(context).scale(38) + 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: people.length,
              separatorBuilder: (_, __) => AppSpacing.gapSm,
              itemBuilder: (context, index) {
                final person = people[index];
                final freshness = person.freshnessAt(now);
                final name =
                    person.isMe
                        ? 'loc_you'.tr()
                        : person.name.trim().split(RegExp(r'\s+')).first;
                return SizedBox(
                  width: 84,
                  child: Pressable(
                    onTap: () => _select(_PersonSelected(person.memberId)),
                    label: '$name, ${freshnessLabel(freshness)}',
                    child: ExcludeSemantics(
                      child: Column(
                        children: [
                          PersonBadge(
                            person: person,
                            familyId: circle.id,
                            freshness: freshness,
                            repository: _family,
                          ),
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: e.meta,
                          ),
                          Text(
                            freshnessLabel(freshness),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: e.meta.copyWith(
                              color: freshnessColor(context, freshness),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          AppSpacing.gapSm,
        ],
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 're_find_safe'.tr(),
                leadingIcon: Icons.support_agent_rounded,
                onPressed: () => _openExplorer(safeOnly: _anyProtected),
              ),
            ),
            if (circle != null) ...[
              AppSpacing.gapSm,
              _RoundButton(
                icon: Icons.campaign_outlined,
                tooltip: 're_nudge_title'.tr(),
                onTap: _notifyFamily,
              ),
              AppSpacing.gapSm,
              _RoundButton(
                icon: Icons.share_location_rounded,
                tooltip: 'loc_manage'.tr(),
                onTap:
                    () => Navigator.pushNamed(
                      context,
                      '/locationSharing',
                      arguments: FamilyArgs(circle),
                    ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _panel(_Selection selection, DateTime now) {
    void close() => setState(() => _selected = null);
    return switch (selection) {
      _PersonSelected(:final id) => _personPanel(id, now, close),
      _PointSelected(:final point) => _pointPanel(point, close),
      _CaseSelected(:final item) => _casePanel(item, close),
      _SightingSelected(:final item, :final sighting) => _sightingPanel(
        item,
        sighting,
        close,
      ),
    };
  }

  Widget _title(String text, Widget tag, VoidCallback close) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.editorial.title,
              ),
              tag,
            ],
          ),
        ),
        IconButton(
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          icon: const Icon(Icons.close_rounded),
          onPressed: close,
        ),
      ],
    );
  }

  Widget _personPanel(String id, DateTime now, VoidCallback close) {
    final e = context.editorial;
    final person = _people(now).where((p) => p.memberId == id).firstOrNull;
    if (person == null) {
      // Their sharing ended while this was open. Nothing of it stays on screen.
      WidgetsBinding.instance.addPostFrameCallback((_) => close());
      return const SizedBox.shrink();
    }
    final freshness = person.freshnessAt(now);
    final age = person.ageSeconds;
    final seen =
        age == null ? null : age + now.difference(person.fetchedAt).inSeconds;
    final accuracy = person.accuracyM;
    final caseId = person.caseId;
    final circle = _circle;
    final protectedCase =
        _cases
            .where((c) => c.memberId == person.memberId && c.isProtected)
            .isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title(
          person.isMe ? 'loc_you'.tr() : person.name,
          FreshnessTag(freshness),
          close,
        ),
        MetaLine([
          if (seen != null) 'loc_updated'.tr(args: [agoText(seen)]),
          if (accuracy != null) accuracyText(accuracy),
        ]),
        if (freshness == Freshness.lastKnown)
          Text('loc_may_have_moved'.tr(), style: e.meta),
        if (protectedCase) ...[
          AppSpacing.gapSm,
          FamilyNote(text: 're_caution_stay_put'.tr()),
        ],
        AppSpacing.gapSm,
        if (_selfProtected)
          AppButton(
            label: 're_find_help'.tr(),
            leadingIcon: Icons.support_agent_rounded,
            onPressed: () => _openExplorer(safeOnly: true),
          )
        else if (person.hasPosition && !person.isMe)
          AppButton(
            label: 're_route'.tr(),
            leadingIcon: Icons.directions_walk_rounded,
            onPressed:
                () => Navigator.pushNamed(
                  context,
                  '/reunionRoute',
                  arguments: RouteTarget(
                    kind: 'member',
                    id: person.memberId,
                    name: person.name,
                    latitude: person.latitude!,
                    longitude: person.longitude!,
                  ),
                ),
          ),
        if (circle != null && !person.isMe)
          TextButton(
            onPressed:
                () => Navigator.pushNamed(
                  context,
                  '/familyMember',
                  arguments: FamilyArgs(circle, memberId: person.memberId),
                ),
            child: Text('re_member_details'.tr()),
          ),
        if (caseId != null)
          TextButton(
            onPressed:
                () => Navigator.pushNamed(
                  context,
                  '/reunionCase',
                  arguments: caseId,
                ),
            child: Text('re_open_plan'.tr()),
          ),
      ],
    );
  }

  Widget _pointPanel(MeetingPoint point, VoidCallback close) {
    final caseId =
        _cases.length == 1 && _cases.first.plan.meetingPoint == null
            ? _cases.first.id
            : null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title(point.name, TrustTag(point), close),
        Text(categoryLabel(point.category), style: context.editorial.meta),
        AppSpacing.gapSm,
        AppButton(
          label: 're_details'.tr(),
          onPressed: () async {
            final changed = await showModalBottomSheet<bool>(
              context: context,
              isScrollControlled: true,
              showDragHandle: true,
              builder:
                  (_) => PointSheet(
                    point: point,
                    repository: _repo,
                    familyId: _circle?.id,
                    caseId: caseId,
                  ),
            );
            if (changed == true && mounted) {
              await _loadPoints();
              await _poll();
            }
          },
        ),
      ],
    );
  }

  Widget _casePanel(CaseMarker item, VoidCallback close) {
    final e = context.editorial;
    final at = item.eventAt;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title(
          item.personName.isEmpty ? 'lf_unnamed'.tr() : item.personName,
          Text('re_stage_${item.plan.stage}'.tr(), style: e.meta),
          close,
        ),
        MetaLine([
          item.locationText,
          if (at != null) dateTimeText(context, at),
        ]),
        Text('lf_not_live'.tr(), style: e.meta),
        AppSpacing.gapSm,
        AppButton(
          label: 're_open_plan'.tr(),
          onPressed:
              () => Navigator.pushNamed(
                context,
                '/reunionCase',
                arguments: item.id,
              ),
        ),
      ],
    );
  }

  Widget _sightingPanel(
    CaseMarker item,
    Sighting sighting,
    VoidCallback close,
  ) {
    final e = context.editorial;
    final at = sighting.seenAt;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title(
          (sighting.verified ? 're_sighting_verified' : 're_sighting_reported')
              .tr(),
          Text(item.reference, style: e.meta),
          close,
        ),
        MetaLine([
          sighting.locationText,
          if (at != null) dateTimeText(context, at),
          if (at != null) agoText(DateTime.now().difference(at).inSeconds),
        ]),
        Text('lf_not_live'.tr(), style: e.meta),
        AppSpacing.gapSm,
        AppButton.secondary(
          label: 're_open_plan'.tr(),
          onPressed:
              () => Navigator.pushNamed(
                context,
                '/reunionCase',
                arguments: item.id,
              ),
        ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return Material(
      color: colors.surface,
      elevation: 2,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        tooltip: tooltip,
        color: colors.onSurface,
        icon: Icon(icon),
        onPressed: onTap,
      ),
    );
  }
}

class _BottomSheet extends StatelessWidget {
  const _BottomSheet({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colorScheme.surface,
      elevation: 8,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppRadius.xl),
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.55,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _LayerChips extends StatelessWidget {
  const _LayerChips({required this.layers, required this.onToggle});

  final Set<MapLayer> layers;
  final ValueChanged<MapLayer> onToggle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSpacing.minTouchTarget,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final layer in MapLayer.values)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: AppSpacing.xs),
              child: FilterChip(
                selected: layers.contains(layer),
                showCheckmark: false,
                avatar: Icon(
                  layers.contains(layer)
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_outlined,
                  size: 16,
                ),
                label: Text('re_layer_${layer.name}'.tr()),
                onSelected: (_) => onToggle(layer),
              ),
            ),
        ],
      ),
    );
  }
}

class _SafetyBanner extends StatelessWidget {
  const _SafetyBanner({required this.selfProtected, required this.onTap});

  final bool selfProtected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.semanticColors;
    final label = (selfProtected ? 're_safe_self_title' : 're_safe_title').tr();
    return Material(
      color: s.warningContainer,
      borderRadius: AppRadius.lgAll,
      child: InkWell(
        borderRadius: AppRadius.lgAll,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            children: [
              Icon(Icons.shield_outlined, color: s.onWarningContainer),
              AppSpacing.gapSm,
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(color: s.onWarningContainer),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: s.onWarningContainer),
            ],
          ),
        ),
      ),
    );
  }
}

class _CaseStrip extends StatelessWidget {
  const _CaseStrip({required this.item, required this.onTap});

  final CaseMarker item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final e = context.editorial;
    final name = item.personName.isEmpty ? 'lf_unnamed'.tr() : item.personName;
    return Pressable(
      onTap: onTap,
      label: '$name, ${'re_stage_${item.plan.stage}'.tr()}',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            children: [
              Icon(
                Icons.person_search_rounded,
                color: context.colorScheme.error,
              ),
              AppSpacing.gapSm,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: e.title),
                    Text('re_stage_${item.plan.stage}'.tr(), style: e.meta),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegendSheet extends StatelessWidget {
  const _LegendSheet();

  @override
  Widget build(BuildContext context) {
    final s = context.semanticColors;
    final colors = context.colorScheme;
    final e = context.editorial;
    Widget row(IconData icon, Color color, String key) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, color: color),
          AppSpacing.gapSm,
          Expanded(child: Text(key.tr())),
        ],
      ),
    );
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          editorialMargin,
          0,
          editorialMargin,
          AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('re_legend'.tr(), style: e.headline),
            AppSpacing.gapMd,
            row(Icons.place_rounded, s.success, 're_legend_live'),
            row(Icons.place_outlined, s.warning, 're_legend_stale'),
            row(Icons.square_rounded, s.success, 're_legend_help'),
            row(Icons.crop_square_rounded, s.warning, 're_legend_meeting'),
            row(Icons.diamond_rounded, colors.error, 're_legend_last_seen'),
            row(
              Icons.change_history_rounded,
              colors.error,
              're_legend_reported',
            ),
            row(Icons.warning_rounded, colors.error, 're_legend_verified'),
          ],
        ),
      ),
    );
  }
}

/// The dashboard's way in.
class ReunionDashboardEntry extends StatelessWidget {
  const ReunionDashboardEntry({super.key, required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final label = 're_map_title'.tr();
    final line = 're_entry_line'.tr();
    return Pressable(
      onTap: onOpen,
      label: '$label, $line',
      child: ExcludeSemantics(
        child: Container(
          constraints: const BoxConstraints(
            minHeight: AppSpacing.minTouchTarget,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHigh,
            borderRadius: AppRadius.lgAll,
          ),
          child: Row(
            children: [
              Icon(Icons.diversity_3_rounded, color: colors.primary),
              AppSpacing.gapSm,
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.labelLarge,
                ),
              ),
              Flexible(
                child: Text(
                  line,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.editorial.meta,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
