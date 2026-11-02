import 'dart:async';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:kumbha_path/main_layout.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/modules/family/data/family_repository.dart';
import 'package:kumbha_path/src/modules/family/models/family_models.dart';
import 'package:kumbha_path/src/modules/family/offline/contact_sync.dart';
import 'package:kumbha_path/src/modules/family/widgets/family_parts.dart';
import 'package:kumbha_path/src/modules/safety/data/safety_repository.dart';
import 'package:kumbha_path/src/modules/journey/widgets/journey_ui.dart'
    show openExternal, showJourneySnack;

/// Arguments for screens that work inside one circle.
class FamilyArgs {
  const FamilyArgs(this.circle, {this.memberId, this.member, this.memberName});

  final FamilyCircle circle;
  final String? memberId;
  final FamilyMember? member;
  final String? memberName;
}

/// `/family`: onboarding when you aren't in a family yet, otherwise the circle.
class FamilyHomeScreen extends StatefulWidget {
  const FamilyHomeScreen({super.key, this.repository});

  final FamilyRepository? repository;

  @override
  State<FamilyHomeScreen> createState() => _FamilyHomeScreenState();
}

class _FamilyHomeScreenState extends State<FamilyHomeScreen> {
  late final FamilyRepository _repo =
      widget.repository ?? FamilyServices.repository;

  bool _loading = true;
  Object? _error;
  bool _stale = false;
  List<FamilyCircle> _circles = const [];
  List<InvitePreview> _invites = const [];
  List<FamilyMember> _members = const [];
  List<EmergencyContact> _contacts = const [];
  String? _selectedId;

  int _openAlerts = 0;
  bool _isHelper = false;

  /// Saved on the phone, for when the first load can't reach the server.
  FamilyCircle? _savedCircle;
  List<ScopeInfo> _savedLists = const [];
  List<EmergencyContact> _savedContacts = const [];

