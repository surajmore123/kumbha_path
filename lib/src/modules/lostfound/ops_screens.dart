import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/modules/family/widgets/family_parts.dart';
import 'package:kumbha_path/src/modules/journey/widgets/journey_ui.dart'
    show openExternal, showJourneySnack;
import 'package:kumbha_path/src/modules/lostfound/data/lf_repository.dart';
import 'package:kumbha_path/src/modules/lostfound/models/lf_models.dart';
import 'package:kumbha_path/src/modules/lostfound/widgets/case_ai_panel.dart';
import 'package:kumbha_path/src/modules/lostfound/widgets/lf_parts.dart';

const _checkMethods = [
  'id_document',
  'known_to_staff',
  'family_in_person',
  'other',
];

/// `/lostFoundOps`: the role-protected foundation. Every route behind it is
/// refused by the server for anyone else, whatever this screen shows.
class OpsHomeScreen extends StatefulWidget {
  const OpsHomeScreen({super.key, this.repository});

  final LostFoundRepository? repository;

  @override
  State<OpsHomeScreen> createState() => _OpsHomeScreenState();
}

class _OpsHomeScreenState extends State<OpsHomeScreen> {
  late final LostFoundRepository _repo =
      widget.repository ?? LostFoundServices.repository;
  final _search = TextEditingController();
  OpsPage? _page;
  Object? _error;
  String? _type;
  String? _status;
  bool _mine = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final page = await _repo.opsCases(
        type: _type,
        status: _status,
        query: _search.text.trim(),
        mine: _mine,
      );
      if (mounted) setState(() => _page = page);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _set(VoidCallback change) {
    setState(change);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final page = _page;
    final colors = context.colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text('lf_ops_title'.tr())),
      body: SafeArea(
        child:
            _error != null
                ? AppErrorView(message: lfErrorText(_error!), onRetry: _load)
                : ListView(
                  padding: const EdgeInsets.all(editorialMargin),
                  children: [
                    AppTextField(
                      controller: _search,
                      label: 'lf_ops_search'.tr(),
                      textCapitalization: TextCapitalization.characters,
                      onFieldSubmitted: (_) => _load(),
                    ),
                    AppSpacing.gapSm,
                    Wrap(
                      spacing: AppSpacing.sm,
                      children: [
                        FilterChip(
                          label: Text('lf_ops_mine'.tr()),
                          selected: _mine,
                          onSelected: (v) => _set(() => _mine = v),
                        ),
                        for (final t in const ['lost', 'found'])
                          FilterChip(
                            label: Text('lf_type_$t'.tr()),
                            selected: _type == t,
                            onSelected: (v) => _set(() => _type = v ? t : null),
                          ),
                      ],
                    ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final s in caseStages)
                            Padding(
                              padding: const EdgeInsets.only(
                                right: AppSpacing.sm,
                              ),
                              child: FilterChip(
                                label: Text(statusLabel(s)),
                                selected: _status == s,
                                onSelected:
                                    (v) => _set(() => _status = v ? s : null),
                              ),
                            ),
                        ],
                      ),
                    ),
                    AppSpacing.gapMd,
                    if (page == null)
                      const Center(child: CircularProgressIndicator())
                    else if (page.rows.isEmpty)
                      AppEmptyState(
                        compact: true,
                        icon: Icons.inbox_outlined,
                        title: 'lf_ops_none'.tr(),
                      ),
                    for (final row in page?.rows ?? const <OpsCaseRow>[])
                      Pressable(
                        onTap: () async {
                          await Navigator.pushNamed(
                            context,
                            '/lostFoundOpsCase',
                            arguments: row.id,
                          );
                          if (mounted) await _load();
                        },
                        label: row.reference,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: AppSpacing.md),
                          padding: const EdgeInsets.only(left: AppSpacing.md),
                          decoration: BoxDecoration(
                            border: Border(
                              left: BorderSide(
                                width: 3,
                                color:
                                    row.isVulnerable
                                        ? colors.error
                                        : colors.primary,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                row.reference,
                                style: context.editorial.title,
                              ),
                              StatusTag(row.status),
                              MetaLine([
                                'lf_type_${row.caseType}'.tr(),
                                if (row.isVulnerable) 'lf_ops_vulnerable'.tr(),
                                if (row.matchCount > 0)
                                  'lf_ops_matches'.plural(row.matchCount),
                              ]),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
      ),
    );
  }
}

