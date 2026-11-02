import 'dart:async';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/modules/emergency/data/emergency_repository.dart';
import 'package:kumbha_path/src/modules/emergency/models/emergency_models.dart';
import 'package:kumbha_path/src/modules/emergency/widgets/sos_parts.dart';
import 'package:kumbha_path/src/modules/family/models/family_models.dart'
    show EmergencyContact;
import 'package:kumbha_path/src/modules/family/offline/contact_sync.dart';
import 'package:kumbha_path/src/modules/family/widgets/family_parts.dart';
import 'package:kumbha_path/src/modules/journey/widgets/journey_ui.dart'
    show confirmJourneyAction, showJourneySnack;
import 'package:kumbha_path/src/modules/location/data/location_tracker.dart';
import 'package:kumbha_path/src/modules/location/models/location_models.dart';
import 'package:kumbha_path/src/modules/lostfound/widgets/lf_parts.dart'
    show dateTimeText;

/// Saved contacts on this phone, which still work with no connection.
Future<List<EmergencyContact>> savedEmergencyContacts() async {
  try {
    final sync = FamilyContacts.service;
    final out = <EmergencyContact>[];
    for (final circle in await sync.savedCircles()) {
      final view = await sync.local(ContactScope(circle.id));
      out.addAll(view.contacts.map((row) => row.contact));
    }
    return out;
  } catch (_) {
    return const [];
  }
}

enum _Stage { idle, counting, sending, failed }

/// `/sos`: asking for help. One category, one deliberate action, and a plain
/// account of what will and won't happen.
class SosScreen extends StatefulWidget {
  const SosScreen({
    super.key,
    this.repository,
    this.unsent,
    this.source = const GeolocatorSource(),
    this.contacts = savedEmergencyContacts,
    this.locationWait = const Duration(seconds: 6),
    this.countdownFrom = 5,
  });

  final EmergencyRepository? repository;
  final UnsentSos? unsent;
  final PositionSource source;
  final Future<List<EmergencyContact>> Function() contacts;

  /// How long a position may hold up an emergency. After this it's sent without.
  final Duration locationWait;
  final int countdownFrom;

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  late final EmergencyRepository _repo =
      widget.repository ?? EmergencyServices.repository;
  late final UnsentSos _unsent = widget.unsent ?? EmergencyServices.unsent;

  SosOverview _overview = const SosOverview();
  bool _overviewLoaded = false;
  LocationPermit? _permit;
  List<EmergencyContact> _contacts = const [];
  SosDraft? _saved;