  FamilyCircle? get _circle =>
      _circles.where((c) => c.id == _selectedId).firstOrNull ??
      _circles.firstOrNull;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final hadData = _circles.isNotEmpty;
    setState(() {
      _loading = !hadData;
      _error = null;
    });
    try {
      final circles = await _repo.circles();
      final invites = await _repo.myInvitations();
      final selected =
          circles.where((c) => c.id == _selectedId).firstOrNull ??
          circles.firstOrNull;
      final members =
          selected == null
              ? const <FamilyMember>[]
              : await _repo.members(selected.id);
      final contacts = await _familyContacts(circles, selected);
      if (!mounted) return;
      setState(() {
        _circles = circles;
        _invites = invites;
        _members = members;
        _contacts = contacts;
        _selectedId = selected?.id;
        _loading = false;
        _stale = false;
      });
      unawaited(_loadSafety(selected));
    } catch (e) {
      if (!mounted) return;
      if (!hadData) await _loadSaved();
      if (!mounted) return;
      setState(() {
        _loading = false;
        // Keep what's on screen if a refresh fails: it may be needed most
        // where the network is worst.
        if (hadData) {
          _stale = true;
        } else {
          _error = e;
        }
      });
    }
  }

  /// Extras only, loaded after the family is on screen so that a slow
  /// connection can never hold the family screen back.
  Future<void> _loadSafety(FamilyCircle? circle) async {
    final safety = SafetyServices.repository;
    var helper = false;
    var open = 0;
    try {
      helper = (await safety.helperStatus()).isHelper;
    } catch (_) {
      helper = false;
    }
    try {
      final alerts = circle == null ? const [] : await safety.alerts(circle.id);
      open = alerts.where((a) => !a.isResolved).length;
    } catch (_) {
      open = 0;
    }
    if (!mounted) return;
    setState(() {
      _isHelper = helper;
      _openAlerts = open;
    });
  }

  /// Through the saved copy, so it's kept fresh for offline use. A fault in
  /// local storage must not stop the family loading, so it falls back.
  Future<List<EmergencyContact>> _familyContacts(
    List<FamilyCircle> circles,
    FamilyCircle? selected,
  ) async {
    try {
      final sync = FamilyContacts.service;
      await sync.rememberCircles(circles);
      if (selected == null) return const [];
      final scope = ContactScope(selected.id);
      await sync.remember(scope, canEdit: selected.isOrganizer);
      final view = await sync.refresh(scope);
      return [for (final r in view.contacts) r.contact];
    } catch (_) {
      if (selected == null) return const [];
      return _repo.contacts(selected.id);
    }
  }

  Future<void> _loadSaved() async {
    try {
      final sync = FamilyContacts.service;
      final circle = (await sync.savedCircles()).firstOrNull;
      if (circle == null) return;
      final view = await sync.local(ContactScope(circle.id));
      final lists = await sync.savedLists(circle.id);
      _savedCircle = circle;
      _savedLists = lists.where((l) => l.scope.memberId != null).toList();
      _savedContacts = [for (final r in view.contacts) r.contact];
    } catch (_) {
      // Nothing saved to show: the error view explains.
    }
  }

  Future<void> _open(String route, {Object? arguments}) async {
    await Navigator.pushNamed(context, route, arguments: arguments);
    if (mounted) await _load();
  }

  void _select(FamilyCircle circle) {
    setState(() => _selectedId = circle.id);
    _load();
  }

  Future<void> _addSomeone(FamilyCircle circle) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder:
          (ctx) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                editorialMargin,
                0,
                editorialMargin,
                AppSpacing.lg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('fam_add_who'.tr(), style: ctx.editorial.headline),
                  AppSpacing.gapMd,
                  ChoiceRow(
                    icon: Icons.child_care_rounded,
                    title: 'fam_add_dependent'.tr(),
                    subtitle: 'fam_add_dependent_hint'.tr(),
                    selected: false,
                    onTap: () => Navigator.pop(ctx, 'dependent'),
                  ),
                  ChoiceRow(
                    icon: Icons.person_add_alt_outlined,
                    title: 'fam_add_adult'.tr(),
                    subtitle: 'fam_add_adult_hint'.tr(),
                    selected: false,
                    onTap: () => Navigator.pop(ctx, 'adult'),
                  ),
                ],
              ),
            ),
          ),
    );
    if (choice == 'dependent') {
      await _open('/familyMemberForm', arguments: FamilyArgs(circle));
    } else if (choice == 'adult') {
      await _open('/familyInvite', arguments: FamilyArgs(circle));
    }
  }

  Future<void> _openQr(FamilyCircle circle) async {
    final mine = _members.where((m) => m.permissions.viewQr).toList();
    if (mine.isEmpty) return;
    var chosen = mine.first;
    if (mine.length > 1) {
      final picked = await showModalBottomSheet<FamilyMember>(
        context: context,
        showDragHandle: true,
        builder:
            (ctx) => SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  editorialMargin,
                  0,
                  editorialMargin,
                  AppSpacing.lg,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('qr_pick'.tr(), style: ctx.editorial.headline),
                    AppSpacing.gapMd,
                    for (final m in mine)
                      ChoiceRow(
                        icon: Icons.qr_code_2_rounded,
                        title: m.name,
                        subtitle: memberRelationLine(m),
                        selected: false,
                        onTap: () => Navigator.pop(ctx, m),
                      ),
                  ],
                ),
              ),
            ),
      );
      if (picked == null) return;
      chosen = picked;
    }
    await _open(
      '/safetyQr',
      arguments: FamilyArgs(
        circle,
        memberId: chosen.id,
        memberName: chosen.name,
      ),
    );
  }

  Future<void> _acceptOrganizer(FamilyCircle circle) async {
    try {
      await _repo.acceptOrganizer(circle.id);
      if (mounted) await _load();
    } catch (e) {
      if (mounted) showJourneySnack(context, familyErrorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final circle = _circle;
    Widget body;
    if (_loading) {
      body = const FamilySkeleton();
    } else if (_error != null && _savedCircle != null) {
      body = _SavedView(
        circle: _savedCircle!,
        lists: _savedLists,
        contacts: _savedContacts,
        onOpen: _open,
        onRetry: _load,
      );
    } else if (_error != null) {
      final offline =
          _error is FamilyException &&
          (_error! as FamilyException).kind == FamilyFailure.offline;
      body = SafeArea(
        child: Column(
          children: [
            if (Navigator.canPop(context))
              const Align(alignment: Alignment.centerLeft, child: BackButton()),
            Expanded(
              child: AppErrorView(
                title: 'fam_title'.tr(),
                icon: offline ? Icons.cloud_off_rounded : Icons.error_outline,
                message: [
                  familyErrorText(_error!),
                  if (offline) 'fam_offline_note'.tr(),
                ].join('\n\n'),
                onRetry: _load,
              ),
            ),
          ],
        ),
      );
    } else if (circle == null) {
      body = _Onboarding(
        invites: _invites,
        onCreate: () => _open('/familyCreate'),
        onJoin: () => _open('/familyJoin'),
        onReview: (invite) => _open('/familyJoin', arguments: invite),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: _CircleView(
          repo: _repo,
          circle: circle,
          circles: _circles,
          members: _members,
          contacts: _contacts,
          invites: _invites,
          stale: _stale,
          onSelect: _select,
          onOpen: _open,
          onAdd: () => _addSomeone(circle),
          onAcceptOrganizer: () => _acceptOrganizer(circle),
          onOpenQr: () => _openQr(circle),
          openAlerts: _openAlerts,
          isHelper: _isHelper,
        ),
      );
    }
    return MainLayout(ctx: 0, showDefaultBottom: true, body: body);
  }
}

class _Onboarding extends StatelessWidget {
  const _Onboarding({
    required this.invites,
    required this.onCreate,
    required this.onJoin,
    required this.onReview,
  });

  final List<InvitePreview> invites;
  final VoidCallback onCreate;
  final VoidCallback onJoin;
  final ValueChanged<InvitePreview> onReview;

  @override
  Widget build(BuildContext context) {
    final e = context.editorial;
    final colors = context.colorScheme;
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.huge),
      children: [
        _Hero(
          children: [
            Text(
              'fam_onboard_kicker'.tr(),
              style: e.kicker.copyWith(color: colors.onPrimary),
            ),
            AppSpacing.gapSm,
            Semantics(
              header: true,
              child: Text(
                'fam_onboard_title'.tr(),
                style: e.masthead.copyWith(color: colors.onPrimary),
              ),
            ),
            AppSpacing.gapSm,
            Text(
              'fam_onboard_body'.tr(),
              style: e.dek.copyWith(color: colors.onPrimary),
            ),
          ],
        ),
        for (final invite in invites)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              editorialMargin,
              AppSpacing.md,
              editorialMargin,
              0,
            ),
            child: _InviteBanner(invite: invite, onTap: () => onReview(invite)),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            editorialMargin,
            AppSpacing.lg,
            editorialMargin,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppButton(
                label: 'fam_create'.tr(),
                leadingIcon: Icons.add_rounded,
                onPressed: onCreate,
              ),
              AppSpacing.gapSm,
              AppButton.secondary(
                label: 'fam_join'.tr(),
                leadingIcon: Icons.vpn_key_outlined,
                onPressed: onJoin,
              ),
              AppSpacing.gapXl,
              Text('fam_how_title'.tr(), style: e.headline),
              AppSpacing.gapLg,
              for (final (i, key)
                  in const ['fam_how_1', 'fam_how_2', 'fam_how_3'].indexed)
                ThreadStep(
                  marker: '${i + 1}',
                  isLast: i == 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${key}_title'.tr(), style: e.title),
                      Text('${key}_body'.tr()),
                    ],
                  ),
                ),
              AppSpacing.gapXl,
              FamilyNote(
                title: 'fam_private_title'.tr(),
                text: 'fam_private_body'.tr(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InviteBanner extends StatelessWidget {
  const _InviteBanner({required this.invite, required this.onTap});

  final InvitePreview invite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.semanticColors;
    return Pressable(
      onTap: onTap,
      label: 'fam_invited_to'.tr(args: [invite.familyName]),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: s.warningContainer,
          borderRadius: AppRadius.lgAll,
        ),
        child: Row(
          children: [
            Icon(Icons.mail_outline_rounded, color: s.onWarningContainer),
            AppSpacing.gapMd,
            Expanded(
              child: Text(
                'fam_invited_to'.tr(args: [invite.familyName]),
                style: context.editorial.title.copyWith(
                  color: s.onWarningContainer,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_rounded,
              size: 18,
              color: s.onWarningContainer,
            ),
          ],
        ),
      ),
    );
  }
}

/// A solid header ending in the journal's stepped edge.
class _Hero extends StatelessWidget {
  const _Hero({required this.children, this.trailing});

  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    return ClipPath(
      clipper: const GhatEdgeClipper(stepHeight: 8),
      child: ColoredBox(
        color: colors.primary,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xs,
              AppSpacing.xs,
              AppSpacing.xs,
              AppSpacing.huge + AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (canPop)
                      BackButton(color: colors.onPrimary)
                    else
                      const SizedBox(height: AppSpacing.minTouchTarget),
                    const Spacer(),
                    if (trailing != null) trailing!,
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: editorialMargin - AppSpacing.xs,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: children,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CircleView extends StatelessWidget {
  const _CircleView({
    required this.repo,
    required this.circle,
    required this.circles,
    required this.members,
    required this.contacts,
    required this.invites,
    required this.stale,
    required this.onSelect,
    required this.onOpen,
    required this.onAdd,
    required this.onAcceptOrganizer,
    required this.onOpenQr,
    this.openAlerts = 0,
    this.isHelper = false,
  });

  final FamilyRepository repo;
  final FamilyCircle circle;
  final List<FamilyCircle> circles;
  final List<FamilyMember> members;
  final List<EmergencyContact> contacts;
  final List<InvitePreview> invites;
  final bool stale;
  final ValueChanged<FamilyCircle> onSelect;
  final Future<void> Function(String route, {Object? arguments}) onOpen;
  final VoidCallback onAdd;
  final VoidCallback onAcceptOrganizer;
  final VoidCallback onOpenQr;
  final int openAlerts;
  final bool isHelper;

  @override
  Widget build(BuildContext context) {
    final e = context.editorial;
    final colors = context.colorScheme;
    final cared = members.where((m) => m.isDependent).length;
    final organizer = members.where((m) => m.isOrganizer).firstOrNull;
    final first = contacts.firstOrNull;
    final args = FamilyArgs(circle);

    Widget gutter(Widget child, {double top = AppSpacing.xl}) => Padding(
      padding: EdgeInsets.fromLTRB(editorialMargin, top, editorialMargin, 0),
      child: child,
    );

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: AppSpacing.huge),
      children: [
        _Hero(
          trailing: IconButton(
            tooltip: 'fam_settings'.tr(),
            color: colors.onPrimary,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => onOpen('/familySettings', arguments: args),
          ),
          children: [
            Text(
              'fam_title'.tr(),
              style: e.kicker.copyWith(color: colors.onPrimary),
            ),
            AppSpacing.gapXs,
            Semantics(
              header: true,
              child: Text(
                circle.name,
                style: e.masthead.copyWith(color: colors.onPrimary),
              ),
            ),
            AppSpacing.gapSm,
            MetaLine([
              'fam_member_count'.plural(members.length),
              if (cared > 0) 'fam_in_care_count'.plural(cared),
            ], color: colors.onPrimary),
            if (organizer != null)
              MetaLine([
                'fam_organized_by'.tr(args: [organizer.name]),
              ], color: colors.onPrimary),
          ],
        ),
        if (openAlerts > 0)
          gutter(
            _AlertBanner(
              count: openAlerts,
              onTap: () => onOpen('/safetyAlerts', arguments: args),
            ),
            top: AppSpacing.md,
          ),
        if (stale)
          gutter(FamilyNote(text: 'fam_stale_note'.tr()), top: AppSpacing.md),
        if (circles.length > 1)
          gutter(
            PillChoices(
              values: [for (final c in circles) c.id],
              labelOf: (id) => circles.firstWhere((c) => c.id == id).name,
              selected: circle.id,
              onChanged:
                  (id) => onSelect(circles.firstWhere((c) => c.id == id)),
            ),
            top: AppSpacing.sm,
          ),
        if (circle.organizerOfferForMe)
          gutter(
            FamilyNote(
              title: 'fam_offer_title'.tr(),
              text: 'fam_offer_body'.tr(),
            ),
          ),
        if (circle.organizerOfferForMe)
          gutter(
            AppButton.secondary(
              label: 'fam_offer_accept'.tr(),
              onPressed: onAcceptOrganizer,
            ),
            top: AppSpacing.sm,
          ),
        for (final invite in invites)
          gutter(
            _InviteBanner(
              invite: invite,
              onTap: () => onOpen('/familyJoin', arguments: invite),
            ),
            top: AppSpacing.md,
          ),
        gutter(
          FamilyMap(
            familyId: circle.id,
            members: members,
            repository: repo,
            onOpen:
                (m) => onOpen(
                  '/familyMember',
                  arguments: FamilyArgs(circle, memberId: m.id),
                ),
          ),
          top: AppSpacing.md,
        ),
        gutter(const _Legend(), top: AppSpacing.sm),
        gutter(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (circle.isOrganizer) ...[
                _Action(
                  icon: Icons.person_add_alt_outlined,
                  label: 'fam_add_member'.tr(),
                  onTap: onAdd,
                ),
                _Action(
                  icon: Icons.mail_outline_rounded,
                  label: 'fam_invitations'.tr(),
                  onTap: () => onOpen('/familyInvite', arguments: args),
                ),
              ],
              _Action(
                icon: Icons.emergency_outlined,
                label: 'fam_emergency_contacts'.tr(),
                onTap: () => onOpen('/familyContacts', arguments: args),
              ),
              _Action(
                icon: Icons.qr_code_2_rounded,
                label: 'qr_title'.tr(),
                onTap: onOpenQr,
              ),
            ],
          ),
        ),
        gutter(
          AppButton.secondary(
            label: 'loc_map_title'.tr(),
            leadingIcon: Icons.share_location_rounded,
            onPressed: () => onOpen('/familyMap', arguments: args),
          ),
          top: AppSpacing.md,
        ),
        gutter(
          AppButton.secondary(
            label: 'sos_title'.tr(),
            leadingIcon: Icons.sos_rounded,
            onPressed: () => onOpen('/sos'),
          ),
          top: AppSpacing.sm,
        ),
        gutter(
          AppButton.secondary(
            label: 're_map_title'.tr(),
            leadingIcon: Icons.diversity_3_rounded,
            onPressed: () => onOpen('/reunionMap', arguments: args),
          ),
          top: AppSpacing.sm,
        ),
        if (isHelper)
          gutter(
            AppButton.secondary(
              label: 'scan_title'.tr(),
              leadingIcon: Icons.qr_code_scanner_rounded,
              onPressed: () => onOpen('/safetyScan'),
            ),
            top: AppSpacing.md,
          ),
        gutter(
          TextButton.icon(
            onPressed: () => onOpen('/safetyAlerts', arguments: args),
            icon: const Icon(Icons.notifications_none_rounded, size: 18),
            label: Text('alert_title'.tr()),
          ),
          top: AppSpacing.xs,
        ),
        gutter(
          _FirstCall(
            contact: first,
            onCall:
                first == null
                    ? null
                    : () => openExternal(context, 'tel:${first.mobile}'),
            onOpen: () => onOpen('/familyContacts', arguments: args),
          ),
        ),
        gutter(const GhatRule(padding: EdgeInsets.zero)),
        gutter(const _Guidance(), top: AppSpacing.md),
      ],
    );
  }
}

