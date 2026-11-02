import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/modules/family/widgets/family_parts.dart';
import 'package:kumbha_path/src/modules/journey/widgets/journey_ui.dart'
    show confirmJourneyAction, openExternal, showJourneySnack;
import 'package:kumbha_path/src/modules/location/widgets/shared_location_note.dart';
import 'package:kumbha_path/src/modules/lostfound/data/lf_repository.dart';
import 'package:kumbha_path/src/modules/lostfound/models/lf_models.dart';
import 'package:kumbha_path/src/modules/lostfound/report_screens.dart'
    show PositionReader;
import 'package:kumbha_path/src/modules/lostfound/widgets/lf_parts.dart';

/// `/lostFoundCase`: what the family can see. The server leaves out internal
/// notes, possible matches, and anything not yet reviewed.
class CaseDetailScreen extends StatefulWidget {
  const CaseDetailScreen({super.key, required this.id, this.repository});

  final String id;
  final LostFoundRepository? repository;

  @override
  State<CaseDetailScreen> createState() => _CaseDetailScreenState();
}

class _CaseDetailScreenState extends State<CaseDetailScreen> {
  late final LostFoundRepository _repo =
      widget.repository ?? LostFoundServices.repository;
  CaseDetail? _case;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final detail = await _repo.caseDetail(widget.id);
      if (mounted) setState(() => _case = detail);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _act(Future<void> Function() action, String done) async {
    try {
      await action();
      await _load();
      if (mounted) showJourneySnack(context, done.tr());
    } catch (e) {
      if (mounted) showJourneySnack(context, lfErrorText(e));
    }
  }

