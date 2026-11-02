import 'dart:async';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/modules/emergency/data/emergency_repository.dart';
import 'package:kumbha_path/src/modules/emergency/models/emergency_models.dart';
import 'package:kumbha_path/src/modules/emergency/widgets/sos_parts.dart';
import 'package:kumbha_path/src/modules/family/widgets/family_parts.dart';
import 'package:kumbha_path/src/modules/journey/widgets/journey_ui.dart'
    show openExternal, showJourneySnack;
import 'package:kumbha_path/src/modules/operations/ops_case_screen.dart'
    show SosResponderPanel;
import 'package:kumbha_path/src/modules/location/data/location_tracker.dart';
import 'package:kumbha_path/src/modules/location/widgets/location_parts.dart';
import 'package:kumbha_path/src/modules/lostfound/widgets/lf_parts.dart'
    show dateTimeText;

/// `/sosDetail`: one emergency, for the person who sent it, their family, or a
/// responder. The server decides who sees what. Family can say they've seen it,
/// which is never shown as a responder, and nobody here can change the status
/// fields that belong to responders.
class SosDetailScreen extends StatefulWidget {
  const SosDetailScreen({
    super.key,
    required this.id,
    this.repository,
    this.source = const GeolocatorSource(),
    this.refreshEvery = const Duration(seconds: 20),
  });

  final String id;
  final EmergencyRepository? repository;
  final PositionSource source;
  final Duration refreshEvery;

  @override
  State<SosDetailScreen> createState() => _SosDetailScreenState();
}

