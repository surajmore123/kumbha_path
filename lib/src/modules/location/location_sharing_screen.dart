import 'dart:async';
import 'dart:io' show Platform;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:kumbha_path/src/components/components.dart';
import 'package:kumbha_path/src/constant/design_system/design_system.dart';
import 'package:kumbha_path/src/modules/family/data/family_repository.dart';
import 'package:kumbha_path/src/modules/family/family_home_screen.dart'
    show FamilyArgs;
import 'package:kumbha_path/src/modules/family/models/family_models.dart';
import 'package:kumbha_path/src/modules/family/widgets/family_parts.dart';
import 'package:kumbha_path/src/modules/journey/widgets/journey_ui.dart'
    show confirmJourneyAction, showJourneySnack;
import 'package:kumbha_path/src/modules/location/data/location_repository.dart';
import 'package:kumbha_path/src/modules/location/data/location_tracker.dart';
import 'package:kumbha_path/src/modules/location/models/location_models.dart';
import 'package:kumbha_path/src/modules/location/widgets/location_parts.dart';

/// `/locationSharing`: start sharing, or see and control what's being shared.
class LocationSharingScreen extends StatefulWidget {
  const LocationSharingScreen({
    super.key,
    required this.args,
    this.repository,
    this.familyRepository,
    this.tracker,
  });

  final FamilyArgs args;
  final LocationRepository? repository;
  final FamilyRepository? familyRepository;
  final LocationTracker? tracker;

  @override
  State<LocationSharingScreen> createState() => _LocationSharingScreenState();
}

class _LocationSharingScreenState extends State<LocationSharingScreen> {
  late final LocationRepository _repo =
      widget.repository ?? LocationServices.repository;
  late final FamilyRepository _family =
      widget.familyRepository ?? FamilyServices.repository;
  late final LocationTracker _tracker =
      widget.tracker ?? LocationSharing.tracker;

  List<SharingSession> _sessions = const [];
  List<FamilyMember> _members = const [];
  bool _loading = true;
  Object? _error;
  Timer? _ticker;

  String get _familyId => widget.args.circle.id;

