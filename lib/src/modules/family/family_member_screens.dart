import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' as intl;
import 'package:image_picker/image_picker.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/modules/family/data/family_repository.dart';
import 'package:kumbha_path/src/modules/family/family_home_screen.dart';
import 'package:kumbha_path/src/modules/family/models/family_models.dart';
import 'package:kumbha_path/src/modules/family/offline/contact_sync.dart';
import 'package:kumbha_path/src/modules/family/widgets/family_parts.dart';
import 'package:kumbha_path/src/modules/journey/widgets/journey_ui.dart'
    show confirmJourneyAction, formatDate, openExternal, showJourneySnack;

/// `/familyMember`: one person, showing only what the requester may see, with
/// only the actions the backend says they may take.
class MemberProfileScreen extends StatefulWidget {
  const MemberProfileScreen({super.key, required this.args, this.repository});

  final FamilyArgs args;
  final FamilyRepository? repository;

  @override
  State<MemberProfileScreen> createState() => _MemberProfileScreenState();
}

class _MemberProfileScreenState extends State<MemberProfileScreen> {
  late final FamilyRepository _repo =
      widget.repository ?? FamilyServices.repository;
  FamilyMember? _member;
  Object? _error;

  String get _familyId => widget.args.circle.id;
  String get _memberId => widget.args.memberId!;
  bool get _isMe => widget.args.circle.myMemberId == _memberId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final member = await _repo.member(_familyId, _memberId);
      if (mounted) setState(() => _member = member);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      if (mounted) await _load();
    } catch (e) {
      if (mounted) showJourneySnack(context, familyErrorText(e));
    }
  }

  Future<void> _setPrivacy(String field, bool value) =>
      _run(() => _repo.updateMember(_familyId, _memberId, {field: value}));

  Future<void> _remove(FamilyMember m) async {
    final sure = await confirmJourneyAction(
      context,
      title: 'fam_remove_title'.tr(args: [m.name]),
      message: 'fam_remove_body'.tr(),
      confirm: 'fam_remove'.tr(),
      destructive: true,
    );
    if (!sure) return;
    try {
      await _repo.removeMember(_familyId, m.id);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showJourneySnack(context, familyErrorText(e));
    }
  }

  Future<void> _addGuardian(FamilyMember m) async {
    final List<FamilyMember> everyone;
    try {
      everyone = await _repo.members(_familyId);
    } catch (e) {
      if (mounted) showJourneySnack(context, familyErrorText(e));
      return;
    }
    if (!mounted) return;
    final taken = m.guardians.map((g) => g.id).toSet();
    final options =
        everyone.where((a) => !a.isDependent && !taken.contains(a.id)).toList();
    if (options.isEmpty) {
      showJourneySnack(context, 'fam_no_more_guardians'.tr());
      return;
    }
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder:
          (ctx) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final a in options)
                  ListTile(
                    title: Text(a.name),
                    onTap: () => Navigator.pop(ctx, a.id),
                  ),
              ],
            ),
          ),
    );
    if (picked != null) {
      await _run(() => _repo.addGuardian(_familyId, m.id, picked));
    }
  }

  Future<void> _changePhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 80,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    await _run(() async {
      await _repo.uploadPhoto(_familyId, _memberId, bytes);
      FamilyPhotos.forget(_memberId);
    });
  }

  Future<void> _removePhoto() => _run(() async {
    await _repo.removePhoto(_familyId, _memberId);
    FamilyPhotos.forget(_memberId);
  });

  Future<void> _edit(FamilyMember m) async {
    await Navigator.pushNamed(
      context,
      '/familyMemberForm',
      arguments: FamilyArgs(widget.args.circle, member: m),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final m = _member;
    if (m == null) {
      return Scaffold(
        appBar: AppBar(),
        body:
            _error == null
                ? const FamilySkeleton()
                : AppErrorView(
                  message: familyErrorText(_error!),
                  onRetry: _load,
                ),
      );
    }
    final e = context.editorial;
    final p = m.permissions;
    final phone = m.phone;
    return Scaffold(
      appBar: AppBar(
        actions: [
          if (m.isDependent && p.editProfile)
            IconButton(
              tooltip: 'fam_edit_member'.tr(),
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _edit(m),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            editorialMargin,
            0,
            editorialMargin,
            AppSpacing.huge,
          ),
          children: [
            Center(
              child: FamilyAvatar(
                member: m,
                familyId: _familyId,
                repository: _repo,
                size: 112,
              ),
            ),
            if (p.editProfile)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: _changePhoto,
                    child: Text('fam_change_photo'.tr()),
                  ),
                  if (m.hasPhoto)
                    TextButton(
                      onPressed: _removePhoto,
                      child: Text('fam_remove_photo'.tr()),
                    ),
                ],
              ),
            AppSpacing.gapMd,
            Semantics(
              header: true,
              child: Text(
                m.name,
                textAlign: TextAlign.center,
                style: e.headline,
              ),
            ),
            AppSpacing.gapXs,
            Center(
              child: MetaLine([
                memberRelationLine(m),
                if (m.relationship != 'self') memberKindLabel(m),
              ]),
            ),
            AppSpacing.gapLg,
            if (m.isDependent)
              FamilyNote(text: 'fam_dependent_note'.tr())
            else if (_isMe)
              FamilyNote(text: 'fam_self_note'.tr())
            else
              FamilyNote(text: 'fam_adult_note'.tr(args: [m.name])),
            AppSpacing.gapMd,
            FactRow(
              label: 'fam_field_language'.tr(),
              value: 'fam_lang_${m.language}'.tr(),
            ),
            if (m.ageGroup.isNotEmpty)
              FactRow(
                label: 'fam_field_age_group'.tr(),
                value: 'fam_age_${m.ageGroup}'.tr(),
              ),
            if (m.dateOfBirth != null)
              FactRow(
                label: 'fam_field_birth'.tr(),
                value: formatDate(context, m.dateOfBirth!),
              ),
            if (phone != null)
              FactRow(
                label: 'fam_field_mobile'.tr(),
                value: '+91 ${localMobile(phone)}',
                trailing: IconButton(
                  tooltip: 'fam_call_name'.tr(args: [m.name]),
                  icon: const Icon(Icons.call_outlined),
                  onPressed: () => openExternal(context, 'tel:$phone'),
                ),
              ),
            FactRow(
              label: 'fam_field_status'.tr(),
              value: 'fam_status_active'.tr(),
            ),
            if (m.isDependent) ...[
              AppSpacing.gapXl,
              Text('fam_guardians'.tr(), style: e.headline),
              for (final g in m.guardians)
                FactRow(
                  label: 'fam_guardian'.tr(),
                  value: g.name,
                  trailing:
                      p.manageGuardians && m.guardians.length > 1
                          ? IconButton(
                            tooltip: 'fam_remove_guardian'.tr(args: [g.name]),
                            icon: const Icon(Icons.close_rounded),
                            onPressed:
                                () => _run(
                                  () => _repo.removeGuardian(
                                    _familyId,
                                    m.id,
                                    g.id,
                                  ),
                                ),
                          )
                          : null,
                ),
              if (p.manageGuardians)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _addGuardian(m),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text('fam_add_guardian'.tr()),
                  ),
                ),
            ],
            if (p.viewQr) ...[
              AppSpacing.gapLg,
              AppButton.secondary(
                label: 'qr_title'.tr(),
                leadingIcon: Icons.qr_code_2_rounded,
                onPressed:
                    () => Navigator.pushNamed(
                      context,
                      '/safetyQr',
                      arguments: FamilyArgs(
                        widget.args.circle,
                        memberId: m.id,
                        memberName: m.name,
                      ),
                    ),
              ),
            ],
            if (p.viewContacts) ...[
              AppSpacing.gapLg,
              AppButton.secondary(
                label: 'fam_their_contacts'.tr(),
                leadingIcon: Icons.emergency_outlined,
                onPressed:
                    () => Navigator.pushNamed(
                      context,
                      '/familyContacts',
                      arguments: FamilyArgs(
                        widget.args.circle,
                        memberId: m.id,
                        memberName: m.name,
                        member: m,
                      ),
                    ),
              ),
            ],
            if (_isMe && m.privacy != null) ...[
              AppSpacing.gapXl,
              Text('fam_privacy_title'.tr(), style: e.headline),
              AppSpacing.gapXs,
              Text('fam_privacy_body'.tr()),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('fam_share_phone'.tr()),
                subtitle: Text('fam_share_phone_hint'.tr()),
                value: m.privacy!.sharePhone,
                onChanged: (v) => _setPrivacy('share_phone', v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('fam_share_contacts'.tr()),
                subtitle: Text('fam_share_contacts_hint'.tr()),
                value: m.privacy!.shareContactsWithOrganizer,
                onChanged:
                    (v) => _setPrivacy('share_contacts_with_organizer', v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('qr_share_location'.tr()),
                subtitle: Text('qr_share_location_hint'.tr()),
                value: m.privacy!.shareLocationInAlerts,
                onChanged: (v) => _setPrivacy('location_sharing_consent', v),
              ),
            ],
            if (p.remove) ...[
              AppSpacing.gapXl,
              TextButton(
                onPressed: () => _remove(m),
                child: Text(
                  'fam_remove'.tr(),
                  style: TextStyle(color: context.colorScheme.error),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// `/familyContacts`: who to try, in order, on a numbered thread. Reads from
/// the phone first and works with no connection.
class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key, required this.args});

  final FamilyArgs args;

  @override
  State<EmergencyContactsScreen> createState() =>
      _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  final ContactSyncService _sync = FamilyContacts.service;
  ContactListView? _view;
  Object? _error;

  /// Changes have been waiting, so their arrival is worth announcing.
  bool _waiting = false;

  ContactScope get _scope =>
      ContactScope(widget.args.circle.id, widget.args.memberId);

  /// From the backend when known, or as remembered when opened offline.
  bool get _canEdit =>
      widget.args.member?.permissions.editContacts ??
      (widget.args.memberId == null
          ? widget.args.circle.isOrganizer
          : _view?.info?.canEdit ?? false);

  @override
  void initState() {
    super.initState();
    _sync.addListener(_onSync);
    _start();
  }

  @override
  void dispose() {
    _sync.removeListener(_onSync);
    super.dispose();
  }

  Future<void> _start() async {
    await _loadLocal();
    final member = widget.args.member;
    if (member != null || widget.args.memberId == null) {
      await _sync.remember(
        _scope,
        label: widget.args.memberName,
        canEdit: _canEdit,
      );
    }
    await _refresh();
  }

  Future<void> _loadLocal() async {
    try {
      final view = await _sync.local(_scope);
      if (mounted) {
        setState(() {
          _view = view;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _refresh() async {
    try {
      final view = await _sync.refresh(_scope);
      if (mounted) setState(() => _view = view);
    } catch (e) {
      if (mounted && _view == null) setState(() => _error = e);
    }
  }

  /// Reloads as sync moves on, and says when waiting changes have landed.
  void _onSync() {
    if (!mounted) return;
    final phase = _sync.phase;
    if (_sync.unsynced > 0 &&
        (phase == SyncPhase.offline || phase == SyncPhase.retrying)) {
      _waiting = true;
    }
    final landed = _waiting && phase == SyncPhase.idle && _sync.unsynced == 0;
    if (landed) _waiting = false;
    setState(() {});
    _loadLocal();
    if (landed) showJourneySnack(context, 'fam_synced_toast'.tr());
  }

  bool get _isOffline => _sync.phase == SyncPhase.offline;

  /// Says where a change actually went, once sync has had its turn.
  Future<void> _afterSave() async {
    // On a poor connection, don't keep the person waiting to hear it's safe.
    await _sync.sync().timeout(const Duration(seconds: 3), onTimeout: () {});
    await _loadLocal();
    if (!mounted) return;
    showJourneySnack(
      context,
      _sync.phase == SyncPhase.idle && _sync.unsynced == 0
          ? 'fam_saved_synced'.tr()
          : 'fam_saved_offline'.tr(),
    );
  }

  Future<void> _edit([LocalContact? row]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ContactSheet(sync: _sync, scope: _scope, row: row),
    );
    if (saved == true && mounted) await _afterSave();
  }

  Future<void> _delete(LocalContact row) async {
    final sure = await confirmJourneyAction(
      context,
      title: 'fam_contact_delete_title'.tr(args: [row.contact.name]),
      message: 'fam_contact_delete_body'.tr(),
      confirm: 'fam_delete'.tr(),
      destructive: true,
    );
    if (!sure) return;
    await _guard(() => _sync.delete(row));
    if (mounted) await _afterSave();
  }

  Future<void> _move(int from, int to) async {
    final list = [..._view!.contacts];
    final item = list.removeAt(from);
    list.insert(to, item);
    await _guard(() => _sync.reorder(_scope, [for (final r in list) r.id]));
    await _loadLocal();
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
      await _loadLocal();
    } catch (e) {
      if (mounted) showJourneySnack(context, familyErrorText(e));
    }
  }

  void _contactOut(EmergencyContact c) {
    final digits = c.mobile.replaceAll('+', '');
    openExternal(context, switch (c.method) {
      'whatsapp' => 'https://wa.me/$digits',
      'sms' => 'sms:${c.mobile}',
      _ => 'tel:${c.mobile}',
    });
  }

  @override
  Widget build(BuildContext context) {
    final e = context.editorial;
    final view = _view;
    final rows = view?.contacts;
    final name = widget.args.memberName;
    final title =
        name == null
            ? 'fam_emergency_contacts'.tr()
            : 'fam_contacts_of'.tr(args: [name]);
    final status = _SyncBar(
      phase: _sync.phase,
      unsynced: _sync.unsynced,
      lastSynced: view?.info?.lastSyncedAt,
      onRetry: _sync.sync,
    );

    Widget body;
    if (rows == null) {
      body =
          _error == null
              ? const FamilySkeleton()
              : AppErrorView(
                message: familyErrorText(_error!),
                onRetry: _start,
              );
    } else if (rows.isEmpty) {
      final neverSaved = view?.info?.lastSyncedAt == null && _isOffline;
      body = Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              editorialMargin,
              AppSpacing.sm,
              editorialMargin,
              0,
            ),
            child: status,
          ),
          Expanded(
            child: AppEmptyState(
              icon:
                  neverSaved
                      ? Icons.cloud_off_rounded
                      : Icons.emergency_outlined,
              title:
                  neverSaved
                      ? 'fam_no_saved_contacts_title'.tr()
                      : 'fam_no_contacts_title'.tr(),
              message:
                  neverSaved
                      ? 'fam_no_saved_contacts_body'.tr()
                      : 'fam_no_contacts_body'.tr(),
              actionLabel: _canEdit ? 'fam_contact_add'.tr() : null,
              onAction: _canEdit ? _edit : null,
            ),
          ),
        ],
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            editorialMargin,
            AppSpacing.sm,
            editorialMargin,
            editorialMargin,
          ),
          children: [
            status,
            AppSpacing.gapLg,
            Text('fam_contacts_order'.tr(), style: e.dek),
            AppSpacing.gapXl,
            for (final (i, row) in rows.indexed)
              ThreadStep(
                marker: '${i + 1}',
                isLast: i == rows.length - 1,
                child: _ContactRow(
                  row: row,
                  canEdit: _canEdit,
                  onContact: () => _contactOut(row.contact),
                  onEdit: () => _edit(row),
                  onDelete: () => _delete(row),
                  onUp: i == 0 ? null : () => _move(i, i - 1),
                  onDown: i == rows.length - 1 ? null : () => _move(i, i + 1),
                  onKeepMine: () => _guard(() => _sync.keepMine(row)),
                  onUseTheirs: () => _guard(() => _sync.useTheirs(row)),
                  onDiscard: () => _guard(() => _sync.discard(row)),
                ),
              ),
            if (_canEdit) ...[
              AppSpacing.gapXl,
              AppButton.secondary(
                label: 'fam_contact_add'.tr(),
                leadingIcon: Icons.add_rounded,
                onPressed: _edit,
              ),
            ],
            AppSpacing.gapLg,
            FamilyNote(text: 'fam_contacts_private'.tr()),
          ],
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(child: body),
    );
  }
}

/// One line saying whether this list can be trusted right now.
class _SyncBar extends StatelessWidget {
  const _SyncBar({
    required this.phase,
    required this.unsynced,
    required this.lastSynced,
    required this.onRetry,
  });

  final SyncPhase phase;
  final int unsynced;
  final DateTime? lastSynced;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final s = context.semanticColors;
    final e = context.editorial;
    final (IconData icon, Color color, String headline) = switch (phase) {
      SyncPhase.offline => (
        Icons.cloud_off_rounded,
        s.gold,
        'fam_sync_offline'.tr(),
      ),
      SyncPhase.syncing => (
        Icons.sync_rounded,
        colors.primary,
        'fam_sync_syncing'.tr(),
      ),
      SyncPhase.retrying => (
        Icons.sync_problem_rounded,
        colors.error,
        'fam_sync_retrying'.tr(),
      ),
      SyncPhase.signedOut => (
        Icons.lock_outline_rounded,
        colors.error,
        'fam_sync_signed_out'.tr(),
      ),
      SyncPhase.idle =>
        unsynced > 0
            ? (
              Icons.cloud_upload_outlined,
              s.gold,
              'fam_sync_waiting'.plural(unsynced),
            )
            : (Icons.cloud_done_outlined, s.success, 'fam_sync_done'.tr()),
    };
    final detail = [
      if (unsynced > 0 && phase != SyncPhase.idle)
        'fam_sync_waiting'.plural(unsynced),
      lastSynced == null
          ? 'fam_sync_never'.tr()
          : 'fam_sync_last'.tr(args: [_when(context, lastSynced!)]),
    ].join('  ·  ');
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.only(left: AppSpacing.md),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: color, width: 2)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: color),
            AppSpacing.gapSm,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(headline, style: context.textTheme.labelLarge),
                  Text(detail, style: e.meta),
                  // Below the text, so it never squeezes it at large sizes.
                  if (phase != SyncPhase.syncing &&
                      (phase != SyncPhase.idle || unsynced > 0))
                    TextButton(
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                      onPressed: onRetry,
                      child: Text('fam_sync_now'.tr()),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _when(BuildContext context, DateTime at) {
    final now = DateTime.now();
    final today =
        at.year == now.year && at.month == now.month && at.day == now.day;
    final clock = TimeOfDay.fromDateTime(at).format(context);
    if (today) return clock;
    final locale = Localizations.localeOf(context).toLanguageTag();
    try {
      return '${intl.DateFormat('d MMM', locale).format(at)}, $clock';
    } catch (_) {
      return '${intl.DateFormat('d MMM', 'en').format(at)}, $clock';
    }
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.row,
    required this.canEdit,
    required this.onContact,
    required this.onEdit,
    required this.onDelete,
    required this.onUp,
    required this.onDown,
    required this.onKeepMine,
    required this.onUseTheirs,
    required this.onDiscard,
  });

  final LocalContact row;
  final bool canEdit;
  final VoidCallback onContact;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onUp;
  final VoidCallback? onDown;
  final VoidCallback onKeepMine;
  final VoidCallback onUseTheirs;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final e = context.editorial;
    final c = row.contact;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.name, style: e.title),
                  MetaLine([
                    c.relationship,
                    localMobile(c.mobile),
                    'fam_method_${c.method}'.tr(),
                  ]),
                  if (row.isQueued)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xxs),
                      child: Row(
                        children: [
                          Icon(
                            Icons.cloud_upload_outlined,
                            size: 14,
                            color: context.semanticColors.gold,
                          ),
                          AppSpacing.gapXs,
                          Flexible(
                            child: Text('fam_row_waiting'.tr(), style: e.meta),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            IconButton.filledTonal(
              tooltip: 'fam_call_name'.tr(args: [c.name]),
              onPressed: onContact,
              icon: Icon(
                c.method == 'whatsapp'
                    ? Icons.chat_outlined
                    : Icons.call_rounded,
              ),
            ),
          ],
        ),
        if (row.state == ContactSyncState.conflict) _conflict(context),
        if (row.state == ContactSyncState.failed) _failed(context),
        if (canEdit && row.state != ContactSyncState.conflict)
          Row(
            children: [
              IconButton(
                tooltip: 'fam_move_up'.tr(args: [c.name]),
                icon: const Icon(Icons.arrow_upward_rounded, size: 20),
                onPressed: onUp,
              ),
              IconButton(
                tooltip: 'fam_move_down'.tr(args: [c.name]),
                icon: const Icon(Icons.arrow_downward_rounded, size: 20),
                onPressed: onDown,
              ),
              const Spacer(),
              IconButton(
                tooltip: 'fam_contact_edit'.tr(args: [c.name]),
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: onEdit,
              ),
              IconButton(
                tooltip: 'fam_delete'.tr(),
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                onPressed: onDelete,
              ),
            ],
          ),
      ],
    );
  }

  Widget _conflict(BuildContext context) {
    final e = context.editorial;
    final theirs = row.serverCopy;
    final message =
        row.goneFromServer
            ? 'fam_row_conflict_gone'.tr()
            : row.wantsDelete
            ? 'fam_row_conflict_delete'.tr()
            : 'fam_row_conflict'.tr();
    final keepLabel =
        row.wantsDelete ? 'fam_delete_anyway'.tr() : 'fam_keep_mine'.tr();
    final theirsLabel =
        row.goneFromServer && !row.wantsDelete
            ? 'fam_accept_deletion'.tr()
            : 'fam_use_theirs'.tr();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: FamilyNote(
        text: message,
        trailing: [
          if (theirs != null)
            Text(
              '${theirs.name}  ·  ${localMobile(theirs.mobile)}',
              style: e.title,
            ),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              TextButton(onPressed: onKeepMine, child: Text(keepLabel)),
              TextButton(onPressed: onUseTheirs, child: Text(theirsLabel)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _failed(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.sm),
    child: FamilyNote(
      text:
          row.wantsDelete
              ? 'fam_row_failed_delete'.tr()
              : 'fam_row_failed'.tr(),
      trailing: [
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            if (!row.wantsDelete)
              TextButton(onPressed: onEdit, child: Text('fam_fix'.tr())),
            TextButton(onPressed: onDiscard, child: Text('fam_discard'.tr())),
          ],
        ),
      ],
    ),
  );
}

