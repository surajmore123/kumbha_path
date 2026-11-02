import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/modules/emergency/widgets/sos_parts.dart';
import 'package:kumbha_path/src/modules/family/widgets/family_parts.dart';
import 'package:kumbha_path/src/modules/journey/widgets/journey_ui.dart'
    show formatDate, openExternal, showJourneySnack;
import 'package:kumbha_path/src/modules/lostfound/report_screens.dart'
    show PositionReader;
import 'package:kumbha_path/src/modules/lostfound/widgets/lf_parts.dart'
    show readPosition;
import 'package:kumbha_path/src/modules/reunion/data/reunion_repository.dart';
import 'package:kumbha_path/src/modules/reunion/models/reunion_models.dart';
import 'package:kumbha_path/src/modules/reunion/widgets/reunion_parts.dart';

const assistanceCategories = [
  'police',
  'medical',
  'hospital',
  'ambulance',
  'fire_rescue',
  'lost_found',
  'help_desk',
];

/// `/sosAssistance`: verified places only. Anything else stays off this list,
/// and with no data it says so rather than showing something uncertain.
class AssistanceScreen extends StatefulWidget {
  const AssistanceScreen({super.key, this.repository, this.position});

  final ReunionRepository? repository;
  final PositionReader? position;

  @override
  State<AssistanceScreen> createState() => _AssistanceScreenState();
}

class _AssistanceScreenState extends State<AssistanceScreen> {
  late final ReunionRepository _repo =
      widget.repository ?? ReunionServices.repository;
  static const _all = 'all';

  bool _loading = true;
  List<MeetingPoint> _points = const [];
  DateTime? _savedAt;
  bool _failed = false;
  String _category = _all;
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
      _failed = false;
    });
    try {
      final points = await _repo.points(verifiedOnly: true);
      await ReunionServices.saved.save(points);
      if (!mounted) return;
      setState(() {
        _points = points;
        _savedAt = null;
        _loading = false;
      });
    } catch (_) {
      final saved = await ReunionServices.saved.load();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _points = saved?.points ?? const [];
        _savedAt = saved?.savedAt;
        _failed = saved == null;
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
        _points
            .where(
              (p) =>
                  p.isVerified &&
                  assistanceCategories.contains(p.category) &&
                  (_category == _all || p.category == _category),
            )
            .toList();
    rows.sort(
      (a, b) =>
          _me == null ? a.name.compareTo(b.name) : _km(a)!.compareTo(_km(b)!),
    );
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final e = context.editorial;
    final visible = _visible;
    return Scaffold(
      appBar: AppBar(title: Text('sos_nearby'.tr())),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              editorialMargin,
              AppSpacing.md,
              editorialMargin,
              AppSpacing.huge,
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
              PillChoices(
                values: const [_all, ...assistanceCategories],
                labelOf:
                    (c) => c == _all ? 're_filter_all'.tr() : categoryLabel(c),
                selected: _category,
                onChanged: (c) => setState(() => _category = c),
              ),
              AppSpacing.gapSm,
              if (_me == null)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: _locating ? null : _locate,
                    icon: const Icon(Icons.my_location_rounded, size: 18),
                    label: Text('re_near_me'.tr()),
                  ),
                )
              else
                Text('re_straight_note'.tr(), style: e.meta),
              AppSpacing.gapMd,
              if (_loading)
                const SkeletonLine(height: 72)
              else if (visible.isEmpty) ...[
                AppEmptyState(
                  compact: true,
                  icon: Icons.local_hospital_outlined,
                  title:
                      (_failed ? 'sos_assist_failed' : 'sos_assist_none').tr(),
                  message: 'sos_assist_none_body'.tr(),
                ),
                AppSpacing.gapMd,
                const DirectCallButtons(),
              ] else
                for (final point in visible)
                  _PointCard(point: point, km: _km(point)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PointCard extends StatelessWidget {
  const _PointCard({required this.point, this.km});

  final MeetingPoint point;
  final double? km;

  @override
  Widget build(BuildContext context) {
    final e = context.editorial;
    final distance = km;
    final phone = point.contactPhone;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                categoryIcon(point.category),
                color: context.colorScheme.primary,
              ),
              AppSpacing.gapSm,
              Expanded(child: Text(point.name, style: e.title)),
            ],
          ),
          MetaLine([
            categoryLabel(point.category),
            if (distance != null) straightLineText(distance),
          ]),
          AppSpacing.gapXs,
          TrustTag(point),
          if (point.address.isNotEmpty) Text(point.address),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              TextButton.icon(
                onPressed:
                    () => openExternal(
                      context,
                      googleMapsWalkingUrl(point.latitude, point.longitude),
                    ),
                icon: const Icon(Icons.navigation_outlined, size: 18),
                label: Text('re_open_google_maps'.tr()),
              ),
              if (point.isVerified && phone.isNotEmpty)
                TextButton.icon(
                  onPressed:
                      () => confirmAndDial(
                        context,
                        number: phone,
                        title: 'sos_call_person'.tr(args: [point.name]),
                      ),
                  icon: const Icon(Icons.call_outlined, size: 18),
                  label: Text('re_call_point'.tr()),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