  @override
  void initState() {
    super.initState();
    _tracker.addListener(_changed);
    // The time left and "last update" count on by themselves.
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) => _changed());
    _load();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _tracker.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final results = await Future.wait([
        _repo.sessions(_familyId),
        _family.members(_familyId),
      ]);
      await _tracker.checkAccess();
      if (!mounted) return;
      setState(() {
        _sessions = results[0] as List<SharingSession>;
        _members = results[1] as List<FamilyMember>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _started(SharingSession session) {
    setState(() => _sessions = [session, ..._sessions]);
  }

  void _replace(SharingSession session) {
    setState(() {
      _sessions = [
        for (final s in _sessions)
          if (s.id != session.id) s else if (session.isOpen) session,
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    final failed = _error;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (failed != null) {
      body = AppErrorView(message: locationErrorText(failed), onRetry: _load);
    } else {
      final reporting = _sessions.any((s) => s.reportsFromMe);
      final ended = _tracker.endedStatus;
      body = RefreshIndicator(
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
            if (ended != null && _sessions.isEmpty) ...[
              FamilyNote(
                text:
                    (ended == 'expired' ? 'loc_my_expired' : 'loc_my_stopped')
                        .tr(),
              ),
              AppSpacing.gapLg,
            ],
            for (final session in _sessions) ...[
              _ManageCard(
                key: ValueKey(session.id),
                session: session,
                familyId: _familyId,
                repository: _repo,
                tracker: _tracker,
                onChanged: _replace,
              ),
              AppSpacing.gapXl,
            ],
            if (!reporting)
              _StartForm(
                familyId: _familyId,
                myMemberId: widget.args.circle.myMemberId,
                presetMemberId: widget.args.memberId,
                members: _members,
                busyMembers: {for (final s in _sessions) s.memberId},
                repository: _repo,
                tracker: _tracker,
                onStarted: _started,
              ),
          ],
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text('loc_sharing_title'.tr())),
      body: SafeArea(child: body),
    );
  }
}

String _backgroundNote() =>
    (Platform.isIOS ? 'loc_background_ios' : 'loc_background_android').tr();

/// What the phone will and won't allow, with the way to fix it.
class _AccessNote extends StatelessWidget {
  const _AccessNote({required this.tracker});

  final LocationTracker tracker;

  @override
  Widget build(BuildContext context) {
    Widget note(String title, String text, {Widget? action}) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: FamilyNote(
        title: title.tr(),
        text: text.tr(),
        trailing: [if (action != null) action],
      ),
    );
    final settings = TextButton(
      onPressed: tracker.openAppSettings,
      child: Text('loc_open_settings'.tr()),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        switch (tracker.permit) {
          LocationPermit.servicesOff => note(
            'loc_gps_off_title',
            'loc_gps_off_body',
            action: TextButton(
              onPressed: tracker.openLocationSettings,
              child: Text('loc_turn_on_gps'.tr()),
            ),
          ),
          LocationPermit.blocked => note(
            'loc_blocked_title',
            'loc_blocked_body',
            action: settings,
          ),
          LocationPermit.denied => note('loc_ask_title', 'loc_ask_body'),
          LocationPermit.approximate => note(
            'loc_approx_title',
            'loc_approx_body',
            action: settings,
          ),
          LocationPermit.allowed => const SizedBox.shrink(),
        },
        if (!tracker.notificationsAllowed)
          note(
            'loc_notifications_title',
            'loc_notifications_body',
            action: settings,
          ),
      ],
    );
  }
}

class _StartForm extends StatefulWidget {
  const _StartForm({
    required this.familyId,
    required this.myMemberId,
    required this.presetMemberId,
    required this.members,
    required this.busyMembers,
    required this.repository,
    required this.tracker,
    required this.onStarted,
  });

  final String familyId;
  final String? myMemberId;
  final String? presetMemberId;
  final List<FamilyMember> members;
  final Set<String> busyMembers;
  final LocationRepository repository;
  final LocationTracker tracker;
  final ValueChanged<SharingSession> onStarted;

  @override
  State<_StartForm> createState() => _StartFormState();
}

class _StartFormState extends State<_StartForm> {
  static const _untilStopped = 'until_stopped';

  late String? _subject = widget.presetMemberId ?? widget.myMemberId;
  EligibleViewers? _eligible;
  final _chosen = <String>{};
  String _duration = '60';
  bool _consent = false;
  bool _busy = false;
  String? _problem;

  /// Yourself, and those in your care. An adult is never on this list unless
  /// it's you: nobody can start someone else's sharing.
  List<FamilyMember> get _subjects => [
    for (final m in widget.members)
      if (m.id == widget.myMemberId ||
          (m.isDependent && m.permissions.editProfile))
        if (!widget.busyMembers.contains(m.id)) m,
  ];

  FamilyMember? get _person =>
      widget.members.where((m) => m.id == _subject).firstOrNull;

  bool get _forDependent => _person?.isDependent ?? false;

  @override
  void initState() {
    super.initState();
    if (!_subjects.any((m) => m.id == _subject)) {
      _subject = _subjects.firstOrNull?.id;
    }
    _loadEligible();
  }

  Future<void> _loadEligible() async {
    final subject = _subject;
    if (subject == null) return;
    setState(() {
      _eligible = null;
      _chosen.clear();
      _problem = null;
    });
    try {
      final eligible = await widget.repository.eligible(
        widget.familyId,
        memberId: subject == widget.myMemberId ? null : subject,
      );
      if (mounted) setState(() => _eligible = eligible);
    } catch (e) {
      if (mounted) setState(() => _problem = locationErrorText(e));
    }
  }

  Future<void> _start() async {
    if (_chosen.isEmpty) {
      setState(() => _problem = 'loc_choose_someone'.tr());
      return;
    }
    if (!_consent) {
      setState(() => _problem = 'loc_need_consent'.tr());
      return;
    }
    setState(() {
      _busy = true;
      _problem = null;
    });
    final tracker = widget.tracker;
    tracker
      ..notificationTitle = 'loc_notification_title'.tr()
      ..notificationText = 'loc_notification_text'.tr();
    try {
      final permit = await tracker.requestAccess();
      if (permit != LocationPermit.allowed &&
          permit != LocationPermit.approximate) {
        if (mounted) {
          setState(() {
            _busy = false;
            _problem = 'loc_permission_needed'.tr();
          });
        }
        return;
      }
      final session = await widget.repository.start(
        widget.familyId,
        consent: _consent,
        recipientIds: _chosen.toList(),
        memberId: _subject == widget.myMemberId ? null : _subject,
        minutes: _duration == _untilStopped ? null : int.parse(_duration),
        untilStopped: _duration == _untilStopped,
      );
      await tracker.begin(session);
      if (!mounted) return;
      widget.onStarted(session);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _problem = locationErrorText(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = context.editorial;
    final colors = context.colorScheme;
    final subjects = _subjects;
    final eligible = _eligible;
    if (subjects.isEmpty) {
      return AppEmptyState(
        icon: Icons.share_location_rounded,
        title: 'loc_nothing_to_start'.tr(),
      );
    }
    final person = _person;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text('loc_start_title'.tr(), style: e.headline),
        ),
        AppSpacing.gapXs,
        Text('loc_start_intro'.tr()),
        AppSpacing.gapLg,
        if (subjects.length > 1) ...[
          FieldLabel('loc_whose'.tr()),
          PillChoices(
            values: [for (final m in subjects) m.id],
            labelOf:
                (id) =>
                    id == widget.myMemberId
                        ? 'loc_you'.tr()
                        : subjects.firstWhere((m) => m.id == id).name,
            selected: _subject,
            onChanged: (id) {
              setState(() => _subject = id);
              _loadEligible();
            },
          ),
          AppSpacing.gapMd,
        ],
        if (_forDependent && person != null) ...[
          FamilyNote(text: 'loc_dependent_note'.tr(args: [person.name])),
          AppSpacing.gapMd,
        ],
        FieldLabel('loc_who_can_see'.tr()),
        if (eligible == null)
          const SkeletonLine()
        else if (eligible.people.isEmpty)
          Text('loc_no_one_eligible'.tr(), style: e.meta)
        else
          for (final viewer in eligible.people)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _chosen.contains(viewer.memberId),
              title: Text(viewer.name),
              controlAffinity: ListTileControlAffinity.leading,
              onChanged:
                  (on) => setState(() {
                    on == true
                        ? _chosen.add(viewer.memberId)
                        : _chosen.remove(viewer.memberId);
                  }),
            ),
        AppSpacing.gapMd,
        FieldLabel('loc_how_long'.tr()),
        PillChoices(
          values: [for (final m in sharingMinutes) '$m', _untilStopped],
          labelOf:
              (v) =>
                  v == _untilStopped
                      ? 'loc_until_stopped'.tr()
                      : durationLabel(int.parse(v)),
          selected: _duration,
          onChanged: (v) => setState(() => _duration = v),
        ),
        if (_duration == _untilStopped && eligible != null) ...[
          AppSpacing.gapXs,
          Text(
            'loc_until_stopped_note'.tr(args: ['${eligible.maxHours}']),
            style: e.meta,
          ),
        ],
        AppSpacing.gapLg,
        _AccessNote(tracker: widget.tracker),
        FamilyNote(title: 'loc_how_title'.tr(), text: _backgroundNote()),
        AppSpacing.gapMd,
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _consent,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(
            _forDependent && person != null
                ? 'loc_consent_dependent'.tr(args: [person.name])
                : 'loc_consent'.tr(),
          ),
          onChanged: (on) => setState(() => _consent = on == true),
        ),
        if (_problem != null) ...[
          AppSpacing.gapSm,
          Text(_problem!, style: TextStyle(color: colors.error)),
        ],
        AppSpacing.gapMd,
        AppButton(
          label: 'loc_start'.tr(),
          leadingIcon: Icons.share_location_rounded,
          isLoading: _busy,
          onPressed: _busy ? null : _start,
        ),
      ],
    );
  }
}