class _ContactSheet extends StatefulWidget {
  const _ContactSheet({required this.sync, required this.scope, this.row});

  final ContactSyncService sync;
  final ContactScope scope;
  final LocalContact? row;

  @override
  State<_ContactSheet> createState() => _ContactSheetState();
}

class _ContactSheetState extends State<_ContactSheet> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.row?.contact.name);
  late final _relation = TextEditingController(
    text: widget.row?.contact.relationship,
  );
  late final _mobile = TextEditingController(
    text: localMobile(widget.row?.contact.mobile ?? ''),
  );
  late String _method = widget.row?.contact.method ?? 'call';
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _relation.dispose();
    _mobile.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    final data = {
      'name': _name.text.trim(),
      'relationship': _relation.text.trim(),
      'mobile': _mobile.text.trim(),
      'method': _method,
    };
    try {
      final existing = widget.row;
      if (existing == null) {
        await widget.sync.add(widget.scope, data);
      } else {
        await widget.sync.edit(existing, data);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showJourneySnack(context, familyErrorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: editorialMargin,
        right: editorialMargin,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.row == null
                    ? 'fam_contact_add'.tr()
                    : 'fam_contact_edit'.tr(args: [widget.row!.contact.name]),
                style: context.editorial.headline,
              ),
              AppSpacing.gapMd,
              AppTextField(
                controller: _name,
                label: 'fam_field_contact_name'.tr(),
                textCapitalization: TextCapitalization.words,
                maxLength: 120,
                validator:
                    (v) =>
                        (v ?? '').trim().isEmpty
                            ? 'fam_name_required'.tr()
                            : null,
              ),
              AppSpacing.gapMd,
              AppTextField(
                controller: _relation,
                label: 'fam_field_contact_relation'.tr(),
                maxLength: 60,
              ),
              AppSpacing.gapMd,
              AppTextField(
                controller: _mobile,
                label: 'fam_field_mobile'.tr(),
                prefixText: '+91 ',
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                validator:
                    (v) =>
                        isValidMobile(v ?? '')
                            ? null
                            : 'auth_phone_invalid'.tr(),
              ),
              FieldLabel('fam_field_method'.tr()),
              PillChoices(
                values: contactMethods,
                labelOf: (m) => 'fam_method_$m'.tr(),
                selected: _method,
                onChanged: (m) => setState(() => _method = m),
              ),
              AppSpacing.gapLg,
              AppButton(
                label: 'fam_save'.tr(),
                isLoading: _busy,
                onPressed: _busy ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `/familySettings`: family details, handing over, leaving and deleting.
class FamilySettingsScreen extends StatefulWidget {
  const FamilySettingsScreen({super.key, required this.args, this.repository});

  final FamilyArgs args;
  final FamilyRepository? repository;

  @override
  State<FamilySettingsScreen> createState() => _FamilySettingsScreenState();
}

class _FamilySettingsScreenState extends State<FamilySettingsScreen> {
  late final FamilyRepository _repo =
      widget.repository ?? FamilyServices.repository;
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: _circle.name);
  late final _description = TextEditingController(text: _circle.description);
  late String _language = _circle.language;
  List<FamilyMember> _adults = const [];
  bool _busy = false;

  FamilyCircle get _circle => widget.args.circle;

  @override
  void initState() {
    super.initState();
    _loadAdults();
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _loadAdults() async {
    if (!_circle.isOrganizer) return;
    try {
      final members = await _repo.members(_circle.id);
      if (mounted) {
        setState(() {
          _adults =
              members.where((m) => !m.isDependent && !m.isOrganizer).toList();
        });
      }
    } catch (_) {
      // Handing over just isn't offered until the list can load.
    }
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      await _repo.updateCircle(_circle.id, {
        'name': _name.text.trim(),
        'description': _description.text.trim(),
        'language': _language,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showJourneySnack(context, familyErrorText(e));
    }
  }

  Future<void> _handOver(FamilyMember adult) async {
    final sure = await confirmJourneyAction(
      context,
      title: 'fam_handover_title'.tr(args: [adult.name]),
      message: 'fam_handover_body'.tr(),
      confirm: 'fam_handover_confirm'.tr(),
    );
    if (!sure) return;
    try {
      await _repo.offerOrganizer(_circle.id, adult.id);
      if (mounted) {
        showJourneySnack(context, 'fam_handover_sent'.tr(args: [adult.name]));
      }
    } catch (e) {
      if (mounted) showJourneySnack(context, familyErrorText(e));
    }
  }

  /// Leaving or deleting ends this circle for the user: back to the home.
  Future<void> _exit({
    required String title,
    required String message,
    required String confirm,
    required Future<void> Function() action,
  }) async {
    final sure = await confirmJourneyAction(
      context,
      title: title,
      message: message,
      confirm: confirm,
      destructive: true,
    );
    if (!sure) return;
    try {
      await action();
      FamilyPhotos.clear();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showJourneySnack(context, familyErrorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = context.editorial;
    final error = context.colorScheme.error;
    final organizer = _circle.isOrganizer;
    return Scaffold(
      appBar: AppBar(title: Text('fam_settings'.tr())),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(editorialMargin),
          children: [
            if (organizer) ...[
              Form(
                key: _form,
                child: Column(
                  children: [
                    AppTextField(
                      controller: _name,
                      label: 'fam_field_family_name'.tr(),
                      maxLength: 80,
                      validator:
                          (v) =>
                              (v ?? '').trim().isEmpty
                                  ? 'fam_name_required'.tr()
                                  : null,
                    ),
                    AppSpacing.gapMd,
                    AppTextField(
                      controller: _description,
                      label: 'fam_field_description'.tr(),
                      maxLength: 300,
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              FieldLabel('fam_field_language'.tr()),
              PillChoices(
                values: const ['en', 'hi', 'mr'],
                labelOf: (l) => 'fam_lang_$l'.tr(),
                selected: _language,
                onChanged: (l) => setState(() => _language = l),
              ),
              AppSpacing.gapLg,
              AppButton(
                label: 'fam_save'.tr(),
                isLoading: _busy,
                onPressed: _busy ? null : _save,
              ),
              if (_adults.isNotEmpty) ...[
                AppSpacing.gapXl,
                Text('fam_handover'.tr(), style: e.headline),
                AppSpacing.gapXs,
                Text('fam_handover_hint'.tr()),
                for (final adult in _adults)
                  FactRow(
                    label: memberRelationLine(adult),
                    value: adult.name,
                    trailing: TextButton(
                      onPressed: () => _handOver(adult),
                      child: Text('fam_handover_confirm'.tr()),
                    ),
                  ),
              ],
              AppSpacing.gapXl,
              TextButton(
                onPressed:
                    () => _exit(
                      title: 'fam_delete_title'.tr(args: [_circle.name]),
                      message: 'fam_delete_body'.tr(),
                      confirm: 'fam_delete'.tr(),
                      action: () => _repo.deleteCircle(_circle.id),
                    ),
                child: Text(
                  'fam_delete_family'.tr(),
                  style: TextStyle(color: error),
                ),
              ),
            ] else ...[
              Text(_circle.name, style: e.headline),
              if (_circle.description.isNotEmpty) ...[
                AppSpacing.gapXs,
                Text(_circle.description),
              ],
              AppSpacing.gapXl,
              FamilyNote(text: 'fam_leave_hint'.tr()),
              AppSpacing.gapLg,
              TextButton(
                onPressed:
                    () => _exit(
                      title: 'fam_leave_title'.tr(args: [_circle.name]),
                      message: 'fam_leave_body'.tr(),
                      confirm: 'fam_leave'.tr(),
                      action: () => _repo.leaveCircle(_circle.id),
                    ),
                child: Text('fam_leave'.tr(), style: TextStyle(color: error)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