  Future<String?> _ask(String title, String hint) =>
      showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => _TextSheet(title: title, hint: hint),
      );

  Future<void> _addInfo() async {
    final text = await _ask('lf_add_info'.tr(), 'lf_add_info_hint'.tr());
    if (text != null) {
      await _act(() => _repo.addInfo(widget.id, text), 'lf_sent_to_staff');
    }
  }

  Future<void> _correct() async {
    final text = await _ask('lf_correct'.tr(), 'lf_correct_hint'.tr());
    if (text != null) {
      await _act(
        () => _repo.requestCorrection(widget.id, text),
        'lf_sent_to_staff',
      );
    }
  }

  Future<void> _cancel() async {
    final sure = await confirmJourneyAction(
      context,
      title: 'lf_cancel_title'.tr(),
      message: 'lf_cancel_body'.tr(),
      confirm: 'lf_cancel'.tr(),
      destructive: true,
    );
    if (sure) {
      await _act(() => _repo.cancel(widget.id, ''), 'lf_cancelled');
    }
  }

  Future<void> _confirm() async {
    final sure = await confirmJourneyAction(
      context,
      title: 'lf_confirm_title'.tr(),
      message: 'lf_confirm_body'.tr(),
      confirm: 'lf_confirm'.tr(),
    );
    if (sure) {
      await _act(() => _repo.confirmReunion(widget.id), 'lf_sent_to_staff');
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = _case;
    Widget body;
    if (detail == null) {
      body =
          _error == null
              ? const Center(child: CircularProgressIndicator())
              : AppErrorView(message: lfErrorText(_error!), onRetry: _load);
    } else if (!detail.familyView) {
      body = _HelperView(detail: detail);
    } else {
      body = RefreshIndicator(onRefresh: _load, child: _body(detail));
    }
    return Scaffold(
      appBar: AppBar(title: Text('lf_case'.tr())),
      body: SafeArea(child: body),
    );
  }

  Widget _body(CaseDetail c) {
    final e = context.editorial;
    final name = c.personName.isEmpty ? 'lf_unnamed'.tr() : c.personName;
    final at = c.eventAt;
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
        StageRail(status: c.status),
        AppSpacing.gapSm,
        Text(statusMeaning(c.status)),
        if (c.safeFacility.isNotEmpty) ...[
          AppSpacing.gapLg,
          FamilyNote(title: 'lf_safe_at'.tr(), text: c.safeFacility),
        ],
        if (c.status == 'MATCH_CONFIRMED') ...[
          AppSpacing.gapLg,
          FamilyNote(
            title: 'lf_handover_title'.tr(),
            text: 'lf_handover_body'.tr(),
          ),
        ],
        AppSpacing.gapXl,
        Text('lf_description'.tr(), style: e.headline),
        AppSpacing.gapXs,
        Text('lf_description_source'.tr(), style: e.meta),
        if (c.attachmentIds.isNotEmpty) ...[
          AppSpacing.gapMd,
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final id in c.attachmentIds)
                PrivatePhoto(id: id, repository: _repo),
            ],
          ),
        ],
        if (c.ageMin != null)
          FactRow(
            label: 'lf_field_age'.tr(),
            value: ageText(c.ageMin, c.ageMax),
          ),
        if (c.physical.isNotEmpty)
          FactRow(label: 'lf_field_physical'.tr(), value: c.physical),
        if (c.clothing.isNotEmpty)
          FactRow(label: 'lf_field_clothing'.tr(), value: c.clothing),
        if (c.locationText.isNotEmpty)
          FactRow(
            label: c.isLost ? 'lf_last_seen'.tr() : 'lf_found_near'.tr(),
            value: c.locationText,
          ),
        if (at != null)
          FactRow(label: 'lf_when'.tr(), value: dateTimeText(context, at)),
        if (c.latitude != null) ...[
          AppSpacing.gapXs,
          TextButton.icon(
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            onPressed:
                () => openExternal(
                  context,
                  'https://www.google.com/maps/search/?api=1&query=${c.latitude},${c.longitude}',
                ),
            icon: const Icon(Icons.place_outlined, size: 18),
            label: Text('lf_open_last_known'.tr()),
          ),
          Text('lf_not_live'.tr(), style: e.meta),
        ],
        if (c.isLost && c.isOpen) ...[
          AppSpacing.gapLg,
          SharedLocationNote(caseId: c.id),
          AppSpacing.gapSm,
          AppButton.secondary(
            label: 're_open_plan'.tr(),
            leadingIcon: Icons.diversity_3_rounded,
            onPressed:
                () => Navigator.pushNamed(
                  context,
                  '/reunionCase',
                  arguments: c.id,
                ),
          ),
        ],
        if (c.sightings.isNotEmpty) ...[
          AppSpacing.gapXl,
          Text('lf_sightings'.tr(), style: e.headline),
          AppSpacing.gapMd,
          for (final s in c.sightings) _SightingRow(sighting: s),
        ],
        AppSpacing.gapXl,
        Text('lf_timeline'.tr(), style: e.headline),
        AppSpacing.gapMd,
        for (final (i, event) in c.timeline.indexed)
          ThreadStep(
            marker: '${c.timeline.length - i}',
            isLast: i == c.timeline.length - 1,
            child: _TimelineRow(event: event),
          ),
        if (c.isOpen) ...[
          AppSpacing.gapXl,
          if (c.isLost)
            AppButton(
              label: 'lf_add_sighting'.tr(),
              leadingIcon: Icons.visibility_outlined,
              onPressed: () async {
                await Navigator.pushNamed(
                  context,
                  '/lostFoundSighting',
                  arguments: widget.id,
                );
                if (mounted) await _load();
              },
            ),
          AppSpacing.gapSm,
          AppButton.secondary(label: 'lf_add_info'.tr(), onPressed: _addInfo),
          AppSpacing.gapSm,
          AppButton.secondary(label: 'lf_correct'.tr(), onPressed: _correct),
          AppSpacing.gapLg,
          if (c.familyConfirmedAt == null)
            TextButton(onPressed: _confirm, child: Text('lf_confirm_open'.tr()))
          else
            Text('lf_confirm_sent'.tr(), style: e.meta),
          if (c.canCancel)
            TextButton(
              onPressed: _cancel,
              child: Text(
                'lf_cancel'.tr(),
                style: TextStyle(color: context.colorScheme.error),
              ),
            ),
        ],
        AppSpacing.gapLg,
        const NotOfficialNote(),
      ],
    );
  }
}

class _HelperView extends StatelessWidget {
  const _HelperView({required this.detail});

  final CaseDetail detail;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(editorialMargin),
    children: [
      Text(detail.reference, style: context.editorial.meta),
      AppSpacing.gapMd,
      StageRail(status: detail.status),
      AppSpacing.gapMd,
      if (detail.safeFacility.isNotEmpty)
        FactRow(label: 'lf_safe_at'.tr(), value: detail.safeFacility),
      AppSpacing.gapLg,
      FamilyNote(
        title: 'scan_handover_title'.tr(),
        text: 'scan_handover_body'.tr(),
      ),
    ],
  );
}

class _SightingRow extends StatelessWidget {
  const _SightingRow({required this.sighting});

  final Sighting sighting;

  @override
  Widget build(BuildContext context) {
    final e = context.editorial;
    final s = sighting;
    final at = s.seenAt;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                s.verified ? Icons.verified_outlined : Icons.campaign_outlined,
                size: 16,
                color:
                    s.verified
                        ? context.semanticColors.success
                        : context.semanticColors.gold,
              ),
              AppSpacing.gapXs,
              Expanded(
                child: Text(
                  s.verified
                      ? 'lf_verified'.tr()
                      : s.fromHelper
                      ? 'lf_reported_helper'.tr()
                      : 'lf_reported_community'.tr(),
                  style: e.meta,
                ),
              ),
            ],
          ),
          Text(s.description),
          MetaLine([s.locationText, if (at != null) dateTimeText(context, at)]),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.event});

  final TimelineEvent event;

  @override
  Widget build(BuildContext context) {
    final e = context.editorial;
    final at = event.at;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          event.kind == 'status'
              ? statusLabel(event.status ?? '')
              : 'lf_note_${event.noteKind}'.tr(),
          style: e.title,
        ),
        if (event.body != null) Text(event.body!),
        if (at != null) MetaLine([dateTimeText(context, at)]),
      ],
    );
  }
}

