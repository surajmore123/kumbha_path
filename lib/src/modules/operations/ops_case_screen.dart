import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/modules/emergency/models/emergency_models.dart';
import 'package:kumbha_path/src/modules/emergency/widgets/sos_parts.dart'
    show askForText;
import 'package:kumbha_path/src/modules/family/widgets/family_parts.dart';
import 'package:kumbha_path/src/modules/journey/widgets/journey_ui.dart'
    show confirmJourneyAction, showJourneySnack;
import 'package:kumbha_path/src/modules/lostfound/data/lf_repository.dart'
    show LostFoundRepository, LostFoundServices;
import 'package:kumbha_path/src/modules/lostfound/widgets/case_ai_panel.dart';
import 'package:kumbha_path/src/modules/lostfound/widgets/lf_parts.dart'
    show dateTimeText, statusLabel;
import 'package:kumbha_path/src/modules/operations/data/ops_repository.dart';
import 'package:kumbha_path/src/modules/operations/ops_home_screen.dart'
    show assignmentLabel, availabilityLabel;

/// `/opsCase`: one assigned case. It shows what's needed to find the person and
/// nothing else, and the server withholds a child's exact position. Finishing
/// a task never changes the case itself.
class AssignedCaseScreen extends StatefulWidget {
  const AssignedCaseScreen({
    super.key,
    required this.id,
    this.repository,
    this.caseRepository,
  });

  final String id;
  final OpsRepository? repository;
  final LostFoundRepository? caseRepository;

  @override
  State<AssignedCaseScreen> createState() => _AssignedCaseScreenState();
}