/// `/lostFoundOpsCase`: working one case.
class OpsCaseScreen extends StatefulWidget {
  const OpsCaseScreen({super.key, required this.id, this.repository});

  final String id;
  final LostFoundRepository? repository;

  @override
  State<OpsCaseScreen> createState() => _OpsCaseScreenState();
}

class _OpsCaseScreenState extends State<OpsCaseScreen> {
  late final LostFoundRepository _repo =
      widget.repository ?? LostFoundServices.repository;
  OpsCase? _case;
  Object? _error;
  String? _phone;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final loaded = await _repo.opsCase(widget.id);
      if (mounted) setState(() => _case = loaded);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _run(Future<OpsCase> Function() action) async {
    try {
      final updated = await action();
      if (mounted) setState(() => _case = updated);
    } catch (e) {
      if (mounted) showJourneySnack(context, lfErrorText(e));
    }
  }

  Future<void> _changeStatus(String status) async {
    final reason = await _askText(statusLabel(status), 'lf_ops_reason'.tr());
    if (reason != null) {
      await _run(() => _repo.changeStatus(widget.id, status, reason));
    }
  }

  Future<void> _addNote(String kind) async {
    final body = await _askText('lf_ops_note_$kind'.tr(), 'lf_ops_note'.tr());
    if (body != null) await _run(() => _repo.addNote(widget.id, kind, body));
  }

