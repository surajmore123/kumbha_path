import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/modules/family/widgets/family_parts.dart';
import 'package:kumbha_path/src/modules/journey/widgets/journey_ui.dart'
    show confirmJourneyAction, showJourneySnack;
import 'package:kumbha_path/src/modules/location/widgets/location_parts.dart';
import 'package:kumbha_path/src/modules/location/widgets/shared_location_note.dart';
import 'package:kumbha_path/src/modules/lostfound/models/lf_models.dart';
import 'package:kumbha_path/src/modules/lostfound/widgets/lf_parts.dart';
import 'package:kumbha_path/src/modules/reunion/data/reunion_repository.dart';
import 'package:kumbha_path/src/modules/reunion/models/reunion_models.dart';
import 'package:kumbha_path/src/modules/reunion/point_explorer_screen.dart';
import 'package:kumbha_path/src/modules/reunion/route_preview_screen.dart'
    show PointExplorerArgs;
import 'package:kumbha_path/src/modules/reunion/widgets/reunion_parts.dart';

/// `/reunionCase`: getting one family back together. Everything here is
/// coordination. Only staff, in person, can record a reunion, and they do that
/// on the case itself.
class ReunionCaseScreen extends StatefulWidget {
  const ReunionCaseScreen({
    super.key,
    required this.id,
    this.repository,
    this.showSharedLocation = true,
  });

  final String id;
  final ReunionRepository? repository;

  /// Off in tests that have no location server to ask.
  final bool showSharedLocation;

  @override
  State<ReunionCaseScreen> createState() => _ReunionCaseScreenState();
}