/// What's left with no connection and nothing loaded: the circle's name, who
/// to call first, and every list saved on this phone.
class _SavedView extends StatelessWidget {
  const _SavedView({
    required this.circle,
    required this.lists,
    required this.contacts,
    required this.onOpen,
    required this.onRetry,
  });

  final FamilyCircle circle;
  final List<ScopeInfo> lists;
  final List<EmergencyContact> contacts;
  final Future<void> Function(String route, {Object? arguments}) onOpen;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final e = context.editorial;
    final colors = context.colorScheme;
    final first = contacts.firstOrNull;
    final args = FamilyArgs(circle);
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.huge),
      children: [
        _Hero(
          children: [
            Text(
              'fam_title'.tr(),
              style: e.kicker.copyWith(color: colors.onPrimary),
            ),
            AppSpacing.gapXs,
            Semantics(
              header: true,
              child: Text(
                circle.name,
                style: e.masthead.copyWith(color: colors.onPrimary),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            editorialMargin,
            AppSpacing.md,
            editorialMargin,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FamilyNote(
                title: 'fam_offline_title'.tr(),
                text: 'fam_offline_saved_body'.tr(),
              ),
              AppSpacing.gapLg,
              _FirstCall(
                contact: first,
                onCall:
                    first == null
                        ? null
                        : () => openExternal(context, 'tel:${first.mobile}'),
                onOpen: () => onOpen('/familyContacts', arguments: args),
              ),
              AppSpacing.gapMd,
              AppButton(
                label: 'fam_emergency_contacts'.tr(),
                leadingIcon: Icons.emergency_outlined,
                onPressed: () => onOpen('/familyContacts', arguments: args),
              ),
              for (final list in lists) ...[
                AppSpacing.gapSm,
                AppButton.secondary(
                  label: 'fam_contacts_of'.tr(args: [list.label ?? '']),
                  onPressed:
                      () => onOpen(
                        '/familyContacts',
                        arguments: FamilyArgs(
                          circle,
                          memberId: list.scope.memberId,
                          memberName: list.label,
                        ),
                      ),
                ),
              ],
              AppSpacing.gapSm,
              TextButton(onPressed: onRetry, child: Text('common_retry'.tr())),
            ],
          ),
        ),
      ],
    );
  }
}