class _SosDetailScreenState extends State<SosDetailScreen> {
  late final EmergencyRepository _repo =
      widget.repository ?? EmergencyServices.repository;
  SosDetail? _sos;
  Object? _error;
  bool _stale = false;
  bool _busy = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    _timer?.cancel();
    try {
      final sos = await _repo.detail(widget.id);
      if (!mounted) return;
      setState(() {
        _sos = sos;
        _error = null;
        _stale = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (_sos == null) _error = e;
        _stale = _sos != null;
      });
    }
    if (mounted && (_sos?.isActive ?? false)) {
      _timer = Timer(widget.refreshEvery, _load);
    }
  }

  Future<void> _act(Future<SosDetail> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      final sos = await action();
      if (!mounted) return;
      setState(() => _sos = sos);
      showJourneySnack(context, done.tr());
    } catch (e) {
      if (mounted) showJourneySnack(context, sosErrorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final reason = await askForText(
      context,
      title: 'sos_cancel_title'.tr(),
      hint: 'sos_cancel_hint'.tr(),
      confirm: 'sos_cancel'.tr(),
      maxLength: 300,
    );
    if (reason != null) {
      await _act(() => _repo.cancel(widget.id, reason), 'sos_cancelled');
    }
  }

  Future<void> _addInfo() async {
    final body = await askForText(
      context,
      title: 'sos_add_info'.tr(),
      hint: 'sos_add_info_hint'.tr(),
      confirm: 'sos_send'.tr(),
    );
    if (body != null) {
      await _act(() => _repo.addInfo(widget.id, body), 'sos_info_sent');
    }
  }

  /// One position, once, because the person pressed this. It starts no tracking.
  Future<void> _updateLocation() async {
    setState(() => _busy = true);
    var permit = await widget.source.check();
    if (permit == LocationPermit.denied) {
      permit = await widget.source.request();
    }
    final usable =
        permit == LocationPermit.allowed ||
        permit == LocationPermit.approximate;
    final fix = usable ? await widget.source.current() : null;
    if (!mounted) return;
    setState(() => _busy = false);
    if (fix != null) {
      await _act(
        () => _repo.updateLocation(widget.id, {
          'latitude': fix.latitude.toStringAsFixed(6),
          'longitude': fix.longitude.toStringAsFixed(6),
          if (fix.accuracyM != null) 'accuracy_m': fix.accuracyM,
          'location_at': fix.capturedAt.toUtc().toIso8601String(),
        }),
        'sos_location_sent',
      );
      return;
    }
    final text = await askForText(
      context,
      title: 'sos_where'.tr(),
      hint: 'sos_where_hint'.tr(),
      confirm: 'sos_send'.tr(),
      maxLength: 240,
    );
    if (text != null) {
      await _act(
        () => _repo.updateLocation(widget.id, {'location_text': text}),
        'sos_location_sent',
      );
    }
  }

  Future<void> _call() async {
    try {
      final phone = await _repo.contact(widget.id);
      if (!mounted || phone == null) return;
      await confirmAndDial(
        context,
        number: phone,
        title: 'sos_call_person'.tr(args: [_sos?.personName ?? '']),
        message: 'sos_call_person_body'.tr(),
      );
    } catch (e) {
      if (mounted) showJourneySnack(context, sosErrorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final sos = _sos;
    final failed = _error;
    return Scaffold(
      appBar: AppBar(title: Text('sos_detail_title'.tr())),
      body: SafeArea(
        child:
            sos != null
                ? RefreshIndicator(onRefresh: _load, child: _body(sos))
                : failed != null
                ? ListView(
                  padding: const EdgeInsets.all(editorialMargin),
                  children: [
                    AppErrorView(
                      compact: true,
                      message: sosErrorText(failed),
                      onRetry: _load,
                    ),
                    AppSpacing.gapMd,
                    const DirectCallButtons(),
                  ],
                )
                : const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _body(SosDetail sos) {
    final e = context.editorial;
    final at = sos.createdAt;
    final written = sos.writtenAt;
    final located = sos.locationAt;
    final accuracy = sos.accuracyM;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        editorialMargin,
        AppSpacing.sm,
        editorialMargin,
        AppSpacing.huge,
      ),
      children: [
        Text(sos.reference, style: e.meta),
        Semantics(
          header: true,
          child: Text(sosCategoryLabel(sos.category), style: e.headline),
        ),
        if (!sos.isOwner) Text(sos.personName, style: e.title),
        if (at != null) Text(dateTimeText(context, at), style: e.meta),
        if (written != null)
          Text(
            'sos_written_earlier'.tr(args: [dateTimeText(context, written)]),
            style: e.meta,
          ),
        AppSpacing.gapSm,
        Semantics(
          liveRegion: true,
          child: Text(sosStatusLabel(sos.status), style: e.title),
        ),
        Text('sos_status_${sos.status}_means'.tr(), style: e.meta),
        if (_stale) ...[AppSpacing.gapSm, FamilyNote(text: 'sos_stale'.tr())],
        if (sos.isActive) ...[
          AppSpacing.gapMd,
          const NoDispatchNote(),
          AppSpacing.gapSm,
          const DirectCallButtons(),
        ],
        AppSpacing.gapLg,
        SosStagesCard(sos: sos),
        if (sos.role == 'ops') ...[
          AppSpacing.gapLg,
          SosResponderPanel(sos: sos, onChanged: _load),
        ],
        if (sos.isFamily && sos.isActive) ...[
          AppSpacing.gapMd,
          if (sos.iAcknowledged)
            Text('sos_you_acknowledged'.tr(), style: e.meta)
          else ...[
            AppButton(
              label: 'sos_acknowledge_family'.tr(),
              isLoading: _busy,
              onPressed:
                  _busy
                      ? null
                      : () => _act(
                        () => _repo.acknowledgeAsFamily(widget.id),
                        'sos_acknowledged_done',
                      ),
            ),
            AppSpacing.gapXs,
            Text('sos_acknowledge_note'.tr(), style: e.meta),
          ],
          AppSpacing.gapSm,
          AppButton.secondary(
            label: 'sos_call_person'.tr(args: [sos.personName]),
            leadingIcon: Icons.call_outlined,
            onPressed: _call,
          ),
        ],
        if (sos.isOwner && sos.family.isNotEmpty) ...[
          AppSpacing.gapLg,
          Text('sos_family_title'.tr(), style: e.title),
          for (final person in sos.family)
            FactRow(
              label: person.name,
              value:
                  person.acknowledgedAt != null
                      ? 'sos_person_acknowledged'.tr()
                      : person.reachedAppAt != null
                      ? 'sos_person_reached'.tr()
                      : 'sos_person_${person.notification}'.tr(),
            ),
        ],
        if (sos.hasPosition || sos.locationText.isNotEmpty) ...[
          AppSpacing.gapLg,
          Text('sos_location_title'.tr(), style: e.title),
          if (sos.locationText.isNotEmpty) Text(sos.locationText),
          if (located != null)
            Text(
              [
                'loc_updated'.tr(
                  args: [agoText(DateTime.now().difference(located).inSeconds)],
                ),
                if (accuracy != null) accuracyText(accuracy),
              ].join(' · '),
              style: e.meta,
            ),
          Text('sos_location_once'.tr(), style: e.meta),
          if (sos.hasPosition && !sos.isOwner)
            TextButton.icon(
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              onPressed:
                  () => openExternal(
                    context,
                    'https://www.google.com/maps/search/?api=1&query=${sos.latitude},${sos.longitude}',
                  ),
              icon: const Icon(Icons.place_outlined, size: 18),
              label: Text('sos_open_map'.tr()),
            ),
        ],
        if (sos.details.isNotEmpty) ...[
          AppSpacing.gapLg,
          Text('sos_details'.tr(), style: e.title),
          Text(sos.details),
        ],
        if (sos.isOwner && sos.isActive) ...[
          AppSpacing.gapLg,
          AppButton.secondary(
            label: 'sos_update_location'.tr(),
            leadingIcon: Icons.my_location_rounded,
            isLoading: _busy,
            onPressed: _busy ? null : _updateLocation,
          ),
          AppSpacing.gapSm,
          AppButton.secondary(
            label: 'sos_add_info'.tr(),
            onPressed: _busy ? null : _addInfo,
          ),
        ],
        AppSpacing.gapSm,
        AppButton.secondary(
          label: 'sos_nearby'.tr(),
          leadingIcon: Icons.local_hospital_outlined,
          onPressed: () => Navigator.pushNamed(context, '/sosAssistance'),
        ),
        if (sos.resolutionNote.isNotEmpty) ...[
          AppSpacing.gapLg,
          Text('sos_resolution'.tr(), style: e.title),
          Text(sos.resolutionNote),
        ],
        if (sos.cancelReason.isNotEmpty) ...[
          AppSpacing.gapLg,
          Text('sos_cancel_reason'.tr(), style: e.title),
          Text(sos.cancelReason),
        ],
        if (sos.updates.isNotEmpty) ...[
          AppSpacing.gapLg,
          Text('sos_updates'.tr(), style: e.title),
          AppSpacing.gapXs,
          for (final note in sos.updates)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('sos_note_${note.kind}'.tr(), style: e.meta),
                  if (note.body.isNotEmpty) Text(note.body),
                  if (note.at != null)
                    Text(dateTimeText(context, note.at!), style: e.meta),
                ],
              ),
            ),
        ],
        AppSpacing.gapLg,
        Text('sos_timeline'.tr(), style: e.title),
        AppSpacing.gapSm,
        SosTimeline(sos: sos),
        if (sos.isOwner && sos.isActive) ...[
          AppSpacing.gapLg,
          TextButton(
            onPressed: _busy ? null : _cancel,
            child: Text(
              'sos_cancel'.tr(),
              style: TextStyle(color: context.colorScheme.error),
            ),
          ),
        ],
      ],
    );
  }
}