class _ReunionCaseScreenState extends State<ReunionCaseScreen> {
  late final ReunionRepository _repo =
      widget.repository ?? ReunionServices.repository;
  ReunionCase? _case;
  List<MeetingPoint> _recommended = const [];
  Object? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final view = await _repo.caseView(widget.id);
      var recommended = const <MeetingPoint>[];
      if (view.detail.isOpen && view.plan.meetingPoint == null) {
        try {
          recommended = await _repo.guidance(widget.id);
        } catch (_) {
          // The rest of the case is still useful.
        }
      }
      if (mounted) {
        setState(() {
          _case = view;
          _recommended = recommended;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _pick(bool isProtected) async {
    await Navigator.pushNamed(
      context,
      '/reunionPoints',
      arguments: PointExplorerArgs(
        safeOnly: isProtected,
        caseId: widget.id,
        picking: true,
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _openPoint(MeetingPoint point) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder:
          (_) => PointSheet(
            point: point,
            repository: _repo,
            caseId: widget.id,
            picking: true,
          ),
    );
    if (mounted) await _load();
  }

  Future<void> _coordinate({String? event, String? update}) async {
    setState(() => _busy = true);
    try {
      await _repo.coordinate(widget.id, event: event, update: update);
      await _load();
      if (mounted) showJourneySnack(context, 're_recorded'.tr());
    } catch (e) {
      if (mounted) showJourneySnack(context, reunionErrorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _arrived(String event, String title, String body) async {
    final sure = await confirmJourneyAction(
      context,
      title: title.tr(),
      message: body.tr(),
      confirm: 're_confirm'.tr(),
    );
    if (sure) await _coordinate(event: event);
  }

  Future<void> _sendUpdate() async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('re_staff_update'.tr()),
            content: TextField(
              controller: controller,
              maxLength: 1000,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 're_staff_update_hint'.tr(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  MaterialLocalizations.of(context).cancelButtonLabel,
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, controller.text.trim()),
                child: Text('re_send'.tr()),
              ),
            ],
          ),
    );
    controller.dispose();
    if (text != null && text.isNotEmpty) await _coordinate(update: text);
  }

  @override
  Widget build(BuildContext context) {
    final view = _case;
    final failed = _error;
    return Scaffold(
      appBar: AppBar(title: Text('re_case_title'.tr())),
      body: SafeArea(
        child:
            view != null
                ? RefreshIndicator(onRefresh: _load, child: _body(view))
                : failed != null
                ? AppErrorView(
                  message: reunionErrorText(failed),
                  onRetry: _load,
                )
                : const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _body(ReunionCase view) {
    final e = context.editorial;
    final c = view.detail;
    final plan = view.plan;
    final point = plan.meetingPoint;
    final name = c.personName.isEmpty ? 'lf_unnamed'.tr() : c.personName;
    final seen = c.eventAt;
    final updates = c.timeline.where((t) => t.kind == 'note').toList();
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        editorialMargin,
        AppSpacing.sm,
        editorialMargin,
        AppSpacing.huge,
      ),
      children: [
        Text(c.reference, style: e.meta),
        Semantics(header: true, child: Text(name, style: e.headline)),
        AppSpacing.gapMd,
        ReunionStageRail(stage: plan.stage),
        if (view.isProtected && c.isOpen) ...[
          AppSpacing.gapLg,
          const SafetyPanel(),
        ],
        AppSpacing.gapXl,
        Text('re_meeting_title'.tr(), style: e.headline),
        AppSpacing.gapSm,
        if (point != null) ...[
          PointRow(point: point, onTap: () => _openPoint(point)),
          if (plan.familyArrivedAt != null)
            Text('re_family_there'.tr(), style: e.meta),
          if (plan.personArrivedAt != null)
            Text('re_person_there'.tr(), style: e.meta),
        ] else if (_recommended.isNotEmpty) ...[
          Text(
            (view.isProtected ? 're_recommended_safe' : 're_recommended').tr(),
          ),
          AppSpacing.gapXs,
          for (final p in _recommended)
            PointRow(point: p, onTap: () => _openPoint(p)),
        ] else
          Text('re_points_none_body'.tr(), style: e.meta),
        if (c.isOpen) ...[
          AppSpacing.gapSm,
          AppButton.secondary(
            label: (point == null ? 're_pick_point' : 're_change_point').tr(),
            leadingIcon: Icons.flag_outlined,
            onPressed: () => _pick(view.isProtected),
          ),
          if (point != null && plan.familyArrivedAt == null) ...[
            AppSpacing.gapSm,
            AppButton.secondary(
              label: 're_we_arrived'.tr(),
              isLoading: _busy,
              onPressed:
                  _busy
                      ? null
                      : () => _arrived(
                        'family_arrived',
                        're_arrived_title',
                        're_arrived_body',
                      ),
            ),
          ],
        ],
        if (view.canOperate && c.isOpen) ...[
          AppSpacing.gapXl,
          Text('re_staff_title'.tr(), style: e.headline),
          AppSpacing.gapSm,
          if (point != null && plan.personArrivedAt == null) ...[
            AppButton.secondary(
              label: 're_person_arrived'.tr(),
              onPressed:
                  _busy
                      ? null
                      : () => _arrived(
                        'person_arrived',
                        're_person_arrived',
                        're_arrived_body',
                      ),
            ),
            AppSpacing.gapSm,
          ],
          AppButton.secondary(
            label: 're_staff_update'.tr(),
            onPressed: _busy ? null : _sendUpdate,
          ),
          AppSpacing.gapSm,
          AppButton.secondary(
            label: 're_verify_handover'.tr(),
            leadingIcon: Icons.verified_user_outlined,
            onPressed:
                () => Navigator.pushNamed(
                  context,
                  '/lostFoundOpsCase',
                  arguments: widget.id,
                ),
          ),
          AppSpacing.gapXs,
          Text('re_no_proximity'.tr(), style: e.meta),
        ],
        AppSpacing.gapXl,
        Text('re_where_title'.tr(), style: e.headline),
        AppSpacing.gapSm,
        if (c.locationText.isNotEmpty)
          FactRow(label: 'lf_last_seen'.tr(), value: c.locationText),
        if (seen != null)
          FactRow(
            label: 'lf_when'.tr(),
            value:
                '${dateTimeText(context, seen)} · ${agoText(DateTime.now().difference(seen).inSeconds)}',
          ),
        Text('lf_not_live'.tr(), style: e.meta),
        if (widget.showSharedLocation && c.isLost && c.isOpen) ...[
          AppSpacing.gapMd,
          SharedLocationNote(caseId: c.id),
        ],
        if (c.sightings.isNotEmpty) ...[
          AppSpacing.gapXl,
          Text('lf_sightings'.tr(), style: e.headline),
          AppSpacing.gapSm,
          for (final s in c.sightings) _SightingLine(sighting: s),
        ],
        if (updates.isNotEmpty) ...[
          AppSpacing.gapXl,
          Text('re_updates_title'.tr(), style: e.headline),
          AppSpacing.gapSm,
          for (final u in updates)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(u.body ?? ''),
                  if (u.at != null)
                    Text(dateTimeText(context, u.at!), style: e.meta),
                ],
              ),
            ),
        ],
        AppSpacing.gapXl,
        TextButton.icon(
          style: TextButton.styleFrom(padding: EdgeInsets.zero),
          onPressed:
              () => Navigator.pushNamed(
                context,
                view.canOperate ? '/lostFoundOpsCase' : '/lostFoundCase',
                arguments: widget.id,
              ),
          icon: const Icon(Icons.folder_open_outlined, size: 18),
          label: Text('re_open_full_case'.tr()),
        ),
        const NotOfficialNote(),
      ],
    );
  }
}

class _SightingLine extends StatelessWidget {
  const _SightingLine({required this.sighting});

  final Sighting sighting;

  @override
  Widget build(BuildContext context) {
    final at = sighting.seenAt;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                sighting.verified
                    ? Icons.verified_outlined
                    : Icons.record_voice_over_outlined,
                size: 16,
                color: context.colorScheme.primary,
              ),
              AppSpacing.gapXs,
              Text(
                (sighting.verified
                        ? 're_sighting_verified'
                        : 're_sighting_reported')
                    .tr(),
                style: context.textTheme.labelMedium,
              ),
            ],
          ),
          if (sighting.description.isNotEmpty) Text(sighting.description),
          MetaLine([
            sighting.locationText,
            if (at != null) dateTimeText(context, at),
          ]),
        ],
      ),
    );
  }
}