class _TextSheet extends StatefulWidget {
  const _TextSheet({required this.title, required this.hint});

  final String title;
  final String hint;

  @override
  State<_TextSheet> createState() => _TextSheetState();
}

class _TextSheetState extends State<_TextSheet> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      left: editorialMargin,
      right: editorialMargin,
      bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.title, style: context.editorial.headline),
        AppSpacing.gapMd,
        AppTextField(
          controller: _text,
          label: widget.hint,
          maxLength: 1000,
          maxLines: 4,
        ),
        AppSpacing.gapMd,
        AppButton(
          label: 'lf_send'.tr(),
          onPressed: () {
            final text = _text.text.trim();
            if (text.isNotEmpty) Navigator.pop(context, text);
          },
        ),
      ],
    ),
  );
}

/// `/lostFoundSighting`: anyone with access to the case can add one. Staff
/// review it before the family sees it.
class AddSightingScreen extends StatefulWidget {
  const AddSightingScreen({
    super.key,
    required this.caseId,
    this.repository,
    this.position = readPosition,
  });

  final String caseId;
  final LostFoundRepository? repository;
  final PositionReader position;

  @override
  State<AddSightingScreen> createState() => _AddSightingScreenState();
}

class _AddSightingScreenState extends State<AddSightingScreen> {
  late final LostFoundRepository _repo =
      widget.repository ?? LostFoundServices.repository;
  final _form = GlobalKey<FormState>();
  final _what = TextEditingController();
  final _where = TextEditingController();
  DateTime? _when;
  (double, double)? _gps;
  bool _busy = false;

  @override
  void dispose() {
    _what.dispose();
    _where.dispose();
    super.dispose();
  }

  /// Sets the time directly. Used by the time field.
  @visibleForTesting
  void pickWhen(DateTime value) => setState(() => _when = value);

  Future<void> _useGps() async {
    final found = await widget.position();
    if (!mounted) return;
    if (found == null) {
      showJourneySnack(context, 'lf_gps_failed'.tr());
    } else {
      setState(() => _gps = found);
    }
  }

  Future<void> _send() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final when = _when;
    if (when == null) {
      showJourneySnack(context, 'lf_need_place'.tr());
      return;
    }
    setState(() => _busy = true);
    try {
      await _repo.addSighting(widget.caseId, {
        'description': _what.text.trim(),
        'location_text': _where.text.trim(),
        'seen_at': when.toUtc().toIso8601String(),
        if (_gps != null) 'latitude': _gps!.$1,
        if (_gps != null) 'longitude': _gps!.$2,
      });
      if (!mounted) return;
      showJourneySnack(context, 'lf_sighting_sent'.tr());
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showJourneySnack(context, lfErrorText(e));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('lf_add_sighting'.tr())),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(editorialMargin),
        children: [
          Text('lf_sighting_hint'.tr(), style: context.editorial.dek),
          AppSpacing.gapLg,
          Form(
            key: _form,
            child: Column(
              children: [
                AppTextField(
                  controller: _what,
                  label: 'lf_sighting_what'.tr(),
                  maxLength: 1000,
                  maxLines: 3,
                  validator:
                      (v) =>
                          (v ?? '').trim().isEmpty
                              ? 'lf_need_description'.tr()
                              : null,
                ),
                AppSpacing.gapMd,
                AppTextField(
                  controller: _where,
                  label: 'lf_sighting_where'.tr(),
                  maxLength: 240,
                  validator:
                      (v) =>
                          (v ?? '').trim().isEmpty
                              ? 'lf_need_place'.tr()
                              : null,
                ),
              ],
            ),
          ),
          WhenField(
            label: 'lf_sighting_when'.tr(),
            value: _when,
            onChanged: (v) => setState(() => _when = v),
          ),
          AppSpacing.gapSm,
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              onPressed: _useGps,
              icon: Icon(
                _gps == null ? Icons.my_location_rounded : Icons.check_rounded,
                size: 18,
              ),
              label: Text(
                _gps == null ? 'lf_add_gps'.tr() : 'lf_gps_added'.tr(),
              ),
            ),
          ),
          AppSpacing.gapLg,
          AppButton(
            label: 'lf_send'.tr(),
            isLoading: _busy,
            onPressed: _busy ? null : _send,
          ),
        ],
      ),
    ),
  );
}