class _ManageCard extends StatefulWidget {
  const _ManageCard({
    super.key,
    required this.session,
    required this.familyId,
    required this.repository,
    required this.tracker,
    required this.onChanged,
  });

  final SharingSession session;
  final String familyId;
  final LocationRepository repository;
  final LocationTracker tracker;
  final ValueChanged<SharingSession> onChanged;

  @override
  State<_ManageCard> createState() => _ManageCardState();
}

class _ManageCardState extends State<_ManageCard> {
  bool _busy = false;

  SharingSession get _session => widget.session;
  bool get _here => _session.id == widget.tracker.sessionId;

  Future<void> _act(
    Future<SharingSession> Function() action, {
    String? done,
  }) async {
    setState(() => _busy = true);
    try {
      final session = await action();
      await widget.tracker.sync(session);
      if (!mounted) return;
      widget.onChanged(session);
      if (done != null) showJourneySnack(context, done.tr());
    } catch (e) {
      if (mounted) showJourneySnack(context, locationErrorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stop() async {
    final sure = await confirmJourneyAction(
      context,
      title: 'loc_stop_title'.tr(),
      message: 'loc_stop_body'.tr(),
      confirm: 'loc_stop'.tr(),
      destructive: true,
    );
    if (!sure || !mounted) return;
    setState(() => _busy = true);
    final told = await widget.tracker.stop(_session.id);
    if (!mounted) return;
    setState(() => _busy = false);
    widget.onChanged(
      SharingSession(
        id: _session.id,
        memberId: _session.memberId,
        memberName: _session.memberName,
        status: 'stopped',
        remainingSeconds: 0,
      ),
    );
    showJourneySnack(
      context,
      (told ? 'loc_stopped' : 'loc_stopped_offline').tr(),
    );
  }

  Future<void> _changePeople() async {
    final EligibleViewers eligible;
    try {
      eligible = await widget.repository.eligible(
        widget.familyId,
        memberId: _session.memberId,
      );
    } catch (e) {
      if (mounted) showJourneySnack(context, locationErrorText(e));
      return;
    }
    if (!mounted) return;
    final chosen = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder:
          (_) => _PeopleSheet(
            people: eligible.people,
            chosen: {for (final r in _session.recipients) r.memberId},
          ),
    );
    if (chosen == null || !mounted) return;
    final sure = await confirmJourneyAction(
      context,
      title: 'loc_change_people_title'.tr(),
      message: 'loc_change_people_body'.plural(chosen.length),
      confirm: 'loc_save'.tr(),
    );
    if (sure) {
      await _act(
        () => widget.repository.setRecipients(_session.id, chosen.toList()),
        done: 'loc_saved',
      );
    }
  }

  Future<void> _changeTime() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => const _TimeSheet(),
    );
    if (choice == null || !mounted) return;
    final until = choice == _TimeSheet.untilStopped;
    final sure = await confirmJourneyAction(
      context,
      title: 'loc_change_time_title'.tr(),
      message: 'loc_change_time_body'.tr(),
      confirm: 'loc_save'.tr(),
    );
    if (sure) {
      await _act(
        () => widget.repository.changeDuration(
          _session.id,
          minutes: until ? null : int.parse(choice),
          untilStopped: until,
        ),
        done: 'loc_saved',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = context.editorial;
    final session = _session;
    final tracker = widget.tracker;
    final now = DateTime.now();
    final paused = session.isPaused;
    final interrupted = _here && tracker.state == TrackerState.interrupted;
    final last =
        _here ? tracker.lastSentAt ?? session.lastUpdate : session.lastUpdate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(session.memberName, style: e.headline),
        ),
        AppSpacing.gapXs,
        // Never "Live" here: that's for a position someone has actually seen.
        if (paused || interrupted) ...[
          FreshnessTag(paused ? Freshness.paused : Freshness.unavailable),
          AppSpacing.gapSm,
        ],
        Text(
          paused
              ? 'loc_status_paused'.tr()
              : interrupted
              ? 'loc_status_interrupted'.tr()
              : 'loc_status_on'.tr(),
        ),
        AppSpacing.gapMd,
        if (_here) _AccessNote(tracker: tracker),
        if (_here && tracker.offline) ...[
          FamilyNote(text: 'loc_sending_later'.tr()),
          AppSpacing.gapMd,
        ],
        if (!session.reportsFromMe) ...[
          FamilyNote(text: 'loc_other_phone'.tr()),
          AppSpacing.gapMd,
        ],
        FactRow(
          label: 'loc_time_left'.tr(),
          value: timeLeftText(session.remainingAt(now)),
        ),
        FactRow(
          label: 'loc_last_update'.tr(),
          value:
              last == null
                  ? 'loc_no_update_yet'.tr()
                  : agoText(now.difference(last).inSeconds),
        ),
        FactRow(
          label: 'loc_battery'.tr(),
          value: 'loc_battery_value'.tr(args: ['${session.updateSeconds}']),
        ),
        AppSpacing.gapMd,
        FieldLabel('loc_who_can_see'.tr()),
        for (final r in session.recipients)
          FactRow(
            label: r.name,
            value:
                r.lastViewedAt == null
                    ? 'loc_not_viewed'.tr()
                    : 'loc_viewed'.tr(
                      args: [
                        agoText(now.difference(r.lastViewedAt!).inSeconds),
                      ],
                    ),
          ),
        AppSpacing.gapMd,
        if (paused)
          AppButton(
            label: 'loc_resume'.tr(),
            leadingIcon: Icons.play_arrow_rounded,
            isLoading: _busy,
            onPressed:
                _busy
                    ? null
                    : () => _act(() => widget.repository.resume(session.id)),
          )
        else
          AppButton.secondary(
            label: 'loc_pause'.tr(),
            leadingIcon: Icons.pause_rounded,
            isLoading: _busy,
            onPressed:
                _busy
                    ? null
                    : () => _act(() => widget.repository.pause(session.id)),
          ),
        AppSpacing.gapSm,
        Row(
          children: [
            Expanded(
              child: AppButton.secondary(
                label: 'loc_change_people'.tr(),
                onPressed: _busy ? null : _changePeople,
              ),
            ),
            AppSpacing.gapSm,
            Expanded(
              child: AppButton.secondary(
                label: 'loc_change_time'.tr(),
                onPressed: _busy ? null : _changeTime,
              ),
            ),
          ],
        ),
        AppSpacing.gapSm,
        TextButton.icon(
          onPressed: _busy ? null : _stop,
          icon: Icon(
            Icons.stop_circle_outlined,
            color: context.colorScheme.error,
          ),
          label: Text(
            'loc_stop'.tr(),
            style: TextStyle(color: context.colorScheme.error),
          ),
        ),
      ],
    );
  }
}