  _Stage _stage = _Stage.idle;
  String _category = 'other';
  final _where = TextEditingController();
  final _details = TextEditingController();
  int _count = 0;
  Timer? _ticker;
  SosDraft? _failedDraft;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _where.dispose();
    _details.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final saved = await _unsent.load();
    final permit = await widget.source.check();
    final contacts = await widget.contacts();
    if (mounted) {
      setState(() {
        _saved = saved;
        _permit = permit;
        _contacts = contacts;
      });
    }
    try {
      final overview = await _repo.overview();
      if (mounted) {
        setState(() {
          _overview = overview;
          _overviewLoaded = true;
        });
      }
    } catch (_) {
      // The screen still works: the SOS itself says whether it got through.
    }
  }

  Future<void> _askPermission() async {
    final permit = await widget.source.request();
    if (mounted) setState(() => _permit = permit);
  }

  void _startCountdown() {
    setState(() {
      _stage = _Stage.counting;
      _count = widget.countdownFrom;
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
      } else if (_count <= 1) {
        timer.cancel();
        unawaited(_send());
      } else {
        setState(() => _count--);
      }
    });
  }

  void _cancelCountdown() {
    _ticker?.cancel();
    setState(() => _stage = _Stage.idle);
    showJourneySnack(context, 'sos_not_sent_cancelled'.tr());
  }

  /// Only if it's already allowed, and only briefly: nothing about location
  /// may stand between someone and their SOS.
  Future<LocationFix?> _position() async {
    try {
      final permit = await widget.source.check();
      if (permit != LocationPermit.allowed &&
          permit != LocationPermit.approximate) {
        return null;
      }
      return await widget.source.current().timeout(widget.locationWait);
    } catch (_) {
      return null;
    }
  }

  Future<void> _send() async {
    setState(() => _stage = _Stage.sending);
    final fix = await _position();
    final draft = SosDraft(
      clientId: newContactId(),
      category: _category,
      writtenAt: DateTime.now(),
      details: _details.text.trim(),
      locationText: _where.text.trim(),
      latitude: fix?.latitude,
      longitude: fix?.longitude,
      accuracyM: fix?.accuracyM,
      locationAt: fix?.capturedAt,
    );
    await _submit(draft);
  }

  /// One automatic retry for a dropped request. The same id means the server
  /// can't create it twice.
  Future<void> _submit(SosDraft draft, {bool delayed = false}) async {
    if (mounted) setState(() => _stage = _Stage.sending);
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final sos = await _repo.create(draft, delayed: delayed);
        await _unsent.clear();
        if (mounted) _openDetail(sos.id);
        return;
      } on SosAlreadyActive catch (open) {
        await _unsent.clear();
        if (mounted) _openDetail(open.id);
        return;
      } catch (e) {
        if (!isNetworkFailure(e)) break;
      }
    }
    await _unsent.save(draft);
    if (!mounted) return;
    setState(() {
      _failedDraft = draft;
      _saved = draft;
      _stage = _Stage.failed;
    });
  }

  void _openDetail(String id) {
    Navigator.pushReplacementNamed(context, '/sosDetail', arguments: id);
  }

  Future<void> _sendSaved(SosDraft draft) async {
    final sure = await confirmJourneyAction(
      context,
      title: 'sos_saved_send_title'.tr(),
      message: 'sos_saved_send_body'.tr(
        args: [dateTimeText(context, draft.writtenAt)],
      ),
      confirm: 'sos_saved_send'.tr(),
    );
    if (sure) await _submit(draft, delayed: true);
  }

  Future<void> _discardSaved() async {
    final sure = await confirmJourneyAction(
      context,
      title: 'sos_saved_discard_title'.tr(),
      message: 'sos_saved_discard_body'.tr(),
      confirm: 'sos_saved_discard'.tr(),
      destructive: true,
    );
    if (!sure) return;
    await _unsent.clear();
    if (mounted) setState(() => _saved = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('sos_title'.tr()),
        actions: [
          IconButton(
            tooltip: 'sos_history_title'.tr(),
            icon: const Icon(Icons.history_rounded),
            onPressed: () => Navigator.pushNamed(context, '/sosHistory'),
          ),
        ],
      ),
      body: SafeArea(
        child: switch (_stage) {
          _Stage.counting => _countdown(),
          _Stage.sending => _sending(),
          _Stage.failed => _failed(),
          _Stage.idle => _main(),
        },
      ),
    );
  }

  Widget _countdown() {
    final e = context.editorial;
    final colors = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.all(editorialMargin),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'sos_sending_in'.tr(),
            textAlign: TextAlign.center,
            style: e.headline,
          ),
          AppSpacing.gapMd,
          Semantics(
            liveRegion: true,
            child: Text(
              '$_count',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 96,
                fontWeight: FontWeight.w800,
                color: colors.error,
              ),
            ),
          ),
          AppSpacing.gapLg,
          SizedBox(
            height: 64,
            child: AppButton(
              label: 'sos_cancel_now'.tr(),
              onPressed: _cancelCountdown,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sending() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          AppSpacing.gapMd,
          Semantics(liveRegion: true, child: Text('sos_sending'.tr())),
        ],
      ),
    );
  }

  /// Nothing went through, and it says so before anything else.
  Widget _failed() {
    final e = context.editorial;
    final draft = _failedDraft;
    return ListView(
      padding: const EdgeInsets.all(editorialMargin),
      children: [
        Semantics(
          liveRegion: true,
          child: Text('sos_failed_title'.tr(), style: e.headline),
        ),
        AppSpacing.gapXs,
        Text('sos_failed_body'.tr()),
        AppSpacing.gapLg,
        DirectCallButtons(numbers: _overview.numbers),
        AppSpacing.gapSm,
        if (draft != null)
          AppButton(
            label: 'common_retry'.tr(),
            leadingIcon: Icons.refresh_rounded,
            onPressed: () => _submit(draft),
          ),
        AppSpacing.gapSm,
        Text('sos_failed_saved'.tr(), style: e.meta),
        AppSpacing.gapSm,
        TextButton(
          onPressed: () => setState(() => _stage = _Stage.idle),
          child: Text('sos_back'.tr()),
        ),
      ],
    );
  }

  Widget _main() {
    final e = context.editorial;
    final active = _overview.active;
    final saved = _saved;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          editorialMargin,
          AppSpacing.sm,
          editorialMargin,
          AppSpacing.huge,
        ),
        children: [
          if (saved != null) ...[
            _SavedBanner(
              draft: saved,
              onSend: () => _sendSaved(saved),
              onDiscard: _discardSaved,
            ),
            AppSpacing.gapMd,
          ],
          if (active != null) ...[
            _ActiveBanner(
              row: active,
              onOpen:
                  () => Navigator.pushNamed(
                    context,
                    '/sosDetail',
                    arguments: active.id,
                  ),
            ),
            AppSpacing.gapMd,
          ] else ...[
            Center(
              child: SosHoldButton(
                onActivated: _send,
                onAccessibleTap: _startCountdown,
              ),
            ),
            AppSpacing.gapXs,
            Center(
              child: TextButton(
                onPressed: _startCountdown,
                child: Text('sos_use_countdown'.tr()),
              ),
            ),
            AppSpacing.gapXs,
            Text('sos_what_happens'.tr()),
            AppSpacing.gapMd,
          ],
          const NoDispatchNote(),
          AppSpacing.gapMd,
          DirectCallButtons(numbers: _overview.numbers),
          if (active == null) ...[
            AppSpacing.gapLg,
            Text('sos_what_kind'.tr(), style: e.title),
            AppSpacing.gapSm,
            for (final category in sosCategories)
              _CategoryTile(
                icon: sosCategoryIcon(category),
                label: sosCategoryLabel(category),
                selected: category == _category,
                onTap: () => setState(() => _category = category),
              ),
            AppSpacing.gapMd,
            _LocationRow(
              permit: _permit,
              onAllow: _askPermission,
              onOpenSettings: widget.source.openAppSettings,
              onLocationSettings: widget.source.openLocationSettings,
            ),
            AppSpacing.gapSm,
            AppTextField(label: 'sos_where'.tr(), controller: _where),
            AppSpacing.gapSm,
            AppTextField(label: 'sos_details'.tr(), controller: _details),
          ],
          AppSpacing.gapLg,
          Text('sos_who_title'.tr(), style: e.title),
          AppSpacing.gapXs,
          Text(
            !_overviewLoaded
                ? 'sos_who_unknown'.tr()
                : _overview.family.isEmpty
                ? 'sos_who_nobody'.tr()
                : _overview.family.join(', '),
          ),
          if (_contacts.isNotEmpty) ...[
            AppSpacing.gapMd,
            Text('sos_contacts_title'.tr(), style: e.title),
            for (final contact in _contacts)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(contact.name),
                trailing: IconButton(
                  tooltip: 'sos_call_person'.tr(args: [contact.name]),
                  icon: const Icon(Icons.call_outlined),
                  onPressed:
                      () => confirmAndDial(
                        context,
                        number: contact.mobile,
                        title: 'sos_call_person'.tr(args: [contact.name]),
                      ),
                ),
              ),
          ],
          AppSpacing.gapMd,
          AppButton.secondary(
            label: 'sos_nearby'.tr(),
            leadingIcon: Icons.local_hospital_outlined,
            onPressed: () => Navigator.pushNamed(context, '/sosAssistance'),
          ),
        ],
      ),
    );
  }
}

