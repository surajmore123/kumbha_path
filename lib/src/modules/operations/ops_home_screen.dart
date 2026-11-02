import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/modules/emergency/widgets/sos_parts.dart';
import 'package:kumbha_path/src/modules/family/widgets/family_parts.dart';
import 'package:kumbha_path/src/modules/journey/widgets/journey_ui.dart'
    show showJourneySnack;
import 'package:kumbha_path/src/modules/lostfound/widgets/lf_parts.dart'
    show dateTimeText;
import 'package:kumbha_path/src/modules/notification_centre/notification_centre_screen.dart'
    show NotificationBell;
import 'package:kumbha_path/src/modules/operations/data/ops_repository.dart';
import 'package:kumbha_path/src/modules/reunion/widgets/reunion_parts.dart'
    show categoryIcon, categoryLabel;

String opsRoleLabel(String role) => 'ops_role_$role'.tr();
String availabilityLabel(String state) => 'ops_avail_$state'.tr();
String assignmentLabel(String status) => 'ops_assign_$status'.tr();

/// Sends operational accounts to their dashboard once, using the role the
/// server just returned. Pilgrims, and any failure, stay where they are, so the
/// pilgrim app is unchanged. Back returns to the normal app.
Future<void> openOperationsIfAllowed(
  NavigatorState navigator, {
  OpsRepository? repository,
}) async {
  try {
    final me = await (repository ?? OpsServices.repository).me();
    if (!me.isPilgrim) navigator.pushNamed('/ops');
  } catch (_) {
    // Signed out or offline: nothing changes.
  }
}

/// A case in one line, with priority in words as well as colour.
class OpsCaseCard extends StatelessWidget {
  const OpsCaseCard({super.key, required this.item, required this.onTap});

