import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/components/maps/app_map.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/modules/family/widgets/family_parts.dart';
import 'package:kumbha_path/src/modules/journey/widgets/journey_ui.dart'
    show confirmJourneyAction, formatDate, openExternal, showJourneySnack;
import 'package:kumbha_path/src/modules/lostfound/report_screens.dart'
    show PositionReader;
import 'package:kumbha_path/src/modules/lostfound/widgets/lf_parts.dart'
    show readPosition;
import 'package:kumbha_path/src/modules/reunion/data/reunion_repository.dart';
import 'package:kumbha_path/src/modules/reunion/models/reunion_models.dart';
import 'package:kumbha_path/src/modules/reunion/route_preview_screen.dart'
    show PointExplorerArgs;
import 'package:kumbha_path/src/modules/reunion/widgets/reunion_parts.dart';

const _safeCategories = {
  'help_desk',
  'lost_found',
  'police',
  'emergency',
  'medical',
  'hospital',
};

/// `/reunionPoints`: find a safe place to meet. Distance is worked out on the
/// phone, so a position isn't sent to browse a list.
class PointExplorerScreen extends StatefulWidget {
  const PointExplorerScreen({
    super.key,
    this.args = const PointExplorerArgs(),
    this.repository,
    this.position,
  });

  final PointExplorerArgs args;
  final ReunionRepository? repository;
  final PositionReader? position;

  @override
  State<PointExplorerScreen> createState() => _PointExplorerScreenState();
}

class _PointExplorerScreenState extends State<PointExplorerScreen> {
  static const _all = 'all';
  static const _ranges = ['1', '3', '10', 'any'];

  late final ReunionRepository _repo =
      widget.repository ?? ReunionServices.repository;

  bool _loading = true;
  Object? _error;
  List<MeetingPoint> _points = const [];
  DateTime? _savedAt;
  String _category = _all;
  late bool _verifiedOnly = widget.args.safeOnly;
  String _range = 'any';
  (double, double)? _me;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final points = await _repo.points();
      await ReunionServices.saved.save(points);
      if (!mounted) return;
      setState(() {
        _points = points;
        _savedAt = null;
        _loading = false;
      });
    } catch (e) {
      final saved = await ReunionServices.saved.load();
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (saved != null) {
          _points = saved.points;
          _savedAt = saved.savedAt;
        } else {
          _error = e;
        }
      });
    }
  }

  Future<void> _locate() async {
    setState(() => _locating = true);
    final me = await (widget.position ?? readPosition)();
    if (!mounted) return;
    setState(() {
      _locating = false;
      _me = me;
    });
    if (me == null) showJourneySnack(context, 're_route_no_gps'.tr());
  }

  double? _km(MeetingPoint p) {
    final me = _me;
    return me == null ? null : straightLineKm(me, p.latitude, p.longitude);
  }

  List<MeetingPoint> get _visible {
    final rows =
        _points.where((p) {
          if (widget.args.safeOnly &&
              !(p.isVerified && _safeCategories.contains(p.category))) {
            return false;
          }
          if (_verifiedOnly && !p.isVerified) return false;
          if (_category != _all && p.category != _category) return false;
          final km = _km(p);
          if (_range != 'any' && km != null && km > double.parse(_range)) {
            return false;
          }
          return true;
        }).toList();
    int rank(MeetingPoint p) => p.isVerified ? 0 : (p.isPrivate ? 1 : 2);
    rows.sort((a, b) {
      final byTrust = rank(a).compareTo(rank(b));
      if (_me == null) {
        return byTrust != 0 ? byTrust : a.name.compareTo(b.name);
      }
      return _km(a)!.compareTo(_km(b)!);
    });
    return rows;
  }

  Future<void> _open(MeetingPoint point) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder:
          (_) => PointSheet(
            point: point,
            repository: _repo,
            familyId: widget.args.familyId,
            caseId: widget.args.caseId,
            km: _km(point),
            picking: widget.args.picking,
          ),
    );
    if (changed == true && mounted) {
      if (widget.args.picking) {
        Navigator.pop(context, true);
      } else {
        await _load();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = context.editorial;
    final categories = [
      _all,
      for (final c in pointCategories)
        if (!widget.args.safeOnly || _safeCategories.contains(c)) c,
    ];
    final failed = _error;
    final visible = _visible;
    final familyId = widget.args.familyId;
    return Scaffold(
      appBar: AppBar(title: Text('re_points_title'.tr())),
      floatingActionButton:
          familyId == null || widget.args.safeOnly
              ? null
              : FloatingActionButton.extended(
                onPressed: () async {
                  await Navigator.pushNamed(
                    context,
                    '/reunionAddPoint',
                    arguments: familyId,
                  );
                  if (mounted) await _load();
                },
                icon: const Icon(Icons.add_location_alt_outlined),
                label: Text('re_add_spot'.tr()),
              ),
      body: SafeArea(
        child:
            failed != null
                ? AppErrorView(
                  message: reunionErrorText(failed),
                  onRetry: _load,
                )
                : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      editorialMargin,
                      AppSpacing.md,
                      editorialMargin,
                      AppSpacing.huge * 2,
                    ),
                    children: [
                      if (_savedAt != null) ...[
                        FamilyNote(
                          text: 're_points_saved'.tr(
                            args: [formatDate(context, _savedAt!)],
                          ),
                        ),
                        AppSpacing.gapMd,
                      ],
                      if (widget.args.safeOnly) ...[
                        Text('re_safe_only_note'.tr()),
                        AppSpacing.gapMd,
                      ],
                      PillChoices(
                        values: categories,
                        labelOf:
                            (c) =>
                                c == _all
                                    ? 're_filter_all'.tr()
                                    : categoryLabel(c),
                        selected: _category,
                        onChanged: (c) => setState(() => _category = c),
                      ),
                      if (!widget.args.safeOnly)
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _verifiedOnly,
                          title: Text('re_verified_only'.tr()),
                          onChanged: (on) => setState(() => _verifiedOnly = on),
                        ),
                      AppSpacing.gapSm,
                      if (_me == null)
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: TextButton.icon(
                            onPressed: _locating ? null : _locate,
                            icon: const Icon(
                              Icons.my_location_rounded,
                              size: 18,
                            ),
                            label: Text('re_near_me'.tr()),
                          ),
                        )
                      else ...[
                        FieldLabel('re_within'.tr()),
                        PillChoices(
                          values: _ranges,
                          labelOf:
                              (r) =>
                                  r == 'any'
                                      ? 're_any_distance'.tr()
                                      : 're_within_km'.tr(args: [r]),
                          selected: _range,
                          onChanged: (r) => setState(() => _range = r),
                        ),
                        AppSpacing.gapXs,
                        Text('re_straight_note'.tr(), style: e.meta),
                      ],
                      AppSpacing.gapMd,
                      if (_loading)
                        const SkeletonLine(height: 72)
                      else if (visible.isEmpty)
                        AppEmptyState(
                          compact: true,
                          icon: Icons.place_outlined,
                          title:
                              (_points.isEmpty
                                      ? 're_points_none'
                                      : 're_points_filtered')
                                  .tr(),
                          message:
                              _points.isEmpty
                                  ? 're_points_none_body'.tr()
                                  : null,
                        )
                      else
                        for (final point in visible)
                          PointRow(
                            point: point,
                            km: _km(point),
                            onTap: () => _open(point),
                          ),
                    ],
                  ),
                ),
      ),
    );
  }
}

