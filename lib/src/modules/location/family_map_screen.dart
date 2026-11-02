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
    show confirmJourneyAction, openExternal, showJourneySnack;
import 'package:kumbha_path/src/modules/location/data/location_repository.dart';
import 'package:kumbha_path/src/modules/location/data/location_tracker.dart';
import 'package:kumbha_path/src/modules/location/models/location_models.dart';
import 'package:kumbha_path/src/modules/location/widgets/location_parts.dart';

/// `/familyMap`: where people who chose to share with you last reported from.
///
/// Updates by polling, and only while this screen is in front. Positions are
/// held in memory, age on screen by themselves, and are never moved or
/// estimated between updates.
class FamilyMapScreen extends StatefulWidget {
  const FamilyMapScreen({
    super.key,
    this.args,
    this.familyId,
    this.repository,
    this.familyRepository,
    this.tracker,
  });

  final FamilyArgs? args;

  /// From a notification, which only knows the family's id.
  final String? familyId;
  final LocationRepository? repository;
  final FamilyRepository? familyRepository;
  final LocationTracker? tracker;

  @override
  State<FamilyMapScreen> createState() => _FamilyMapScreenState();
}

class _FamilyMapScreenState extends State<FamilyMapScreen>
    with WidgetsBindingObserver {
  late final LocationRepository _repo =
      widget.repository ?? LocationServices.repository;
  late final FamilyRepository _family =
      widget.familyRepository ?? FamilyServices.repository;
  late final LocationTracker _tracker =
      widget.tracker ?? LocationSharing.tracker;

  FamilyCircle? _circle;
  LocationFeed? _feed;
  Object? _error;
  bool _loading = true;
  bool _noCircle = false;
  bool _refreshing = false;
  int _failures = 0;
  String? _selectedId;
  GoogleMapController? _map;
  bool _fitted = false;
  Timer? _timer;
  final _icons = <String, BitmapDescriptor>{};

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
      if (_circle != null) unawaited(_poll());
    } else {
      // No polling for a screen nobody can see.
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
        circle =
            circles.where((c) => c.id == widget.familyId).firstOrNull ??
            circles.firstOrNull;
      }
      if (!mounted) return;
      if (circle == null) {
        setState(() {
          _noCircle = true;
          _loading = false;
        });
        return;
      }
      _circle = circle;
      _feed = LocationServices.lastFeed[circle.id];
      await _poll();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  Future<void> _poll() async {
    final circle = _circle;
    if (circle == null) return;
    _timer?.cancel();
    setState(() => _refreshing = true);
    try {
      final feed = await _repo.feed(circle.id);
      LocationServices.lastFeed[circle.id] = feed;
      if (!mounted) return;
      await _drawIcons(feed);
      if (!mounted) return;
      setState(() {
        _feed = feed;
        _failures = 0;
        _error = null;
      });
      _fitOnce();
    } catch (e) {
      if (!mounted) return;
      // Positions age with no new data, so their pins need redrawing.
      final held = _feed;
      if (held != null) await _drawIcons(held);
      if (!mounted) return;
      setState(() {
        _failures++;
        if (_feed == null) _error = e;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _refreshing = false;
        });
        _schedule();
      }
    }
  }

  /// Backs off while failing, so a bad signal doesn't drain the battery.
  void _schedule() {
    final base = _feed?.pollSeconds ?? 20;
    final wait = (base * (1 << _failures.clamp(0, 3))).clamp(base, 120);
    _timer = Timer(Duration(seconds: wait), () {
      if (mounted) unawaited(_poll());
    });
  }

  Future<void> _drawIcons(LocationFeed feed) async {
    if (!mounted) return;
    final now = DateTime.now();
    final context = this.context;
    final colors = context.colorScheme;
    for (final person in feed.people) {
      final freshness = person.freshnessAt(now);
      _icons['${person.memberId}|${freshness.name}'] =
          await LocationMarkers.pin(
            initials: initialsOf(person.name),
            ring: freshnessColor(context, freshness),
            fill: colors.primary,
            text: colors.onPrimary,
            current: freshness == Freshness.live,
          );
      if (!context.mounted) return;
    }
  }

  List<LocationPerson> get _people {
    final feed = _feed;
    return feed == null ? const [] : feed.visibleAt(DateTime.now());
  }

  bool _onMap(LocationPerson p, DateTime now) =>
      p.hasPosition &&
      const {
        Freshness.live,
        Freshness.recent,
        Freshness.lastKnown,
      }.contains(p.freshnessAt(now));

  List<LocationPerson> _mapped(DateTime now) => [
    for (final p in _people)
      if (_onMap(p, now)) p,
  ];

  void _fitOnce() {
    if (_fitted || _map == null) return;
    if (_mapped(DateTime.now()).isEmpty) return;
    _fitted = true;
    _fitAll();
  }

  void _fitAll() {
    final map = _map;
    final points = [
      for (final p in _mapped(DateTime.now()))
        LatLng(p.latitude!, p.longitude!),
    ];
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
        72,
      ),
    );
  }

  void _select(LocationPerson person) {
    setState(() => _selectedId = person.memberId);
    if (person.hasPosition) _center(person);
  }

  void _center(LocationPerson person) {
    _map?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(person.latitude!, person.longitude!),
        17,
      ),
    );
  }

  Future<void> _manage() async {
    final circle = _circle;
    if (circle == null) return;
    await Navigator.pushNamed(
      context,
      '/locationSharing',
      arguments: FamilyArgs(circle),
    );
    if (mounted) unawaited(_poll());
  }

  Future<void> _togglePause() async {
    final id = _tracker.sessionId;
    if (id == null) return;
    try {
      if (_tracker.state == TrackerState.paused) {
        await _tracker.sync(await _repo.resume(id));
      } else {
        await _tracker.sync(await _repo.pause(id));
      }
      if (mounted) unawaited(_poll());
    } catch (e) {
      if (mounted) showJourneySnack(context, locationErrorText(e));
    }
  }

  Future<void> _stop() async {
    final id = _tracker.sessionId;
    if (id == null) return;
    final sure = await confirmJourneyAction(
      context,
      title: 'loc_stop_title'.tr(),
      message: 'loc_stop_body'.tr(),
      confirm: 'loc_stop'.tr(),
      destructive: true,
    );
    if (!sure) return;
    final told = await _tracker.stop(id);
    if (!mounted) return;
    showJourneySnack(
      context,
      (told ? 'loc_stopped' : 'loc_stopped_offline').tr(),
    );
    unawaited(_poll());
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _feed == null) {
      return Scaffold(
        appBar: AppBar(title: Text('loc_map_title'.tr())),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_noCircle) {
      return Scaffold(
        appBar: AppBar(title: Text('loc_map_title'.tr())),
        body: AppEmptyState(
          icon: Icons.groups_outlined,
          title: 'loc_no_family_title'.tr(),
          message: 'loc_no_family_body'.tr(),
          actionLabel: 'fam_title'.tr(),
          onAction: () => Navigator.pushReplacementNamed(context, '/family'),
        ),
      );
    }
    final failed = _error;
    if (_feed == null && failed != null) {
      return Scaffold(
        appBar: AppBar(title: Text('loc_map_title'.tr())),
        body: AppErrorView(message: locationErrorText(failed), onRetry: _load),
      );
    }
    final now = DateTime.now();
    return _mapped(now).isEmpty ? _withoutMap(now) : _withMap(now);
  }

  /// Nothing to place, so no map: an empty map would look like knowledge.
  Widget _withoutMap(DateTime now) {
    final e = context.editorial;
    final people = _people;
    return Scaffold(
      appBar: AppBar(
        title: Text('loc_map_title'.tr()),
        actions: [
          IconButton(
            tooltip: 'loc_refresh'.tr(),
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refreshing ? null : _poll,
          ),
        ],
      ),
      body: SafeArea(
        child:
            people.isEmpty
                ? ListView(
                  padding: const EdgeInsets.all(editorialMargin),
                  children: [
                    if (_failures > 0) ...[
                      FamilyNote(text: 'loc_offline_note'.tr()),
                      AppSpacing.gapMd,
                    ],
                    AppEmptyState(
                      icon: Icons.share_location_rounded,
                      title: 'loc_empty_title'.tr(),
                      message: 'loc_empty_body'.tr(),
                      actionLabel:
                          _tracker.sessionId == null
                              ? 'loc_share_mine'.tr()
                              : 'loc_manage'.tr(),
                      onAction: _manage,
                    ),
                    for (final ended in _feed?.ended ?? const <EndedSharing>[])
                      _EndedLine(ended: ended),
                  ],
                )
                : ListView(
                  padding: const EdgeInsets.all(editorialMargin),
                  children: [
                    if (_failures > 0) ...[
                      FamilyNote(text: 'loc_offline_note'.tr()),
                      AppSpacing.gapMd,
                    ],
                    Text('loc_no_positions'.tr(), style: e.title),
                    AppSpacing.gapXs,
                    Text('loc_no_positions_body'.tr(), style: e.meta),
                    AppSpacing.gapLg,
                    for (final person in people)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: Row(
                          children: [
                            PersonBadge(
                              person: person,
                              familyId: _circle!.id,
                              freshness: person.freshnessAt(now),
                              repository: _family,
                            ),
                            AppSpacing.gapSm,
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(person.name, style: e.title),
                                  FreshnessTag(person.freshnessAt(now)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    AppSpacing.gapMd,
                    _MyBar(
                      tracker: _tracker,
                      onShare: _manage,
                      onPause: _togglePause,
                      onStop: _stop,
                    ),
                  ],
                ),
      ),
    );
  }

  Widget _withMap(DateTime now) {
    final colors = context.colorScheme;
    final mapped = _mapped(now);
    final people = _people;
    final selected = people.where((p) => p.memberId == _selectedId).firstOrNull;
    final first = mapped.first;

    final markers = <Marker>{
      for (final p in mapped)
        Marker(
          markerId: MarkerId(p.memberId),
          position: LatLng(p.latitude!, p.longitude!),
          icon:
              _icons['${p.memberId}|${p.freshnessAt(now).name}'] ??
              BitmapDescriptor.defaultMarker,
          anchor: const Offset(0.5, 1),
          zIndexInt: p.memberId == _selectedId ? 2 : 1,
          consumeTapEvents: true,
          onTap: () => _select(p),
        ),
    };
    final accuracy = selected?.accuracyM;
    final circles = <Circle>{
      if (selected != null && selected.hasPosition && accuracy != null)
        Circle(
          circleId: const CircleId('accuracy'),
          center: LatLng(selected.latitude!, selected.longitude!),
          radius: accuracy,
          strokeWidth: 1,
          strokeColor: colors.primary,
          fillColor: colors.primary.withValues(alpha: 0.12),
        ),
    };

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: AppMap(
              config: AppMapConfig(
                target: LatLng(first.latitude!, first.longitude!),
                zoom: 15,
                markers: markers,
                circles: circles,
                showMyLocation: _tracker.collecting,
                padding: const EdgeInsets.only(bottom: 220),
                onMapCreated: (controller) {
                  _map = controller;
                  _fitOnce();
                },
                onTap: (_) => setState(() => _selectedId = null),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MapControl(
                    icon: Icons.arrow_back_rounded,
                    tooltip:
                        MaterialLocalizations.of(context).backButtonTooltip,
                    onTap: () => Navigator.maybePop(context),
                  ),
                  AppSpacing.gapSm,
                  Expanded(
                    child: _MapHeading(
                      title: 'loc_map_title'.tr(),
                      offline: _failures > 0,
                    ),
                  ),
                  AppSpacing.gapSm,
                  Column(
                    children: [
                      _MapControl(
                        icon: Icons.fit_screen_rounded,
                        tooltip: 'loc_fit_all'.tr(),
                        onTap: _fitAll,
                      ),
                      AppSpacing.gapSm,
                      _MapControl(
                        icon: Icons.refresh_rounded,
                        tooltip: 'loc_refresh'.tr(),
                        onTap: _refreshing ? null : _poll,
                      ),
                      AppSpacing.gapSm,
                      _MapControl(
                        icon: Icons.privacy_tip_outlined,
                        tooltip: 'loc_permissions'.tr(),
                        onTap: _manage,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _BottomPanel(
              children: [
                if (selected != null)
                  _PersonPanel(
                    person: selected,
                    now: now,
                    familyId: _circle!.id,
                    repository: _family,
                    onClose: () => setState(() => _selectedId = null),
                    onCenter: () => _center(selected),
                  )
                else
                  _PeopleStrip(
                    people: people,
                    now: now,
                    familyId: _circle!.id,
                    repository: _family,
                    onSelect: _select,
                  ),
                AppSpacing.gapSm,
                _MyBar(
                  tracker: _tracker,
                  onShare: _manage,
                  onPause: _togglePause,
                  onStop: _stop,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MapControl extends StatelessWidget {
  const _MapControl({
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

class _MapHeading extends StatelessWidget {
  const _MapHeading({required this.title, required this.offline});

  final String title;
  final bool offline;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final e = context.editorial;
    return Material(
      color: colors.surface,
      elevation: 2,
      borderRadius: BorderRadius.circular(AppRadius.lg),
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
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: e.title,
              ),
            ),
            Text(
              (offline ? 'loc_offline_short' : 'loc_not_realtime').tr(),
              style: e.meta,
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomPanel extends StatelessWidget {
  const _BottomPanel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return Material(
      color: colors.surface,
      elevation: 8,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppRadius.xl),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: children),
        ),
      ),
    );
  }
}

class _PeopleStrip extends StatelessWidget {
  const _PeopleStrip({
    required this.people,
    required this.now,
    required this.familyId,
    required this.repository,
    required this.onSelect,
  });

  final List<LocationPerson> people;
  final DateTime now;
  final String familyId;
  final FamilyRepository repository;
  final ValueChanged<LocationPerson> onSelect;

  @override
  Widget build(BuildContext context) {
    final e = context.editorial;
    final height = MediaQuery.textScalerOf(context).scale(38) + 56;
    return SizedBox(
      height: height,
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
              onTap: () => onSelect(person),
              label: '$name, ${freshnessLabel(freshness)}',
              child: ExcludeSemantics(
                child: Column(
                  children: [
                    PersonBadge(
                      person: person,
                      familyId: familyId,
                      freshness: freshness,
                      repository: repository,
                      size: 48,
                    ),
                    AppSpacing.gapXs,
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
    );
  }
}

class _PersonPanel extends StatelessWidget {
  const _PersonPanel({
    required this.person,
    required this.now,
    required this.familyId,
    required this.repository,
    required this.onClose,
    required this.onCenter,
  });

  final LocationPerson person;
  final DateTime now;
  final String familyId;
  final FamilyRepository repository;
  final VoidCallback onClose;
  final VoidCallback onCenter;

  @override
  Widget build(BuildContext context) {
    final e = context.editorial;
    final freshness = person.freshnessAt(now);
    final age = person.ageSeconds;
    final accuracy = person.accuracyM;
    final caseId = person.caseId;
    final seen =
        age == null ? null : age + now.difference(person.fetchedAt).inSeconds;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            PersonBadge(
              person: person,
              familyId: familyId,
              freshness: freshness,
              repository: repository,
            ),
            AppSpacing.gapSm,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    person.isMe ? 'loc_you'.tr() : person.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: e.title,
                  ),
                  FreshnessTag(freshness),
                ],
              ),
            ),
            IconButton(
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              icon: const Icon(Icons.close_rounded),
              onPressed: onClose,
            ),
          ],
        ),
        AppSpacing.gapXs,
        MetaLine([
          if (seen != null) 'loc_updated'.tr(args: [agoText(seen)]),
          if (accuracy != null) accuracyText(accuracy),
        ]),
        if (freshness == Freshness.lastKnown) ...[
          AppSpacing.gapXs,
          Text('loc_may_have_moved'.tr(), style: e.meta),
        ],
        if (person.hasPosition) ...[
          AppSpacing.gapSm,
          Row(
            children: [
              Expanded(
                child: AppButton.secondary(
                  label: 'loc_center'.tr(),
                  leadingIcon: Icons.center_focus_strong_rounded,
                  onPressed: onCenter,
                ),
              ),
              AppSpacing.gapSm,
              Expanded(
                child: AppButton.secondary(
                  label: 'loc_directions'.tr(),
                  leadingIcon: Icons.directions_outlined,
                  onPressed:
                      () => openExternal(
                        context,
                        'https://www.google.com/maps/dir/?api=1&destination=${person.latitude},${person.longitude}',
                      ),
                ),
              ),
            ],
          ),
        ],
        if (caseId != null)
          TextButton.icon(
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            onPressed:
                () => Navigator.pushNamed(
                  context,
                  '/lostFoundCase',
                  arguments: caseId,
                ),
            icon: const Icon(Icons.folder_open_outlined, size: 18),
            label: Text('loc_open_case'.tr(args: [person.caseReference ?? ''])),
          ),
      ],
    );
  }
}

/// Your own sharing, always one tap from stopping.
class _MyBar extends StatelessWidget {
  const _MyBar({
    required this.tracker,
    required this.onShare,
    required this.onPause,
    required this.onStop,
  });

  final LocationTracker tracker;
  final VoidCallback onShare;
  final VoidCallback onPause;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final e = context.editorial;
    if (tracker.sessionId == null) {
      return AppButton(
        label: 'loc_share_mine'.tr(),
        leadingIcon: Icons.share_location_rounded,
        onPressed: onShare,
      );
    }
    final paused = tracker.state == TrackerState.paused;
    final text = switch (tracker.state) {
      TrackerState.paused => 'loc_mine_paused',
      TrackerState.interrupted => 'loc_mine_interrupted',
      _ => 'loc_mine_on',
    };
    return Row(
      children: [
        Expanded(
          child: TextButton(
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              alignment: Alignment.centerLeft,
            ),
            onPressed: onShare,
            child: Text(text.tr(), style: e.meta),
          ),
        ),
        IconButton(
          tooltip: (paused ? 'loc_resume' : 'loc_pause').tr(),
          icon: Icon(paused ? Icons.play_arrow_rounded : Icons.pause_rounded),
          onPressed: onPause,
        ),
        IconButton(
          tooltip: 'loc_stop'.tr(),
          color: context.colorScheme.error,
          icon: const Icon(Icons.stop_circle_outlined),
          onPressed: onStop,
        ),
      ],
    );
  }
}

class _EndedLine extends StatelessWidget {
  const _EndedLine({required this.ended});

  final EndedSharing ended;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        children: [
          Icon(
            freshnessIcon(Freshness.expired),
            size: 16,
            color: context.colorScheme.outline,
          ),
          AppSpacing.gapXs,
          Expanded(
            child: Text(
              (ended.state == 'expired'
                      ? 'loc_ended_expired'
                      : 'loc_ended_stopped')
                  .tr(args: [ended.name]),
              style: context.editorial.meta,
            ),
          ),
        ],
      ),
    );
  }
}