class _AssignedCaseScreenState extends State<AssignedCaseScreen> {
  late final OpsRepository _repo = widget.repository ?? OpsServices.repository;
  OpsCase? _case;
  OpsMe? _me;
  List<OpsAssignment> _history = const [];
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
      final me = await _repo.me();
      final item = await _repo.caseDetail(widget.id);
      final history =
          me.canAssign ? await _repo.history(widget.id) : <OpsAssignment>[];
      if (!mounted) return;
      setState(() {
        _me = me;
        _case = item;
        _history = history;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _act(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      await _load();
      if (mounted) showJourneySnack(context, done.tr());
    } catch (e) {
      if (mounted) showJourneySnack(context, familyErrorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _observe() async {
    final body = await askForText(
      context,
      title: 'ops_add_observation'.tr(),
      hint: 'ops_observation_hint'.tr(),
      confirm: 'sos_send'.tr(),
    );
    if (body != null) {
      await _act(() => _repo.addObservation(widget.id, body), 'ops_saved');
    }
  }

  Future<void> _escalate() async {
    final reason = await askForText(
      context,
      title: 'ops_escalate'.tr(),
      hint: 'ops_escalate_hint'.tr(),
      confirm: 'ops_escalate'.tr(),
      maxLength: 500,
    );
    if (reason != null) {
      await _act(() => _repo.escalate(widget.id, reason), 'ops_escalated');
    }
  }

  Future<void> _assign() async {
    final List<TeamMember> team;
    try {
      team = await _repo.team();
    } catch (e) {
      if (mounted) showJourneySnack(context, familyErrorText(e));
      return;
    }
    if (!mounted) return;
    final chosen = await showModalBottomSheet<TeamMember>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _TeamSheet(team: team),
    );
    if (chosen != null) {
      await _act(() => _repo.assign(widget.id, chosen.userId), 'ops_assigned');
    }
  }

  Future<void> _unassign() async {
    final sure = await confirmJourneyAction(
      context,
      title: 'ops_unassign_title'.tr(),
      message: 'ops_unassign_body'.tr(),
      confirm: 'ops_unassign'.tr(),
      destructive: true,
    );
    if (sure) await _act(() => _repo.unassign(widget.id), 'ops_saved');
  }

  /// The next step for the person doing the work, if there is one.
  (String, String)? _nextStep(OpsCase item, OpsMe me) {
    final assignment = item.assignment;
    if (assignment?.volunteerId != me.userId) return null;
    return switch (assignment?.status) {
      'ASSIGNED' => ('ACCEPTED', 'ops_accept'),
      'ACCEPTED' => ('IN_PROGRESS', 'ops_start'),
      'IN_PROGRESS' || 'ESCALATED' => ('COMPLETED', 'ops_complete'),
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final item = _case;
    final me = _me;
    final failed = _error;
    return Scaffold(
      appBar: AppBar(title: Text('ops_case_title'.tr())),
      body: SafeArea(
        child:
            item != null && me != null
                ? RefreshIndicator(onRefresh: _load, child: _body(item, me))
                : failed != null
                ? AppErrorView(message: familyErrorText(failed), onRetry: _load)
                : const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _body(OpsCase item, OpsMe me) {
    final e = context.editorial;
    final colors = context.colorScheme;
    final at = item.eventAt;
    final assignment = item.assignment;
    final next = _nextStep(item, me);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        editorialMargin,
        AppSpacing.sm,
        editorialMargin,
        AppSpacing.huge,
      ),
      children: [
        Text(item.reference, style: e.meta),
        Semantics(
          header: true,
          child: Text(
            item.personName.isEmpty ? 'lf_unnamed'.tr() : item.personName,
            style: e.headline,
          ),
        ),
        MetaLine([
          statusLabel(item.status),
          if (item.zone != null) item.zone!.name,
        ]),
        if (item.isHighPriority) ...[
          AppSpacing.gapSm,
          FamilyNote(
            title: 'ops_priority_high'.tr(),
            text: 'ops_vulnerable_note'.tr(),
          ),
        ],
        if (assignment != null) ...[
          AppSpacing.gapMd,
          FactRow(
            label: 'ops_assignment'.tr(),
            value: assignmentLabel(assignment.status),
          ),
          if (assignment.notes.isNotEmpty)
            FactRow(label: 'ops_notes'.tr(), value: assignment.notes),
          if (assignment.escalationReason.isNotEmpty)
            FactRow(
              label: 'ops_escalation_reason'.tr(),
              value: assignment.escalationReason,
            ),
        ],
        AppSpacing.gapMd,
        if (item.physical.isNotEmpty)
          FactRow(label: 'lf_field_physical'.tr(), value: item.physical),
        if (item.clothing.isNotEmpty)
          FactRow(label: 'lf_field_clothing'.tr(), value: item.clothing),
        if (item.marks.isNotEmpty)
          FactRow(label: 'ops_marks'.tr(), value: item.marks),
        if (item.locationText.isNotEmpty)
          FactRow(label: 'lf_last_seen'.tr(), value: item.locationText),
        if (at != null)
          FactRow(label: 'lf_when'.tr(), value: dateTimeText(context, at)),
        if (item.safeFacility.isNotEmpty)
          FactRow(label: 'lf_safe_at'.tr(), value: item.safeFacility),
        AppSpacing.gapLg,
        if (next != null) ...[
          AppButton(
            label: next.$2.tr(),
            isLoading: _busy,
            onPressed:
                _busy
                    ? null
                    : () => _act(
                      () => _repo.progress(widget.id, next.$1),
                      'ops_saved',
                    ),
          ),
          AppSpacing.gapXs,
          Text('ops_progress_note'.tr(), style: e.meta),
          AppSpacing.gapSm,
        ],
        AppButton.secondary(
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
        AppButton.secondary(
          label: 'ops_add_observation'.tr(),
          onPressed: _busy ? null : _observe,
        ),
        AppSpacing.gapSm,
        AppButton.secondary(
          label: 'ops_escalate'.tr(),
          leadingIcon: Icons.outbound_outlined,
          onPressed: _busy ? null : _escalate,
        ),
        if (me.canManageCases) ...[
          AppSpacing.gapSm,
          AppButton.secondary(
            label: 'ops_open_full_case'.tr(),
            leadingIcon: Icons.folder_open_outlined,
            onPressed:
                () => Navigator.pushNamed(
                  context,
                  '/lostFoundOpsCase',
                  arguments: widget.id,
                ),
          ),
        ],
        AppSpacing.gapLg,
        CaseAiPanel(
          caseId: widget.id,
          repository: widget.caseRepository ?? LostFoundServices.repository,
          fields: [
            CaseAiField(
              'physical_description',
              'lf_field_physical'.tr(),
              item.physical,
            ),
            CaseAiField(
              'clothing_description',
              'lf_field_clothing'.tr(),
              item.clothing,
            ),
            CaseAiField('identifying_marks', 'ops_marks'.tr(), item.marks),
          ],
        ),
        if (me.canAssign) ...[
          AppSpacing.gapLg,
          Text('ops_assignment'.tr(), style: e.title),
          AppSpacing.gapSm,
          AppButton.secondary(
            label: (assignment == null ? 'ops_assign' : 'ops_reassign').tr(),
            leadingIcon: Icons.assignment_ind_outlined,
            onPressed: _busy ? null : _assign,
          ),
          if (assignment != null)
            TextButton(
              onPressed: _busy ? null : _unassign,
              child: Text(
                'ops_unassign'.tr(),
                style: TextStyle(color: colors.error),
              ),
            ),
          if (_history.isNotEmpty) ...[
            AppSpacing.gapMd,
            Text('ops_history'.tr(), style: e.title),
            for (final row in _history)
              FactRow(
                label: row.volunteerName,
                value: [
                  assignmentLabel(row.status),
                  if (row.assignedAt != null)
                    dateTimeText(context, row.assignedAt!),
                ].join(' · '),
              ),
          ],
        ],
      ],
    );
  }
}

class _TeamSheet extends StatelessWidget {
  const _TeamSheet({required this.team});

  final List<TeamMember> team;

  @override
  Widget build(BuildContext context) {
    final e = context.editorial;
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(
          editorialMargin,
          0,
          editorialMargin,
          AppSpacing.md,
        ),
        children: [
          Text('ops_choose_volunteer'.tr(), style: e.title),
          AppSpacing.gapSm,
          if (team.isEmpty) Text('ops_team_empty'.tr(), style: e.meta),
          for (final person in team)
            ListTile(
              contentPadding: EdgeInsets.zero,
              enabled: person.canTakeWork,
              title: Text(person.name),
              subtitle: Text(availabilityLabel(person.availability)),
              trailing: Text('ops_open_count'.plural(person.openCases)),
              onTap:
                  person.canTakeWork
                      ? () => Navigator.pop(context, person)
                      : null,
            ),
        ],
      ),
    );
  }
}

/// Responder controls for an SOS. Each is a separate, deliberate step, and
/// nothing here contacts any emergency service.
class SosResponderPanel extends StatefulWidget {
  const SosResponderPanel({
    super.key,
    required this.sos,
    required this.onChanged,
    this.repository,
  });

  final SosDetail sos;
  final Future<void> Function() onChanged;
  final OpsRepository? repository;

  @override
  State<SosResponderPanel> createState() => _SosResponderPanelState();
}

class _SosResponderPanelState extends State<SosResponderPanel> {
  late final OpsRepository _repo = widget.repository ?? OpsServices.repository;
  bool _busy = false;

  Future<void> _run(String action, {String? body}) async {
    setState(() => _busy = true);
    try {
      await _repo.sosAction(widget.sos.id, action, body: body);
      await widget.onChanged();
    } catch (e) {
      if (mounted) showJourneySnack(context, familyErrorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _withText(String action, String title, String hint) async {
    final body = await askForText(
      context,
      title: title.tr(),
      hint: hint.tr(),
      confirm: 'sos_send'.tr(),
      maxLength: 500,
    );
    if (body != null) await _run(action, body: body);
  }

  Future<void> _acknowledge() async {
    final sure = await confirmJourneyAction(
      context,
      title: 'ops_sos_ack_title'.tr(),
      message: 'ops_sos_ack_body'.tr(),
      confirm: 'ops_sos_ack'.tr(),
    );
    if (sure) await _run('acknowledge');
  }

  @override
  Widget build(BuildContext context) {
    final e = context.editorial;
    final status = widget.sos.status;
    final waiting = status == 'SUBMITTED' || status == 'FAMILY_NOTIFIED';
    final acknowledged = status == 'ACKNOWLEDGED';
    final coordinated = status == 'ASSISTANCE_COORDINATED';
    final canClose = status == 'RESOLVED' || status == 'CANCELLED';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('ops_responder_title'.tr(), style: e.title),
        Text('ops_responder_note'.tr(), style: e.meta),
        AppSpacing.gapSm,
        if (waiting)
          AppButton(
            label: 'ops_sos_ack'.tr(),
            isLoading: _busy,
            onPressed: _busy ? null : _acknowledge,
          ),
        if (acknowledged)
          AppButton(
            label: 'ops_sos_coordinate'.tr(),
            onPressed:
                _busy
                    ? null
                    : () => _withText(
                      'coordinate',
                      'ops_sos_coordinate',
                      'ops_sos_coordinate_hint',
                    ),
          ),
        if (acknowledged || coordinated) ...[
          AppSpacing.gapSm,
          AppButton.secondary(
            label: 'ops_sos_resolve'.tr(),
            onPressed:
                _busy
                    ? null
                    : () => _withText(
                      'resolve',
                      'ops_sos_resolve',
                      'ops_sos_resolve_hint',
                    ),
          ),
        ],
        if (canClose)
          AppButton.secondary(
            label: 'ops_sos_close'.tr(),
            onPressed: _busy ? null : () => _run('close'),
          ),
        if (widget.sos.isActive) ...[
          AppSpacing.gapSm,
          AppButton.secondary(
            label: 'ops_sos_update'.tr(),
            onPressed:
                _busy
                    ? null
                    : () => _withText(
                      'update',
                      'ops_sos_update',
                      'ops_sos_update_hint',
                    ),
          ),
          AppSpacing.gapSm,
          AppButton.secondary(
            label: 'ops_escalate'.tr(),
            leadingIcon: Icons.outbound_outlined,
            onPressed:
                _busy
                    ? null
                    : () => _withText(
                      'escalate',
                      'ops_escalate',
                      'ops_escalate_hint',
                    ),
          ),
        ],
      ],
    );
  }
}