/// One place: how far to trust it, and what can be done with it.
class PointSheet extends StatefulWidget {
  const PointSheet({
    super.key,
    required this.point,
    required this.repository,
    this.familyId,
    this.caseId,
    this.km,
    this.picking = false,
  });

  final MeetingPoint point;
  final ReunionRepository repository;
  final String? familyId;
  final String? caseId;
  final double? km;
  final bool picking;

  @override
  State<PointSheet> createState() => _PointSheetState();
}

class _PointSheetState extends State<PointSheet> {
  bool _busy = false;

  MeetingPoint get _point => widget.point;

  Future<void> _act(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      showJourneySnack(context, done.tr());
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showJourneySnack(context, reunionErrorText(e));
      }
    }
  }

  Future<void> _choose() async {
    final sure = await confirmJourneyAction(
      context,
      title: 're_choose_title'.tr(),
      message: 're_choose_body'.tr(args: [_point.name]),
      confirm: 're_choose'.tr(),
    );
    if (sure) {
      await _act(
        () => widget.repository.choosePoint(widget.caseId!, _point.id),
        're_chosen',
      );
    }
  }

  Future<void> _share() async {
    final sure = await confirmJourneyAction(
      context,
      title: 're_share_title'.tr(),
      message: 're_share_body'.tr(),
      confirm: 're_share'.tr(),
    );
    if (sure) {
      await _act(
        () => widget.repository.notifyFamily(
          widget.familyId!,
          'meet_at_point',
          pointId: _point.id,
        ),
        're_shared',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = context.editorial;
    final p = _point;
    final distance = widget.km ?? p.straightLineKm;
    final caseId = widget.caseId;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          editorialMargin,
          0,
          editorialMargin,
          AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(p.name, style: e.headline),
            MetaLine([
              categoryLabel(p.category),
              if (distance != null) straightLineText(distance),
            ]),
            AppSpacing.gapSm,
            TrustTag(p),
            if (p.isVerified && p.sourceDetail.isNotEmpty) ...[
              AppSpacing.gapXs,
              Text('re_source'.tr(args: [p.sourceDetail]), style: e.meta),
            ],
            if (!p.isVerified) ...[
              AppSpacing.gapXs,
              Text(
                (p.isPrivate ? 're_family_note' : 're_community_note').tr(),
                style: e.meta,
              ),
            ],
            if (p.description.isNotEmpty) ...[
              AppSpacing.gapSm,
              Text(p.description),
            ],
            if (p.openingHours.isNotEmpty)
              FactRow(label: 're_hours'.tr(), value: p.openingHours),
            AppSpacing.gapMd,
            AppButton(
              label: 're_route'.tr(),
              leadingIcon: Icons.directions_walk_rounded,
              onPressed:
                  () => Navigator.pushNamed(
                    context,
                    '/reunionRoute',
                    arguments: RouteTarget(
                      kind: 'point',
                      id: p.id,
                      name: p.name,
                      latitude: p.latitude,
                      longitude: p.longitude,
                      caseId: caseId,
                    ),
                  ),
            ),
            if (caseId != null) ...[
              AppSpacing.gapSm,
              AppButton.secondary(
                label: 're_choose'.tr(),
                leadingIcon: Icons.flag_outlined,
                isLoading: _busy,
                onPressed: _busy ? null : _choose,
              ),
            ],
            if (widget.familyId != null && !widget.picking) ...[
              AppSpacing.gapSm,
              AppButton.secondary(
                label: 're_share'.tr(),
                leadingIcon: Icons.campaign_outlined,
                onPressed: _busy ? null : _share,
              ),
            ],
            if (p.contactPhone.isNotEmpty)
              TextButton.icon(
                onPressed: () => openExternal(context, 'tel:${p.contactPhone}'),
                icon: const Icon(Icons.call_outlined, size: 18),
                label: Text('re_call_point'.tr()),
              ),
            if (p.status == 'family')
              TextButton(
                onPressed:
                    _busy
                        ? null
                        : () => _act(
                          () => widget.repository.suggestPoint(p.id),
                          're_suggested',
                        ),
                child: Text('re_suggest'.tr()),
              ),
            if (p.isPrivate)
              TextButton(
                onPressed:
                    _busy
                        ? null
                        : () => _act(
                          () => widget.repository.removePoint(p.id),
                          're_removed',
                        ),
                child: Text('re_remove'.tr()),
              ),
          ],
        ),
      ),
    );
  }
}