  Future<String?> _askText(String title, String label) => showDialog<String>(
    context: context,
    builder: (ctx) {
      final text = TextEditingController();
      return AlertDialog(
        title: Text(title),
        content: AppTextField(
          controller: text,
          label: label,
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('scan_cancel'.tr()),
          ),
          TextButton(
            onPressed: () {
              final value = text.text.trim();
              if (value.isNotEmpty) Navigator.pop(ctx, value);
            },
            child: Text('fam_save'.tr()),
          ),
        ],
      );
    },
  );

  Future<void> _reveal() async {
    try {
      final phone = await _repo.revealContact(widget.id);
      if (mounted) setState(() => _phone = phone);
    } catch (e) {
      if (mounted) showJourneySnack(context, lfErrorText(e));
    }
  }

  Future<void> _record({required bool reunion}) async {
    final result = await showModalBottomSheet<CheckResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder:
          (_) => CheckSheet(
            reunion: reunion,
            vulnerable: _case?.row.isVulnerable ?? false,
          ),
    );
    if (result == null) return;
    await _run(
      () =>
          reunion
              ? _repo.reunite(
                widget.id,
                method: result.method,
                remarks: result.remarks,
                identityChecked: result.identityChecked,
                personRecognised: result.personRecognised,
              )
              : _repo.verify(widget.id, result.method, result.remarks),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loaded = _case;
    return Scaffold(
      appBar: AppBar(title: Text(loaded?.row.reference ?? 'lf_case'.tr())),
      body: SafeArea(
        child:
            loaded == null
                ? (_error == null
                    ? const Center(child: CircularProgressIndicator())
                    : AppErrorView(
                      message: lfErrorText(_error!),
                      onRetry: _load,
                    ))
                : _body(loaded),
      ),
    );
  }

  Widget _body(OpsCase c) {
    final e = context.editorial;
    final d = c.detail;
    final at = d.eventAt;
    final phone = _phone;
    return ListView(
      padding: const EdgeInsets.all(editorialMargin),
      children: [
        StageRail(status: d.status),
        if (c.row.isVulnerable) ...[
          AppSpacing.gapMd,
          FamilyNote(
            title: 'lf_ops_vulnerable'.tr(),
            text: 'lf_ops_vulnerable_body'.tr(),
          ),
        ],
        if (c.familyConfirmed) ...[
          AppSpacing.gapMd,
          FamilyNote(text: 'lf_ops_family_says'.tr()),
        ],
        AppSpacing.gapMd,
        if (d.personName.isNotEmpty)
          FactRow(label: 'lf_field_name'.tr(), value: d.personName),
        if (d.ageMin != null)
          FactRow(
            label: 'lf_field_age'.tr(),
            value: ageText(d.ageMin, d.ageMax),
          ),
        if (d.physical.isNotEmpty)
          FactRow(label: 'lf_field_physical'.tr(), value: d.physical),
        if (d.clothing.isNotEmpty)
          FactRow(label: 'lf_field_clothing'.tr(), value: d.clothing),
        if (d.marks.isNotEmpty)
          FactRow(label: 'lf_field_marks'.tr(), value: d.marks),
        FactRow(label: 'lf_last_seen'.tr(), value: d.locationText),
        if (at != null)
          FactRow(label: 'lf_when'.tr(), value: dateTimeText(context, at)),
        if (d.safeFacility.isNotEmpty)
          FactRow(label: 'lf_safe_at'.tr(), value: d.safeFacility),
        if (d.attachmentIds.isNotEmpty) ...[
          AppSpacing.gapMd,
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final id in d.attachmentIds)
                PrivatePhoto(id: id, repository: _repo),
            ],
          ),
        ],
        AppSpacing.gapLg,
        if (phone == null)
          AppButton.secondary(
            label: 'lf_ops_reveal'.tr(),
            leadingIcon: Icons.call_outlined,
            onPressed: _reveal,
          )
        else
          FactRow(
            label: 'lf_ops_contact'.tr(),
            value: phone,
            trailing: IconButton(
              tooltip: 'lf_ops_contact'.tr(),
              icon: const Icon(Icons.call_rounded),
              onPressed: () => openExternal(context, 'tel:$phone'),
            ),
          ),
        AppSpacing.gapSm,
        Text('lf_ops_reveal_logged'.tr(), style: e.meta),
        AppSpacing.gapXl,
        Text('lf_ops_status'.tr(), style: e.headline),
        AppSpacing.gapSm,
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            for (final status in c.allowedStatuses)
              ActionChip(
                label: Text(statusLabel(status)),
                onPressed: () => _changeStatus(status),
              ),
          ],
        ),
        AppSpacing.gapSm,
        if (c.linkedToFamily &&
            (d.status == 'VERIFICATION_REQUIRED' ||
                d.status == 'POTENTIAL_MATCH_FOUND'))
          AppButton.secondary(
            label: 're_open_plan'.tr(),
            leadingIcon: Icons.diversity_3_rounded,
            onPressed:
                () => Navigator.pushNamed(
                  context,
                  '/reunionCase',
                  arguments: widget.id,
                ),
          ),
          AppSpacing.gapSm,
          AppButton.secondary(
            label: 'lf_ops_verify'.tr(),
            onPressed: () => _record(reunion: false),
          ),
        if (d.status == 'MATCH_CONFIRMED')
          AppButton(
            label: 'lf_ops_reunite'.tr(),
            onPressed: () => _record(reunion: true),
          ),
        AppSpacing.gapXl,
        Row(
          children: [
            Expanded(
              child: Text('lf_ops_matches_title'.tr(), style: e.headline),
            ),
            IconButton(
              tooltip: 'lf_ops_find'.tr(),
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => _run(() => _repo.findMatches(widget.id)),
            ),
          ],
        ),
        Text('lf_ops_matches_note'.tr(), style: e.meta),
        AppSpacing.gapSm,
        for (final match in c.matches)
          _MatchBlock(
            match: match,
            onOpen: () async {
              await Navigator.pushNamed(
                context,
                '/lostFoundMatch',
                arguments: match,
              );
              if (mounted) await _load();
            },
          ),
        if (c.sightings.isNotEmpty) ...[
          AppSpacing.gapXl,
          Text('lf_sightings'.tr(), style: e.headline),
          for (final s in c.sightings)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.description),
                  MetaLine([s.locationText, 'lf_review_${s.review}'.tr()]),
                  if (s.review == 'pending')
                    Wrap(
                      spacing: AppSpacing.sm,
                      children: [
                        TextButton(
                          onPressed:
                              () => _run(
                                () => _repo.reviewSighting(s.id, approve: true),
                              ),
                          child: Text('lf_ops_share'.tr()),
                        ),
                        TextButton(
                          onPressed:
                              () => _run(
                                () => _repo.reviewSighting(
                                  s.id,
                                  approve: true,
                                  verified: true,
                                ),
                              ),
                          child: Text('lf_ops_share_verified'.tr()),
                        ),
                        TextButton(
                          onPressed:
                              () => _run(
                                () =>
                                    _repo.reviewSighting(s.id, approve: false),
                              ),
                          child: Text('lf_ops_reject'.tr()),
                        ),
                      ],
                    ),
                ],
              ),
            ),
        ],
        AppSpacing.gapXl,
        CaseAiPanel(
          caseId: widget.id,
          repository: _repo,
          canReview: true,
          fields: [
            CaseAiField(
              'physical_description',
              'lf_field_physical'.tr(),
              d.physical,
            ),
            CaseAiField(
              'clothing_description',
              'lf_field_clothing'.tr(),
              d.clothing,
            ),
            CaseAiField('identifying_marks', 'lf_field_marks'.tr(), d.marks),
          ],
        ),
        AppSpacing.gapXl,
        Text('lf_ops_notes'.tr(), style: e.headline),
        for (final note in c.notes)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: FactRow(
              label: 'lf_note_${note.kind}'.tr(),
              value: note.body,
            ),
          ),
        AppSpacing.gapMd,
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            for (final kind in const [
              'internal',
              'family_update',
              'info_request',
            ])
              ActionChip(
                label: Text('lf_ops_note_$kind'.tr()),
                onPressed: () => _addNote(kind),
              ),
          ],
        ),
        AppSpacing.gapLg,
        TextButton(
          onPressed: () => _run(() => _repo.assignToMe(widget.id)),
          child: Text('lf_ops_assign'.tr()),
        ),
      ],
    );
  }
}