  final OpsCase item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final e = context.editorial;
    final colors = context.colorScheme;
    final s = context.semanticColors;
    final at = item.eventAt;
    final assignment = item.assignment;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: colors.surfaceContainerHigh,
        borderRadius: AppRadius.lgAll,
        child: InkWell(
          borderRadius: AppRadius.lgAll,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      item.isHighPriority
                          ? Icons.priority_high_rounded
                          : Icons.person_search_outlined,
                      color:
                          item.isHighPriority ? colors.error : colors.primary,
                    ),
                    AppSpacing.gapXs,
                    Expanded(child: Text(item.reference, style: e.title)),
                    if (item.isHighPriority)
                      Text(
                        'ops_priority_high'.tr(),
                        style: e.meta.copyWith(
                          color: colors.error,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
                AppSpacing.gapXs,
                if (item.locationText.isNotEmpty) Text(item.locationText),
                MetaLine([
                  'ops_case_${item.caseType}'.tr(),
                  if (item.zone != null) item.zone!.name,
                  if (at != null) dateTimeText(context, at),
                ]),
                if (assignment != null) ...[
                  AppSpacing.gapXs,
                  Row(
                    children: [
                      Icon(
                        Icons.assignment_ind_outlined,
                        size: 16,
                        color:
                            assignment.status == 'ESCALATED'
                                ? colors.error
                                : s.info,
                      ),
                      AppSpacing.gapXs,
                      Text(assignmentLabel(assignment.status), style: e.meta),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// `/ops`: one dashboard, shaped by what the server says this person may do.
/// Hiding something here is only a convenience: the API refuses it anyway.
class VolunteerHomeScreen extends StatefulWidget {
  const VolunteerHomeScreen({super.key, this.repository});

  final OpsRepository? repository;

  @override
  State<VolunteerHomeScreen> createState() => _VolunteerHomeScreenState();
}

class _VolunteerHomeScreenState extends State<VolunteerHomeScreen> {
  late final OpsRepository _repo = widget.repository ?? OpsServices.repository;
  OpsMe? _me;
  OpsOverview _overview = const OpsOverview();
  Object? _error;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final me = await _repo.me();
      final overview =
          me.isActive ? await _repo.overview() : const OpsOverview();
      if (!mounted) return;
      setState(() {
        _me = me;
        _overview = overview;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _open(String route, {Object? arguments}) async {
    await Navigator.pushNamed(context, route, arguments: arguments);
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final me = _me;
    final failed = _error;
    if (me == null) {
      return Scaffold(
        appBar: AppBar(title: Text('ops_dashboard'.tr())),
        body:
            failed != null
                ? AppErrorView(message: familyErrorText(failed), onRetry: _load)
                : const Center(child: CircularProgressIndicator()),
      );
    }
    if (!me.isActive) return _waiting(me);
    final pages = [
      _overviewPage(me),
      OpsCasesPage(me: me, repository: _repo),
      OpsZonesPage(repository: _repo),
      _ProfilePage(me: me, repository: _repo, onChanged: _load),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text('ops_title_${me.role}'.tr()),
        actions: const [NotificationBell()],
      ),
      body: SafeArea(child: pages[_tab]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.dashboard_outlined),
            label: 'ops_tab_overview'.tr(),
          ),
          NavigationDestination(
            icon: const Icon(Icons.assignment_outlined),
            label: 'ops_tab_cases'.tr(),
          ),
          NavigationDestination(
            icon: const Icon(Icons.map_outlined),
            label: 'ops_tab_zones'.tr(),
          ),
          NavigationDestination(
            icon: const Icon(Icons.badge_outlined),
            label: 'ops_tab_profile'.tr(),
          ),
        ],
      ),
    );
  }

  /// Signed in, but not cleared to do anything yet, or any more.
  Widget _waiting(OpsMe me) {
    final status = me.status ?? 'pending';
    return Scaffold(
      appBar: AppBar(title: Text('ops_dashboard'.tr())),
      body: SafeArea(
        child: AppEmptyState(
          icon: Icons.hourglass_empty_rounded,
          title: 'ops_status_${status}_title'.tr(),
          message: 'ops_status_${status}_body'.tr(),
          actionLabel: 'common_retry'.tr(),
          onAction: _load,
        ),
      ),
    );
  }

  Widget _overviewPage(OpsMe me) {
    final e = context.editorial;
    final o = _overview;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(editorialMargin),
        children: [
          Text(me.fullName, style: e.headline),
          MetaLine([
            opsRoleLabel(me.role),
            availabilityLabel(me.availability),
            if (me.zones.isNotEmpty) me.zones.map((z) => z.name).join(', '),
          ]),
          AppSpacing.gapMd,
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _Stat(label: 'ops_stat_active'.tr(), value: o.active),
              _Stat(label: 'ops_stat_pending'.tr(), value: o.pending),
              _Stat(label: 'ops_stat_completed'.tr(), value: o.completed),
              if (o.openSos != null)
                _Stat(
                  label: 'ops_stat_sos'.tr(),
                  value: o.openSos!,
                  urgent: o.openSos! > 0,
                ),
              if (o.escalations != null)
                _Stat(
                  label: 'ops_stat_escalations'.tr(),
                  value: o.escalations!,
                  urgent: o.escalations! > 0,
                ),
              if (o.unassigned != null)
                _Stat(label: 'ops_stat_unassigned'.tr(), value: o.unassigned!),
            ],
          ),
          AppSpacing.gapLg,
          Text('ops_quick_actions'.tr(), style: e.title),
          AppSpacing.gapSm,
          if (me.canScan) ...[
            AppButton(
              label: 'ops_scan'.tr(),
              leadingIcon: Icons.qr_code_scanner_rounded,
              onPressed: () => _open('/safetyScan'),
            ),
            AppSpacing.gapSm,
            AppButton.secondary(
              label: 'ops_register_found'.tr(),
              leadingIcon: Icons.person_add_alt_outlined,
              onPressed: () => _open('/lostFoundFound'),
            ),
            AppSpacing.gapSm,
          ],
          if (me.canManageCases) ...[
            AppButton.secondary(
              label: 'ops_register_missing'.tr(),
              leadingIcon: Icons.person_search_outlined,
              onPressed: () => _open('/lostFoundReport'),
            ),
            AppSpacing.gapSm,
            AppButton.secondary(
              label: 'ops_manage_cases'.tr(),
              leadingIcon: Icons.folder_open_outlined,
              onPressed: () => _open('/lostFoundOps'),
            ),
            AppSpacing.gapSm,
          ],
          if (me.canViewSos)
            AppButton.secondary(
              label: 'ops_sos_alerts'.tr(),
              leadingIcon: Icons.sos_rounded,
              onPressed: () => _open('/opsSos'),
            ),
          if (me.canViewTeam) ...[
            AppSpacing.gapSm,
            AppButton.secondary(
              label: 'ops_team'.tr(),
              leadingIcon: Icons.groups_outlined,
              onPressed: () => _open('/opsTeam'),
            ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.urgent = false});

  final String label;
  final int value;
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final tone = urgent ? colors.error : colors.primary;
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minWidth: 104),
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHigh,
          borderRadius: AppRadius.mdAll,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$value',
              style: context.textTheme.headlineSmall?.copyWith(color: tone),
            ),
            Text(label, style: context.editorial.meta),
          ],
        ),
      ),
    );
  }
}