class _AlertBanner extends StatelessWidget {
  const _AlertBanner({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final text = 'alert_open_count'.plural(count);
    return Pressable(
      onTap: onTap,
      label: text,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: colors.errorContainer,
          borderRadius: AppRadius.lgAll,
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: colors.onErrorContainer),
            AppSpacing.gapMd,
            Expanded(
              child: Text(
                text,
                style: context.editorial.title.copyWith(
                  color: colors.onErrorContainer,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_rounded,
              size: 18,
              color: colors.onErrorContainer,
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final e = context.editorial;
    final colors = context.colorScheme;
    final s = context.semanticColors;
    Widget item(Color color, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
        ),
        AppSpacing.gapXs,
        Flexible(child: Text(text, style: e.meta)),
      ],
    );
    return Wrap(
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.xs,
      children: [
        item(colors.primary, 'fam_legend_adults'.tr()),
        item(s.gold, 'fam_legend_dependents'.tr()),
      ],
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Pressable(
      onTap: onTap,
      label: label,
      child: ExcludeSemantics(
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: context.colorScheme.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: context.colorScheme.primary),
            ),
            AppSpacing.gapXs,
            Text(
              label,
              textAlign: TextAlign.center,
              style: context.editorial.meta,
            ),
          ],
        ),
      ),
    ),
  );
}