/// `/reunionAddPoint`: a family's own meeting spot, placed by tapping the map.
/// It stays private to the family, and can't be labelled as a help point.
class AddFamilyPointScreen extends StatefulWidget {
  const AddFamilyPointScreen({
    super.key,
    required this.familyId,
    this.repository,
    this.position,
  });

  final String familyId;
  final ReunionRepository? repository;
  final PositionReader? position;

  @override
  State<AddFamilyPointScreen> createState() => _AddFamilyPointScreenState();
}

class _AddFamilyPointScreenState extends State<AddFamilyPointScreen> {
  final _name = TextEditingController();
  LatLng? _spot;
  bool _busy = false;
  String? _problem;

  // Nashik, only so the map opens somewhere useful. Nothing is saved from it.
  static const _start = LatLng(19.9975, 73.7898);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final spot = _spot;
    if (_name.text.trim().isEmpty || spot == null) {
      setState(() => _problem = 're_add_need_both'.tr());
      return;
    }
    setState(() {
      _busy = true;
      _problem = null;
    });
    try {
      await (widget.repository ?? ReunionServices.repository).addFamilyPoint(
        widget.familyId,
        name: _name.text.trim(),
        latitude: spot.latitude,
        longitude: spot.longitude,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _problem = reunionErrorText(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final spot = _spot;
    return Scaffold(
      appBar: AppBar(title: Text('re_add_spot'.tr())),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: AppMap(
                config: AppMapConfig(
                  target: _start,
                  zoom: 13,
                  markers: {
                    if (spot != null)
                      Marker(markerId: const MarkerId('spot'), position: spot),
                  },
                  onTap: (at) => setState(() => _spot = at),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('re_add_hint'.tr(), style: context.editorial.meta),
                  AppSpacing.gapSm,
                  AppTextField(label: 're_add_name'.tr(), controller: _name),
                  if (_problem != null) ...[
                    AppSpacing.gapSm,
                    Text(
                      _problem!,
                      style: TextStyle(color: context.colorScheme.error),
                    ),
                  ],
                  AppSpacing.gapSm,
                  AppButton(
                    label: 'loc_save'.tr(),
                    isLoading: _busy,
                    onPressed: _busy ? null : _save,
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