class _PeopleSheet extends StatefulWidget {
  const _PeopleSheet({required this.people, required this.chosen});

  final List<EligibleViewer> people;
  final Set<String> chosen;

  @override
  State<_PeopleSheet> createState() => _PeopleSheetState();
}

class _PeopleSheetState extends State<_PeopleSheet> {
  late final Set<String> _chosen = {...widget.chosen};

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          editorialMargin,
          0,
          editorialMargin,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('loc_change_people'.tr(), style: context.editorial.title),
            AppSpacing.gapSm,
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final viewer in widget.people)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _chosen.contains(viewer.memberId),
                      title: Text(viewer.name),
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged:
                          (on) => setState(() {
                            on == true
                                ? _chosen.add(viewer.memberId)
                                : _chosen.remove(viewer.memberId);
                          }),
                    ),
                ],
              ),
            ),
            AppSpacing.gapSm,
            AppButton(
              label: 'loc_save'.tr(),
              onPressed:
                  _chosen.isEmpty
                      ? null
                      : () => Navigator.pop(context, _chosen),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeSheet extends StatelessWidget {
  const _TimeSheet();

  static const untilStopped = 'until_stopped';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          editorialMargin,
          0,
          editorialMargin,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('loc_change_time'.tr(), style: context.editorial.title),
            AppSpacing.gapXs,
            Text('loc_time_from_now'.tr(), style: context.editorial.meta),
            AppSpacing.gapMd,
            PillChoices(
              values: [for (final m in sharingMinutes) '$m', untilStopped],
              labelOf:
                  (v) =>
                      v == untilStopped
                          ? 'loc_until_stopped'.tr()
                          : durationLabel(int.parse(v)),
              selected: null,
              onChanged: (v) => Navigator.pop(context, v),
            ),
          ],
        ),
      ),
    );
  }
}