/// Assigned work, plus, for coordinators, what needs someone.
class OpsCasesPage extends StatefulWidget {
  const OpsCasesPage({super.key, required this.me, required this.repository});

  final OpsMe me;
  final OpsRepository repository;

  @override
  State<OpsCasesPage> createState() => _OpsCasesPageState();
}

class _OpsCasesPageState extends State<OpsCasesPage> {
  String _view = 'open';
  List<OpsCase>? _rows;
  Object? _error;

  List<String> get _views => [
    'open',
    'COMPLETED',
    if (widget.me.canAssign) ...['unassigned', 'escalated'],
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _rows = null;
      _error = null;
    });
    final repo = widget.repository;
    try {
      final rows = await switch (_view) {
        'unassigned' => repo.unassigned(),
        'escalated' => repo.escalations(),
        _ => repo.myCases(status: _view),
      };
      if (mounted) setState(() => _rows = rows);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    final failed = _error;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(editorialMargin),
        children: [
          PillChoices(
            values: _views,
            labelOf: (v) => 'ops_view_$v'.tr(),
            selected: _view,
            onChanged: (v) {
              setState(() => _view = v);
              _load();
            },
          ),
          AppSpacing.gapMd,
          if (failed != null)
            AppErrorView(
              compact: true,
              message: familyErrorText(failed),
              onRetry: _load,
            )
          else if (rows == null)
            const SkeletonLine(height: 96)
          else if (rows.isEmpty)
            AppEmptyState(
              compact: true,
              icon: Icons.assignment_turned_in_outlined,
              title: 'ops_no_cases'.tr(),
              message: 'ops_no_cases_body'.tr(),
            )
          else
            for (final item in rows)
              OpsCaseCard(
                item: item,
                onTap: () async {
                  await Navigator.pushNamed(
                    context,
                    '/opsCase',
                    arguments: item.id,
                  );
                  if (mounted) await _load();
                },
              ),
        ],
      ),
    );
  }
}

class OpsZonesPage extends StatefulWidget {
  const OpsZonesPage({super.key, required this.repository});

  final OpsRepository repository;

  @override
  State<OpsZonesPage> createState() => _OpsZonesPageState();
}

class _OpsZonesPageState extends State<OpsZonesPage> {
  List<ZoneInfo>? _zones;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final zones = await widget.repository.zones();
      if (mounted) setState(() => _zones = zones);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = context.editorial;
    final zones = _zones;
    final failed = _error;
    if (failed != null && zones == null) {
      return AppErrorView(message: familyErrorText(failed), onRetry: _load);
    }
    if (zones == null) return const Center(child: CircularProgressIndicator());
    if (zones.isEmpty) {
      return AppEmptyState(
        icon: Icons.map_outlined,
        title: 'ops_no_zones'.tr(),
        message: 'ops_no_zones_body'.tr(),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(editorialMargin),
        children: [
          for (final info in zones) ...[
            Text(info.zone.name, style: e.headline),
            if (info.city.isNotEmpty) Text(info.city, style: e.meta),
            AppSpacing.gapSm,
            if (info.points.isEmpty)
              Text('ops_no_points'.tr(), style: e.meta)
            else
              for (final point in info.points)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(categoryIcon(point.category)),
                  title: Text(point.name),
                  subtitle: Text(
                    [
                      categoryLabel(point.category),
                      (point.isOfficial
                              ? 're_trust_official'
                              : 're_trust_verified')
                          .tr(),
                    ].join(' · '),
                  ),
                ),
            AppSpacing.gapLg,
          ],
        ],
      ),
    );
  }
}

class _ProfilePage extends StatefulWidget {
  const _ProfilePage({
    required this.me,
    required this.repository,
    required this.onChanged,
  });

  final OpsMe me;
  final OpsRepository repository;
  final Future<void> Function() onChanged;