class _MatchBlock extends StatelessWidget {
  const _MatchBlock({required this.match, required this.onOpen});

  final CaseMatch match;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onOpen,
    label: 'lf_ops_review_match'.tr(),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${match.lost.reference}  ·  ${match.found.reference}',
                  style: context.editorial.title,
                ),
                MetaLine([
                  'lf_match_state_${match.state}'.tr(),
                  'lf_match_score'.tr(args: ['${match.score}']),
                ]),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_rounded, size: 18),
        ],
      ),
    ),
  );
}

/// `/lostFoundMatch`: two reports side by side, and why they were suggested.
/// The score only sets the order: a person decides everything here.
class MatchReviewScreen extends StatefulWidget {
  const MatchReviewScreen({super.key, required this.match, this.repository});

  final CaseMatch match;
  final LostFoundRepository? repository;

  @override
  State<MatchReviewScreen> createState() => _MatchReviewScreenState();
}

class _MatchReviewScreenState extends State<MatchReviewScreen> {
  late final LostFoundRepository _repo =
      widget.repository ?? LostFoundServices.repository;
  bool _notifyFamily = false;
  bool _busy = false;

  Future<void> _act(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showJourneySnack(context, lfErrorText(e));
    }
  }

  Future<void> _confirm() async {
    final result = await showModalBottomSheet<CheckResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const CheckSheet(reunion: false, vulnerable: false),
    );
    if (result != null) {
      await _act(
        () =>
            _repo.confirmMatch(widget.match.id, result.method, result.remarks),
      );
    }
  }

  Widget _side(String label, MatchSide side) {
    final e = context.editorial;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: e.meta),
        Text(side.reference, style: e.title),
        if (side.ageMin != null) Text(ageText(side.ageMin, side.ageMax)),
        if (side.clothing.isNotEmpty) Text(side.clothing),
        if (side.physical.isNotEmpty) Text(side.physical),
        Text(side.locationText, style: e.meta),
      ],
    );
  }

  String _attributes(List<String> names) =>
      names.map((name) => 'lf_reason_$name'.tr()).join(', ');

  @override
  Widget build(BuildContext context) {
    final e = context.editorial;
    final m = widget.match;
    return Scaffold(
      appBar: AppBar(title: Text('lf_ops_review_match'.tr())),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(editorialMargin),
          children: [
            FamilyNote(
              title: 'lf_match_warning_title'.tr(),
              text: 'lf_match_warning_body'.tr(),
            ),
            AppSpacing.gapLg,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _side('lf_type_lost'.tr(), m.lost)),
                AppSpacing.gapMd,
                Expanded(child: _side('lf_type_found'.tr(), m.found)),
              ],
            ),
            AppSpacing.gapXl,
            Text('lf_match_why'.tr(), style: e.headline),
            AppSpacing.gapXs,
            Text('lf_match_score'.tr(args: ['${m.score}']), style: e.meta),
            AppSpacing.gapXs,
            Text(
              'lf_match_confidence_${m.explanation.confidence}'.tr(),
              style: e.meta,
            ),
            if (m.explanation.matching.isNotEmpty)
              FactRow(
                label: 'lf_match_agrees'.tr(),
                value: _attributes(m.explanation.matching),
              ),
            if (m.explanation.conflicting.isNotEmpty)
              FactRow(
                label: 'lf_match_differs'.tr(),
                value: _attributes(m.explanation.conflicting),
              ),
            if (m.explanation.missing.isNotEmpty)
              FactRow(
                label: 'lf_match_missing'.tr(),
                value: _attributes(m.explanation.missing),
              ),
            if (m.explanation.usesReviewedAi)
              Text('lf_match_used_ai'.tr(), style: e.meta),
            AppSpacing.gapMd,
            for (final reason in m.reasons)
              FactRow(
                label: 'lf_reason_${reason.attribute}'.tr(),
                value: reason.detail,
                trailing: Text(
                  '${reason.points}/${reason.outOf}',
                  style: e.meta,
                ),
              ),
            AppSpacing.gapXl,
            if (m.state == 'suggested') ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('lf_match_notify'.tr()),
                subtitle: Text('lf_match_notify_hint'.tr()),
                value: _notifyFamily,
                onChanged: (v) => setState(() => _notifyFamily = v),
              ),
              AppButton(
                label: 'lf_match_approve'.tr(),
                isLoading: _busy,
                onPressed:
                    _busy
                        ? null
                        : () => _act(
                          () => _repo.approveMatch(
                            m.id,
                            notifyFamily: _notifyFamily,
                          ),
                        ),
              ),
            ],
            if (m.state == 'approved')
              AppButton(
                label: 'lf_match_confirm'.tr(),
                isLoading: _busy,
                onPressed: _busy ? null : _confirm,
              ),
            if (m.state == 'suggested' || m.state == 'approved') ...[
              AppSpacing.gapSm,
              TextButton(
                onPressed:
                    _busy
                        ? null
                        : () => _act(() => _repo.dismissMatch(m.id, '')),
                child: Text('lf_match_dismiss'.tr()),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class CheckResult {
  const CheckResult(
    this.method,
    this.remarks, {
    this.identityChecked = false,
    this.personRecognised = false,
  });

  final String method;
  final String remarks;
  final bool identityChecked;
  final bool personRecognised;
}

/// Records a human check. Both boxes are the person's own statement, so they
/// start unticked, and the server refuses a reunion without them.
class CheckSheet extends StatefulWidget {
  const CheckSheet({
    super.key,
    required this.reunion,
    required this.vulnerable,
  });

  final bool reunion;
  final bool vulnerable;

  @override
  State<CheckSheet> createState() => _CheckSheetState();
}

class _CheckSheetState extends State<CheckSheet> {
  final _remarks = TextEditingController();
  String? _method;
  bool _identity = false;
  bool _recognised = false;

  @override
  void dispose() {
    _remarks.dispose();
    super.dispose();
  }

  bool get _ready =>
      _method != null &&
      _remarks.text.trim().length >= 10 &&
      (!widget.reunion || (_identity && (!widget.vulnerable || _recognised)));

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      left: editorialMargin,
      right: editorialMargin,
      bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
    ),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.reunion ? 'lf_ops_reunite'.tr() : 'lf_ops_verify'.tr(),
            style: context.editorial.headline,
          ),
          AppSpacing.gapXs,
          Text('lf_check_hint'.tr()),
          FieldLabel('lf_check_method'.tr()),
          PillChoices(
            values: _checkMethods,
            labelOf: (m) => 'lf_method_$m'.tr(),
            selected: _method,
            onChanged: (m) => setState(() => _method = m),
          ),
          AppSpacing.gapMd,
          AppTextField(
            controller: _remarks,
            label: 'lf_check_remarks'.tr(),
            maxLength: 800,
            maxLines: 3,
            onChanged: (_) => setState(() {}),
          ),
          if (widget.reunion) ...[
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('lf_check_identity'.tr()),
              value: _identity,
              onChanged: (v) => setState(() => _identity = v ?? false),
            ),
            if (widget.vulnerable)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('lf_check_recognised'.tr()),
                value: _recognised,
                onChanged: (v) => setState(() => _recognised = v ?? false),
              ),
          ],
          AppSpacing.gapMd,
          AppButton(
            label: 'fam_save'.tr(),
            onPressed:
                _ready
                    ? () => Navigator.pop(
                      context,
                      CheckResult(
                        _method!,
                        _remarks.text.trim(),
                        identityChecked: _identity,
                        personRecognised: _recognised,
                      ),
                    )
                    : null,
          ),
        ],
      ),
    ),
  );
}