/// The one thing someone needs in a hurry: who to ring first.
class _FirstCall extends StatelessWidget {
  const _FirstCall({
    required this.contact,
    required this.onCall,
    required this.onOpen,
  });

  final EmergencyContact? contact;
  final VoidCallback? onCall;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final e = context.editorial;
    final c = contact;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHigh,
        borderRadius: AppRadius.lgAll,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('fam_first_call'.tr(), style: e.meta),
                Text(c?.name ?? 'fam_no_contacts_short'.tr(), style: e.title),
                if (c != null && c.relationship.isNotEmpty)
                  Text(c.relationship, style: e.meta),
              ],
            ),
          ),
          if (c == null)
            TextButton(onPressed: onOpen, child: Text('fam_add'.tr()))
          else
            IconButton.filled(
              tooltip: 'fam_call_name'.tr(args: [c.name]),
              onPressed: onCall,
              icon: const Icon(Icons.call_rounded),
            ),
        ],
      ),
    );
  }
}

class _Guidance extends StatelessWidget {
  const _Guidance();

  @override
  Widget build(BuildContext context) {
    final e = context.editorial;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('fam_guidance_title'.tr(), style: e.headline),
        AppSpacing.gapSm,
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: Column(
            children: [
              for (final n in const [1, 2, 3, 4])
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: AppSpacing.md),
                  expandedAlignment: Alignment.centerLeft,
                  title: Text('fam_tip_${n}_title'.tr(), style: e.title),
                  children: [Text('fam_tip_${n}_body'.tr())],
                ),
            ],
          ),
        ),
        AppSpacing.gapSm,
        FamilyNote(text: 'fam_scope_note'.tr()),
      ],
    );
  }
}