  @override
  State<_ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<_ProfilePage> {
  bool _saving = false;

  Future<void> _set(String state) async {
    setState(() => _saving = true);
    try {
      await widget.repository.setAvailability(state);
      await widget.onChanged();
    } catch (e) {
      if (mounted) showJourneySnack(context, familyErrorText(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = context.editorial;
    final me = widget.me;
    return ListView(
      padding: const EdgeInsets.all(editorialMargin),
      children: [
        Text(me.fullName, style: e.headline),
        FactRow(label: 'ops_role'.tr(), value: opsRoleLabel(me.role)),
        FactRow(
          label: 'ops_account'.tr(),
          value: 'ops_status_${me.status}'.tr(),
        ),
        FactRow(
          label: 'ops_zones'.tr(),
          value:
              me.zones.isEmpty
                  ? 'ops_no_zones'.tr()
                  : me.zones.map((z) => z.name).join(', '),
        ),
        AppSpacing.gapLg,
        Text('ops_availability'.tr(), style: e.title),
        AppSpacing.gapXs,
        Text('ops_availability_note'.tr(), style: e.meta),
        AppSpacing.gapSm,
        IgnorePointer(
          ignoring: _saving,
          child: PillChoices(
            values: availabilityStates,
            labelOf: availabilityLabel,
            selected: me.availability,
            onChanged: _set,
          ),
        ),
        AppSpacing.gapLg,
        Text('ops_role_managed'.tr(), style: e.meta),
      ],
    );
  }
}

/// `/opsTeam`: who's available, and how much they're carrying.
class OpsTeamScreen extends StatefulWidget {
  const OpsTeamScreen({super.key, this.repository});

  final OpsRepository? repository;

  @override
  State<OpsTeamScreen> createState() => _OpsTeamScreenState();
}

class _OpsTeamScreenState extends State<OpsTeamScreen> {
  late final OpsRepository _repo = widget.repository ?? OpsServices.repository;
  List<TeamMember>? _team;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final team = await _repo.team();
      if (mounted) setState(() => _team = team);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final team = _team;
    final failed = _error;
    return Scaffold(
      appBar: AppBar(title: Text('ops_team'.tr())),
      body: SafeArea(
        child:
            failed != null
                ? AppErrorView(message: familyErrorText(failed), onRetry: _load)
                : team == null
                ? const Center(child: CircularProgressIndicator())
                : team.isEmpty
                ? AppEmptyState(
                  icon: Icons.groups_outlined,
                  title: 'ops_team_empty'.tr(),
                )
                : ListView(
                  padding: const EdgeInsets.all(editorialMargin),
                  children: [
                    for (final person in team)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(person.name),
                        subtitle: Text(
                          '${opsRoleLabel(person.role)} · ${availabilityLabel(person.availability)}',
                        ),
                        trailing: Text(
                          'ops_open_count'.plural(person.openCases),
                        ),
                      ),
                  ],
                ),
      ),
    );
  }
}

/// `/opsSos`: emergencies this person may see. A notification reaching someone
/// isn't handling it, so each row shows the real status.
class OpsSosScreen extends StatefulWidget {
  const OpsSosScreen({super.key, this.repository});

  final OpsRepository? repository;

  @override
  State<OpsSosScreen> createState() => _OpsSosScreenState();
}

class _OpsSosScreenState extends State<OpsSosScreen> {
  late final OpsRepository _repo = widget.repository ?? OpsServices.repository;
  List<OpsSosRow>? _rows;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final rows = await _repo.sosList();
      if (mounted) setState(() => _rows = rows);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    final failed = _error;
    return Scaffold(
      appBar: AppBar(title: Text('ops_sos_alerts'.tr())),
      body: SafeArea(
        child:
            failed != null
                ? AppErrorView(message: familyErrorText(failed), onRetry: _load)
                : rows == null
                ? const Center(child: CircularProgressIndicator())
                : rows.isEmpty
                ? AppEmptyState(
                  icon: Icons.shield_outlined,
                  title: 'ops_sos_none'.tr(),
                )
                : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(editorialMargin),
                    children: [
                      for (final row in rows)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            sosCategoryIcon(row.category),
                            color: context.colorScheme.error,
                          ),
                          title: Text(sosCategoryLabel(row.category)),
                          subtitle: Text(
                            [
                              row.reference,
                              sosStatusLabel(row.status),
                              if (row.createdAt != null)
                                dateTimeText(context, row.createdAt!),
                            ].join(' · '),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () async {
                            await Navigator.pushNamed(
                              context,
                              '/sosDetail',
                              arguments: row.id,
                            );
                            if (mounted) await _load();
                          },
                        ),
                    ],
                  ),
                ),
      ),
    );
  }
}