/// `/sosHistory`: your own emergencies, and any you were told about.
class SosHistoryScreen extends StatefulWidget {
  const SosHistoryScreen({super.key, this.repository});

  final EmergencyRepository? repository;

  @override
  State<SosHistoryScreen> createState() => _SosHistoryScreenState();
}

class _SosHistoryScreenState extends State<SosHistoryScreen> {
  late final EmergencyRepository _repo =
      widget.repository ?? EmergencyServices.repository;
  String _scope = 'mine';
  List<SosRow>? _rows;
  Object? _error;

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
    try {
      final page = await _repo.history(family: _scope == 'family');
      if (mounted) setState(() => _rows = page.rows);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = context.editorial;
    final rows = _rows;
    final failed = _error;
    return Scaffold(
      appBar: AppBar(title: Text('sos_history_title'.tr())),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(editorialMargin),
          children: [
            PillChoices(
              values: const ['mine', 'family'],
              labelOf: (v) => 'sos_scope_$v'.tr(),
              selected: _scope,
              onChanged: (v) {
                setState(() => _scope = v);
                _load();
              },
            ),
            AppSpacing.gapMd,
            if (failed != null)
              AppErrorView(
                compact: true,
                message: sosErrorText(failed),
                onRetry: _load,
              )
            else if (rows == null)
              const SkeletonLine(height: 72)
            else if (rows.isEmpty)
              AppEmptyState(
                compact: true,
                icon: Icons.shield_outlined,
                title: 'sos_history_empty'.tr(),
              )
            else
              for (final row in rows)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    sosCategoryIcon(row.category),
                    color:
                        row.isActive
                            ? context.colorScheme.error
                            : context.colorScheme.outline,
                  ),
                  title: Text(sosCategoryLabel(row.category)),
                  subtitle: Text(
                    [
                      if (_scope == 'family') row.personName,
                      sosStatusLabel(row.status),
                      if (row.createdAt != null)
                        dateTimeText(context, row.createdAt!),
                    ].join(' · '),
                    style: e.meta,
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
    );
  }
}