/// A large one-tap choice, with selection shown by more than colour.
class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        minTileHeight: AppSpacing.minTouchTarget + 4,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        tileColor: selected ? colors.surfaceContainerHigh : null,
        leading: Icon(icon, color: selected ? colors.error : colors.primary),
        title: Text(label),
        trailing:
            selected
                ? Icon(Icons.check_circle_rounded, color: colors.error)
                : null,
        onTap: onTap,
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({
    required this.permit,
    required this.onAllow,
    required this.onOpenSettings,
    required this.onLocationSettings,
  });

  final LocationPermit? permit;
  final VoidCallback onAllow;
  final VoidCallback onOpenSettings;
  final VoidCallback onLocationSettings;

  @override
  Widget build(BuildContext context) {
    final (String key, String? action, VoidCallback? onTap) = switch (permit) {
      LocationPermit.allowed => ('sos_loc_allowed', null, null),
      LocationPermit.approximate => ('sos_loc_approx', null, null),
      LocationPermit.servicesOff => (
        'sos_loc_off',
        'loc_turn_on_gps',
        onLocationSettings,
      ),
      LocationPermit.blocked => (
        'sos_loc_blocked',
        'loc_open_settings',
        onOpenSettings,
      ),
      LocationPermit.denied => ('sos_loc_denied', 'sos_loc_allow', onAllow),
      null => ('sos_loc_checking', null, null),
    };
    return FamilyNote(
      title: 'sos_loc_title'.tr(),
      text: key.tr(),
      trailing: [
        if (action != null && onTap != null)
          TextButton(onPressed: onTap, child: Text(action.tr())),
      ],
    );
  }
}

class _ActiveBanner extends StatelessWidget {
  const _ActiveBanner({required this.row, required this.onOpen});

  final SosRow row;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return Material(
      color: colors.errorContainer,
      borderRadius: AppRadius.lgAll,
      child: InkWell(
        borderRadius: AppRadius.lgAll,
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Icon(Icons.sos_rounded, color: colors.onErrorContainer),
              AppSpacing.gapSm,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'sos_active'.tr(args: [row.reference]),
                      style: TextStyle(
                        color: colors.onErrorContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      sosStatusLabel(row.status),
                      style: TextStyle(color: colors.onErrorContainer),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.onErrorContainer),
            ],
          ),
        ),
      ),
    );
  }
}

/// A clearly unsent emergency. It only goes if the person says so now.
class _SavedBanner extends StatelessWidget {
  const _SavedBanner({
    required this.draft,
    required this.onSend,
    required this.onDiscard,
  });

  final SosDraft draft;
  final VoidCallback onSend;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    return FamilyNote(
      title: 'sos_saved_title'.tr(),
      text: 'sos_saved_body'.tr(
        args: [
          sosCategoryLabel(draft.category),
          dateTimeText(context, draft.writtenAt),
        ],
      ),
      trailing: [
        TextButton(onPressed: onSend, child: Text('sos_saved_send'.tr())),
        TextButton(onPressed: onDiscard, child: Text('sos_saved_discard'.tr())),
      ],
    );
  }
}
